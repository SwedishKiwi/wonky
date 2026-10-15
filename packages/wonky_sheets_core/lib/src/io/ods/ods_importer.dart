import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';
import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../content/rich_text.dart';
import '../../format/attributes.dart';
import '../formula/excel_formula_translator.dart';
import '../formula/open_formula_translator.dart';
import '../ir/ir_range.dart';
import '../ir/sparse_grid.dart';
import '../ir/workbook_document.dart';
import '../xlsx/ooxml.dart';
import '../xlsx/xlsx_importer.dart' show UnsupportedFormulaMode;
import 'ods_styles.dart';

/// Options of an ODS import.
final class OdsImportOptions {
  /// Creates options.
  const OdsImportOptions({
    this.sheets,
    this.unsupportedFormulas = UnsupportedFormulaMode.value,
    this.isSupportedFunction,
  });

  /// Names of the sheets to import (null = all).
  final Set<String>? sheets;
  final UnsupportedFormulaMode unsupportedFormulas;

  /// Whether Wonky implements a function (upper case); defaults to "all but
  /// the known Excel-only functions".
  final bool Function(String upperName)? isSupportedFunction;
}

/// A sheet listed by [OdsImporter.listSheets].
final class OdsSheetInfo {
  /// Creates info.
  const OdsSheetInfo(this.name, {this.hidden = false, this.estimatedCells = 0});

  final String name;
  final bool hidden;

  /// Number of cells with a value (repeats counted).
  final int estimatedCells;
}

/// ODS (OpenDocument spreadsheet) → IR (11 §5.5): own reader over `archive`
/// and streaming `xml` events. Broken files throw [XlsxFormatException].
abstract final class OdsImporter {
  /// Maximum rows / columns of an ODS sheet read.
  static const int maxRows = 1048576;
  static const int maxCols = 16384;

  /// Imports [bytes].
  static WorkbookDocument import(
    Uint8List bytes, [
    OdsImportOptions options = const OdsImportOptions(),
  ]) {
    try {
      final pkg = ZipPackage.open(bytes);
      _checkMimeType(pkg);
      return _Reader(pkg, options).read();
    } on XlsxFormatException {
      rethrow;
    } on Object catch (e) {
      throw XlsxFormatException('The spreadsheet could not be read ($e)');
    }
  }

  /// Lists the sheets of [bytes] (import dialog) without building cells.
  static List<OdsSheetInfo> listSheets(Uint8List bytes) {
    try {
      final pkg = ZipPackage.open(bytes);
      _checkMimeType(pkg);
      final content = pkg.text('content.xml');
      if (content == null) {
        throw const XlsxFormatException('The file has no content.xml part');
      }
      final tableStyles = <String, bool>{};
      final out = <OdsSheetInfo>[];
      String? name;
      String? style;
      var cells = 0;
      var rowRepeat = 1;
      var inStyles = false;
      String? styleName;
      for (final e in parseEvents(content)) {
        if (e is XmlStartElementEvent) {
          final local = _local(e.name);
          switch (local) {
            case 'automatic-styles':
              inStyles = !e.isSelfClosing;
            case 'style' when inStyles:
              styleName = _attr(e, 'name');
            case 'table-properties' when inStyles && styleName != null:
              tableStyles[styleName] = _attr(e, 'display') == 'false';
            case 'table':
              name = _attr(e, 'name') ?? 'Sheet${out.length + 1}';
              style = _attr(e, 'style-name');
              cells = 0;
            case 'table-row':
              rowRepeat =
                  int.tryParse(_attr(e, 'number-rows-repeated') ?? '') ?? 1;
            case 'table-cell' || 'covered-table-cell':
              if (_attr(e, 'value-type') != null) {
                final rep =
                    int.tryParse(_attr(e, 'number-columns-repeated') ?? '') ??
                    1;
                cells += math.min(rep * rowRepeat, maxRows);
              }
          }
        } else if (e is XmlEndElementEvent) {
          final local = _local(e.name);
          if (local == 'automatic-styles') inStyles = false;
          if (local == 'table' && name != null) {
            out.add(
              OdsSheetInfo(
                name,
                hidden: tableStyles[style] ?? false,
                estimatedCells: cells,
              ),
            );
            name = null;
          }
        }
      }
      return out;
    } on XlsxFormatException {
      rethrow;
    } on Object catch (e) {
      throw XlsxFormatException('The spreadsheet could not be read ($e)');
    }
  }

  static void _checkMimeType(ZipPackage pkg) {
    final mime = pkg.text('mimetype')?.trim();
    if (mime != null &&
        mime.isNotEmpty &&
        mime != OdsNs.mimeType &&
        !mime.startsWith('application/vnd.oasis.opendocument.spreadsheet')) {
      throw XlsxFormatException(
        'The file is not an OpenDocument spreadsheet ($mime)',
      );
    }
    if (!pkg.has('content.xml')) {
      throw const XlsxFormatException('The file has no content.xml part');
    }
  }
}

String _local(String name) {
  final i = name.indexOf(':');
  return i < 0 ? name : name.substring(i + 1);
}

String? _attr(XmlStartElementEvent e, String local) {
  for (final a in e.attributes) {
    if (_local(a.name) == local) return a.value;
  }
  return null;
}

/// Builds a small DOM subtree from events (automatic styles, font faces).
final class _TreeBuilder {
  _TreeBuilder(XmlStartElementEvent start) : root = _element(start);

  final XmlElement root;
  late final List<XmlElement> _stack = [root];

  static XmlElement _element(XmlStartElementEvent e) =>
      XmlElement(XmlName.qualified(e.name), [
        for (final a in e.attributes)
          XmlAttribute(XmlName.qualified(a.name), a.value),
      ]);

  /// Adds an event; returns true when the root element is closed.
  bool add(XmlEvent e) {
    if (e is XmlStartElementEvent) {
      final el = _element(e);
      _stack.last.children.add(el);
      if (!e.isSelfClosing) _stack.add(el);
    } else if (e is XmlEndElementEvent) {
      _stack.removeLast();
      return _stack.isEmpty;
    } else if (e is XmlTextEvent) {
      _stack.last.children.add(XmlText(e.value));
    } else if (e is XmlCDATAEvent) {
      _stack.last.children.add(XmlText(e.value));
    }
    return false;
  }
}

/// One `table:table-cell` run of a row.
final class _CellRun {
  _CellRun(this.col, this.count, this.cell, this.colSpan, this.rowSpan);
  final int col;
  final int count;
  final IrCell? cell;
  final int colSpan;
  final int rowSpan;

  bool get hasContent =>
      cell != null &&
      (cell!.value != null ||
          cell!.formulaA1 != null ||
          cell!.note != null ||
          cell!.link != null);
}

/// A dimension run (columns or rows).
final class _DimRun {
  _DimRun(this.start, this.count, this.style, this.hidden, this.format);
  final int start;
  final int count;
  final OdsDimStyle style;
  final bool hidden;
  final int format;
}

/// Format-only cells postponed until the used range is known.
typedef _PendingFormat = ({int row, int rows, int col, int cols, int format});

/// State of the cell being read.
final class _CellState {
  _CellState(this.attrs);

  final Map<String, String> attrs;
  final List<(StringBuffer, Map<String, Object?>)> segments = [];
  final List<Map<String, Object?>> spanStack = [];
  final List<String?> linkStack = [];
  final StringBuffer note = StringBuffer();
  int paragraphs = 0;
  int noteParagraphs = 0;
  bool lastSpace = true;
  bool inNote = false;

  Map<String, Object?> get currentFormat {
    if (spanStack.isEmpty && linkStack.isEmpty) return const {};
    final m = <String, Object?>{};
    for (final s in spanStack) {
      m.addAll(s);
    }
    final link = linkStack.lastWhere((l) => l != null, orElse: () => null);
    if (link != null) m[RichRunKeys.link] = link;
    return m;
  }

  void append(String s) {
    if (s.isEmpty) return;
    if (inNote) {
      note.write(s);
      return;
    }
    final f = currentFormat;
    if (segments.isNotEmpty && _sameFormat(segments.last.$2, f)) {
      segments.last.$1.write(s);
    } else {
      segments.add((StringBuffer(s), f));
    }
  }

  static bool _sameFormat(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  /// Appends paragraph text with ODF white-space collapsing.
  void text(String raw) {
    final b = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d) {
        if (!lastSpace) {
          b.writeCharCode(0x20);
          lastSpace = true;
        }
      } else {
        b.writeCharCode(c);
        lastSpace = false;
      }
    }
    append(b.toString());
  }

  String get plainText {
    final b = StringBuffer();
    for (final s in segments) {
      b.write(s.$1);
    }
    return b.toString();
  }
}

final class _Reader {
  _Reader(this.pkg, this.options);

  final ZipPackage pkg;
  final OdsImportOptions options;
  final WorkbookDocument doc = WorkbookDocument();
  late final OdsStyleReader styles = OdsStyleReader(
    formats: doc.formats,
    warn: (code, message) => doc.warnings.add(code, message),
  );
  late final OpenFormulaTranslator translator;
  final Map<String, int> _unsupported = {};
  final Set<String> _names = {};

  WorkbookDocument read() {
    _readMeta();
    _readStylesPart();
    final content = pkg.text('content.xml');
    if (content == null) {
      throw const XlsxFormatException('The file has no content.xml part');
    }
    _collectNames(content);
    translator = OpenFormulaTranslator(
      excel: ExcelFormulaTranslator(
        isSupportedFunction: options.isSupportedFunction,
        knownNames: _names,
      ),
    );
    _readContent(content);
    _readSettings();
    doc.defaultFontFamily = styles.defaultFontFamily;
    doc.defaultFontSize = styles.defaultFontSize;
    if (doc.sheets.isEmpty) {
      throw const XlsxFormatException('The spreadsheet has no sheets');
    }
    return doc;
  }

  void _readMeta() {
    try {
      final meta = pkg.xml('meta.xml')?.rootElement;
      final title = meta?.child('meta')?.child('title')?.innerText.trim();
      if (title != null && title.isNotEmpty) doc.title = title;
      final lang = meta?.child('meta')?.child('language')?.innerText.trim();
      if (lang != null && lang.isNotEmpty) {
        doc.locale = lang.replaceAll('-', '_');
      }
    } on XlsxFormatException {
      doc.warnings.add('meta', 'The document properties could not be read');
    }
  }

  void _readStylesPart() {
    final root = pkg.xml('styles.xml')?.rootElement;
    if (root == null) return;
    final faces = root.child('font-face-decls');
    if (faces != null) styles.addFontFaces(faces);
    final named = root.child('styles');
    if (named != null) styles.addStyles(named, automatic: false);
    final auto = root.child('automatic-styles');
    if (auto != null) styles.addStyles(auto, automatic: false);
  }

  /// Names of named ranges/expressions (so formulas keep them as names).
  void _collectNames(String content) {
    for (final m in RegExp(
      r'<table:named-(?:range|expression)\b[^>]*\btable:name="([^"]+)"',
    ).allMatches(content)) {
      _names.add(m.group(1)!);
    }
  }

  // ---------------------------------------------------------------------------
  // content.xml

  _TreeBuilder? _tree;
  IrSheet? _sheet;
  bool _skipSheet = false;
  int _row = 0;
  int _col = 0;
  int _colDef = 0;
  final List<_DimRun> _colRuns = [];
  final List<_DimRun> _rowRuns = [];
  final List<_PendingFormat> _pending = [];
  OdsTableStyle _tableStyle = const OdsTableStyle();

  // Current row.
  bool _inRow = false;
  int _rowRepeat = 1;
  String? _rowStyle;
  bool _rowHidden = false;
  int _rowFormat = 0;
  final List<_CellRun> _cells = [];

  // Current cell.
  _CellState? _cell;
  int _ignoreDepth = 0;
  int _rowGroupDepth = 0;

  void _readContent(String content) {
    for (final e in parseEvents(content)) {
      final tree = _tree;
      if (tree != null) {
        if (tree.add(e)) {
          _tree = null;
          final root = tree.root;
          if (root.localName == 'font-face-decls') {
            styles.addFontFaces(root);
          } else {
            styles.addStyles(root, automatic: true);
          }
        }
        continue;
      }
      if (e is XmlStartElementEvent) {
        _start(e);
      } else if (e is XmlEndElementEvent) {
        _end(_local(e.name));
      } else if (e is XmlTextEvent) {
        _text(e.value);
      } else if (e is XmlCDATAEvent) {
        _text(e.value);
      }
    }
  }

  void _start(XmlStartElementEvent e) {
    final local = _local(e.name);
    if (_ignoreDepth > 0) {
      if (!e.isSelfClosing) _ignoreDepth++;
      return;
    }
    if (_cell != null) {
      _cellChild(e, local);
      return;
    }
    switch (local) {
      case 'automatic-styles' || 'font-face-decls':
        if (_sheet == null && !e.isSelfClosing) _tree = _TreeBuilder(e);
      case 'table':
        if (_sheet != null) {
          // Sub-tables are not supported.
          _ignore(e);
          return;
        }
        _startSheet(e);
        if (e.isSelfClosing) _endSheet();
      case 'table-column':
        if (_sheet != null) _column(e);
      case 'table-row-group':
        _rowGroupDepth++;
      case 'table-row':
        if (_sheet == null) return;
        _startRow(e);
        if (e.isSelfClosing) _endRow();
      case 'table-cell' || 'covered-table-cell':
        if (!_inRow) return;
        _cell = _CellState({
          for (final a in e.attributes)
            a.name.startsWith('calcext:') || a.name.startsWith('wonky:')
                    ? a.name
                    : _local(a.name):
                a.value,
        })..attrs['__covered'] = local == 'covered-table-cell' ? '1' : '0';
        if (e.isSelfClosing) _endCell();
      case 'named-range' || 'named-expression':
        _namedRange(e, local);
      case 'shapes' ||
          'content-validations' ||
          'database-ranges' ||
          'data-pilot-tables' ||
          'conditional-formats' ||
          'dde-links' ||
          'tracked-changes' ||
          'scenario' ||
          'forms':
        if (local == 'content-validations') {
          doc.warnings.add(
            'dataValidation',
            'Data validation rules were not imported',
          );
        } else if (local == 'conditional-formats') {
          doc.warnings.add(
            'conditionalFormat',
            'Conditional formatting was not imported',
          );
        } else if (local == 'data-pilot-tables') {
          doc.warnings.add(
            'pivotTable',
            'Pivot tables were imported as values',
          );
        } else if (local == 'shapes') {
          doc.warnings.add(
            'drawing',
            'Images and drawings were not imported',
            sheet: _sheet?.name,
          );
        }
        _ignore(e);
    }
  }

  void _ignore(XmlStartElementEvent e) {
    if (!e.isSelfClosing) _ignoreDepth = 1;
  }

  void _end(String local) {
    if (_ignoreDepth > 0) {
      _ignoreDepth--;
      return;
    }
    final cell = _cell;
    if (cell != null) {
      switch (local) {
        case 'table-cell' || 'covered-table-cell':
          _endCell();
        case 'span' when !cell.inNote:
          if (cell.spanStack.isNotEmpty) cell.spanStack.removeLast();
        case 'a' when !cell.inNote:
          if (cell.linkStack.isNotEmpty) cell.linkStack.removeLast();
        case 'annotation':
          cell.inNote = false;
      }
      return;
    }
    switch (local) {
      case 'table-row':
        if (_inRow) _endRow();
      case 'table-row-group':
        if (_rowGroupDepth > 0) _rowGroupDepth--;
      case 'table':
        if (_sheet != null) _endSheet();
    }
  }

  void _text(String text) {
    final cell = _cell;
    if (cell == null || _ignoreDepth > 0) return;
    if (cell.inNote) {
      if (cell.noteParagraphs > 0) cell.note.write(text);
      return;
    }
    if (cell.paragraphs > 0) cell.text(text);
  }

  void _cellChild(XmlStartElementEvent e, String local) {
    final cell = _cell!;
    switch (local) {
      case 'annotation':
        if (!e.isSelfClosing) cell.inNote = true;
      case 'creator' || 'date' when cell.inNote:
        if (!e.isSelfClosing) _ignoreDepth = 1;
      case 'p' || 'h':
        if (cell.inNote) {
          if (cell.noteParagraphs > 0) cell.note.write('\n');
          cell.noteParagraphs++;
          return;
        }
        if (cell.paragraphs > 0) cell.append('\n');
        cell.paragraphs++;
        cell.lastSpace = true;
      case 'span':
        if (cell.inNote) return;
        if (!e.isSelfClosing) {
          cell.spanStack.add(styles.textFormat(_attr(e, 'style-name')));
        }
      case 'a':
        if (cell.inNote) return;
        if (!e.isSelfClosing) cell.linkStack.add(_attr(e, 'href'));
      case 's':
        final n = int.tryParse(_attr(e, 'c') ?? '') ?? 1;
        // Elements end a white-space sequence: a following space is kept.
        cell.append(' ' * n.clamp(1, 1000));
        cell.lastSpace = false;
      case 'tab':
        cell.append('\t');
        cell.lastSpace = false;
      case 'line-break':
        cell.append('\n');
        cell.lastSpace = false;
      case 'frame' || 'custom-shape' || 'g' || 'rect' || 'line' || 'ellipse':
        _ignore(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Sheets, columns, rows.

  void _startSheet(XmlStartElementEvent e) {
    final name = _attr(e, 'name') ?? 'Sheet${doc.sheets.length + 1}';
    _skipSheet = options.sheets != null && !options.sheets!.contains(name);
    final s = IrSheet(name);
    _tableStyle = styles.table(_attr(e, 'style-name'));
    s
      ..hidden = _tableStyle.hidden
      ..rtl = _tableStyle.rtl
      ..tabColor = _tableStyle.tabColor;
    _sheet = s;
    _row = 0;
    _colDef = 0;
    _colRuns.clear();
    _rowRuns.clear();
    _pending.clear();
    _cells.clear();
    _inRow = false;
    _rowGroupDepth = 0;
  }

  void _column(XmlStartElementEvent e) {
    final count = (int.tryParse(_attr(e, 'number-columns-repeated') ?? '') ?? 1)
        .clamp(1, OdsImporter.maxCols);
    if (_colDef >= OdsImporter.maxCols) return;
    final n = math.min(count, OdsImporter.maxCols - _colDef);
    final vis = _attr(e, 'visibility');
    _colRuns.add(
      _DimRun(
        _colDef,
        n,
        styles.column(_attr(e, 'style-name')),
        vis == 'collapse' || vis == 'filter',
        styles.cellFormat(_attr(e, 'default-cell-style-name')),
      ),
    );
    _colDef += n;
  }

  int _columnFormat(int col) {
    for (final r in _colRuns) {
      if (col >= r.start && col < r.start + r.count) return r.format;
    }
    return 0;
  }

  void _startRow(XmlStartElementEvent e) {
    _inRow = true;
    _col = 0;
    _cells.clear();
    _rowRepeat = (int.tryParse(_attr(e, 'number-rows-repeated') ?? '') ?? 1)
        .clamp(1, OdsImporter.maxRows);
    _rowStyle = _attr(e, 'style-name');
    final vis = _attr(e, 'visibility');
    _rowHidden = vis == 'collapse' || vis == 'filter';
    _rowFormat = styles.cellFormat(_attr(e, 'default-cell-style-name'));
  }

  void _endRow() {
    _inRow = false;
    final s = _sheet!;
    if (_row >= OdsImporter.maxRows) return;
    final repeat = math.min(_rowRepeat, OdsImporter.maxRows - _row);
    _rowRuns.add(
      _DimRun(_row, repeat, styles.row(_rowStyle), _rowHidden, _rowFormat),
    );
    for (final run in _cells) {
      final cell = run.cell;
      if (cell == null) continue;
      if (!run.hasContent) {
        // Format-only cells: skip the inherited default, defer huge runs.
        final inherited = _rowFormat != 0 ? _rowFormat : _columnFormat(run.col);
        if (cell.format == 0 || cell.format == inherited) continue;
        if (repeat * run.count > 20000 || run.count > 1024) {
          _pending.add((
            row: _row,
            rows: repeat,
            col: run.col,
            cols: run.count,
            format: cell.format,
          ));
          continue;
        }
      }
      for (var r = _row; r < _row + repeat; r++) {
        for (var c = run.col; c < run.col + run.count; c++) {
          if (!_skipSheet) s.cells.set(r, c, cell);
          if (run.colSpan > 1 || run.rowSpan > 1) {
            s.merges.add(
              GridRect(
                r,
                c,
                math.min(r + run.rowSpan - 1, OdsImporter.maxRows - 1),
                math.min(c + run.colSpan - 1, OdsImporter.maxCols - 1),
              ),
            );
          }
        }
      }
    }
    _row += repeat;
  }

  void _endSheet() {
    final s = _sheet!;
    _sheet = null;
    if (_skipSheet) return;
    // Used range from materialized cells and merges.
    final maxRow = math.max(
      s.cells.maxRow,
      s.merges.fold(-1, (m, g) => math.max(m, g.bottom)),
    );
    final maxCol = math.max(
      s.cells.maxCol,
      s.merges.fold(-1, (m, g) => math.max(m, g.right)),
    );
    for (final p in _pending) {
      final r2 = math.min(p.row + p.rows - 1, maxRow);
      final c2 = math.min(p.col + p.cols - 1, maxCol);
      for (var r = p.row; r <= r2; r++) {
        for (var c = p.col; c <= c2; c++) {
          if (s.cells.get(r, c) == null) {
            s.cells.set(r, c, IrCell(format: p.format));
          }
        }
      }
    }
    _pending.clear();

    // Default sizes: Wonky's own, else the largest run.
    double? largest(List<_DimRun> runs) {
      _DimRun? best;
      for (final r in runs) {
        if (r.style.sizePx == null) continue;
        if (best == null || r.count >= best.count) best = r;
      }
      return best?.style.sizePx;
    }

    if (_tableStyle.wonkyDefaults) {
      s.defaultColumnWidth = _tableStyle.defaultColumnWidth;
      s.defaultRowHeight = _tableStyle.defaultRowHeight;
    } else {
      s.defaultColumnWidth = largest(_colRuns);
      s.defaultRowHeight = largest(_rowRuns);
    }

    void apply(
      List<_DimRun> runs,
      SparseAxis<IrDim> axis,
      int used,
      bool rows,
    ) {
      for (final r in runs) {
        final size = r.style.sizePx;
        final explicit =
            size != null &&
            !(rows && r.style.optimal) &&
            size !=
                (rows
                    ? (s.defaultRowHeight ?? 21)
                    : (s.defaultColumnWidth ?? 100));
        final dim = IrDim(
          size: explicit ? size : null,
          hidden: r.hidden,
          format: r.format,
        );
        if (dim.isDefault) continue;
        final end = r.count > 1000
            ? math.min(r.start + r.count - 1, used)
            : r.start + r.count - 1;
        for (var i = r.start; i <= end; i++) {
          axis[i] = dim;
        }
      }
    }

    apply(_colRuns, s.columns, maxCol, false);
    apply(_rowRuns, s.rows, maxRow, true);
    for (final r in _rowRuns) {
      if (r.style.breakBefore) _printBreak(s, 'rows', r.start);
    }
    for (final r in _colRuns) {
      if (r.style.breakBefore) _printBreak(s, 'cols', r.start);
    }
    for (final e in _unsupported.entries) {
      doc.warnings.add(
        'unsupportedFunction',
        '${e.value} cells used unsupported ${e.key.contains(' ') ? '' : 'function '}${e.key}',
        sheet: s.name,
        count: e.value,
      );
    }
    _unsupported.clear();
    doc.sheets.add(s);
  }

  void _printBreak(IrSheet s, String axis, int index) {
    if (index == 0) return;
    final p = s.print ??= <String, Object?>{};
    final breaks =
        (p['pageBreaks'] as Map<String, Object?>?) ??
        <String, Object?>{'rows': <int>[], 'cols': <int>[]};
    p['pageBreaks'] = breaks;
    (breaks[axis] as List<int>).add(index);
  }

  // ---------------------------------------------------------------------------
  // Cells.

  void _endCell() {
    final st = _cell!;
    _cell = null;
    final a = st.attrs;
    final repeat = (int.tryParse(a['number-columns-repeated'] ?? '') ?? 1)
        .clamp(1, OdsImporter.maxCols);
    final col = _col;
    _col += repeat;
    if (col >= OdsImporter.maxCols) return;
    final count = math.min(repeat, OdsImporter.maxCols - col);
    final covered = a['__covered'] == '1';
    final colSpan = covered
        ? 1
        : (int.tryParse(a['number-columns-spanned'] ?? '') ?? 1).clamp(
            1,
            OdsImporter.maxCols,
          );
    final rowSpan = covered
        ? 1
        : (int.tryParse(a['number-rows-spanned'] ?? '') ?? 1).clamp(
            1,
            OdsImporter.maxRows,
          );
    final cell = _buildCell(st, _row, col);
    _cells.add(_CellRun(col, count, cell, colSpan, rowSpan));
  }

  IrCell? _buildCell(_CellState st, int row, int col) {
    final a = st.attrs;
    final format = styles.cellFormat(a['style-name']);
    final type = a['value-type'];
    final calcType = a['calcext:value-type'] ?? type;
    final text = st.plainText;
    IrValue? value;
    var numberFormat = doc.formats[format][FormatAttr.numberFormat];
    String? autoFormat;
    switch (type) {
      case 'float' || 'percentage' || 'currency':
        final v = double.tryParse(a['value'] ?? '');
        if (v != null && v.isFinite) value = IrNumber(v);
        if (type == 'percentage' && numberFormat == null) autoFormat = '0.00%';
      case 'date':
        final iso = a['date-value'];
        final v =
            _exact(a['wonky:value']) ?? (iso == null ? null : _isoDate(iso));
        if (v != null) {
          value = IrNumber(v);
          if (numberFormat == null ||
              !NumberFormatInfo.of(numberFormat as String).isDateOrTime) {
            autoFormat = (iso ?? '').contains('T') && v != v.floorToDouble()
                ? 'preset:dateTime'
                : 'preset:date';
          }
        }
      case 'time':
        final iso = a['time-value'];
        final v =
            _exact(a['wonky:value']) ??
            (iso == null ? null : _isoDuration(iso));
        if (v != null) {
          value = IrNumber(v);
          if (numberFormat == null ||
              !NumberFormatInfo.of(numberFormat as String).isDateOrTime) {
            autoFormat = v >= 1 || v < 0 ? '[h]:mm:ss' : 'preset:time';
          }
        }
      case 'boolean':
        final v = (a['boolean-value'] ?? text).trim().toLowerCase();
        if (v == 'true' || v == 'false') value = IrBool(v == 'true');
      case 'string':
        value = _textValue(st, a['string-value']);
      case null || 'void':
        if (text.isNotEmpty) value = _textValue(st, null);
    }
    if (calcType == 'error') {
      value = IrError(
        CellErrorKind.tryParse(text.trim()) ?? CellErrorKind.value,
      );
    }

    String? formula;
    var kind = IrFormulaKind.normal;
    GridRect? arrayRef;
    String? note = st.noteParagraphs > 0 ? st.note.toString() : null;
    final f = a['formula'];
    if (f != null && f.trim().isNotEmpty) {
      final tr = translator.importFormula(f);
      if (!tr.isSupported) {
        for (final u in tr.unsupported) {
          _unsupported[u] = (_unsupported[u] ?? 0) + 1;
        }
        final msg =
            'Imported value — original formula used unsupported function '
            '${tr.unsupported.join(', ')}: =${tr.formula}';
        note = note == null ? msg : '$note\n$msg';
        if (options.unsupportedFormulas == UnsupportedFormulaMode.text) {
          value = IrText('=${tr.formula}');
        }
      } else {
        formula = tr.formula;
        final mc = int.tryParse(a['number-matrix-columns-spanned'] ?? '');
        final mr = int.tryParse(a['number-matrix-rows-spanned'] ?? '');
        if (mc != null && mr != null && (mc > 1 || mr > 1)) {
          kind = IrFormulaKind.array;
          arrayRef = GridRect(row, col, row + mr - 1, col + mc - 1);
          formula = 'ARRAYFORMULA($formula)';
        }
      }
    }

    // Whole-cell link: one link over the whole text.
    String? link;
    final v = value;
    if (v is IrRich) {
      final norm = v.rich.normalize();
      if (norm.wholeCellLink != null) {
        link = _link(norm.wholeCellLink!);
        value = IrText(v.rich.text);
      } else if (norm.rich == null) {
        value = IrText(v.rich.text);
      } else {
        value = IrRich(
          RichText(norm.rich!.text, [
            for (final r in norm.rich!.runs)
              r.link == null
                  ? r
                  : r.copyWith(
                      format: {...r.format, RichRunKeys.link: _link(r.link!)},
                    ),
          ]),
        );
      }
    }
    var fmt = format;
    if (autoFormat != null) {
      fmt = doc.formats.intern(
        doc.formats[format].withValues({FormatAttr.numberFormat: autoFormat}),
      );
    }
    if (value == null && formula == null && note == null && link == null) {
      return fmt == 0 ? null : IrCell(format: fmt);
    }
    return IrCell(
      value: value,
      formulaA1: formula,
      formulaKind: kind,
      arrayRef: arrayRef,
      format: fmt,
      note: note,
      link: link,
    );
  }

  IrValue _textValue(_CellState st, String? stringValue) {
    final text = st.plainText;
    if (stringValue != null && stringValue != text) return IrText(stringValue);
    final runs = <RichRun>[];
    var pos = 0;
    for (final (b, f) in st.segments) {
      final len = b.length;
      if (f.isNotEmpty) runs.add(RichRun(pos, pos + len, f));
      pos += len;
    }
    if (runs.isEmpty) return IrText(text);
    return IrRich(RichText(text, runs));
  }

  /// ODF link → IR link (`#Sheet1.A1` → `#Sheet1!A1`).
  String _link(String href) {
    final h = href.trim();
    if (!h.startsWith('#')) return h;
    final ref = h.substring(1);
    final r = translator.importFormula('of:=[\$$ref]');
    if (r.isSupported && !r.formula.contains('#REF!')) return '#${r.formula}';
    return h;
  }

  static double? _exact(String? v) {
    final d = v == null ? null : double.tryParse(v);
    return d != null && d.isFinite ? d : null;
  }

  static double? _isoDate(String iso) {
    final m = RegExp(
      r'^(-?\d{4,})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}(?:\.\d+)?))?)?',
    ).firstMatch(iso.trim());
    if (m == null) return null;
    final day = DateSerial.fromYmd(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
    if (m.group(4) == null) return day.toDouble();
    final secs = double.parse(m.group(6) ?? '0');
    return day +
        DateSerial.timeFraction(
          int.parse(m.group(4)!),
          int.parse(m.group(5)!),
          secs,
        );
  }

  static double? _isoDuration(String iso) {
    final m = RegExp(
      r'^(-)?P(?:(\d+(?:\.\d+)?)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
    ).firstMatch(iso.trim());
    if (m == null) return null;
    double g(int i) => double.tryParse(m.group(i) ?? '') ?? 0;
    final days = g(2) + (g(3) * 3600 + g(4) * 60 + g(5)) / 86400;
    final v = m.group(1) != null ? -days : days;
    return (v * 1e12).roundToDouble() / 1e12;
  }

  // ---------------------------------------------------------------------------
  // Names.

  void _namedRange(XmlStartElementEvent e, String local) {
    var name = _attr(e, 'name');
    if (name == null || name.isEmpty) return;
    final scope = _sheet?.name;
    if (scope != null) {
      final qualified = '${scope}_$name'.replaceAll(RegExp(r'[^\w.]'), '_');
      doc.warnings.add(
        'sheetScopedName',
        'Sheet-level name "$name" of "$scope" was imported as "$qualified"',
        sheet: scope,
      );
      name = qualified;
    }
    if (local == 'named-range') {
      final address = _attr(e, 'cell-range-address');
      if (address == null) return;
      final r = _rangeOf(address);
      if (r == null) {
        doc.warnings.add('namedRange', 'Named range "$name" was not imported');
        return;
      }
      doc.namedRanges.add(
        IrNamedRange(name: name, sheet: r.$1 ?? scope, range: r.$2),
      );
      return;
    }
    final expr = _attr(e, 'expression');
    if (expr == null) return;
    final tr = translator.importFormula(expr);
    final asRange = IrRange.parseA1(tr.formula);
    if (asRange != null && asRange.$1 != null) {
      doc.namedRanges.add(
        IrNamedRange(
          name: name,
          sheet: asRange.$1,
          range: asRange.$2.openAt(
            maxRows: OdsImporter.maxRows,
            maxCols: OdsImporter.maxCols,
          ),
        ),
      );
      return;
    }
    doc.namedRanges.add(IrNamedRange(name: name, formulaA1: tr.formula));
  }

  (String?, IrRange)? _rangeOf(String address) {
    // `$Data.$A$1:.$A$5` (several ranges separated by spaces: first one).
    final t = address.trim();
    var end = t.length;
    var quoted = false;
    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      if (ch == "'") quoted = !quoted;
      if (!quoted && (ch == ' ' || ch == ';')) {
        end = i;
        break;
      }
    }
    final first = t.substring(0, end);
    if (quoted || first.isEmpty) return null;
    final tr = translator.importFormula('of:=[$first]');
    final p = IrRange.parseA1(tr.formula);
    if (p == null) return null;
    return (
      p.$1,
      p.$2.openAt(maxRows: OdsImporter.maxRows, maxCols: OdsImporter.maxCols),
    );
  }

  // ---------------------------------------------------------------------------
  // settings.xml: frozen panes and gridlines.

  void _readSettings() {
    XmlElement? root;
    try {
      root = pkg.xml('settings.xml')?.rootElement;
    } on XlsxFormatException {
      doc.warnings.add('settings', 'The view settings could not be read');
      return;
    }
    if (root == null) return;
    XmlElement? views;
    for (final e in root.descendantElements) {
      if (e.localName == 'config-item-map-indexed' &&
          e.attr('name') == 'Views') {
        views = e;
        break;
      }
    }
    final view = views?.child('config-item-map-entry');
    if (view == null) return;
    String? item(XmlElement parent, String name) {
      for (final c in parent.elems('config-item')) {
        if (c.attr('name') == name) return c.innerText.trim();
      }
      return null;
    }

    final globalGrid = item(view, 'ShowGrid');
    XmlElement? tables;
    for (final m in view.elems('config-item-map-named')) {
      if (m.attr('name') == 'Tables') tables = m;
    }
    for (final s in doc.sheets) {
      XmlElement? entry;
      for (final t
          in tables?.elems('config-item-map-entry') ?? const <XmlElement>[]) {
        if (t.attr('name') == s.name) entry = t;
      }
      final grid =
          (entry == null ? null : item(entry, 'ShowGrid')) ?? globalGrid;
      if (grid == 'false') s.showGridlines = false;
      if (entry == null) continue;
      if (item(entry, 'HorizontalSplitMode') == '2') {
        s.frozenColumns =
            int.tryParse(item(entry, 'HorizontalSplitPosition') ?? '') ?? 0;
      }
      if (item(entry, 'VerticalSplitMode') == '2') {
        s.frozenRows =
            int.tryParse(item(entry, 'VerticalSplitPosition') ?? '') ?? 0;
      }
      final tab = item(entry, 'TabColor');
      if (s.tabColor == null && tab != null) {
        final v = int.tryParse(tab);
        if (v != null && v >= 0 && v != 0xFFFFFFFF) {
          s.tabColor =
              '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
        }
      }
    }
  }
}
