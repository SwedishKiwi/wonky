import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';

/// Rows×columns grid picker for "Insert table" (suite 02 §4.10): 10×10,
/// growing to 20×20 when hovering near the edge. Arrow keys change the size,
/// Enter picks it.
class WonkyTableSizePicker extends StatefulWidget {
  const WonkyTableSizePicker({
    super.key,
    required this.onSelected,
    this.initialSize = 10,
    this.maxSize = 20,
    this.cellSize = 18,
  });

  final void Function(int rows, int columns) onSelected;
  final int initialSize;
  final int maxSize;
  final double cellSize;

  @override
  State<WonkyTableSizePicker> createState() => _WonkyTableSizePickerState();
}

class _WonkyTableSizePickerState extends State<WonkyTableSizePicker> {
  int _rows = 1;
  int _cols = 1;
  late int _visibleRows = widget.initialSize;
  late int _visibleCols = widget.initialSize;

  void _hover(int r, int c) {
    setState(() {
      _rows = r;
      _cols = c;
      if (r >= _visibleRows - 1) _visibleRows = (r + 2).clamp(widget.initialSize, widget.maxSize);
      if (c >= _visibleCols - 1) _visibleCols = (c + 2).clamp(widget.initialSize, widget.maxSize);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    var r = _rows, c = _cols;
    if (k == LogicalKeyboardKey.arrowRight) {
      c++;
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      c--;
    } else if (k == LogicalKeyboardKey.arrowDown) {
      r++;
    } else if (k == LogicalKeyboardKey.arrowUp) {
      r--;
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space) {
      widget.onSelected(_rows, _cols);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    _hover(r.clamp(1, widget.maxSize), c.clamp(1, widget.maxSize));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l10n = WonkyUiLocalizations.of(context);
    final s = widget.cellSize;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Semantics(
        label: l10n.tableSizeLabel(_rows, _cols),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MouseRegion(
              onHover: (e) {
                final c = (e.localPosition.dx / (s + 2)).floor() + 1;
                final r = (e.localPosition.dy / (s + 2)).floor() + 1;
                _hover(r.clamp(1, _visibleRows), c.clamp(1, _visibleCols));
              },
              child: GestureDetector(
                onTap: () => widget.onSelected(_rows, _cols),
                child: SizedBox(
                  width: _visibleCols * (s + 2),
                  height: _visibleRows * (s + 2),
                  child: CustomPaint(
                    painter: _GridPainter(
                      rows: _visibleRows,
                      cols: _visibleCols,
                      selRows: _rows,
                      selCols: _cols,
                      cell: s,
                      border: theme.colorScheme.border,
                      fill: theme.colorScheme.primary.withValues(alpha: 0.18),
                      selBorder: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tableSize(_rows, _cols),
              key: const ValueKey<String>('tableSizePicker.label'),
              style: theme.textTheme.small,
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.rows,
    required this.cols,
    required this.selRows,
    required this.selCols,
    required this.cell,
    required this.border,
    required this.fill,
    required this.selBorder,
  });

  final int rows, cols, selRows, selCols;
  final double cell;
  final Color border, fill, selBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final b = Paint()
      ..style = PaintingStyle.stroke
      ..color = border;
    final sb = Paint()
      ..style = PaintingStyle.stroke
      ..color = selBorder;
    final f = Paint()..color = fill;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * (cell + 2) + 0.5, r * (cell + 2) + 0.5, cell, cell);
        final sel = r < selRows && c < selCols;
        if (sel) canvas.drawRect(rect, f);
        canvas.drawRect(rect, sel ? sb : b);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) =>
      o.rows != rows ||
      o.cols != cols ||
      o.selRows != selRows ||
      o.selCols != selCols ||
      o.border != border ||
      o.fill != fill;
}
