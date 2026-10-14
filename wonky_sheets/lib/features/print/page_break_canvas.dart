import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import 'print_controller.dart';

/// Break mode of the print route (11 §7.6): the print range of the current
/// sheet as a read-only, scaled grid with the automatic page breaks as
/// dashed grey lines and the custom breaks as solid lines with handles.
/// Dragging a line moves the break to the nearest row/column boundary
/// (dragging an automatic break makes it custom); dragging it off the grid
/// removes it; clicking a row number or column letter adds (or removes) a
/// break before it. The panel's list editor is the keyboard alternative;
/// *Confirm breaks* writes them (`sheets.print.setPageBreaks`).
class PageBreakCanvas extends StatefulWidget {
  const PageBreakCanvas({super.key, required this.controller});

  final PrintController controller;

  /// The geometry of the last build (tests drive the lines with it).
  @visibleForTesting
  static BreakGeometry? lastGeometry;

  @override
  State<PageBreakCanvas> createState() => _PageBreakCanvasState();
}

/// Layout of the break canvas (content coordinates, px).
@visibleForTesting
class BreakGeometry {
  BreakGeometry({
    required this.rows,
    required this.rowTops,
    required this.cols,
    required this.colLefts,
    required this.scale,
    required this.autoRows,
    required this.autoCols,
    required this.customRows,
    required this.customCols,
  });

  static const headerH = 22.0;
  static const headerW = 44.0;

  /// Sheet row/column indices of the print range, in order, and the
  /// start of each plus the end (length + 1).
  final List<int> rows;
  final List<double> rowTops;
  final List<int> cols;
  final List<double> colLefts;
  final double scale;

  /// Positions (indices into [rows]/[cols]) breaks are before.
  final Set<int> autoRows;
  final Set<int> autoCols;
  final Set<int> customRows;
  final Set<int> customCols;

  double get width => colLefts.last;
  double get height => rowTops.last;

  /// The geometry of [c]'s current sheet with its draft breaks.
  static BreakGeometry? of(PrintController c, double availableWidth) {
    final sheet = c.model.sheet(c.sheetId);
    if (sheet == null) return null;
    final rowH = <int, double>{};
    final colW = <int, double>{};
    final pages = [
      for (final p in c.draftPagination.pages)
        if (p.kind == PageKind.cells && p.sheetId == c.sheetId) p,
    ];
    if (pages.isEmpty) return null;
    final rowStarts = <int>{};
    final colStarts = <int>{};
    for (final p in pages) {
      for (var i = 0; i < p.rows.length; i++) {
        rowH[p.rows[i]] = p.rowHeightsPx[i];
      }
      for (var i = 0; i < p.cols.length; i++) {
        colW[p.cols[i]] = p.colWidthsPx[i];
      }
      if (p.rows.isNotEmpty) rowStarts.add(p.rows.first);
      if (p.cols.isNotEmpty) colStarts.add(p.cols.first);
    }
    final rows = rowH.keys.toList()..sort();
    final cols = colW.keys.toList()..sort();
    if (rows.isEmpty || cols.isEmpty) return null;
    final totalW = cols.fold<double>(0, (s, c) => s + colW[c]!);
    final scale = ((availableWidth - headerW - 32) / math.max(1, totalW)).clamp(
      0.35,
      1.0,
    );
    final rowTops = <double>[headerH];
    for (final r in rows) {
      rowTops.add(rowTops.last + rowH[r]! * scale);
    }
    final colLefts = <double>[headerW];
    for (final col in cols) {
      colLefts.add(colLefts.last + colW[col]! * scale);
    }
    final rowPos = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    final colPos = {for (var i = 0; i < cols.length; i++) cols[i]: i};
    Set<int> custom(List<String> ids, AxisIndex axis, Map<int, int> pos) => {
      for (final id in ids)
        if (pos[axis.indexOf(id)] case final p? when p > 0) p,
    };
    final customRows = custom(c.draftRowBreaks, sheet.rows, rowPos);
    final customCols = custom(c.draftColBreaks, sheet.columns, colPos);
    return BreakGeometry(
      rows: rows,
      rowTops: rowTops,
      cols: cols,
      colLefts: colLefts,
      scale: scale,
      autoRows: {
        for (final r in rowStarts)
          if (rowPos[r] case final p? when p > 0 && !customRows.contains(p)) p,
      },
      autoCols: {
        for (final col in colStarts)
          if (colPos[col] case final p? when p > 0 && !customCols.contains(p))
            p,
      },
      customRows: customRows,
      customCols: customCols,
    );
  }

  /// The boundary position nearest to [y] (1 … rows.length - 1).
  int nearestRow(double y) => _nearest(rowTops, y);
  int nearestCol(double x) => _nearest(colLefts, x);

  static int _nearest(List<double> edges, double v) {
    var best = 1;
    var dist = double.infinity;
    for (var i = 1; i < edges.length - 1; i++) {
      final d = (edges[i] - v).abs();
      if (d < dist) {
        dist = d;
        best = i;
      }
    }
    return best;
  }

  /// The break line near a point (within [slop] px), or null.
  ({bool row, int pos})? hit(Offset p, {double slop = 5}) {
    if (p.dx >= headerW && p.dy >= headerH) {
      for (final i in {...customRows, ...autoRows}) {
        if ((rowTops[i] - p.dy).abs() <= slop) return (row: true, pos: i);
      }
      for (final i in {...customCols, ...autoCols}) {
        if ((colLefts[i] - p.dx).abs() <= slop) return (row: false, pos: i);
      }
    }
    // Handles in the header bands.
    if (p.dx < headerW && p.dy >= headerH) {
      for (final i in customRows) {
        if ((rowTops[i] - p.dy).abs() <= slop + 3) return (row: true, pos: i);
      }
    }
    if (p.dy < headerH && p.dx >= headerW) {
      for (final i in customCols) {
        if ((colLefts[i] - p.dx).abs() <= slop + 3) {
          return (row: false, pos: i);
        }
      }
    }
    return null;
  }

  /// The row (index into [rows]) whose header is at [y], or null.
  int? rowAt(double y) {
    for (var i = 0; i < rows.length; i++) {
      if (y >= rowTops[i] && y < rowTops[i + 1]) return i;
    }
    return null;
  }

  int? colAt(double x) {
    for (var i = 0; i < cols.length; i++) {
      if (x >= colLefts[i] && x < colLefts[i + 1]) return i;
    }
    return null;
  }
}

class _Drag {
  _Drag({required this.row, required this.from, required this.wasCustom});

  final bool row;
  final int from;
  final bool wasCustom;
  int to = 0;
  bool remove = false;
  Offset start = Offset.zero;
}

class _PageBreakCanvasState extends State<PageBreakCanvas> {
  final _v = ScrollController();
  final _h = ScrollController();
  _Drag? _drag;
  Offset? _down;
  MouseCursor _cursor = MouseCursor.defer;

  PrintController get c => widget.controller;

  @override
  void dispose() {
    _v.dispose();
    _h.dispose();
    super.dispose();
  }

  void _commit(BreakGeometry g, _Drag d) {
    final sheet = c.model.sheet(c.sheetId);
    if (sheet == null) return;
    if (d.row) {
      final ids = [...c.draftRowBreaks];
      if (d.wasCustom) ids.remove(sheet.rows.idAt(g.rows[d.from]));
      if (!d.remove) ids.add(sheet.rows.idAt(g.rows[d.to]));
      c.setDraftBreaks(rows: ids);
    } else {
      final ids = [...c.draftColBreaks];
      if (d.wasCustom) ids.remove(sheet.columns.idAt(g.cols[d.from]));
      if (!d.remove) ids.add(sheet.columns.idAt(g.cols[d.to]));
      c.setDraftBreaks(cols: ids);
    }
  }

  /// Click on a row number / column letter: toggles a break before it.
  void _toggleAt(BreakGeometry g, Offset p) {
    final sheet = c.model.sheet(c.sheetId);
    if (sheet == null) return;
    if (p.dx < BreakGeometry.headerW && p.dy >= BreakGeometry.headerH) {
      final i = g.rowAt(p.dy);
      if (i == null || i == 0) return;
      final id = sheet.rows.idAt(g.rows[i]);
      final ids = [...c.draftRowBreaks];
      ids.contains(id) ? ids.remove(id) : ids.add(id);
      c.setDraftBreaks(rows: ids);
    } else if (p.dy < BreakGeometry.headerH && p.dx >= BreakGeometry.headerW) {
      final i = g.colAt(p.dx);
      if (i == null || i == 0) return;
      final id = sheet.columns.idAt(g.cols[i]);
      final ids = [...c.draftColBreaks];
      ids.contains(id) ? ids.remove(id) : ids.add(id);
      c.setDraftBreaks(cols: ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final g = BreakGeometry.of(c, box.maxWidth);
          if (g == null) {
            return Center(
              child: Text(l.printNothing, style: theme.textTheme.muted),
            );
          }
          PageBreakCanvas.lastGeometry = g;
          final size = Size(g.width + 16, g.height + 16);
          final canvas = MouseRegion(
            cursor: _cursor,
            onHover: (e) {
              final h = g.hit(e.localPosition);
              final cursor = h == null
                  ? (_headerAt(e.localPosition)
                        ? SystemMouseCursors.click
                        : MouseCursor.defer)
                  : (h.row
                        ? SystemMouseCursors.resizeRow
                        : SystemMouseCursors.resizeColumn);
              if (cursor != _cursor) setState(() => _cursor = cursor);
            },
            child: Listener(
              onPointerDown: (e) {
                if (e.buttons != kPrimaryButton &&
                    e.kind == PointerDeviceKind.mouse) {
                  return;
                }
                _down = e.localPosition;
                final h = g.hit(e.localPosition);
                if (h == null) return;
                setState(
                  () => _drag =
                      _Drag(
                          row: h.row,
                          from: h.pos,
                          wasCustom: h.row
                              ? g.customRows.contains(h.pos)
                              : g.customCols.contains(h.pos),
                        )
                        ..to = h.pos
                        ..start = e.localPosition,
                );
              },
              onPointerMove: (e) {
                final d = _drag;
                if (d == null) return;
                final p = e.localPosition;
                setState(() {
                  if (d.row) {
                    d.to = g.nearestRow(p.dy);
                    d.remove =
                        p.dy < BreakGeometry.headerH ||
                        p.dy > g.height + 12 ||
                        p.dx < 0 ||
                        p.dx > g.width + 24;
                  } else {
                    d.to = g.nearestCol(p.dx);
                    d.remove =
                        p.dx < BreakGeometry.headerW ||
                        p.dx > g.width + 12 ||
                        p.dy < 0 ||
                        p.dy > g.height + 24;
                  }
                });
              },
              onPointerUp: (e) {
                final d = _drag;
                final down = _down;
                _down = null;
                if (d != null) {
                  setState(() => _drag = null);
                  final moved = (e.localPosition - d.start).distance > 3;
                  if (moved) _commit(g, d);
                  return;
                }
                if (down != null &&
                    (e.localPosition - down).distance < 4 &&
                    _headerAt(e.localPosition)) {
                  _toggleAt(g, e.localPosition);
                }
              },
              onPointerCancel: (_) => setState(() {
                _drag = null;
                _down = null;
              }),
              child: CustomPaint(
                key: const ValueKey<String>('print.breakCanvas.paint'),
                size: size,
                painter: _BreakPainter(
                  g: g,
                  sheetId: c.sheetId,
                  text: _cellText,
                  drag: _drag,
                  colors: _BreakColors.of(theme),
                  textStyle: theme.textTheme.small.copyWith(
                    fontSize: (12 * g.scale).clamp(8, 12).toDouble(),
                    color: theme.colorScheme.foreground,
                  ),
                  headerStyle: theme.textTheme.small.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
          );
          return Semantics(
            key: const ValueKey<String>('print.breakCanvas'),
            container: true,
            label: l.printBreakCanvasLabel,
            child: WonkyScrollArea(
              controller: _v,
              child: SingleChildScrollView(
                controller: _v,
                physics: _drag == null
                    ? null
                    : const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  controller: _h,
                  scrollDirection: Axis.horizontal,
                  physics: _drag == null
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  child: canvas,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _headerAt(Offset p) =>
      (p.dx < BreakGeometry.headerW && p.dy >= BreakGeometry.headerH) ||
      (p.dy < BreakGeometry.headerH && p.dx >= BreakGeometry.headerW);

  final Map<int, String> _texts = {};
  int _textVersion = -1;
  CellDisplayResolver? _resolver;

  String _cellText(int row, int col) {
    if (_textVersion != c.contentVersion || _resolver == null) {
      _texts.clear();
      _textVersion = c.contentVersion;
      _resolver = CellDisplayResolver(c.model, c.ed.engine);
    }
    final key = row * 20000 + col;
    return _texts[key] ??= () {
      try {
        return _resolver!.display(c.sheetId, row, col).formatted.plainText;
      } catch (_) {
        return '';
      }
    }();
  }
}

class _BreakColors {
  const _BreakColors({
    required this.background,
    required this.header,
    required this.grid,
    required this.auto,
    required this.custom,
    required this.remove,
  });

  factory _BreakColors.of(ShadThemeData t) {
    final cs = t.colorScheme;
    return _BreakColors(
      background: cs.background,
      header: cs.muted,
      grid: cs.border,
      auto: cs.mutedForeground,
      custom: cs.primary,
      remove: cs.destructive,
    );
  }

  final Color background;
  final Color header;
  final Color grid;
  final Color auto;
  final Color custom;
  final Color remove;
}

class _BreakPainter extends CustomPainter {
  _BreakPainter({
    required this.g,
    required this.sheetId,
    required this.text,
    required this.drag,
    required this.colors,
    required this.textStyle,
    required this.headerStyle,
  }) : dragTo = drag?.to,
       dragRemove = drag?.remove;

  final BreakGeometry g;
  final String sheetId;
  final String Function(int row, int col) text;
  final _Drag? drag;
  final int? dragTo;
  final bool? dragRemove;
  final _BreakColors colors;
  final TextStyle textStyle;
  final TextStyle headerStyle;

  int _first(List<double> edges, double v) {
    var lo = 0;
    var hi = edges.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (edges[mid] <= v) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  void _text(
    Canvas canvas,
    String s,
    TextStyle style,
    Rect r, {
    bool center = false,
  }) {
    if (s.isEmpty || r.width < 6) return;
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0, r.width - 6));
    final dx = center ? r.left + (r.width - tp.width) / 2 : r.left + 3;
    tp.paint(canvas, Offset(dx, r.top + (r.height - tp.height) / 2));
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final clip = canvas.getLocalClipBounds();
    const hw = BreakGeometry.headerW;
    const hh = BreakGeometry.headerH;
    final bg = Paint()..color = colors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, g.width, g.height), bg);
    final r0 = _first(g.rowTops, clip.top);
    final r1 = _first(g.rowTops, clip.bottom);
    final c0 = _first(g.colLefts, clip.left);
    final c1 = _first(g.colLefts, clip.right);

    // Cells.
    final line = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    for (var i = r0; i <= r1 && i < g.rows.length; i++) {
      final top = g.rowTops[i];
      final bottom = g.rowTops[i + 1];
      for (var j = c0; j <= c1 && j < g.cols.length; j++) {
        final rect = Rect.fromLTRB(
          g.colLefts[j],
          top,
          g.colLefts[j + 1],
          bottom,
        );
        _text(canvas, text(g.rows[i], g.cols[j]), textStyle, rect);
      }
      canvas.drawLine(Offset(hw, bottom), Offset(g.width, bottom), line);
    }
    for (var j = c0; j <= c1 && j < g.cols.length; j++) {
      final x = g.colLefts[j + 1];
      canvas.drawLine(Offset(x, hh), Offset(x, g.height), line);
    }

    // Header bands.
    final hp = Paint()..color = colors.header;
    canvas.drawRect(Rect.fromLTWH(0, 0, g.width, hh), hp);
    canvas.drawRect(Rect.fromLTWH(0, 0, hw, g.height), hp);
    for (var i = r0; i <= r1 && i < g.rows.length; i++) {
      final rect = Rect.fromLTRB(0, g.rowTops[i], hw, g.rowTops[i + 1]);
      _text(canvas, '${g.rows[i] + 1}', headerStyle, rect, center: true);
      canvas.drawLine(rect.bottomLeft, rect.bottomRight, line);
    }
    for (var j = c0; j <= c1 && j < g.cols.length; j++) {
      final rect = Rect.fromLTRB(g.colLefts[j], 0, g.colLefts[j + 1], hh);
      _text(
        canvas,
        ColumnLetters.fromIndex(g.cols[j]),
        headerStyle,
        rect,
        center: true,
      );
      canvas.drawLine(rect.topRight, rect.bottomRight, line);
    }
    canvas.drawLine(const Offset(hw, 0), Offset(hw, g.height), line);
    canvas.drawLine(const Offset(0, hh), Offset(g.width, hh), line);

    // Breaks.
    final d = drag;
    bool dragged(bool row, int pos) =>
        d != null && d.row == row && d.from == pos;
    final auto = Paint()
      ..color = colors.auto
      ..strokeWidth = 1.5;
    for (final i in g.autoRows) {
      if (dragged(true, i)) continue;
      _dashed(
        canvas,
        Offset(hw, g.rowTops[i]),
        Offset(g.width, g.rowTops[i]),
        auto,
      );
    }
    for (final i in g.autoCols) {
      if (dragged(false, i)) continue;
      _dashed(
        canvas,
        Offset(g.colLefts[i], hh),
        Offset(g.colLefts[i], g.height),
        auto,
      );
    }
    final custom = Paint()
      ..color = colors.custom
      ..strokeWidth = 2;
    for (final i in g.customRows) {
      if (dragged(true, i)) continue;
      _rowBreak(canvas, g.rowTops[i], custom);
    }
    for (final i in g.customCols) {
      if (dragged(false, i)) continue;
      _colBreak(canvas, g.colLefts[i], custom);
    }
    if (d != null) {
      final p = Paint()
        ..color = d.remove ? colors.remove : colors.custom
        ..strokeWidth = 2;
      if (d.row) {
        _rowBreak(canvas, g.rowTops[d.to], p);
      } else {
        _colBreak(canvas, g.colLefts[d.to], p);
      }
    }
  }

  void _rowBreak(Canvas canvas, double y, Paint p) {
    canvas.drawLine(Offset(0, y), Offset(g.width, y), p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(BreakGeometry.headerW / 2, y),
          width: 28,
          height: 8,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = p.color,
    );
  }

  void _colBreak(Canvas canvas, double x, Paint p) {
    canvas.drawLine(Offset(x, 0), Offset(x, g.height), p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, BreakGeometry.headerH / 2),
          width: 8,
          height: 16,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = p.color,
    );
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 6.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final e = math.min(total, t + dash);
      canvas.drawLine(a + dir * t, a + dir * e, p);
      t = e + gap;
    }
  }

  @override
  bool shouldRepaint(_BreakPainter old) =>
      old.g != g ||
      old.drag != drag ||
      old.dragTo != dragTo ||
      old.dragRemove != dragRemove ||
      old.colors.background != colors.background;
}
