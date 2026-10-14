import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../../addressing/a1.dart';
import '../../addressing/grid_geometry.dart';
import '../../charts/spec/image_spec.dart';
import '../../content/rich_text.dart';
import '../../data_tools/names/name_rules.dart';
import '../../engine_bridge/stored_formula.dart';
import '../../format/attributes.dart';
import '../../format/borders.dart';
import '../../format/theme.dart';
import '../../formula/codec/formula_codec.dart';
import '../../formula/model/workbook_view.dart';
import '../../model/grid_range.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';
import '../../mutations/handlers/sheets.dart' show sheetChildren;
import '../../mutations/plan_builder.dart';
import '../../mutations/row_change.dart';
import '../../objects/anchor.dart';
import '../formula/formula_tokens.dart';
import '../ir/import_warning.dart';
import '../ir/ir_chart_spec.dart';
import '../ir/ir_range.dart';
import '../ir/workbook_document.dart';
import 'import_options.dart';
import 'import_report.dart';
import 'planned_workbook_view.dart';

/// IR → synced rows (11 §1.2): turns a [WorkbookDocument] into the
/// [MutationPlan] that creates a new spreadsheet, inserts sheets into an
/// existing one, or writes into the active sheet ([ImportLocation]).
///
/// - New sheets get UUIDv7 ids ([PlanContext.ids]) and evenly spaced sort
///   keys, sized `max(used + 1, 1000)` rows × `max(used, 26)` columns
///   (tight `used` sizes when the padding would exceed the cell limit).
/// - Cells use deterministic ids; formulas are converted A1 → stored form
///   after all sheets, rows and columns of the plan exist.
/// - Only non-default attributes are written; a format shared by ≥ 90 % of a
///   column's cells becomes the column default.
/// - Merges, groups, DV, CF, the basic filter, named ranges, images, charts
///   and print settings use id-based `GridRange` JSON.
/// - The cell limit (§3.4) is enforced: `PlanException('cell_limit_exceeded')`.
///
/// The plan is one undo step for imports into an existing spreadsheet
/// (`plan.inverse()` / `UndoInverter`); apply it with `model.applyPlan` and
/// write it in [MutationPlan.chunks].
abstract final class IrToRowsPlanner {
  /// Plans [doc] into [model] at [ImportOptions.location].
  ///
  /// - [activeSheetId]: insert position for [ImportLocation.insertSheets]
  ///   and target sheet of the in-sheet locations (default: first sheet).
  /// - [fileName]: used for the undo label (`Import orders.csv`) and the
  ///   title of a new spreadsheet.
  /// - [startRow]/[startCol] override [ImportOptions.cell] for
  ///   [ImportLocation.replaceAtCell].
  ///
  /// For [ImportLocation.createNew], [model] is the (empty) model of the new
  /// spreadsheet; its `spreadsheetId` is used.
  static IrImportResult plan(
    WorkbookDocument doc,
    WorkbookModel model,
    PlanContext ctx, {
    ImportOptions options = const ImportOptions(),
    String? activeSheetId,
    String? fileName,
    String? label,
    int? startRow,
    int? startCol,
  }) => _Planner(
    doc,
    model,
    ctx,
    options,
    activeSheetId: activeSheetId,
    fileName: fileName,
    label: label,
    startRow: startRow,
    startCol: startCol,
  ).run();

  /// The resulting grid size of importing [doc] (dialog check, 11 §3.4),
  /// computed like [plan] without building rows.
  static ImportSizeEstimate estimate(
    WorkbookDocument doc,
    WorkbookModel model, {
    ImportOptions options = const ImportOptions(),
    String? activeSheetId,
    int maxCells = 1000000,
    int? startRow,
    int? startCol,
  }) {
    final p = _Planner(
      doc,
      model,
      PlanContext(userId: '', now: DateTime.utc(1970), maxCells: maxCells),
      options,
      activeSheetId: activeSheetId,
      startRow: startRow,
      startCol: startCol,
    );
    return p.estimate();
  }
}

/// Default grid of a new sheet.
const int _defaultRows = 1000;
const int _defaultCols = 26;

/// Format attributes that are invisible on empty cells (candidates for
/// column defaults).
const Set<FormatAttr> _invisibleOnEmpty = {
  FormatAttr.numberFormat,
  FormatAttr.fontFamily,
  FormatAttr.fontSize,
  FormatAttr.bold,
  FormatAttr.italic,
  FormatAttr.underline,
  FormatAttr.strikethrough,
  FormatAttr.textColor,
  FormatAttr.hAlign,
  FormatAttr.vAlign,
  FormatAttr.wrap,
  FormatAttr.rotation,
};

/// Cell columns cleared explicitly when a cell is rewritten in place.
const List<String> _cellValueColumns = [
  CellCols.content,
  CellCols.note,
  CellCols.numberFormat,
  CellCols.fontFamily,
  CellCols.fontSize,
  CellCols.bold,
  CellCols.italic,
  CellCols.underline,
  CellCols.strikethrough,
  CellCols.textColor,
  CellCols.fillColor,
  CellCols.hAlign,
  CellCols.vAlign,
  CellCols.wrap,
  CellCols.rotation,
  CellCols.borderTop,
  CellCols.borderRight,
  CellCols.borderBottom,
  CellCols.borderLeft,
  CellCols.linkUrl,
];

/// Where rows of the plan go: new rows straight into change lists, or
/// writes into existing sheets through a [PlanBuilder] overlay.
abstract class _Sink {
  /// Inserts a new row.
  void insert(String table, String id, Map<String, Object?> columns);

  /// Updates an existing row.
  void update(String table, String id, Map<String, Object?> columns);

  /// Writes cell columns (creating the cell row when needed).
  void cell(
    String sheetId,
    String rowId,
    String colId,
    Map<String, Object?> columns,
  );

  /// Whether this sink writes into existing rows (cells get explicit nulls).
  bool get inPlace;
}

final class _FreshSink implements _Sink {
  _FreshSink(this.now);

  final DateTime now;
  final Map<String, List<RowChange>> byTable = {};
  int cellDetails = 0;
  final List<Map<String, Object?>> details = [];

  @override
  bool get inPlace => false;

  final Map<(String, String), int> _positions = {};

  @override
  void insert(String table, String id, Map<String, Object?> columns) {
    final list = byTable[table] ??= [];
    if (table != SheetsTables.cell) _positions[(table, id)] = list.length;
    list.add(RowChange.insert(table, id, {Cols.createdAt: now, ...columns}));
  }

  /// Merges [columns] into a row inserted earlier (cells excluded).
  @override
  void update(String table, String id, Map<String, Object?> columns) {
    final i = _positions[(table, id)];
    if (i == null) throw StateError('Row $table $id was not inserted');
    final list = byTable[table]!;
    list[i] = RowChange.insert(table, id, {
      ...list[i].columnsAfter,
      ...columns,
    });
  }

  @override
  void cell(
    String sheetId,
    String rowId,
    String colId,
    Map<String, Object?> columns,
  ) {
    final cols = <String, Object?>{
      Cols.sheetId: sheetId,
      CellCols.rowId: rowId,
      CellCols.columnId: colId,
    };
    columns.forEach((k, v) {
      if (v != null) cols[k] = v;
    });
    final content = cols[CellCols.content];
    if (content != null) {
      if (details.length < MutationPlan.maxDetailCells) {
        details.add({
          's': sheetId,
          'r': rowId,
          'c': colId,
          'b': null,
          'a': content,
        });
      }
      cellDetails++;
    }
    insert(SheetsTables.cell, SheetsIds.cellId(sheetId, rowId, colId), cols);
  }

  /// All rows in table dependency order.
  List<RowChange> get changes => [
    for (final t in SheetsTables.dependencyOrder) ...?byTable[t],
    for (final e in byTable.entries)
      if (!SheetsTables.dependencyOrder.contains(e.key)) ...e.value,
  ];
}

final class _BuilderSink implements _Sink {
  _BuilderSink(this.b);

  final PlanBuilder b;

  @override
  bool get inPlace => true;

  @override
  void insert(String table, String id, Map<String, Object?> columns) =>
      b.insert(table, id, columns);

  @override
  void update(String table, String id, Map<String, Object?> columns) =>
      b.update(table, id, columns);

  @override
  void cell(
    String sheetId,
    String rowId,
    String colId,
    Map<String, Object?> columns,
  ) => b.writeCell(sheetId, rowId, colId, columns);
}

/// One sheet being written.
final class _Target {
  _Target({
    required this.ir,
    required this.view,
    required this.sink,
    this.rowOffset = 0,
    this.colOffset = 0,
    this.full = true,
  });

  final IrSheet ir;
  final PlannedSheetView view;
  final _Sink sink;
  final int rowOffset;
  final int colOffset;

  /// Whether the whole sheet is written (dims, rules, objects, settings),
  /// not just cells.
  final bool full;
  int cells = 0;

  String get id => view.id;
  PlannedAxis get rows => view.rows;
  PlannedAxis get cols => view.columns;
}

/// Size of an IR sheet: used rows/columns (cells, merges, formatted or
/// sized rows/columns, objects, frozen panes).
(int rows, int cols) _extent(IrSheet s) {
  var r = s.cells.maxRow;
  var c = s.cells.maxCol;
  for (final m in s.merges) {
    if (m.bottom > r) r = m.bottom;
    if (m.right > c) c = m.right;
  }
  for (final e in s.rows.entries) {
    if (!e.value.isDefault && e.key > r) r = e.key;
  }
  for (final e in s.columns.entries) {
    if (!e.value.isDefault && e.key > c) c = e.key;
  }
  for (final i in s.images) {
    if (i.anchor.row > r) r = i.anchor.row;
    if (i.anchor.col > c) c = i.anchor.col;
  }
  for (final ch in s.charts) {
    if (ch.anchor.row > r) r = ch.anchor.row;
    if (ch.anchor.col > c) c = ch.anchor.col;
  }
  if (s.frozenRows - 1 > r) r = s.frozenRows - 1;
  if (s.frozenColumns - 1 > c) c = s.frozenColumns - 1;
  return (r + 1, c + 1);
}

final class _Planner {
  _Planner(
    this.doc,
    this.model,
    this.ctx,
    this.options, {
    this.activeSheetId,
    this.fileName,
    this.label,
    this.startRow,
    this.startCol,
  }) : builder = PlanBuilder(model, ctx),
       fresh = _FreshSink(ctx.now) {
    warnings.addAll(doc.warnings);
    final loc = options.location;
    if (doc.theme != null &&
        loc != ImportLocation.createNew &&
        loc != ImportLocation.replaceSpreadsheet) {
      _docTheme = doc.theme!.toSpreadsheetTheme();
    }
  }

  final WorkbookDocument doc;
  final WorkbookModel model;
  final PlanContext ctx;
  final ImportOptions options;
  final String? activeSheetId;
  final String? fileName;
  final String? label;
  final int? startRow;
  final int? startCol;

  final PlanBuilder builder;
  final _FreshSink fresh;
  final ImportWarnings warnings = ImportWarnings();
  late PlannedWorkbookView view;
  final List<_Target> targets = [];
  final List<IrImageUpload> uploads = [];

  /// IR sheet name (lower case) → final name.
  final Map<String, String> _sheetRenames = {};

  /// IR name (lower case) → final name.
  final Map<String, String> _nameRenames = {};

  /// Theme used to resolve `theme:*` colors of the file when the target
  /// keeps its own theme.
  SpreadsheetTheme? _docTheme;

  // ---------------------------------------------------------------------------
  // Selection and sizes.

  List<IrSheet> get _irSheets {
    final wanted = options.sheets;
    if (wanted == null) return doc.sheets;
    final lower = {for (final n in wanted) n.toLowerCase()};
    return [
      for (final s in doc.sheets)
        if (lower.contains(s.name.toLowerCase())) s,
    ];
  }

  /// `(rows, cols)` of a new sheet for [ir] (padded or tight).
  static (int, int) _sizeOf(IrSheet ir, {required bool tight}) {
    final (r, c) = _extent(ir);
    if (tight) return (r < 1 ? 1 : r, c < 1 ? 1 : c);
    return (
      r + 1 < _defaultRows ? _defaultRows : r + 1,
      c < _defaultCols ? _defaultCols : c,
    );
  }

  int get _keptCells =>
      options.location == ImportLocation.createNew ||
          options.location == ImportLocation.replaceSpreadsheet
      ? 0
      : model.gridCellCount;

  /// Sheet sizes for the sheet-creating locations, honoring the limit.
  List<(int, int)> _sheetSizes(List<IrSheet> sheets) {
    var sizes = [for (final s in sheets) _sizeOf(s, tight: false)];
    int total(List<(int, int)> l) =>
        l.fold(_keptCells, (a, e) => a + e.$1 * e.$2);
    if (total(sizes) > ctx.maxCells) {
      sizes = [for (final s in sheets) _sizeOf(s, tight: true)];
    }
    return sizes;
  }

  ImportSizeEstimate estimate() {
    final sheets = _irSheets;
    if (options.location.createsSheets) {
      final sizes = _sheetSizes(sheets);
      return ImportSizeEstimate(
        cells: sizes.fold(_keptCells, (a, e) => a + e.$1 * e.$2),
        limit: ctx.maxCells,
        sheets: [
          for (var i = 0; i < sheets.length; i++)
            (sheets[i].name, sizes[i].$1, sizes[i].$2),
        ],
      );
    }
    if (sheets.isEmpty) {
      return ImportSizeEstimate(
        cells: model.gridCellCount,
        limit: ctx.maxCells,
        sheets: const [],
      );
    }
    final s = _activeSheet();
    final (rows, cols) = _inSheetSize(s, sheets.first);
    var total = 0;
    for (final x in model.sheets) {
      total += x.id == s.id ? rows * cols : x.rows.length * x.columns.length;
    }
    return ImportSizeEstimate(
      cells: total,
      limit: ctx.maxCells,
      sheets: [(s.name, rows, cols)],
    );
  }

  void _checkLimit(int total) {
    if (total > ctx.maxCells) {
      final e = ImportSizeEstimate(
        cells: total,
        limit: ctx.maxCells,
        sheets: const [],
      );
      throw PlanException(
        'cell_limit_exceeded',
        e.message,
        details: {'cells': total, 'limit': ctx.maxCells},
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Entry.

  IrImportResult run() {
    final sheets = _irSheets;
    if (sheets.isEmpty) {
      throw const PlanException(
        'invalid_argument',
        'The file has no sheets to import',
      );
    }
    if (options.location.createsSheets) {
      _planSheets(sheets);
    } else {
      _planInSheet(sheets);
    }
    return _result();
  }

  // ---------------------------------------------------------------------------
  // Sheet-creating locations.

  void _planSheets(List<IrSheet> sheets) {
    final loc = options.location;
    final sizes = _sheetSizes(sheets);
    _checkLimit(sizes.fold(_keptCells, (a, e) => a + e.$1 * e.$2));
    final tight =
        sizes.isNotEmpty && sizes.first != _sizeOf(sheets.first, tight: false);
    if (tight) {
      warnings.add(
        'gridTrimmed',
        'Empty rows and columns after the data were not added to stay within the cell limit',
        severity: ImportSeverity.info,
      );
    }

    final keep = loc == ImportLocation.insertSheets;
    if (loc == ImportLocation.replaceSpreadsheet) {
      for (final s in model.sheets) {
        for (final (t, id) in sheetChildren(s)) {
          builder.delete(t, id);
        }
        builder.delete(SheetsTables.sheet, s.id);
        builder.summary.addDeleted('sheets', s.id);
      }
      for (final n in model.namedRanges) {
        builder.delete(SheetsTables.namedRange, n.id);
      }
    }
    if (loc == ImportLocation.createNew ||
        loc == ImportLocation.replaceSpreadsheet) {
      _spreadsheetRow(loc == ImportLocation.createNew);
    } else {
      _sheetDefaultFont = _defaultFontFormat();
    }

    // Names: unique among the kept sheets and the imported ones.
    final taken = <String>{
      if (keep)
        for (final s in model.sheets) s.name.toLowerCase(),
    };
    final names = <String>[];
    for (final s in sheets) {
      final n = _uniqueSheetName(s.name, taken);
      names.add(n);
      if (n != s.name) {
        _sheetRenames[s.name.toLowerCase()] = n;
        warnings.add(
          'sheetRenamed',
          'Sheet "${s.name}" was renamed to "$n"',
          severity: ImportSeverity.info,
          sheet: s.name,
        );
      }
    }

    // Sort keys.
    final keys = _sheetKeys(sheets.length, keep);

    view = PlannedWorkbookView(model.spreadsheetId, settings: _settings());
    var anyVisible = keep && model.sheets.any((s) => !s.record!.hidden);
    for (var i = 0; i < sheets.length; i++) {
      if (!sheets[i].hidden) anyVisible = true;
    }
    for (var i = 0; i < sheets.length; i++) {
      final ir = sheets[i];
      final (rows, cols) = sizes[i];
      final id = ctx.ids.newId();
      var hidden = ir.hidden;
      if (!anyVisible && i == 0) {
        hidden = false;
        warnings.add(
          'hiddenSheetShown',
          'All sheets were hidden; the first one is shown',
          sheet: ir.name,
        );
      }
      fresh.insert(SheetsTables.sheet, id, {
        Cols.spreadsheetId: model.spreadsheetId,
        ..._sheetColumns(ir, rows, cols),
        Cols.name: names[i],
        Cols.sortKey: keys[i],
        SheetCols.kind: SheetKind.grid.name,
        Cols.hidden: hidden,
        Cols.formatJson: _sheetFormat(ir).toJson(),
      });
      final rowAxis = PlannedAxis();
      final rk = FractionalIndex.nBetween(null, null, rows);
      for (var r = 0; r < rows; r++) {
        rowAxis.add(ctx.ids.newId(), rk[r]);
      }
      final colAxis = PlannedAxis();
      final ck = FractionalIndex.nBetween(null, null, cols);
      for (var c = 0; c < cols; c++) {
        colAxis.add(ctx.ids.newId(), ck[c]);
      }
      final sv = PlannedSheetView(id, names[i], rowAxis, colAxis);
      view.addSheet(sv);
      targets.add(_Target(ir: ir, view: sv, sink: fresh));
      builder.summary.sheets.add(id);
    }
    if (keep) {
      for (final s in model.sheets) {
        if (s.record!.kind != SheetKind.grid) continue;
        view.addSheet(
          PlannedSheetView(
            s.id,
            s.name,
            PlannedAxis(base: s.rows),
            PlannedAxis(base: s.columns),
          ),
        );
      }
    }
    _planNames(keepExisting: keep);
    for (final t in targets) {
      _dimensionRows(t, fresh: true);
    }
    for (final t in targets) {
      _writeSheet(t);
    }
  }

  CellFormat? _sheetDefaultFont;

  /// `Sheet.formatJson` of an imported sheet: the document default font
  /// (when it differs from the spreadsheet's) under the sheet default.
  CellFormat _sheetFormat(IrSheet ir) {
    final base = _sheetDefaultFont ?? CellFormat.empty;
    if (ir.defaultFormat == 0) return base;
    return base.overlay(_mapFormat(doc.formats[ir.defaultFormat].attrs));
  }

  /// The document default font as a sheet default format when it differs
  /// from the spreadsheet's (insert into an existing spreadsheet).
  CellFormat? _defaultFontFormat() {
    final sp = model.spreadsheet;
    final values = <FormatAttr, Object?>{
      if (doc.defaultFontFamily != null &&
          doc.defaultFontFamily != sp.defaultFontFamily)
        FormatAttr.fontFamily: doc.defaultFontFamily,
      if (doc.defaultFontSize != null &&
          doc.defaultFontSize != sp.defaultFontSize)
        FormatAttr.fontSize: doc.defaultFontSize,
    };
    if (values.isEmpty) return null;
    return CellFormat(values);
  }

  CalcSettings _settings() {
    final sp = model.spreadsheet;
    return CalcSettings(
      locale: model.hasSpreadsheetRow ? sp.locale : (doc.locale ?? 'en_US'),
      timeZone: model.hasSpreadsheetRow ? sp.timeZone : (doc.timeZone ?? 'UTC'),
    );
  }

  void _spreadsheetRow(bool create) {
    final theme = doc.theme?.toSpreadsheetTheme();
    final font =
        doc.defaultFontFamily ??
        theme?.textFont ??
        SpreadsheetTheme.standard.textFont;
    final size = doc.defaultFontSize ?? 10.0;
    if (model.hasSpreadsheetRow || !create) {
      final cur = builder.current(
        SheetsTables.spreadsheet,
        model.spreadsheetId,
      );
      if (cur == null) return;
      builder.update(SheetsTables.spreadsheet, model.spreadsheetId, {
        if (theme != null) SpreadsheetCols.themeJson: theme.toJson(),
        SpreadsheetCols.defaultFontFamily: font,
        SpreadsheetCols.defaultFontSize: size,
      });
      return;
    }
    final title = doc.title ?? _baseName(fileName) ?? 'Untitled spreadsheet';
    fresh.insert(SheetsTables.spreadsheet, model.spreadsheetId, {
      SpreadsheetCols.title: title,
      SpreadsheetCols.locale: doc.locale ?? ctx.locale ?? 'en_US',
      SpreadsheetCols.timeZone: doc.timeZone ?? 'UTC',
      SpreadsheetCols.recalcMode: RecalcMode.onChange.name,
      SpreadsheetCols.iterativeCalc: false,
      SpreadsheetCols.maxIterations: 50,
      SpreadsheetCols.convergenceThreshold: 0.05,
      SpreadsheetCols.defaultFontFamily: font,
      SpreadsheetCols.defaultFontSize: size,
      SpreadsheetCols.themeJson: (theme ?? SpreadsheetTheme.standard).toJson(),
      Cols.createdBy: ctx.userId,
    });
  }

  static String? _baseName(String? file) {
    if (file == null || file.isEmpty) return null;
    final base = file.split(RegExp(r'[/\\]')).last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  static final RegExp _badSheetChars = RegExp(r'[\[\]*?/\\:]');

  String _uniqueSheetName(String raw, Set<String> taken) {
    var base = raw.replaceAll(_badSheetChars, ' ').trim();
    if (base.isEmpty) base = 'Sheet';
    if (base.length > 100) base = base.substring(0, 100).trim();
    var n = base;
    var k = 2;
    while (taken.contains(n.toLowerCase())) {
      final suffix = ' ($k)';
      k++;
      n = base.length + suffix.length > 100
          ? '${base.substring(0, 100 - suffix.length)}$suffix'
          : '$base$suffix';
    }
    taken.add(n.toLowerCase());
    return n;
  }

  List<String> _sheetKeys(int n, bool keep) {
    if (!keep || model.sheets.isEmpty) {
      return FractionalIndex.nBetween(null, null, n);
    }
    final list = model.sheets;
    var i = list.indexWhere((s) => s.id == activeSheetId);
    if (i < 0) i = list.length - 1;
    final prev = list[i].record!.sortKey;
    final next = i + 1 < list.length ? list[i + 1].record!.sortKey : null;
    if (next != null && prev.compareTo(next) >= 0) {
      return FractionalIndex.nBetween(prev, null, n);
    }
    return FractionalIndex.nBetween(prev, next, n);
  }

  Map<String, Object?> _sheetColumns(IrSheet ir, int rows, int cols) => {
    SheetCols.tabColor: ir.tabColor == null ? null : _color(ir.tabColor!),
    SheetCols.rightToLeft: ir.rtl,
    SheetCols.showGridlines: ir.showGridlines,
    SheetCols.frozenRows: ir.frozenRows.clamp(0, rows - 1),
    SheetCols.frozenColumns: ir.frozenColumns.clamp(0, cols - 1),
    SheetCols.defaultRowHeight: ir.defaultRowHeight ?? 21.0,
    SheetCols.defaultColumnWidth: ir.defaultColumnWidth ?? 100.0,
    SheetCols.printSettingsJson: null,
  };

  // ---------------------------------------------------------------------------
  // Named ranges.

  void _planNames({required bool keepExisting}) {
    final existing = <String>[
      if (keepExisting)
        for (final n in model.namedRanges) n.name,
    ];
    if (keepExisting) {
      for (final n in model.namedRanges) {
        view.addName(PlannedNameView(n.id, n.name));
      }
    }
    final taken = {for (final n in existing) n.toLowerCase()};
    final planned = <(IrNamedRange, String)>[];
    for (final n in doc.namedRanges) {
      if (n.sheet != null &&
          options.sheets != null &&
          !options.sheets!.any(
            (s) => s.toLowerCase() == n.sheet!.toLowerCase(),
          )) {
        continue;
      }
      var name = _validName(n.name);
      if (taken.contains(name.toLowerCase())) {
        var k = 2;
        while (taken.contains('${name}_$k'.toLowerCase())) {
          k++;
        }
        name = '${name}_$k';
      }
      taken.add(name.toLowerCase());
      if (name != n.name) {
        _nameRenames[n.name.toLowerCase()] = name;
        warnings.add(
          'nameRenamed',
          'Named range "${n.name}" was renamed to "$name"',
          severity: ImportSeverity.info,
        );
      }
      planned.add((n, name));
    }
    final ids = <String>[for (final _ in planned) ctx.ids.newId()];
    for (var i = 0; i < planned.length; i++) {
      view.addName(PlannedNameView(ids[i], planned[i].$2));
    }
    final host = targets.isEmpty ? null : targets.first.view;
    for (var i = 0; i < planned.length; i++) {
      final (n, name) = planned[i];
      String? rangeJson;
      String? formula;
      if (n.range != null) {
        final sheet = n.sheet == null ? host : _sheetView(n.sheet!);
        final g = sheet == null ? null : _gridRange(sheet, n.range!);
        if (g == null) {
          warnings.add(
            'nameDropped',
            'Named range "${n.name}" refers to a sheet or cells that were not imported',
          );
          continue;
        }
        rangeJson = g.encode();
      } else if (n.formulaA1 != null && host != null) {
        formula = _stored(n.formulaA1!, host, 0, 0);
      } else {
        continue;
      }
      fresh.insert(SheetsTables.namedRange, ids[i], {
        Cols.spreadsheetId: model.spreadsheetId,
        Cols.name: name,
        Cols.rangeJson: rangeJson,
        'formula': formula,
        'comment': n.comment,
        'metaJson': null,
      });
      builder.summary.kinds.add(ChangeKinds.names);
    }
  }

  static String _validName(String raw) {
    if (NameRules.validateRangeName(raw) == null) return raw;
    var n = raw.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');
    if (n.isEmpty) n = 'Name';
    final lower = n.toLowerCase();
    final c = n.codeUnitAt(0);
    if ((c >= 0x30 && c <= 0x39) ||
        lower.startsWith('true') ||
        lower.startsWith('false') ||
        NameRules.looksLikeReference(n)) {
      n = '_$n';
    }
    if (n.length > 250) n = n.substring(0, 250);
    return n;
  }

  // ---------------------------------------------------------------------------
  // In-sheet locations (replace sheet, append, replace at cell).

  SheetModel _activeSheet() {
    final s = activeSheetId == null
        ? (model.sheets.isEmpty ? null : model.sheets.first)
        : model.sheet(activeSheetId!);
    if (s == null || s.record!.kind != SheetKind.grid) {
      throw const PlanException('not_found', 'The target sheet was not found');
    }
    return s;
  }

  (int, int) _offset(SheetModel s) => switch (options.location) {
    ImportLocation.append => ((s.usedRect()?.bottom ?? -1) + 1, 0),
    ImportLocation.replaceAtCell => (
      startRow ?? options.startCell?.$1 ?? 0,
      startCol ?? options.startCell?.$2 ?? 0,
    ),
    _ => (0, 0),
  };

  (int, int) _inSheetSize(SheetModel s, IrSheet ir) {
    final (used, usedCols) = _extent(ir);
    final (r0, c0) = _offset(s);
    final needRows = r0 + used;
    final needCols = c0 + usedCols;
    if (options.location == ImportLocation.replaceSheet) {
      return (
        needRows + 1 < _defaultRows ? _defaultRows : needRows + 1,
        needCols < _defaultCols ? _defaultCols : needCols,
      );
    }
    return (
      needRows > s.rows.length ? needRows : s.rows.length,
      needCols > s.columns.length ? needCols : s.columns.length,
    );
  }

  void _planInSheet(List<IrSheet> sheets) {
    final s = _activeSheet();
    final ir = sheets.first;
    if (sheets.length > 1) {
      warnings.add(
        'extraSheets',
        'Only the first sheet was imported into the current sheet',
        severity: ImportSeverity.info,
      );
    }
    var (rows, cols) = _inSheetSize(s, ir);
    var total = 0;
    for (final x in model.sheets) {
      total += x.id == s.id ? rows * cols : x.rows.length * x.columns.length;
    }
    final replace = options.location == ImportLocation.replaceSheet;
    if (replace && total > ctx.maxCells) {
      // Without padding.
      final (u, uc) = _extent(ir);
      rows = u < 1 ? 1 : u;
      cols = uc < 1 ? 1 : uc;
      total = 0;
      for (final x in model.sheets) {
        total += x.id == s.id ? rows * cols : x.rows.length * x.columns.length;
      }
    }
    _checkLimit(total);
    final (r0, c0) = _offset(s);
    view = PlannedWorkbookView(model.spreadsheetId, settings: _settings());
    final sink = _BuilderSink(builder);
    PlannedAxis rowAxis;
    PlannedAxis colAxis;
    if (replace) {
      _clearSheet(s);
      rowAxis = _keptAxis(s, Dimension.rows, rows);
      colAxis = _keptAxis(s, Dimension.columns, cols);
    } else {
      rowAxis = PlannedAxis(base: s.rows);
      colAxis = PlannedAxis(base: s.columns);
    }
    _grow(s, rowAxis, Dimension.rows, rows);
    _grow(s, colAxis, Dimension.columns, cols);
    for (final x in model.sheets) {
      if (x.id == s.id || x.record!.kind != SheetKind.grid) continue;
      view.addSheet(
        PlannedSheetView(
          x.id,
          x.name,
          PlannedAxis(base: x.rows),
          PlannedAxis(base: x.columns),
        ),
      );
    }
    final sv = PlannedSheetView(s.id, s.name, rowAxis, colAxis);
    view.addSheet(sv);
    for (final n in model.namedRanges) {
      view.addName(PlannedNameView(n.id, n.name));
    }
    final t = _Target(
      ir: ir,
      view: sv,
      sink: sink,
      rowOffset: r0,
      colOffset: c0,
      full: replace,
    );
    targets.add(t);
    builder.summary.sheets.add(s.id);
    if (replace) {
      _sheetDefaultFont = _defaultFontFormat();
      builder.update(SheetsTables.sheet, s.id, {
        SheetCols.frozenRows: ir.frozenRows.clamp(0, rows - 1),
        SheetCols.frozenColumns: ir.frozenColumns.clamp(0, cols - 1),
        SheetCols.showGridlines: ir.showGridlines,
        SheetCols.rightToLeft: ir.rtl,
        if (ir.defaultRowHeight != null)
          SheetCols.defaultRowHeight: ir.defaultRowHeight,
        if (ir.defaultColumnWidth != null)
          SheetCols.defaultColumnWidth: ir.defaultColumnWidth,
        Cols.formatJson: _sheetFormat(ir).toJson(),
        SheetCols.printSettingsJson: null,
      });
      _dimensionRows(t, fresh: false);
    } else {
      final ignored = <String>[
        if (ir.validations.isNotEmpty) 'data validation',
        if (ir.conditionalFormats.isNotEmpty) 'conditional formatting',
        if (ir.autoFilter != null) 'filters',
        if (ir.images.isNotEmpty || ir.charts.isNotEmpty) 'images and charts',
        if (doc.namedRanges.isNotEmpty) 'named ranges',
      ];
      if (ignored.isNotEmpty) {
        warnings.add(
          'notImportedHere',
          'Only cell data is imported at this location; ${ignored.join(', ')} were skipped',
          severity: ImportSeverity.info,
        );
      }
    }
    _writeSheet(t);
    final (u, uc) = _extent(ir);
    if (u > 0 && uc > 0) {
      builder.addRange(
        s.id == sv.id
            ? GridRange(
                sheetId: s.id,
                r1: rowAxis.idAt(r0),
                r2: rowAxis.idAt(r0 + u - 1),
                c1: colAxis.idAt(c0),
                c2: colAxis.idAt(c0 + uc - 1),
              )
            : GridRange.sheet(s.id),
      );
    }
  }

  /// Clears contents, formats, rules and objects of [s] (replace sheet).
  void _clearSheet(SheetModel s) {
    for (final (t, id) in sheetChildren(s)) {
      if (t == SheetsTables.sheetRow || t == SheetsTables.sheetColumn) continue;
      builder.delete(t, id);
    }
    for (final r in s.rowRecords.values) {
      builder.update(SheetsTables.sheetRow, r.id, {
        DimCols.height: null,
        Cols.hidden: false,
        Cols.formatJson: null,
      });
    }
    for (final c in s.columnRecords.values) {
      builder.update(SheetsTables.sheetColumn, c.id, {
        DimCols.width: null,
        Cols.hidden: false,
        Cols.formatJson: null,
      });
    }
  }

  /// The first [count] entries of an axis of [s]; later ones are deleted.
  PlannedAxis _keptAxis(SheetModel s, Dimension d, int count) {
    final axis = s.axis(d);
    final table = d == Dimension.rows
        ? SheetsTables.sheetRow
        : SheetsTables.sheetColumn;
    final ids = <String>[];
    final keys = <String>[];
    for (var i = 0; i < axis.length; i++) {
      if (i < count) {
        ids.add(axis.idAt(i));
        keys.add(axis.sortKeyAt(i));
      } else {
        builder.delete(table, axis.idAt(i));
        builder.summary.addDeleted(
          d == Dimension.rows ? 'rows' : 'cols',
          axis.idAt(i),
        );
      }
    }
    return PlannedAxis(ids: ids, keys: keys);
  }

  void _grow(SheetModel s, PlannedAxis axis, Dimension d, int count) {
    final missing = count - axis.length;
    if (missing <= 0) return;
    final keys = FractionalIndex.nBetween(axis.lastKey, null, missing);
    final table = d == Dimension.rows
        ? SheetsTables.sheetRow
        : SheetsTables.sheetColumn;
    for (final k in keys) {
      final id = ctx.ids.newId();
      axis.add(id, k);
      builder.insert(table, id, {
        Cols.sheetId: s.id,
        Cols.sortKey: k,
        Cols.hidden: false,
      });
    }
    builder.summary.kinds.add(ChangeKinds.structure);
  }

  // ---------------------------------------------------------------------------
  // Sheet content.

  /// Writes rows/columns of a full sheet (sizes, hidden, default formats)
  /// and the outline groups. [fresh] sheets insert their dimension rows here.
  void _dimensionRows(_Target t, {required bool fresh}) {
    final ir = t.ir;
    final hiddenByGroup = <Dimension, Set<int>>{
      Dimension.rows: {},
      Dimension.columns: {},
    };
    final groups = <(Dimension, int, int, int, bool)>[];
    for (final d in Dimension.values) {
      final dims = d == Dimension.rows ? ir.rows : ir.columns;
      final axis = d == Dimension.rows ? t.rows : t.cols;
      final levels = <int, int>{
        for (final e in dims.entries)
          if (e.value.outlineLevel > 0 && e.key < axis.length)
            e.key: e.value.outlineLevel.clamp(1, 8),
      };
      if (levels.isEmpty) continue;
      final indices = levels.keys.toList()..sort();
      for (var depth = 1; depth <= 8; depth++) {
        int? start;
        int? prev;
        void close() {
          if (start == null) return;
          final s = start, e = prev!;
          final after = dims[e + 1];
          final before = s > 0 ? dims[s - 1] : null;
          final collapsed =
              (after?.collapsed ?? false) ||
              ((before?.collapsed ?? false) &&
                  (before?.outlineLevel ?? 0) < depth);
          groups.add((d, s, e, depth, collapsed));
          if (collapsed) {
            for (var k = s; k <= e; k++) {
              hiddenByGroup[d]!.add(k);
            }
          }
        }

        for (final i in indices) {
          if (levels[i]! < depth) continue;
          if (start != null && i == prev! + 1) {
            prev = i;
            continue;
          }
          close();
          start = i;
          prev = i;
        }
        close();
      }
    }

    for (final d in Dimension.values) {
      final isRow = d == Dimension.rows;
      final dims = isRow ? ir.rows : ir.columns;
      final axis = isRow ? t.rows : t.cols;
      final table = isRow ? SheetsTables.sheetRow : SheetsTables.sheetColumn;
      final sizeCol = isRow ? DimCols.height : DimCols.width;
      final colDefaults = isRow
          ? const <int, CellFormat>{}
          : _columnDefaults(t);
      final written = <int>{};
      void write(int i, IrDim? dim) {
        if (i >= axis.length) return;
        var fmt = dim == null || dim.format == 0
            ? CellFormat.empty
            : _mapFormat(doc.formats[dim.format].attrs);
        final extra = colDefaults[i];
        if (extra != null) fmt = fmt.overlay(extra);
        final hidden = (dim?.hidden ?? false) && !hiddenByGroup[d]!.contains(i);
        final cols = <String, Object?>{
          sizeCol: dim?.size,
          Cols.hidden: hidden,
          Cols.formatJson: fmt.toJson(),
        };
        if (fresh) {
          t.sink.insert(table, axis.idAt(i), {
            Cols.sheetId: t.id,
            Cols.sortKey: axis.sortKeyAt(i),
            ...cols,
          });
        } else if (dim != null || extra != null) {
          t.sink.update(table, axis.idAt(i), cols);
        }
        written.add(i);
      }

      for (final e in dims.entries) {
        if (e.key >= axis.length) break;
        write(e.key, e.value);
      }
      for (final i in colDefaults.keys) {
        if (!written.contains(i)) write(i, null);
      }
      if (fresh) {
        for (var i = 0; i < axis.length; i++) {
          if (written.contains(i)) continue;
          t.sink.insert(table, axis.idAt(i), {
            Cols.sheetId: t.id,
            Cols.sortKey: axis.sortKeyAt(i),
            Cols.hidden: false,
          });
        }
      }
    }
    for (final (d, s, e, depth, collapsed) in groups) {
      final axis = d == Dimension.rows ? t.rows : t.cols;
      t.sink.insert(SheetsTables.dimensionGroup, ctx.ids.newId(), {
        Cols.sheetId: t.id,
        'dimension': d.name,
        'startId': axis.idAt(s),
        'endId': axis.idAt(e),
        'depth': depth,
        'collapsed': collapsed,
      });
    }
    if (groups.isNotEmpty) builder.summary.kinds.add(ChangeKinds.structure);
  }

  final Map<_Target, Map<int, CellFormat>> _colDefaultsCache = {};
  final Map<_Target, Map<int, int>> _colDefaultIndex = {};

  /// Column defaults derived from cell formats shared by ≥ 90 % of a
  /// column's cells (11 §1.2), restricted to attributes invisible on empty
  /// cells. Only computed when no row has a default format and the column
  /// has none.
  Map<int, CellFormat> _columnDefaults(_Target t) {
    final cached = _colDefaultsCache[t];
    if (cached != null) return cached;
    final out = <int, CellFormat>{};
    final index = <int, int>{};
    _colDefaultsCache[t] = out;
    _colDefaultIndex[t] = index;
    final ir = t.ir;
    if (!t.full || ir.rows.entries.any((e) => e.value.format != 0)) return out;
    final counts = <int, Map<int, int>>{};
    final totals = <int, int>{};
    for (final (_, c, cell) in ir.cells.entries) {
      totals[c] = (totals[c] ?? 0) + 1;
      final m = counts[c] ??= {};
      m[cell.format] = (m[cell.format] ?? 0) + 1;
    }
    counts.forEach((c, m) {
      final n = totals[c]!;
      if (n < 2 || (ir.columns[c]?.format ?? 0) != 0) return;
      var best = 0, bestCount = 0;
      m.forEach((f, k) {
        if (k > bestCount) {
          best = f;
          bestCount = k;
        }
      });
      if (best == 0 || bestCount < n * 0.9) return;
      final attrs = _mapFormat(doc.formats[best].attrs);
      final keep = {
        for (final a in attrs.attrs)
          if (_invisibleOnEmpty.contains(a)) a: attrs[a],
      };
      if (keep.isEmpty) return;
      // Every other cell must override all of them.
      for (final f in m.keys) {
        if (f == best) continue;
        final other = doc.formats[f].attrs;
        if (!keep.keys.every(other.has)) return;
      }
      out[c] = CellFormat(keep);
      index[c] = best;
    });
    return out;
  }

  void _writeSheet(_Target t) {
    final ir = t.ir;
    final colDefaults = t.full ? _columnDefaults(t) : const <int, CellFormat>{};
    final colDefaultIdx = _colDefaultIndex[t] ?? const <int, int>{};
    final formatCache = <int, CellFormat>{};
    CellFormat fmtOf(int index) => formatCache[index] ??= index == 0
        ? CellFormat.empty
        : _mapFormat(doc.formats[index].attrs);

    // In-sheet writes carry row/column defaults into the cells.
    CellFormat inheritedOf(int r, int c) {
      if (t.full) return CellFormat.empty;
      var f = fmtOf(ir.defaultFormat);
      final cf = ir.columns[c]?.format ?? 0;
      if (cf != 0) f = f.overlay(fmtOf(cf));
      final rf = ir.rows[r]?.format ?? 0;
      if (rf != 0) f = f.overlay(fmtOf(rf));
      return f;
    }

    final rowLimit = t.rows.length - t.rowOffset;
    final colLimit = t.cols.length - t.colOffset;
    final seen = <(int, int)>{};
    // Values inside array formula ranges are cached results, not content.
    final arrays = [
      for (final (r, c, cell) in ir.cells.entries)
        if (cell.formulaA1 != null &&
            cell.formulaKind != IrFormulaKind.normal &&
            cell.arrayRef != null &&
            !cell.arrayRef!.isSingleCell)
          (r, c, cell.arrayRef!),
    ];
    bool cached(int r, int c) {
      for (final (ar, ac, rect) in arrays) {
        if (rect.contains(r, c) && !(r == ar && c == ac)) return true;
      }
      return false;
    }

    for (var (r, c, cell) in ir.cells.entries) {
      if (r >= rowLimit || c >= colLimit) continue;
      if (arrays.isNotEmpty &&
          cell.formulaA1 == null &&
          cell.value != null &&
          cached(r, c)) {
        cell = cell.copyWith(clearValue: true);
      }
      final row = r + t.rowOffset;
      final col = c + t.colOffset;
      var fmt = inheritedOf(r, c).overlay(fmtOf(cell.format));
      final def = colDefaults[c];
      if (def != null && colDefaultIdx[c] == cell.format) {
        fmt = fmt.without(def.attrs);
      }
      final cols = _cellColumns(t, cell, row, col, fmt);
      if (cols == null) continue;
      if (!t.full && t.sink.inPlace) seen.add((row, col));
      t.sink.cell(t.id, t.rows.idAt(row), t.cols.idAt(col), cols);
      if (cols[CellCols.content] != null) t.cells++;
    }
    // Replace at cell: empty fields of the data rectangle clear old content.
    if (options.location == ImportLocation.replaceAtCell) {
      final (u, uc) = _extent(ir);
      final s = model.sheet(t.id)!;
      final rect = GridRect(
        t.rowOffset,
        t.colOffset,
        t.rowOffset + u - 1,
        t.colOffset + uc - 1,
      );
      if (u > 0 && uc > 0) {
        for (final (r, c, cell) in s.cellsIn(rect)) {
          if (seen.contains((r, c)) || cell.content == null) continue;
          builder.writeCell(t.id, cell.rowId, cell.columnId, {
            CellCols.content: null,
          });
        }
      }
    }
    if (ir.cells.isNotEmpty) builder.summary.kinds.add(ChangeKinds.values);

    // Merges.
    for (final m in ir.merges) {
      final rect = GridRect(
        m.top + t.rowOffset,
        m.left + t.colOffset,
        m.bottom + t.rowOffset,
        m.right + t.colOffset,
      );
      if (rect.bottom >= t.rows.length || rect.right >= t.cols.length) continue;
      if (!t.full) {
        // Merges over existing merges are skipped.
        final s = model.sheet(t.id);
        if (s != null && s.mergesIntersecting(rect).isNotEmpty) {
          warnings.add(
            'mergeSkipped',
            'Merged cells overlapping existing merges were not imported',
            sheet: ir.name,
          );
          continue;
        }
      }
      t.sink.insert(SheetsTables.mergedRange, ctx.ids.newId(), {
        Cols.sheetId: t.id,
        Cols.rangeJson: _rectRange(t.view, rect).encode(),
      });
      builder.summary.kinds.add(ChangeKinds.format);
    }
    if (!t.full) return;
    _writeRules(t);
    _writeObjects(t);
    _writePrint(t);
  }

  Map<String, Object?>? _cellColumns(
    _Target t,
    IrCell cell,
    int row,
    int col,
    CellFormat fmt,
  ) {
    String? content;
    final f = cell.formulaA1;
    if (f != null && f.trim().isNotEmpty) {
      content = _stored(f, t.view, row, col);
    } else if (cell.value != null) {
      content = _mapValue(cell.value!).toContent().encode();
    }
    final link = cell.link == null ? null : _link(cell.link!, t.view);
    if (content == null &&
        cell.note == null &&
        fmt.isEmpty &&
        link == null &&
        !t.sink.inPlace) {
      return null;
    }
    final cols = <String, Object?>{};
    if (t.sink.inPlace && t.full) {
      for (final k in _cellValueColumns) {
        cols[k] = null;
      }
    }
    if (t.sink.inPlace && !t.full) {
      // Overwrite content; keep the target's formats unless the file sets them.
      cols[CellCols.content] = content;
      if (cell.note != null) cols[CellCols.note] = cell.note;
    } else {
      cols[CellCols.content] = content;
      cols[CellCols.note] = cell.note;
    }
    cols.addAll(fmt.toMap());
    if (link != null) cols[CellCols.linkUrl] = link;
    return cols;
  }

  // ---------------------------------------------------------------------------
  // Rules.

  void _writeRules(_Target t) {
    final ir = t.ir;
    final anyRules =
        ir.validations.isNotEmpty ||
        ir.conditionalFormats.isNotEmpty ||
        ir.autoFilter != null;
    if (anyRules) builder.summary.kinds.add(ChangeKinds.rules);
    for (final v in ir.validations) {
      final ranges = _ranges(t.view, v.ranges);
      if (ranges.isEmpty) continue;
      final anchor = _anchorOf(t.view, v.ranges);
      final criteria = _ruleJson(
        {...v.criteria, if (v.extras.isNotEmpty) 'ext': v.extras},
        t.view,
        anchor,
      );
      final range = criteria['range'];
      if (criteria['type'] == 'oneOfRange' && range is String) {
        final g = _gridRangeFromA1(range, t.view);
        if (g == null) {
          warnings.add(
            'validationDropped',
            'A dropdown from a range outside the imported sheets was dropped',
            sheet: ir.name,
          );
          continue;
        }
        criteria['range'] = g.toJson();
      }
      final isList =
          criteria['type'] == 'oneOfList' || criteria['type'] == 'oneOfRange';
      final style =
          v.displayStyle ??
          (isList ? (v.showDropdown ? 'arrow' : 'plainText') : null);
      t.sink.insert(SheetsTables.dataValidationRule, ctx.ids.newId(), {
        Cols.sheetId: t.id,
        Cols.rangesJson: GridRange.encodeList(ranges),
        'criteriaJson': jsonEncode(criteria),
        'strict': v.strict,
        'showDropdown': style == null ? v.showDropdown : style != 'plainText',
        'displayStyle': style,
        'helpText': v.helpText,
      });
    }
    final cfs = ir.conditionalFormats;
    final keys = FractionalIndex.nBetween(null, null, cfs.length);
    for (var i = 0; i < cfs.length; i++) {
      final cf = cfs[i];
      final ranges = _ranges(t.view, cf.ranges);
      if (ranges.isEmpty) continue;
      final anchor = _anchorOf(t.view, cf.ranges);
      final rule = _ruleJson(
        {...cf.rule, if (cf.extras.isNotEmpty) 'ext': cf.extras},
        t.view,
        anchor,
      );
      _mapRuleColors(rule);
      t.sink.insert(SheetsTables.conditionalFormatRule, ctx.ids.newId(), {
        Cols.sheetId: t.id,
        Cols.sortKey: keys[i],
        Cols.rangesJson: GridRange.encodeList(ranges),
        'ruleJson': jsonEncode(rule),
        'enabled': cf.enabled,
      });
    }
    final f = ir.autoFilter;
    if (f != null) {
      final g = _gridRange(t.view, f.range);
      if (g != null) {
        final top = f.range.r1 ?? 0;
        final left = f.range.c1 ?? 0;
        final criteria = <String, Object?>{};
        f.criteria.forEach((offset, c) {
          final colId = t.cols.tryIdAt(left + offset);
          if (colId == null) return;
          criteria[colId] = _ruleJson(c, t.view, (top + 1, left + offset));
        });
        final sort = [
          for (final s in f.sort)
            if (s['col'] case final num off)
              if (t.cols.tryIdAt(left + off.toInt()) case final String id)
                {'colId': id, 'ascending': s['ascending'] != false},
        ];
        t.sink.insert(SheetsTables.basicFilter, SheetsIds.basicFilterId(t.id), {
          Cols.sheetId: t.id,
          Cols.rangeJson: g.encode(),
          'criteriaJson': jsonEncode(criteria),
          'sortJson': sort.isEmpty ? null : jsonEncode(sort),
        });
        builder.summary.kinds.add(ChangeKinds.filters);
      }
    }
  }

  /// Top-left of the first range (rule formulas are relative to it).
  (int, int) _anchorOf(PlannedSheetView s, List<IrRange> ranges) {
    final r = ranges.first;
    return (r.top, r.left);
  }

  List<GridRange> _ranges(PlannedSheetView s, List<IrRange> ranges) => [
    for (final r in ranges)
      if (_gridRange(s, r) case final GridRange g) g,
  ];

  /// Converts every `=formula` string of a rule JSON to the stored form at
  /// [anchor] (a deep copy is returned).
  Map<String, Object?> _ruleJson(
    Map<String, Object?> json,
    PlannedSheetView s,
    (int, int) anchor,
  ) {
    final (out, _) = StoredFormula.mapJsonFormulas(
      json,
      (f) => _stored(f.substring(1), s, anchor.$1, anchor.$2),
    );
    return (out! as Map).cast<String, Object?>();
  }

  void _mapRuleColors(Map<String, Object?> rule) {
    if (_docTheme == null) return;
    final format = rule['format'];
    if (format is Map) {
      for (final k in const ['textColor', 'fillColor']) {
        final v = format[k];
        if (v is String) format[k] = _color(v);
      }
    }
    final points = rule['points'];
    if (points is List) {
      for (final p in points) {
        if (p is Map && p['color'] is String) {
          p['color'] = _color(p['color'] as String);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Objects.

  void _writeObjects(_Target t) {
    final ir = t.ir;
    var z = 0;
    for (final img in ir.images) {
      final a = _objectAnchor(t, img.anchor, lockAspect: true);
      if (a == null) continue;
      String? uuid = img.fileUuid;
      if (img.bytes != null) {
        uuid = ctx.ids.newId();
        uploads.add(
          IrImageUpload(
            fileUuid: uuid,
            bytes: img.bytes!,
            mimeType: img.mimeType,
            name: img.name,
          ),
        );
      }
      if (uuid == null) {
        warnings.add(
          'imageSkipped',
          'Images without data were not imported',
          sheet: ir.name,
        );
        continue;
      }
      t.sink.insert(SheetsTables.embeddedObject, ctx.ids.newId(), {
        Cols.sheetId: t.id,
        'kind': EmbeddedObjectKind.image.name,
        'anchorJson': a.encode(),
        'specJson': ImageSpec(fileUuid: uuid, mime: img.mimeType).encode(),
        'zIndex': z++,
        'title': img.title,
        'altText': img.altText,
      });
      builder.summary.kinds.add(ChangeKinds.objects);
    }
    for (final ch in ir.charts) {
      final a = _objectAnchor(t, ch.anchor, lockAspect: false);
      if (a == null) continue;
      final spec = IrChartSpec.toModel(
        ch.spec,
        resolveRange: (text) => _gridRangeFromA1(text, t.view),
        idAt: (g, offset, switched) {
          final sheet = view.sheetById(g.sheetId);
          if (sheet == null) return null;
          if (switched) {
            final start = g.r1 == null ? 0 : sheet.rows.indexOf(g.r1!);
            return start < 0 ? null : sheet.rows.tryIdAt(start + offset);
          }
          final start = g.c1 == null ? 0 : sheet.columns.indexOf(g.c1!);
          return start < 0 ? null : sheet.columns.tryIdAt(start + offset);
        },
      );
      if (spec == null) {
        warnings.add(
          'chartSkipped',
          'Charts with data outside the imported sheets were not imported',
          sheet: ir.name,
        );
        continue;
      }
      t.sink.insert(SheetsTables.embeddedObject, ctx.ids.newId(), {
        Cols.sheetId: t.id,
        'kind': EmbeddedObjectKind.chart.name,
        'anchorJson': a.encode(),
        'specJson': jsonEncode(spec),
        'zIndex': z++,
        'title': ch.title,
        'altText': ch.altText,
      });
      builder.summary.kinds.add(ChangeKinds.objects);
    }
  }

  ObjectAnchor? _objectAnchor(
    _Target t,
    IrAnchor a, {
    required bool lockAspect,
  }) {
    final row = a.row.clamp(0, t.rows.length - 1);
    final col = a.col.clamp(0, t.cols.length - 1);
    return ObjectAnchor(
      rowId: t.rows.idAt(row),
      colId: t.cols.idAt(col),
      rowKey: t.rows.sortKeyAt(row),
      colKey: t.cols.sortKeyAt(col),
      dx: a.dx < 0 ? 0 : a.dx,
      dy: a.dy < 0 ? 0 : a.dy,
      width: ObjectAnchor.clampSize(a.width),
      height: ObjectAnchor.clampSize(a.height),
      lockAspect: lockAspect,
    );
  }

  // ---------------------------------------------------------------------------
  // Print settings.

  void _writePrint(_Target t) {
    final p = t.ir.print;
    if (p == null || p.isEmpty) return;
    final out = Map<String, Object?>.of(p);
    out['v'] ??= 1;
    Map<String, Object?>? span(Object? v, PlannedAxis axis) {
      if (v is! Map || v['start'] is! num) return null;
      final s = (v['start']! as num).toInt();
      final e = ((v['end'] ?? v['start'])! as num).toInt();
      final a = axis.tryIdAt(s);
      final b = axis.tryIdAt(e < s ? s : e);
      if (a == null || b == null) return null;
      return {'start': a, 'end': b};
    }

    out['repeatRows'] = span(p['repeatRows'], t.rows);
    out['repeatCols'] = span(p['repeatCols'], t.cols);
    final breaks = p['pageBreaks'];
    if (breaks is Map) {
      List<String> ids(Object? l, PlannedAxis axis) => [
        if (l is List)
          for (final i in l)
            if (i is num)
              if (axis.tryIdAt(i.toInt()) case final String id) id,
      ];
      out['pageBreaks'] = {
        'rows': ids(breaks['rows'], t.rows),
        'cols': ids(breaks['cols'], t.cols),
      };
    }
    final area = p['printArea'];
    if (area is String) {
      out['printArea'] = _gridRangeFromA1(area, t.view)?.toJson();
    }
    out.removeWhere((k, v) => v == null);
    t.sink.update(SheetsTables.sheet, t.id, {
      SheetCols.printSettingsJson: jsonEncode(out),
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers.

  PlannedSheetView? _sheetView(String irName) =>
      view.sheetByName(_sheetRenames[irName.toLowerCase()] ?? irName);

  /// GridRange of an IR range on [s] (clamped to the grid; null when the
  /// range lies outside of it).
  GridRange? _gridRange(PlannedSheetView s, IrRange r) {
    final rows = s.rows.length, cols = s.columns.length;
    if (rows == 0 || cols == 0) return null;
    if ((r.r1 ?? 0) >= rows || (r.c1 ?? 0) >= cols) return null;
    String? rid(int? i) =>
        i == null ? null : s.rows.idAt(i < rows ? i : rows - 1);
    String? cid(int? i) =>
        i == null ? null : s.columns.idAt(i < cols ? i : cols - 1);
    String? rkey(int? i) =>
        i == null ? null : s.rows.sortKeyAt(i < rows ? i : rows - 1);
    String? ckey(int? i) =>
        i == null ? null : s.columns.sortKeyAt(i < cols ? i : cols - 1);
    return GridRange(
      sheetId: s.id,
      r1: rid(r.r1),
      r2: rid(r.r2),
      c1: cid(r.c1),
      c2: cid(r.c2),
      r1k: rkey(r.r1),
      r2k: rkey(r.r2),
      c1k: ckey(r.c1),
      c2k: ckey(r.c2),
    );
  }

  GridRange _rectRange(PlannedSheetView s, GridRect r) =>
      _gridRange(s, IrRange.rect(r))!;

  GridRange? _gridRangeFromA1(String text, PlannedSheetView host) {
    final t = text.startsWith('=') ? text.substring(1) : text;
    final parsed = IrRange.parseA1(t);
    if (parsed == null) return null;
    final (sheet, range) = parsed;
    final s = sheet == null ? host : _sheetView(sheet);
    if (s == null) return null;
    return _gridRange(s, range);
  }

  /// IR formula (A1, without `=`) → stored form (with `=`) at a host cell.
  String _stored(String formulaA1, PlannedSheetView host, int row, int col) {
    var f = formulaA1;
    if (_sheetRenames.isNotEmpty) {
      f = FormulaRewriter.renameSheets(f, _sheetRenames);
    }
    if (_nameRenames.isNotEmpty) {
      f = FormulaRewriter.renameNames(f, _nameRenames);
    }
    final stored = FormulaCodec.toStored(
      f,
      CodecContext(
        workbook: view,
        hostSheetId: host.id,
        hostRow: row,
        hostCol: col,
      ),
    );
    return stored.startsWith('=') ? stored : '=$stored';
  }

  /// IR link → model link (internal `#'Sheet 2'!A1` → `#sheet=<id>&range=A1`,
  /// `#Name` → `#range=Name`).
  String? _link(String link, PlannedSheetView host) {
    if (!link.startsWith('#')) return link;
    final body = link.substring(1);
    final a = A1Area.tryParse(body);
    if (a != null) {
      final s = a.sheet == null ? host : _sheetView(a.sheet!);
      if (s == null) return null;
      return '#sheet=${s.id}&range=${a.withSheet(null).format()}';
    }
    if (body.startsWith('sheet=') || body.startsWith('range=')) return link;
    final name = _nameRenames[body.toLowerCase()] ?? body;
    return '#range=$name';
  }

  IrValue _mapValue(IrValue v) {
    if (v is! IrRich) return v;
    final r = v.rich;
    var changed = false;
    final runs = <RichRun>[];
    for (final run in r.runs) {
      final f = Map<String, Object?>.of(run.format);
      final c = f[RichRunKeys.textColor];
      if (c is String && _docTheme != null) {
        final m = _color(c);
        if (m != c) {
          f[RichRunKeys.textColor] = m;
          changed = true;
        }
      }
      final l = f[RichRunKeys.link];
      if (l is String && l.startsWith('#') && targets.isNotEmpty) {
        final m = _link(l, targets.first.view);
        if (m != l) {
          f[RichRunKeys.link] = m;
          changed = true;
        }
      }
      runs.add(RichRun(run.start, run.end, f));
    }
    return changed ? IrRich(RichText(r.text, runs)) : v;
  }

  /// Resolves `theme:*` colors of the file when the target keeps its theme.
  String _color(String c) {
    final theme = _docTheme;
    if (theme == null || !c.startsWith('theme:')) return c;
    return theme.resolveColor(c) ?? c;
  }

  CellFormat _mapFormat(CellFormat f) {
    if (_docTheme == null || f.isEmpty) return f;
    final changes = <FormatAttr, Object?>{};
    for (final a in [FormatAttr.textColor, FormatAttr.fillColor]) {
      final v = f[a];
      if (v is String && v.startsWith('theme:')) changes[a] = _color(v);
    }
    for (final a in FormatAttr.borders) {
      final spec = BorderSpec.tryParse(f[a] as String?);
      final color = spec?.color;
      if (spec == null || spec.isNone || color == null) continue;
      if (color.startsWith('theme:')) {
        changes[a] = '${spec.style!.name}|${_color(color)}';
      }
    }
    return changes.isEmpty ? f : f.withValues(changes);
  }

  // ---------------------------------------------------------------------------
  // Result.

  IrImportResult _result() {
    final built = builder.build(
      label ?? (fileName == null ? 'Import' : 'Import $fileName'),
      kinds: const [ChangeKinds.import],
    );
    final freshChanges = fresh.changes;
    Map<String, Object?>? detail;
    final builtCells = built.detail?['cells'];
    var builtCount = 0;
    for (final c in built.changes) {
      if (c.table != SheetsTables.cell) continue;
      if (c.columnsBefore[CellCols.content] !=
              c.columnsAfter[CellCols.content] &&
          (c.op != RowOp.update ||
              c.columnsAfter.containsKey(CellCols.content))) {
        builtCount++;
      }
    }
    final overflow =
        builtCount + fresh.cellDetails > MutationPlan.maxDetailCells;
    if (!overflow && (builtCount > 0 || fresh.details.isNotEmpty)) {
      detail = {
        'cells': [if (builtCells is List) ...builtCells, ...fresh.details],
      };
    }
    final ids = [for (final t in targets) t.id];
    final plan = MutationPlan(
      label: built.label,
      summary: built.summary,
      changes: [...built.changes, ...freshChanges],
      detail: detail,
      warnings: [for (final w in warnings) w.message],
      result: {
        ...built.result,
        'sheetIds': ids,
        if (ids.isNotEmpty) 'sheetId': ids.first,
      },
    );
    final report = ImportReport(
      fileName: fileName,
      sheets: [
        for (final t in targets)
          ImportSheetReport(
            name: t.view.name,
            sheetId: t.id,
            rows: t.rows.length,
            columns: t.cols.length,
            cells: t.cells,
          ),
      ],
      warnings: warnings,
    );
    return IrImportResult(
      plan: plan,
      report: report,
      sheetIds: ids,
      imageUploads: List.unmodifiable(uploads),
    );
  }
}
