import 'package:wonky_sheets_core/formula.dart'
    show CellSource, FValue, GridDimension;
import 'package:wonky_sheets_core/model.dart';

/// Per-cell render data of the visible window (03 §2.5 `CellRenderResolver`,
/// backed by the core `CellDisplayResolver`): formatted value, effective
/// format, colors, widget and resolved border edges. Cached per cell and
/// dropped on any model change or recalculation.
class CellRenderCache {
  CellRenderCache(this.model, this.source, {this.conditional});

  final WorkbookModel model;
  final CellSource source;

  /// Conditional formatting hook (06 §15; filled in by the CF feature).
  ConditionalOverlayProvider? conditional;

  /// Commit-hint hook (10 §2.2): a collaborator's just-committed value,
  /// painted instead of the computed one until the synced row arrives.
  /// Call [invalidate] after changing it.
  FValue? Function(String sheetId, int row, int col)? hinted;

  CellSource get _source =>
      hinted == null ? source : _HintedSource(source, hinted!);

  /// Whether conditional formatting may apply at a cell (a rule or the
  /// panel's draft covers it); other empty cells keep the fast path.
  bool Function(String sheetId, int row, int col)? conditionalAt;

  /// The data validation panel's draft rule, previewed in the grid (chips,
  /// checkboxes; 07 §6.3). Call [invalidate] after changing it.
  DvDraftPreview? dvDraft;

  /// Computed default formats of overlay output (pivot headers and totals
  /// bold, 07 §7.5). Below conditional formatting; the provider leaves out
  /// attributes the user set explicitly.
  ConditionalOverlayProvider? computedFormat;

  CellDisplayResolver? _resolver;
  final Map<String, Map<int, CellDisplay?>> _cells = {};
  final Map<String, Map<int, CellEdges>> _edges = {};
  int _version = 0;

  /// Incremented by [invalidate].
  int get version => _version;

  CellDisplayResolver get resolver => _resolver ??= CellDisplayResolver(
    model,
    _source,
    conditional: _combinedConditional(),
    dvDraft: dvDraft,
  );

  ConditionalOverlayProvider? _combinedConditional() {
    final cf = conditional;
    final computed = computedFormat;
    if (computed == null) return cf;
    return (sheetId, row, col) {
      final a = computed(sheetId, row, col);
      final b = cf?.call(sheetId, row, col);
      if (a == null) return b;
      if (b == null) return a;
      final af = a.format;
      final bf = b.format;
      return ConditionalOverlay(
        format: af == null ? bf : (bf == null ? af : af.overlay(bf)),
        dataBarFraction: b.dataBarFraction,
        dataBarColor: b.dataBarColor,
        dataBarStart: b.dataBarStart,
      );
    };
  }

  static int _key(int row, int col) => row * 32768 + col;

  /// Cached cells per sheet before the cache starts over.
  static const maxEntries = 60000;

  /// Drops everything (model batch, recalculation, theme or locale change).
  void invalidate() {
    _cells.clear();
    _edges.clear();
    _resolver = null;
    _version++;
  }

  /// Display data of the cell, or null when it shows nothing (no value,
  /// fill, border or widget).
  CellDisplay? displayAt(String sheetId, int row, int col) {
    final map = _cells.putIfAbsent(sheetId, () => {});
    final k = _key(row, col);
    if (map.containsKey(k)) return map[k];
    // Bounded: long scrolls through huge sheets don't keep every cell.
    if (map.length > maxEntries) map.clear();
    final d = _compute(sheetId, row, col);
    map[k] = d;
    return d;
  }

  CellDisplay? _compute(String sheetId, int row, int col) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return null;
    final rec = sheet.cellAt(row, col);
    if (rec == null &&
        sheet.bandings.isEmpty &&
        model.bandingPreview == null &&
        sheet.dvRules.isEmpty &&
        dvDraft?.sheetId != sheetId &&
        (conditional == null ||
            !(conditionalAt?.call(sheetId, row, col) ?? true)) &&
        computedFormat?.call(sheetId, row, col) == null) {
      final chain = model.explicitFormatChain(sheetId, row, col);
      final decorated =
          chain.has(FormatAttr.fillColor) || FormatAttr.borders.any(chain.has);
      if (!decorated) {
        final v = _source.valueAt(sheetId, row, col).toCellValue();
        if (v.isBlank()) return null;
      }
    }
    return resolver.display(sheetId, row, col);
  }

  /// Whether the cell holds or shows anything (overflow stops there).
  bool hasContent(String sheetId, int row, int col) {
    final d = displayAt(sheetId, row, col);
    if (d == null) return false;
    return d.text.isNotEmpty ||
        d.widget.kind != CellWidgetKind.none ||
        d.content != null;
  }

  /// Resolved border edges of a cell (shared-edge conflicts applied).
  CellEdges edgesAt(String sheetId, int row, int col) {
    final map = _edges.putIfAbsent(sheetId, () => {});
    if (map.length > maxEntries) map.clear();
    return map.putIfAbsent(
      _key(row, col),
      () => resolver.edges(sheetId, row, col),
    );
  }

  /// Whether the sheet may have any border at all (fast path).
  bool sheetHasBorders(String sheetId) {
    final s = model.sheet(sheetId);
    if (s == null) return false;
    bool has(CellFormat f) => FormatAttr.borders.any(f.has);
    if (s.record != null && has(s.record!.format)) return true;
    for (final r in s.rowRecords.values) {
      if (r.formatJson != null && has(r.format)) return true;
    }
    for (final c in s.columnRecords.values) {
      if (c.formatJson != null && has(c.format)) return true;
    }
    return _cellBorders(s);
  }

  bool _cellBorders(SheetModel s) {
    final cached = _borderFlag[s.id];
    if (cached != null && cached.$1 == _version) return cached.$2;
    var any = false;
    for (final c in s.cells.all) {
      if (FormatAttr.borders.any(c.format.has)) {
        any = true;
        break;
      }
    }
    _borderFlag[s.id] = (_version, any);
    return any;
  }

  final Map<String, (int, bool)> _borderFlag = {};
}

/// [CellSource] with hinted values on top (10 §2.2).
class _HintedSource implements CellSource {
  _HintedSource(this.base, this.hinted);

  final CellSource base;
  final FValue? Function(String sheetId, int row, int col) hinted;

  @override
  FValue valueAt(String sheetId, int row, int col) =>
      hinted(sheetId, row, col) ?? base.valueAt(sheetId, row, col);

  @override
  String? numberFormatAt(String sheetId, int row, int col) =>
      base.numberFormatAt(sheetId, row, col);

  @override
  bool isHidden(
    String sheetId,
    GridDimension dimension,
    int index, {
    bool includeFilter = true,
  }) => base.isHidden(sheetId, dimension, index, includeFilter: includeFilter);
}
