import 'dart:convert';
import 'dart:typed_data';
import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../../addressing/a1.dart';
import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../engine_bridge/model_workbook_view.dart';
import '../../engine_bridge/pivot_outputs.dart';
import '../../pivot/pivot_layout.dart';
import '../../engine_bridge/stored_formula.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../format/attributes.dart';
import '../../formula/codec/formula_codec.dart';
import '../../formula/model/workbook_view.dart';
import '../../formula/recalc/formula_engine.dart';
import '../../model/axis_index.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';
import '../../objects/anchor.dart';
import '../../objects/image_spec.dart';
import '../ir/import_warning.dart';
import '../ir/ir_chart_spec.dart';
import '../ir/ir_range.dart';
import '../ir/workbook_document.dart';

/// Computed values for [ModelToIr] (exports write cached results, 11 §1.3).
abstract interface class IrValueSource {
  /// The computed value of the formula at ([row], [col]) and its spill
  /// range (null when it does not spill); null when unknown.
  ({CellValue value, GridRect? spill})? computed(
    String sheetId,
    int row,
    int col,
  );

  /// The number format of a formula result shown with Automatic format
  /// (format hint pattern or `preset:*`), or null.
  String? formatHint(String sheetId, int row, int col);

  /// Visits computed cells that have no content of their own (spill
  /// elements, pivot table output) on [sheetId].
  void forEachOverlay(
    String sheetId,
    void Function(int row, int col, CellValue value) visit,
  );
}

/// Optional formats of overlay cells ([IrValueSource.forEachOverlay]):
/// pivot output keeps its number formats and bold headers/totals (07 §7.5).
abstract interface class IrOverlayFormats {
  /// The computed format of the overlay cell, or null.
  CellFormat? overlayFormat(String sheetId, int row, int col);
}

/// [IrValueSource] over the formula engine: values, spill ranges and
/// spill elements of a recalculated [FormulaEngine] (client `RecalcHost`,
/// server `HeadlessWorkbook`, `ModelEngineBinding`), plus pivot table
/// output as cells (computed with [PivotOutputs] when the engine's workbook
/// is a [ModelWorkbookView]).
final class EngineIrValueSource implements IrValueSource, IrOverlayFormats {
  /// Creates the source.
  EngineIrValueSource(this.engine);

  /// The engine (its workbook must be the exported model).
  final FormulaEngine engine;

  Map<String, List<PivotPlacement>>? _pivots;

  Map<String, List<PivotPlacement>> get _placements {
    final cached = _pivots;
    if (cached != null) return cached;
    final wb = engine.workbook;
    final out = <String, List<PivotPlacement>>{};
    if (wb is ModelWorkbookView) {
      for (final p in PivotOutputs.compute(wb.model, engine)) {
        (out[p.sheetId] ??= []).add(p);
      }
    }
    return _pivots = out;
  }

  PivotCell? _pivotCell(String sheetId, int row, int col) {
    for (final p in _placements[sheetId] ?? const <PivotPlacement>[]) {
      if (p.rect.contains(row, col)) return p.cellAt(row, col);
    }
    return null;
  }

  @override
  CellFormat? overlayFormat(String sheetId, int row, int col) {
    final cell = _pivotCell(sheetId, row, col);
    if (cell == null) return null;
    final nf = cell.numberFormat;
    return CellFormat({
      if (cell.bold) FormatAttr.bold: true,
      if (nf != null && nf.isNotEmpty) FormatAttr.numberFormat: nf,
    });
  }

  @override
  ({CellValue value, GridRect? spill})? computed(
    String sheetId,
    int row,
    int col,
  ) {
    final c = engine.computedAt(sheetId, row, col);
    return (value: c.value.toCellValue(), spill: c.spill?.rect);
  }

  @override
  String? formatHint(String sheetId, int row, int col) =>
      engine.numberFormatAt(sheetId, row, col);

  @override
  void forEachOverlay(
    String sheetId,
    void Function(int row, int col, CellValue value) visit,
  ) {
    final sheet = engine.workbook.sheetById(sheetId);
    if (sheet == null) return;
    final pivots = _placements[sheetId] ?? const <PivotPlacement>[];
    final rows = engine.usedRows(sheet);
    final cols = engine.usedColumns(sheet);
    if (rows > 0 && cols > 0) {
      engine.forEachValue(sheet, GridRect(0, 0, rows - 1, cols - 1), (r, c, v) {
        if (sheet.inputAt(r, c) != null) return;
        if (pivots.any((p) => p.rect.contains(r, c))) return;
        visit(r, c, v.toCellValue());
      });
    }
    // Pivot output (cells without content of their own).
    final wb = engine.workbook;
    final model = wb is ModelWorkbookView ? wb.model.sheet(sheetId) : null;
    for (final p in pivots) {
      final rect = p.rect;
      for (var r = rect.top; r <= rect.bottom; r++) {
        for (var c = rect.left; c <= rect.right; c++) {
          final cell = p.cellAt(r, c);
          if (cell == null || cell.value.isBlank()) continue;
          if (model?.cellAt(r, c)?.content != null) continue;
          visit(r, c, cell.value);
        }
      }
    }
  }
}

/// [IrValueSource] over any [CellSource] (values and format hints; no
/// spill ranges or overlays).
final class CellSourceIrValues implements IrValueSource {
  /// Creates the adapter.
  CellSourceIrValues(this.source);

  /// The computed values.
  final CellSource source;

  @override
  ({CellValue value, GridRect? spill})? computed(
    String sheetId,
    int row,
    int col,
  ) => (value: source.valueAt(sheetId, row, col).toCellValue(), spill: null);

  @override
  String? formatHint(String sheetId, int row, int col) =>
      source.numberFormatAt(sheetId, row, col);

  @override
  void forEachOverlay(
    String sheetId,
    void Function(int row, int col, CellValue value) visit,
  ) {}
}

/// Workbook model → IR (11 §1.3), the input of every exporter (XLSX, ODS,
/// HTML, JSON) on the client (live model), for versions (snapshot model) and
/// on the server (headless workbook).
///
/// Formulas are converted stored form → A1 at their cells; computed values
/// come from [IrValueSource] (spilled arrays and pivot output become values;
/// spilling formulas get `IrFormulaKind.dynamicArray` with their range).
/// Model features without an IR equivalent (filter views, protected ranges,
/// alternating colors, pivot definitions, slicers, chart sheets) are listed
/// in [WorkbookDocument.warnings] (the export report).
abstract final class ModelToIr {
  /// Converts [model].
  ///
  /// - [values]: computed values (e.g. [EngineIrValueSource]); without it
  ///   formula cells have no cached value.
  /// - [sheetIds]: sheets to export (default: all, hidden included).
  /// - [formatHints]: give formula cells with Automatic format the number
  ///   format of their result (dates from `TODAY()`), as displayed.
  /// - [imageBytes]: bytes of a stored image file (null: images are
  ///   exported without data and skipped by the file writers).
  /// - [chartImage]: PNG of a chart the target format can't hold (11 §6.3
  ///   fallback); a chart it returns bytes for becomes a picture at the
  ///   same anchor (report `chartsAsImages`).
  static WorkbookDocument convert(
    WorkbookModel model, {
    IrValueSource? values,
    Iterable<String>? sheetIds,
    bool formatHints = true,
    Uint8List? Function(String fileUuid)? imageBytes,
    Uint8List? Function(
      EmbeddedObjectRecord chart,
      double width,
      double height,
    )?
    chartImage,
  }) => _Converter(
    model,
    values: values,
    sheetIds: sheetIds?.toSet(),
    formatHints: formatHints,
    imageBytes: imageBytes,
    chartImage: chartImage,
  ).run();
}

final class _Converter {
  _Converter(
    this.model, {
    this.values,
    this.sheetIds,
    required this.formatHints,
    this.imageBytes,
    this.chartImage,
  }) : view = ModelWorkbookView(model);

  final WorkbookModel model;
  final IrValueSource? values;
  final Set<String>? sheetIds;
  final bool formatHints;
  final Uint8List? Function(String fileUuid)? imageBytes;
  final Uint8List? Function(EmbeddedObjectRecord, double, double)? chartImage;
  final ModelWorkbookView view;
  late final WorkbookDocument doc;

  WorkbookDocument run() {
    final sp = model.spreadsheet;
    doc = WorkbookDocument(
      title: sp.title,
      locale: sp.locale,
      timeZone: sp.timeZone,
    );
    doc.theme = IrTheme.fromSpreadsheetTheme(model.theme);
    doc.defaultFontFamily = sp.defaultFontFamily;
    doc.defaultFontSize = sp.defaultFontSize;
    final exported = <String>{};
    for (final s in model.sheets) {
      if (sheetIds != null && !sheetIds!.contains(s.id)) continue;
      if (s.record!.kind != SheetKind.grid) {
        _warn('chartSheet', 'Chart sheets were not exported', sheet: s.name);
        continue;
      }
      doc.sheets.add(_sheet(s));
      exported.add(s.id);
    }
    for (final n in model.namedRanges) {
      final ir = _name(n, exported);
      if (ir != null) doc.namedRanges.add(ir);
    }
    return doc;
  }

  void _warn(String code, String message, {String? sheet, int count = 1}) =>
      doc.warnings.add(
        code,
        message,
        severity: ImportSeverity.info,
        sheet: sheet,
        count: count,
      );

  int _fmt(CellFormat f) => doc.formats.internAttrs(
    f.has(FormatAttr.linkUrl) ? f.without(const [FormatAttr.linkUrl]) : f,
  );

  // ---------------------------------------------------------------------------
  // Formulas and ranges.

  String _a1(String stored, String sheetId, int row, int col) {
    final a1 = FormulaCodec.toA1(
      stored,
      CodecContext(
        workbook: view,
        hostSheetId: sheetId,
        hostRow: row,
        hostCol: col,
      ),
    );
    return a1.startsWith('=') ? a1.substring(1) : a1;
  }

  /// Rule JSON with stored formulas converted to A1 (with `=`) at [anchor].
  Map<String, Object?> _ruleJson(
    String json,
    String sheetId,
    (int, int) anchor,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return {};
    }
    if (decoded is! Map) return {};
    final (out, _) = StoredFormula.mapJsonFormulas(
      decoded,
      (f) => '=${_a1(f, sheetId, anchor.$1, anchor.$2)}',
    );
    return (out! as Map).cast<String, Object?>();
  }

  /// IR range of a GridRange on [s] (null when it does not resolve).
  static IrRange? _irRange(SheetModel s, GridRange g) {
    final r = s.resolve(g);
    if (r == null) return null;
    final rect = r.rect;
    if (r.wholeSheet) return IrRange.rect(rect);
    if (r.wholeColumns) return IrRange.columns(rect.left, rect.right);
    if (r.wholeRows) return IrRange.rows(rect.top, rect.bottom);
    return IrRange.rect(rect);
  }

  /// A1 text with sheet prefix of a GridRange (null when unresolved).
  String? _rangeA1(GridRange g, {bool absolute = true}) {
    final s = model.sheet(g.sheetId);
    if (s == null) return null;
    final r = _irRange(s, g);
    return r?.toA1(sheet: s.name, absolute: absolute);
  }

  List<IrRange> _ranges(SheetModel s, String json) => [
    for (final g in GridRange.parseList(json))
      if (_irRange(s, g) case final IrRange r) r,
  ];

  /// Model link → IR link (`#sheet=<id>&range=A1` → `#'Sheet 2'!A1`).
  String? _link(String? link) {
    if (link == null || !link.startsWith('#')) return link;
    Map<String, String> q;
    try {
      q = Uri.splitQueryString(link.substring(1));
    } on FormatException {
      return link;
    }
    final sheetId = q['sheet'] ?? q['gid'];
    final range = q['range'];
    if (sheetId != null) {
      final s = model.sheet(sheetId);
      if (s == null) return null;
      final a = range == null ? null : A1Area.tryParse(range);
      final target = a == null ? 'A1' : a.withSheet(null).format();
      return '#${A1Area.tryParse(target)!.withSheet(s.name).format()}';
    }
    if (range != null) return '#$range';
    return link;
  }

  // ---------------------------------------------------------------------------
  // Sheets.

  IrSheet _sheet(SheetModel s) {
    final rec = s.record!;
    final ir = IrSheet(rec.name)
      ..hidden = rec.hidden
      ..tabColor = rec.tabColor
      ..rtl = rec.rightToLeft
      ..showGridlines = rec.showGridlines
      ..frozenRows = rec.frozenRows
      ..frozenColumns = rec.frozenColumns
      ..defaultRowHeight = rec.defaultRowHeight
      ..defaultColumnWidth = rec.defaultColumnWidth
      ..defaultFormat = _fmt(rec.format);
    _dims(s, ir);
    _cells(s, ir);
    for (final m in s.merges.values) {
      final g = GridRange.tryParse(m.rangeJson);
      final r = g == null ? null : s.resolve(g);
      if (r != null && !r.rect.isSingleCell) ir.merges.add(r.rect);
    }
    ir.merges.sort((a, b) {
      final c = a.top.compareTo(b.top);
      return c != 0 ? c : a.left.compareTo(b.left);
    });
    _rules(s, ir);
    _objects(s, ir);
    _print(s, ir);
    final dropped = <String, int>{
      'filter views': s.filterViews.length,
      'protected ranges': s.protections.length,
      'alternating colors': s.bandings.length,
      'pivot table definitions (exported as values)': s.pivots.length,
      'slicers': s.objects.values
          .where((o) => o.kind == EmbeddedObjectKind.slicer)
          .length,
    };
    dropped.forEach((what, n) {
      if (n > 0) {
        _warn(
          'notExported',
          'The ${what.split(' (').first} of this sheet were not exported'
              '${what.contains('(') ? ' (pivot tables were exported as values)' : ''}',
          sheet: s.name,
          count: n,
        );
      }
    });
    return ir;
  }

  void _dims(SheetModel s, IrSheet ir) {
    for (final d in Dimension.values) {
      final isRow = d == Dimension.rows;
      final axis = s.axis(d);
      final recs = s.dimensionRecords(d);
      final dims = isRow ? ir.rows : ir.columns;
      final levels = <int, int>{};
      final collapsedAt = <int>{};
      final hiddenByGroup = <int>{};
      for (final g in s.groups.values) {
        if (g.dimension != d) continue;
        var a = axis.indexOf(g.startId);
        var b = axis.indexOf(g.endId);
        if (a < 0 || b < 0) continue;
        if (a > b) (a, b) = (b, a);
        for (var i = a; i <= b; i++) {
          final l = levels[i] ?? 0;
          if (g.depth > l) levels[i] = g.depth.clamp(1, 8);
        }
        if (g.collapsed) {
          for (var i = a; i <= b; i++) {
            hiddenByGroup.add(i);
          }
          collapsedAt.add(b + 1 < axis.length ? b + 1 : (a > 0 ? a - 1 : b));
        }
      }
      for (var i = 0; i < axis.length; i++) {
        final rec = recs[axis.idAt(i)];
        final dim = IrDim(
          size: rec?.size,
          hidden: (rec?.hidden ?? false) || hiddenByGroup.contains(i),
          outlineLevel: levels[i] ?? 0,
          collapsed: collapsedAt.contains(i),
          format: rec == null ? 0 : _fmt(rec.format),
        );
        if (!dim.isDefault) dims[i] = dim;
      }
    }
  }

  void _cells(SheetModel s, IrSheet ir) {
    final vals = values;
    final spills = <GridRect>[];
    var unresolvedFormats = 0;
    for (final cell in s.cells.all) {
      final r = s.rows.indexOf(cell.rowId);
      final c = s.columns.indexOf(cell.columnId);
      if (r < 0 || c < 0) continue;
      final content = cell.decoded;
      var format = cell.format;
      String? formula;
      IrValue? value;
      var kind = IrFormulaKind.normal;
      GridRect? arrayRef;
      if (content is FormulaContent) {
        formula = _a1(content.text, s.id, r, c);
        final computed = vals?.computed(s.id, r, c);
        if (computed != null) {
          value = IrValue.fromCellValue(computed.value);
          final spill = computed.spill;
          if (spill != null && !spill.isSingleCell) {
            kind = IrFormulaKind.dynamicArray;
            arrayRef = spill;
            spills.add(spill);
          }
        }
        if (kind == IrFormulaKind.normal &&
            formula.toUpperCase().startsWith('ARRAYFORMULA(')) {
          kind = IrFormulaKind.dynamicArray;
        }
        if (formatHints && vals != null) {
          final chain = model.explicitFormatChain(s.id, r, c);
          if (NumberFormatPresets.isAutomatic(
            chain[FormatAttr.numberFormat] as String?,
          )) {
            final hint = vals.formatHint(s.id, r, c);
            if (hint != null && !NumberFormatPresets.isAutomatic(hint)) {
              format = format.withValue(FormatAttr.numberFormat, hint);
            }
          }
        }
      } else if (content != null) {
        value = IrValue.fromContent(content);
      }
      final link = _link(cell.format[FormatAttr.linkUrl] as String?);
      if (cell.format.has(FormatAttr.linkUrl) && link == null) {
        unresolvedFormats++;
      }
      final irCell = IrCell(
        value: value,
        formulaA1: formula,
        formulaKind: kind,
        arrayRef: arrayRef,
        format: _fmt(format),
        note: cell.note,
        link: link,
      );
      if (!irCell.isEmpty) ir.cells.set(r, c, irCell);
    }
    if (unresolvedFormats > 0) {
      _warn(
        'linkDropped',
        'Links to deleted sheets were not exported',
        sheet: s.name,
        count: unresolvedFormats,
      );
    }
    // Spill elements and pivot output as values (format-only cells keep
    // their format).
    final overlayFormats = vals is IrOverlayFormats
        ? vals as IrOverlayFormats
        : null;
    vals?.forEachOverlay(s.id, (r, c, v) {
      final value = IrValue.fromCellValue(v);
      if (value == null) return;
      final cur = ir.cells.get(r, c);
      if (cur != null && (cur.value != null || cur.formulaA1 != null)) return;
      var cell = (cur ?? const IrCell()).copyWith(value: value);
      final computed = overlayFormats?.overlayFormat(s.id, r, c);
      if (computed != null && !computed.isEmpty) {
        // Explicit formats (cell, row, column, sheet) win over the computed
        // defaults.
        final explicit = model.explicitFormatChain(s.id, r, c);
        final own = s.cellAt(r, c)?.format ?? CellFormat.empty;
        cell = cell.copyWith(
          format: _fmt(
            own.withValues({
              for (final a in computed.attrs)
                if (!explicit.has(a)) a: computed[a],
            }),
          ),
        );
      }
      ir.cells.set(r, c, cell);
    });
  }

  // ---------------------------------------------------------------------------
  // Rules.

  void _rules(SheetModel s, IrSheet ir) {
    for (final v in s.dvRules.values) {
      final ranges = _ranges(s, v.rangesJson);
      if (ranges.isEmpty) continue;
      final criteria = _ruleJson(v.criteriaJson, s.id, (
        ranges.first.top,
        ranges.first.left,
      ));
      final ext = criteria.remove('ext');
      if (criteria['type'] == 'oneOfRange') {
        final g = GridRange.tryParse(criteria['range']);
        final a1 = g == null ? null : _rangeA1(g);
        if (a1 == null) continue;
        criteria['range'] = a1;
      }
      ir.validations.add(
        IrDataValidation(
          ranges: ranges,
          criteria: criteria,
          strict: v.strict,
          showDropdown: v.showDropdown,
          displayStyle: v.displayStyle,
          helpText: v.helpText,
          extras: ext is Map ? ext.cast<String, Object?>() : null,
        ),
      );
    }
    final cfs = s.cfRules.values.toList()
      ..sort((a, b) {
        final c = a.sortKey.compareTo(b.sortKey);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    for (final cf in cfs) {
      final ranges = _ranges(s, cf.rangesJson);
      if (ranges.isEmpty) continue;
      final rule = _ruleJson(cf.ruleJson, s.id, (
        ranges.first.top,
        ranges.first.left,
      ));
      final ext = rule.remove('ext');
      ir.conditionalFormats.add(
        IrConditionalFormat(
          ranges: ranges,
          rule: rule,
          enabled: cf.enabled,
          extras: ext is Map ? ext.cast<String, Object?>() : null,
        ),
      );
    }
    final f = s.basicFilter;
    if (f != null) {
      final g = GridRange.tryParse(f.rangeJson);
      final range = g == null ? null : _irRange(s, g);
      if (range != null) {
        final criteria = <int, Map<String, Object?>>{};
        Map<String, Object?> raw = {};
        try {
          final d = jsonDecode(f.criteriaJson);
          if (d is Map) raw = d.cast<String, Object?>();
        } on FormatException {
          raw = {};
        }
        raw.forEach((colId, c) {
          final col = s.columns.indexOf(colId);
          if (col < range.left || c is! Map) return;
          final off = col - range.left;
          criteria[off] = _ruleJson(jsonEncode(c), s.id, (range.top + 1, col));
        });
        final sort = <Map<String, Object?>>[];
        if (f.sortJson != null) {
          try {
            final d = jsonDecode(f.sortJson!);
            if (d is List) {
              for (final e in d) {
                if (e is! Map || e['colId'] is! String) continue;
                final col = s.columns.indexOf(e['colId'] as String);
                if (col < range.left) continue;
                sort.add({
                  'col': col - range.left,
                  'ascending': e['ascending'] != false,
                });
              }
            }
          } on FormatException {
            // Ignored: the sort indicator is optional.
          }
        }
        ir.autoFilter = IrFilter(range: range, criteria: criteria, sort: sort);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Objects.

  IrAnchor? _anchor(SheetModel s, String json) {
    final a = ObjectAnchor.tryParse(json);
    if (a == null || a.ownSheet || a.rowId == null || a.colId == null) {
      return null;
    }
    int index(AxisIndex axis, String id, String? key) {
      final i = axis.indexOf(id);
      if (i >= 0) return i;
      if (key == null) return 0;
      final j = axis.insertionIndex(key, id);
      return j >= axis.length ? axis.length - 1 : j;
    }

    return IrAnchor(
      row: index(s.rows, a.rowId!, a.rowKey),
      col: index(s.columns, a.colId!, a.colKey),
      dx: a.dx,
      dy: a.dy,
      width: a.width,
      height: a.height,
    );
  }

  void _objects(SheetModel s, IrSheet ir) {
    final objects = s.objects.values.toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    var missingImages = 0;
    final asImages = <Object?, int>{};
    for (final o in objects) {
      final anchor = _anchor(s, o.anchorJson);
      if (anchor == null) continue;
      switch (o.kind) {
        case EmbeddedObjectKind.image:
          final spec = ImageSpec.fromJson(o.specJson);
          if (spec.fileUuid.isEmpty) continue;
          final bytes = imageBytes?.call(spec.fileUuid);
          if (bytes == null) missingImages++;
          ir.images.add(
            IrImage(
              bytes: bytes,
              mimeType: spec.mime,
              anchor: anchor,
              altText: o.altText,
              title: o.title,
              fileUuid: spec.fileUuid,
            ),
          );
        case EmbeddedObjectKind.chart:
          Object? spec;
          try {
            spec = jsonDecode(o.specJson);
          } on FormatException {
            spec = null;
          }
          if (spec is! Map) continue;
          final png = chartImage?.call(o, anchor.width, anchor.height);
          if (png != null) {
            ir.images.add(
              IrImage(
                bytes: png,
                anchor: anchor,
                altText: o.altText,
                title: o.title,
                name: 'chart.png',
              ),
            );
            asImages[spec['type'] ?? 'column'] =
                (asImages[spec['type'] ?? 'column'] ?? 0) + 1;
            continue;
          }
          ir.charts.add(
            IrChart(
              anchor: anchor,
              spec: IrChartSpec.fromModel(
                spec.cast<String, Object?>(),
                rangeA1: _rangeA1,
              ),
              title: o.title,
              altText: o.altText,
            ),
          );
        case EmbeddedObjectKind.slicer || EmbeddedObjectKind.drawing:
          break;
      }
    }
    asImages.forEach((type, n) {
      _warn(
        'chartsAsImages',
        'Charts of type $type were exported as pictures (no Excel equivalent)',
        sheet: s.name,
        count: n,
      );
    });
    if (missingImages > 0) {
      _warn(
        'imageData',
        'Images whose file could not be read were not exported',
        sheet: s.name,
        count: missingImages,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Print settings and names.

  void _print(SheetModel s, IrSheet ir) {
    final json = s.record!.printSettingsJson;
    if (json == null || json.isEmpty) return;
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final out = decoded.cast<String, Object?>();
    Map<String, Object?>? span(Object? v, AxisIndex axis) {
      if (v is! Map) return null;
      final a = v['start'], b = v['end'] ?? v['start'];
      if (a is! String || b is! String) return null;
      final i = axis.indexOf(a), j = axis.indexOf(b);
      if (i < 0 || j < 0) return null;
      return {'start': i < j ? i : j, 'end': i < j ? j : i};
    }

    out['repeatRows'] = span(out['repeatRows'], s.rows);
    out['repeatCols'] = span(out['repeatCols'], s.columns);
    final breaks = out['pageBreaks'];
    if (breaks is Map) {
      List<int> idx(Object? l, AxisIndex axis) => [
        if (l is List)
          for (final id in l)
            if (id is String && axis.indexOf(id) >= 0) axis.indexOf(id),
      ]..sort();
      out['pageBreaks'] = {
        'rows': idx(breaks['rows'], s.rows),
        'cols': idx(breaks['cols'], s.columns),
      };
    }
    final area = GridRange.tryParse(out['printArea']);
    out['printArea'] = area == null ? null : _irRange(s, area)?.toA1();
    out
      ..remove('v')
      ..removeWhere((k, v) => v == null);
    ir.print = out;
  }

  IrNamedRange? _name(NamedRangeRecord n, Set<String> exported) {
    if (n.rangeJson != null) {
      final g = GridRange.tryParse(n.rangeJson);
      if (g == null || !exported.contains(g.sheetId)) return null;
      final s = model.sheet(g.sheetId)!;
      final r = _irRange(s, g);
      if (r == null) return null;
      return IrNamedRange(
        name: n.name,
        sheet: s.name,
        range: r,
        comment: n.comment,
      );
    }
    final f = n.formula;
    if (f == null) return null;
    final host = model.sheets.isEmpty ? null : model.sheets.first;
    return IrNamedRange(
      name: n.name,
      formulaA1: host == null
          ? (f.startsWith('=') ? f.substring(1) : f)
          : _a1(f, host.id, 0, 0),
      comment: n.comment,
    );
  }
}
