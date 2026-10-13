import 'dart:math' as math;

import '../addressing/grid_geometry.dart';
import '../content/cell_content.dart';
import '../content/rich_text.dart';
import '../format/attributes.dart';
import '../model/schema.dart';
import 'clipboard_payload.dart';
import 'clipboard_table.dart';
import 'css.dart';
import 'html_tokenizer.dart';
import 'sheets_html_attrs.dart';
import 'tsv_codec.dart';

/// Parses clipboard HTML tables from Wonky, Google Sheets, Excel,
/// LibreOffice and web pages (03 §12.5).
abstract final class HtmlTableCodec {
  /// Maximum `colspan`/`rowspan` honoured.
  static const int maxSpan = 1000;

  /// Parses [html]. All top-level tables are stacked with one blank row in
  /// between ([firstTableOnly] keeps only the first). Returns null when the
  /// HTML contains no table.
  static ClipboardTable? parse(String html, {bool firstTableOnly = false}) {
    final p = _Parser(html)..run();
    if (p.tables.isEmpty) return null;
    final tables = firstTableOnly ? [p.tables.first] : p.tables;
    final placed = [for (final t in tables) _place(t)];
    var rows = 0;
    var cols = 0;
    for (var i = 0; i < placed.length; i++) {
      rows += placed[i].rows + (i > 0 ? 1 : 0);
      cols = math.max(cols, placed[i].cols);
    }
    final cells = List.generate(
      rows,
      (_) => List<ClipboardTableCell?>.filled(cols, null),
    );
    final merges = <GridRect>[];
    final widths = List<double?>.filled(cols, null);
    final heights = List<double?>.filled(rows, null);
    var offset = 0;
    for (var i = 0; i < placed.length; i++) {
      if (i > 0) offset++;
      final t = placed[i];
      for (var r = 0; r < t.rows; r++) {
        heights[offset + r] = t.heights[r];
        for (var c = 0; c < t.cols; c++) {
          cells[offset + r][c] = t.cells[r][c];
        }
      }
      for (final m in t.merges) {
        merges.add(m.shift(offset, 0));
      }
      for (var c = 0; c < t.cols && c < cols; c++) {
        widths[c] ??= t.widths[c];
      }
      offset += t.rows;
    }
    return ClipboardTable(
      rowCount: rows,
      colCount: cols,
      cells: cells,
      merges: merges,
      columnWidths: widths,
      rowHeights: heights,
      origin: p.origin,
      wonkyClipId: p.clipId,
      wonkyPayload: p.payload,
      truncatedCells: p.truncated,
    );
  }

  static _Placed _place(_Table t) {
    final occupied = <(int, int)>{};
    final placedCells = <(int, int, _Cell)>[];
    var width = 0;
    final nRows = t.rows.length;
    for (var r = 0; r < nRows; r++) {
      var c = 0;
      for (final cell in t.rows[r].cells) {
        while (occupied.contains((r, c))) {
          c++;
        }
        final cs = cell.colspan.clamp(1, maxSpan).toInt();
        final rs = cell.rowspan.clamp(1, math.max(1, nRows - r)).toInt();
        for (var rr = r; rr < r + rs; rr++) {
          for (var cc = c; cc < c + cs; cc++) {
            occupied.add((rr, cc));
          }
        }
        placedCells.add((r, c, cell..placedSpan = (rs, cs)));
        width = math.max(width, c + cs);
        c += cs;
      }
    }
    final cells = List.generate(
      nRows,
      (_) => List<ClipboardTableCell?>.filled(width, null),
    );
    final merges = <GridRect>[];
    final widths = List<double?>.filled(width, null);
    for (var c = 0; c < width && c < t.colWidths.length; c++) {
      widths[c] = t.colWidths[c];
    }
    for (final (r, c, cell) in placedCells) {
      cells[r][c] = cell.result;
      final (rs, cs) = cell.placedSpan;
      if (rs > 1 || cs > 1) merges.add(GridRect(r, c, r + rs - 1, c + cs - 1));
      if (cs == 1 && widths[c] == null && cell.widthPx != null) {
        widths[c] = cell.widthPx;
      }
    }
    return _Placed(nRows, width, cells, merges, widths, [
      for (final row in t.rows) row.heightPx,
    ]);
  }
}

final class _Placed {
  _Placed(
    this.rows,
    this.cols,
    this.cells,
    this.merges,
    this.widths,
    this.heights,
  );
  final int rows;
  final int cols;
  final List<List<ClipboardTableCell?>> cells;
  final List<GridRect> merges;
  final List<double?> widths;
  final List<double?> heights;
}

final class _Table {
  _Table(this.decls, this.attrs);
  final Map<String, String> decls;
  final Map<String, String> attrs;
  final List<_Row> rows = [];
  final List<double?> colWidths = [];
}

final class _Row {
  _Row(this.decls, this.attrs, this.heightPx);
  final Map<String, String> decls;
  final Map<String, String> attrs;
  final double? heightPx;
  final List<_Cell> cells = [];
}

final class _Cell {
  _Cell(this.colspan, this.rowspan, this.widthPx);
  final int colspan;
  final int rowspan;
  final double? widthPx;
  (int, int) placedSpan = (1, 1);
  late ClipboardTableCell result;
}

/// Inline formatting active in a cell (rich run keys).
final class _Inline {
  _Inline(this.tag, this.format);
  final String tag;
  final Map<String, Object?> format;
}

final class _Segment {
  _Segment(this.text, this.format);
  String text;
  final Map<String, Object?> format;
}

final class _CellState {
  _CellState(this.cell, this.tag, this.attrs, this.decls);
  final _Cell cell;
  final String tag;
  final Map<String, String> attrs;
  final Map<String, String> decls;
  final List<_Segment> segments = [];
  final List<_Inline> stack = [];
  bool pre = false;

  Map<String, Object?> get current {
    if (stack.isEmpty) return const {};
    final m = <String, Object?>{};
    for (final s in stack) {
      m.addAll(s.format);
    }
    return m;
  }

  bool get endsWithNewline {
    for (var i = segments.length - 1; i >= 0; i--) {
      final t = segments[i].text;
      if (t.isNotEmpty) return t.endsWith('\n');
    }
    return true;
  }

  void add(String text) {
    if (text.isEmpty) return;
    segments.add(_Segment(text, current));
  }
}

final class _Parser {
  _Parser(this.html);

  final String html;
  final List<_Table> tables = [];
  ClipboardOrigin origin = ClipboardOrigin.web;
  String? clipId;
  SheetsClipboardPayload? payload;
  int truncated = 0;
  CssStyleSheet sheet = CssStyleSheet.empty;

  final List<_Table> _tableStack = [];
  _Row? _row;
  _CellState? _cell;

  // Nested tables inside a cell: depth beyond the cell's table.
  int _nested = 0;
  bool _nestedRowStarted = false;
  bool _nestedCellStarted = false;

  bool _google = false;
  bool _excel = false;
  bool _libre = false;
  bool _wonky = false;

  static const _blockTags = {
    'p',
    'div',
    'li',
    'ul',
    'ol',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'section',
    'article',
  };

  void run() {
    final tokens = HtmlTokenizer.tokenize(html);
    final styles = StringBuffer();
    String? rawOwner;
    for (final t in tokens) {
      if (t is HtmlStartTag) rawOwner = t.name;
      if (t is HtmlTextToken && t.raw && rawOwner == 'style') {
        styles.writeln(t.text);
      }
    }
    if (styles.isNotEmpty) sheet = CssStyleSheet.parse(styles.toString());
    var inRaw = false;
    for (final t in tokens) {
      switch (t) {
        case HtmlComment(:final text):
          final s = text.trim();
          if (s.startsWith('wonky:')) {
            payload ??= SheetsClipboardPayload.tryDecodeBase64(s.substring(6));
            if (payload != null) _wonky = true;
          }
        case HtmlStartTag():
          if (t.name == 'style' || t.name == 'script' || t.name == 'title') {
            inRaw = !t.selfClosing;
            continue;
          }
          _start(t);
        case HtmlEndTag():
          if (t.name == 'style' || t.name == 'script' || t.name == 'title') {
            inRaw = false;
            continue;
          }
          _end(t.name);
        case HtmlTextToken():
          if (t.raw || inRaw) continue;
          _text(t.text);
      }
    }
    while (_tableStack.isNotEmpty) {
      _closeTable();
    }
    origin = _wonky
        ? ClipboardOrigin.wonky
        : _google
        ? ClipboardOrigin.googleSheets
        : _excel
        ? ClipboardOrigin.excel
        : _libre
        ? ClipboardOrigin.libreOffice
        : ClipboardOrigin.web;
  }

  void _detect(HtmlStartTag t) {
    final a = t.attributes;
    if (t.name == 'google-sheets-html-origin') _google = true;
    if (t.name == 'html' && (a['xmlns:x']?.contains('office:excel') ?? false)) {
      _excel = true;
    }
    if (t.name == 'meta') {
      final content = (a['content'] ?? '').toLowerCase();
      final name = (a['name'] ?? '').toLowerCase();
      if (name == 'generator' && content.contains('libreoffice')) _libre = true;
      if ((name == 'progid' || name == 'generator') &&
          content.contains('excel')) {
        _excel = true;
      }
    }
    for (final k in a.keys) {
      if (k.startsWith('data-sheets-')) _google = true;
      if (k.startsWith('x:')) _excel = true;
      if (k == 'sdval' || k == 'sdnum') _libre = true;
    }
  }

  // ---------------------------------------------------------------------------

  void _start(HtmlStartTag t) {
    _detect(t);
    final name = t.name;
    if (_cell != null && _nested > 0) {
      _startNested(t);
      return;
    }
    switch (name) {
      case 'table':
        if (_cell != null) {
          _nested = 1;
          _nestedRowStarted = false;
          return;
        }
        final decls = _decls(t);
        final table = _Table(decls, t.attributes);
        final id = t.attributes['data-wonky-clip'];
        if (id != null && id.isNotEmpty) {
          clipId ??= id;
          _wonky = true;
        }
        _tableStack.add(table);
      case 'colgroup':
        final table = _tableStack.lastOrNull;
        final w =
            Css.lengthPx(_decls(t)['width']) ??
            Css.lengthPx(t.attributes['width']);
        if (table == null || w == null) return;
        final span =
            int.tryParse(
              t.attributes['span'] ?? '',
            )?.clamp(1, HtmlTableCodec.maxSpan) ??
            1;
        for (var i = 0; i < span; i++) {
          table.colWidths.add(w);
        }
      case 'col':
        final table = _tableStack.lastOrNull;
        if (table == null) return;
        final span =
            int.tryParse(
              t.attributes['span'] ?? '',
            )?.clamp(1, HtmlTableCodec.maxSpan) ??
            1;
        final d = _decls(t);
        final w =
            Css.lengthPx(d['width']) ?? Css.lengthPx(t.attributes['width']);
        for (var i = 0; i < span; i++) {
          table.colWidths.add(w);
        }
      case 'tr':
        final table = _tableStack.lastOrNull;
        if (table == null) return;
        _closeCell();
        _closeRow();
        final d = _decls(t);
        final h =
            Css.lengthPx(d['height']) ?? Css.lengthPx(t.attributes['height']);
        _row = _Row(d, t.attributes, h);
        // Rows hidden with `display:none` (Excel's column-width helper row).
        if (d['display']?.trim().toLowerCase() != 'none') table.rows.add(_row!);
      case 'td' || 'th':
        final table = _tableStack.lastOrNull;
        if (table == null) return;
        _closeCell();
        if (_row == null) {
          _row = _Row(const {}, const {}, null);
          table.rows.add(_row!);
        }
        final a = t.attributes;
        final cs = int.tryParse(a['colspan'] ?? '') ?? 1;
        final rs = int.tryParse(a['rowspan'] ?? '') ?? 1;
        final d = _decls(t);
        final w = Css.lengthPx(d['width']) ?? Css.lengthPx(a['width']);
        final cell = _Cell(cs < 1 ? 1 : cs, rs < 1 ? 1 : rs, w);
        _row!.cells.add(cell);
        _cell = _CellState(cell, name, a, d)
          ..pre = (d['white-space'] ?? '').startsWith('pre');
      case 'br':
        _cell?.add('\n');
      default:
        final cell = _cell;
        if (cell == null) return;
        if (_blockTags.contains(name) && !cell.endsWithNewline) cell.add('\n');
        final fmt = _inlineFormat(t);
        if (!t.selfClosing) cell.stack.add(_Inline(name, fmt));
        if (name == 'img') {
          final alt = t.attributes['alt'];
          if (alt != null && alt.isNotEmpty) cell.add(alt);
        }
    }
  }

  void _startNested(HtmlStartTag t) {
    final cell = _cell!;
    switch (t.name) {
      case 'table':
        _nested++;
      case 'tr':
        if (_nestedRowStarted && !cell.endsWithNewline) cell.add('\n');
        _nestedRowStarted = true;
        _nestedCellStarted = false;
      case 'td' || 'th':
        if (_nestedCellStarted) cell.add('\t');
        _nestedCellStarted = true;
      case 'br':
        cell.add('\n');
    }
  }

  void _end(String name) {
    if (_cell != null && _nested > 0) {
      if (name == 'table') _nested--;
      return;
    }
    switch (name) {
      case 'table':
        if (_tableStack.isNotEmpty) _closeTable();
      case 'tr':
        _closeCell();
        _closeRow();
      case 'td' || 'th':
        _closeCell();
      default:
        final cell = _cell;
        if (cell == null) return;
        for (var i = cell.stack.length - 1; i >= 0; i--) {
          if (cell.stack[i].tag == name) {
            cell.stack.removeRange(i, cell.stack.length);
            break;
          }
        }
        if (_blockTags.contains(name) && !cell.endsWithNewline) cell.add('\n');
    }
  }

  void _text(String text) {
    final cell = _cell;
    if (cell == null) return;
    if (cell.pre) {
      cell.add(text.replaceAll('\r\n', '\n'));
    } else {
      cell.add(text.replaceAll(RegExp(r'[ \t\n\r\f]+'), ' '));
    }
  }

  void _closeTable() {
    _closeCell();
    _closeRow();
    final t = _tableStack.removeLast();
    if (_tableStack.isEmpty && t.rows.isNotEmpty) tables.add(t);
  }

  void _closeRow() {
    _row = null;
  }

  // ---------------------------------------------------------------------------

  Map<String, String> _decls(HtmlStartTag t, {bool includeTagRules = true}) {
    final classes = (t.attributes['class'] ?? '')
        .split(RegExp(r'\s+'))
        .where((c) => c.isNotEmpty);
    final out = <String, String>{};
    if (!sheet.isEmpty) {
      final fromSheet = sheet.declarationsFor(
        t.name,
        classes.toList(),
        includeTagOnly: false,
      );
      if (includeTagRules) {
        final tagOnly = sheet.declarationsFor(t.name, const []);
        // Tag rules are document defaults: Google's `td {border:…}` are
        // gridlines, fonts (`td {font-family:Calibri}`) are the app default.
        tagOnly.forEach((k, v) {
          if (!k.startsWith('border') &&
              k != 'font-family' &&
              k != 'font-size') {
            out[k] = v;
          }
        });
      }
      out.addAll(fromSheet);
    }
    out.addAll(Css.parseDeclarations(t.attributes['style']));
    return out;
  }

  Map<String, Object?> _inlineFormat(HtmlStartTag t) {
    final f = <String, Object?>{};
    switch (t.name) {
      case 'b' || 'strong':
        f[RichRunKeys.bold] = true;
      case 'i' || 'em' || 'cite' || 'var':
        f[RichRunKeys.italic] = true;
      case 'u' || 'ins':
        f[RichRunKeys.underline] = true;
      case 's' || 'strike' || 'del':
        f[RichRunKeys.strikethrough] = true;
      case 'a':
        final href = _safeLink(t.attributes['href']);
        if (href != null) f[RichRunKeys.link] = href;
      case 'font':
        final color = Css.color(t.attributes['color']);
        if (color != null) f[RichRunKeys.textColor] = color;
        final face = _family(t.attributes['face']);
        if (face != null) f[RichRunKeys.fontFamily] = face;
        final size = Css.fontTagSizePt(t.attributes['size']);
        if (size != null) f[RichRunKeys.fontSize] = size;
    }
    final d = Css.parseDeclarations(t.attributes['style']);
    final classes = (t.attributes['class'] ?? '')
        .split(RegExp(r'\s+'))
        .where((c) => c.isNotEmpty);
    final all = {
      if (!sheet.isEmpty && classes.isNotEmpty)
        ...sheet.declarationsFor(
          t.name,
          classes.toList(),
          includeTagOnly: false,
        ),
      ...d,
    };
    final fw = _bold(all['font-weight']);
    if (fw != null) f[RichRunKeys.bold] = fw;
    final fs = _italic(all['font-style']);
    if (fs != null) f[RichRunKeys.italic] = fs;
    final deco = all['text-decoration'] ?? all['text-decoration-line'];
    if (deco != null) {
      final dl = deco.toLowerCase();
      if (dl.contains('none')) {
        f[RichRunKeys.underline] = false;
        f[RichRunKeys.strikethrough] = false;
      }
      if (dl.contains('underline')) f[RichRunKeys.underline] = true;
      if (dl.contains('line-through')) f[RichRunKeys.strikethrough] = true;
    }
    final color = Css.color(all['color']);
    if (color != null) f[RichRunKeys.textColor] = color;
    final fam = _family(all['font-family']);
    if (fam != null) f[RichRunKeys.fontFamily] = fam;
    final size = Css.fontSizePt(all['font-size']);
    if (size != null) f[RichRunKeys.fontSize] = size;
    return f;
  }

  static String? _safeLink(String? href) {
    if (href == null) return null;
    final h = href.trim();
    final l = h.toLowerCase();
    if (l.startsWith('http://') ||
        l.startsWith('https://') ||
        l.startsWith('mailto:') ||
        l.startsWith('#sheet=') ||
        l.startsWith('#range=')) {
      return h;
    }
    return null;
  }

  static bool? _bold(String? v) {
    if (v == null) return null;
    final s = v.trim().toLowerCase();
    if (s == 'bold' || s == 'bolder') return true;
    if (s == 'normal' || s == 'lighter') return false;
    final n = int.tryParse(s);
    if (n == null) return null;
    return n >= 600;
  }

  static bool? _italic(String? v) {
    if (v == null) return null;
    final s = v.trim().toLowerCase();
    if (s.startsWith('italic') || s.startsWith('oblique')) return true;
    if (s == 'normal') return false;
    return null;
  }

  static const _generic = {
    'serif',
    'sans-serif',
    'monospace',
    'cursive',
    'fantasy',
    'system-ui',
    'inherit',
    'initial',
    '-apple-system',
    'blinkmacsystemfont',
  };

  static String? _family(String? v) {
    if (v == null) return null;
    for (final part in v.split(',')) {
      final name = Css.unescape(part.trim()).trim();
      if (name.isEmpty || _generic.contains(name.toLowerCase())) continue;
      return name;
    }
    return null;
  }

  // ---------------------------------------------------------------------------

  void _closeCell() {
    final st = _cell;
    if (st == null) return;
    _cell = null;
    _nested = 0;
    final table = _tableStack.last;
    final row = _row;
    final a = st.attrs;

    // Inherited declarations: table ▸ row ▸ cell (borders and fonts only from
    // the cell level; table/row fonts are document defaults).
    final decls = <String, String>{};
    void inherit(Map<String, String> m) {
      m.forEach((k, v) {
        if (k.startsWith('border') ||
            k == 'font-family' ||
            k == 'font-size' ||
            k == 'width') {
          return;
        }
        if (k == 'height') return;
        decls[k] = v;
      });
    }

    inherit(table.decls);
    if (row != null) inherit(row.decls);
    decls.addAll(st.decls);

    final attrs = <FormatAttr, Object?>{};
    // Legacy attributes (lowest precedence).
    final bg = Css.color(
      a['bgcolor'] ?? row?.attrs['bgcolor'] ?? table.attrs['bgcolor'],
    );
    if (bg != null) attrs[FormatAttr.fillColor] = bg;
    final align = _hAlign(a['align'] ?? row?.attrs['align']);
    if (align != null) attrs[FormatAttr.hAlign] = align;
    final valign = _vAlign(a['valign'] ?? row?.attrs['valign']);
    if (valign != null) attrs[FormatAttr.vAlign] = valign;
    if (a.containsKey('nowrap')) attrs[FormatAttr.wrap] = WrapStrategy.overflow;
    if (st.tag == 'th') attrs[FormatAttr.bold] = true;

    final fam = _family(decls['font-family']);
    if (fam != null) attrs[FormatAttr.fontFamily] = fam;
    final size = Css.fontSizePt(decls['font-size']);
    if (size != null) attrs[FormatAttr.fontSize] = size;
    final bold = _bold(decls['font-weight']);
    if (bold != null) attrs[FormatAttr.bold] = bold;
    final italic = _italic(decls['font-style']);
    if (italic != null) attrs[FormatAttr.italic] = italic;
    final deco = decls['text-decoration'] ?? decls['text-decoration-line'];
    if (deco != null) {
      final dl = deco.toLowerCase();
      if (dl.contains('underline')) attrs[FormatAttr.underline] = true;
      if (dl.contains('line-through')) attrs[FormatAttr.strikethrough] = true;
    }
    final color = Css.color(decls['color']);
    if (color != null) {
      attrs[FormatAttr.textColor] = color == '#000000' ? null : color;
    }
    final bgCss = decls['background-color'] ?? decls['background'];
    if (bgCss != null) {
      final c = Css.color(bgCss) ?? _firstColor(bgCss);
      if (c != null) {
        attrs[FormatAttr.fillColor] = c;
      } else if (bgCss.trim().toLowerCase() == 'transparent' ||
          bgCss.trim().toLowerCase() == 'none') {
        attrs.remove(FormatAttr.fillColor);
      }
    }
    final ta = _hAlign(decls['text-align']);
    if (ta != null) attrs[FormatAttr.hAlign] = ta;
    final va = _vAlign(decls['vertical-align']);
    if (va != null) attrs[FormatAttr.vAlign] = va;
    final wrap = _wrap(decls);
    if (wrap != null) attrs[FormatAttr.wrap] = wrap;
    final rot = _rotation(decls);
    if (rot != null) attrs[FormatAttr.rotation] = rot;
    _borders(decls, attrs);

    // Number format.
    String? numberFormat = SheetsHtmlAttrs.decodeNumberFormat(
      a['data-sheets-numberformat'],
    );
    numberFormat ??= _msoNumberFormat(decls['mso-number-format']);
    numberFormat ??= _sdnum(a['sdnum']);

    // Text and runs.
    var (text, runs) = _textAndRuns(st.segments);
    if (text.length > kMaxPastedCellChars) {
      text = text.substring(0, kMaxPastedCellChars);
      runs = [
        for (final r in runs)
          if (r.start < text.length)
            r.copyWith(end: math.min(r.end, text.length)),
      ];
      truncated++;
    }

    // Whole-cell keys → cell format; the rest stay runs.
    final cellRunKeys = _promote(text, runs);
    cellRunKeys.forEach((k, v) {
      final attr = k == RichRunKeys.link
          ? FormatAttr.linkUrl
          : FormatAttr.byColumn(k);
      if (attr != null) attrs[attr] = v;
    });
    final hyperlink = _safeLink(a['data-sheets-hyperlink']);
    if (hyperlink != null) attrs[FormatAttr.linkUrl] = hyperlink;
    RichText? rich;
    if (runs.isNotEmpty) {
      final cellMap = {for (final e in cellRunKeys.entries) e.key: e.value};
      final norm = RichText(text, runs).normalize(cellFormat: cellMap);
      rich = norm.rich;
      if (norm.wholeCellLink != null) {
        attrs[FormatAttr.linkUrl] = norm.wholeCellLink;
      }
    }

    // Typed values.
    CellValue? typed = SheetsHtmlAttrs.decodeValue(a['data-sheets-value']);
    if (typed == null && a.containsKey('x:num')) {
      final v = a['x:num']!;
      final n = double.tryParse(
        (v.isEmpty ? text : v).trim().replaceAll(',', ''),
      );
      if (n != null && n.isFinite) typed = NumberValue(n);
    }
    if (typed == null && a.containsKey('x:bool')) {
      final v = (a['x:bool']!.isEmpty ? text : a['x:bool']!)
          .trim()
          .toUpperCase();
      if (v == 'TRUE' || v == 'FALSE') typed = BoolValue(v == 'TRUE');
    }
    if (typed == null && a.containsKey('x:str')) {
      final v = a['x:str']!;
      typed = TextValue(v.isEmpty ? text : v);
    }
    if (typed == null && a['sdval'] != null) {
      final n = double.tryParse(a['sdval']!.trim());
      if (n != null && n.isFinite) typed = NumberValue(n);
    }
    if (typed == null && numberFormat == '@' && text.isNotEmpty) {
      typed = TextValue(text);
    }

    // Typed text is exact (tabs and repeated spaces survive HTML collapsing).
    if (typed is TextValue && typed.text != text) {
      if (rich != null && rich.text != typed.text) rich = null;
      text = typed.text;
    }
    final formula = a['data-sheets-formula'];
    final note = a['data-sheets-note'];
    st.cell.result = ClipboardTableCell(
      text: text,
      typedValue: typed,
      formulaR1C1: formula != null && formula.trim().startsWith('=')
          ? formula.trim()
          : null,
      excelFormula: a['x:fmla'],
      numberFormat: numberFormat,
      format: CellFormat(attrs),
      rich: typed == null || typed is TextValue ? rich : null,
      note: note != null && note.isNotEmpty ? note : null,
    );
  }

  static String? _firstColor(String v) {
    for (final part in v.split(RegExp(r'\s+(?![^(]*\))'))) {
      final c = Css.color(part);
      if (c != null) return c;
    }
    return null;
  }

  static HorizontalAlign? _hAlign(String? v) =>
      switch (v?.trim().toLowerCase()) {
        'left' || 'start' || 'justify' => HorizontalAlign.left,
        'center' || '-webkit-center' || 'middle' => HorizontalAlign.center,
        'right' || 'end' => HorizontalAlign.right,
        _ => null,
      };

  static VerticalAlign? _vAlign(String? v) => switch (v?.trim().toLowerCase()) {
    'top' || 'text-top' => VerticalAlign.top,
    'middle' || 'center' => VerticalAlign.middle,
    'bottom' || 'baseline' || 'text-bottom' => VerticalAlign.bottom,
    _ => null,
  };

  static WrapStrategy? _wrap(Map<String, String> d) {
    final ws = d['wrap-strategy']?.trim();
    if (ws == '4') return WrapStrategy.wrap;
    if (ws == '2') return WrapStrategy.clip;
    if (ws == '3' || ws == '1') return WrapStrategy.overflow;
    final w = d['white-space']?.trim().toLowerCase();
    if (w == null) return null;
    if (w == 'nowrap' || w == 'pre') {
      final ov = d['text-overflow']?.trim().toLowerCase();
      return ov == 'clip' ? WrapStrategy.clip : WrapStrategy.overflow;
    }
    if (w == 'normal' ||
        w == 'pre-wrap' ||
        w == 'pre-line' ||
        w == 'break-spaces') {
      return WrapStrategy.wrap;
    }
    return null;
  }

  static int? _rotation(Map<String, String> d) {
    final mso = d['mso-rotate'];
    if (mso != null) {
      final n = int.tryParse(mso.trim());
      if (n != null) return n == 255 ? 255 : n.clamp(-90, 90);
    }
    final wm = d['writing-mode']?.toLowerCase();
    if (wm != null &&
        wm.startsWith('vertical') &&
        (d['text-orientation'] ?? '').contains('upright')) {
      return 255;
    }
    final t = d['transform'];
    if (t != null) {
      final m = RegExp(r'rotate\(\s*(-?\d+(?:\.\d+)?)deg\s*\)').firstMatch(t);
      if (m != null) {
        final deg = double.parse(m.group(1)!).round();
        return (-deg).clamp(-90, 90);
      }
    }
    return null;
  }

  static void _borders(Map<String, String> d, Map<FormatAttr, Object?> attrs) {
    final sides = <String, CssBorder>{};
    CssBorder empty() =>
        (widthPx: null, style: null, color: null, widthInPt: false);
    CssBorder merge(CssBorder a, CssBorder b) => (
      widthPx: b.widthPx ?? a.widthPx,
      style: b.style ?? a.style,
      color: b.color ?? a.color,
      widthInPt: b.widthPx != null ? b.widthInPt : a.widthInPt,
    );
    const names = ['top', 'right', 'bottom', 'left'];
    for (final s in names) {
      sides[s] = empty();
    }
    // Process in declaration order so later shorthands override.
    for (final e in d.entries) {
      final k = e.key;
      final v = e.value;
      if (k == 'border') {
        final b = Css.border(v);
        for (final s in names) {
          sides[s] = b;
        }
      } else if (k == 'border-width' ||
          k == 'border-style' ||
          k == 'border-color') {
        final box = Css.box(v);
        for (var i = 0; i < 4; i++) {
          final b = Css.border(box[i]);
          sides[names[i]] = merge(sides[names[i]]!, b);
        }
      } else if (k.startsWith('border-')) {
        final rest = k.substring(7);
        final dash = rest.indexOf('-');
        final side = dash < 0 ? rest : rest.substring(0, dash);
        if (!names.contains(side)) continue;
        final b = Css.border(v);
        sides[side] = dash < 0 ? b : merge(sides[side]!, b);
      }
    }
    const attrBySide = {
      'top': FormatAttr.borderTop,
      'right': FormatAttr.borderRight,
      'bottom': FormatAttr.borderBottom,
      'left': FormatAttr.borderLeft,
    };
    for (final s in names) {
      final spec = Css.borderSpec(sides[s]!);
      if (spec != null && !spec.isNone) attrs[attrBySide[s]!] = spec.encode();
    }
  }

  static String? _msoNumberFormat(String? v) {
    if (v == null) return null;
    final f = Css.unescape(v).trim();
    if (f.isEmpty) return null;
    return switch (f.toLowerCase()) {
      'general' => null,
      'short date' => 'preset:date',
      'medium date' => 'd-mmm-yy',
      'long date' => 'dddd, mmmm d, yyyy',
      'short time' => 'h:mm',
      'medium time' => 'h:mm AM/PM',
      'long time' => 'h:mm:ss AM/PM',
      'standard' => '#,##0.00',
      'fixed' => '0.00',
      'percent' => '0.00%',
      'scientific' => '0.00E+00',
      _ => f,
    };
  }

  static String? _sdnum(String? v) {
    if (v == null) return null;
    final first = v.indexOf(';');
    if (first < 0) return null;
    final second = v.indexOf(';', first + 1);
    if (second < 0) return null;
    final f = v.substring(second + 1).trim();
    if (f.isEmpty || f.toLowerCase() == 'general' || f == 'Standard') {
      return null;
    }
    return f;
  }

  /// Joins segments, collapsing spaces around line starts/ends, and returns
  /// runs for formatted segments.
  static (String, List<RichRun>) _textAndRuns(List<_Segment> segments) {
    final chars = StringBuffer();
    final formats = <Map<String, Object?>>[];
    for (final s in segments) {
      for (var i = 0; i < s.text.length; i++) {
        chars.writeCharCode(s.text.codeUnitAt(i));
        formats.add(s.format);
      }
    }
    final raw = chars.toString();
    // Keep mask: drop spaces at line starts, double spaces, trailing spaces.
    final keep = List<bool>.filled(raw.length, true);
    var lineStart = true;
    var prevSpace = false;
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (c == 0x0a) {
        // Trailing spaces before the break.
        var k = i - 1;
        while (k >= 0 && keep[k] && raw.codeUnitAt(k) == 0x20) {
          keep[k] = false;
          k--;
        }
        lineStart = true;
        prevSpace = false;
        continue;
      }
      if (c == 0x20) {
        if (lineStart || prevSpace) keep[i] = false;
        prevSpace = true;
        continue;
      }
      lineStart = false;
      prevSpace = false;
    }
    for (var k = raw.length - 1; k >= 0 && raw.codeUnitAt(k) == 0x20; k--) {
      keep[k] = false;
    }
    // Trailing line breaks from block elements.
    var end = raw.length;
    while (end > 0 && (!keep[end - 1] || raw.codeUnitAt(end - 1) == 0x0a)) {
      end--;
    }
    var start = 0;
    while (start < end && (!keep[start] || raw.codeUnitAt(start) == 0x0a)) {
      start++;
    }
    final out = StringBuffer();
    final outFormats = <Map<String, Object?>>[];
    for (var i = start; i < end; i++) {
      if (!keep[i]) continue;
      final c = raw.codeUnitAt(i);
      out.writeCharCode(c == 0xa0 ? 0x20 : c);
      outFormats.add(formats[i]);
    }
    final text = out.toString();
    final runs = <RichRun>[];
    var i = 0;
    while (i < text.length) {
      final f = outFormats[i];
      var j = i + 1;
      while (j < text.length && identical(outFormats[j], f)) {
        j++;
      }
      if (f.isNotEmpty) runs.add(RichRun(i, j, Map.of(f)));
      i = j;
    }
    return (text, runs);
  }

  /// Keys whose value is the same over every non-space character → cell
  /// level (removed from [runs] in place).
  static Map<String, Object?> _promote(String text, List<RichRun> runs) {
    if (runs.isEmpty || text.trim().isEmpty) return const {};
    final keys = <String>{for (final r in runs) ...r.format.keys};
    final promoted = <String, Object?>{};
    for (final k in keys) {
      Object? value;
      var uniform = true;
      var seen = false;
      for (var i = 0; i < text.length && uniform; i++) {
        if (text.codeUnitAt(i) == 0x20 || text.codeUnitAt(i) == 0x0a) continue;
        Object? v;
        for (final r in runs) {
          if (i >= r.start && i < r.end) {
            v = r.format[k];
            break;
          }
        }
        if (!seen) {
          value = v;
          seen = true;
        } else if (v != value) {
          uniform = false;
        }
      }
      if (uniform && value != null) promoted[k] = value;
    }
    if (promoted.isEmpty) return promoted;
    for (var i = runs.length - 1; i >= 0; i--) {
      final f = Map<String, Object?>.of(runs[i].format)
        ..removeWhere((k, _) => promoted.containsKey(k));
      if (f.isEmpty) {
        runs.removeAt(i);
      } else {
        runs[i] = runs[i].copyWith(format: f);
      }
    }
    return promoted;
  }
}
