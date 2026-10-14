import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../data_tools/data_tools.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'slicer_spec.dart';

/// Hidden layer of slicer rows shown on this device when a viewer changed a
/// slicer locally (not read by formulas, 07 §5).
const slicerViewLayer = 'slicerView';

/// Slicers of an open spreadsheet (07 §5): each slicer hides the rows of
/// its data range whose value in its column fails its criteria — for
/// everyone (`slicer` hidden layer, counted by `SUBTOTAL` and followed by
/// charts on the same data). Viewers' changes are local overrides
/// ([setOverride]), shown only on this device and never used by formulas.
class SlicerController extends ChangeNotifier {
  SlicerController._(this.ed);

  static const _key = #sheetsSlicers;

  /// The slicers of [ed] (installed on first use).
  static SlicerController of(SheetEditorController ed) =>
      ed.extension(_key, () => SlicerController._(ed).._start());

  final SheetEditorController ed;
  WorkbookModel get model => ed.model;

  /// Local criteria by object id (viewers, 07 §5).
  final Map<String, ColumnCriteria?> _overrides = {};
  StreamSubscription<Object?>? _recalc;
  Timer? _debounce;
  final Set<String> _pending = {};

  void _start() {
    model.addListener(_onBatch);
    _recalc = ed.engine.changes.listen((_) => _schedule(_slicerSheets()));
    ed.onDispose(_dispose);
    for (final s in model.sheets) {
      refresh(s.id);
    }
  }

  void _dispose() {
    model.removeListener(_onBatch);
    unawaited(_recalc?.cancel());
    _debounce?.cancel();
    dispose();
  }

  /// The slicer records of [sheetId].
  List<EmbeddedObjectRecord> slicersOn(String sheetId) => [
    for (final o
        in model.sheet(sheetId)?.objects.values ??
            const <EmbeddedObjectRecord>[])
      if (o.kind == EmbeddedObjectKind.slicer) o,
  ];

  /// The slicer [id] with its sheet.
  (SheetModel, EmbeddedObjectRecord)? find(String id) {
    for (final s in model.sheets) {
      final o = s.objects[id];
      if (o != null && o.kind == EmbeddedObjectKind.slicer) return (s, o);
    }
    return null;
  }

  /// Whether [id] has a local (viewer) override.
  bool hasOverride(String id) => _overrides.containsKey(id);

  /// The criteria shown for slicer [o]: the local override, else the
  /// synced criteria.
  ColumnCriteria? criteriaOf(EmbeddedObjectRecord o) {
    if (_overrides.containsKey(o.id)) return _overrides[o.id];
    return SlicerSpec.tryParse(o.specJson)?.criteria;
  }

  /// Sets (or with [clear] removes) a local override of slicer [id].
  void setOverride(String id, ColumnCriteria? criteria, {bool clear = false}) {
    if (clear) {
      _overrides.remove(id);
    } else {
      _overrides[id] = criteria;
    }
    final f = find(id);
    if (f != null) refresh(f.$1.id);
    notifyListeners();
  }

  /// The data range of [spec] on [sheet] resolved (header row first).
  GridRect? rectOf(SheetModel sheet, SlicerSpec spec) =>
      sheet.resolve(spec.dataRange)?.rect;

  /// The values checklist of slicer [o] (other slicers ignored).
  List<ChecklistEntry> checklist(SheetModel sheet, EmbeddedObjectRecord o) {
    final spec = SlicerSpec.tryParse(o.specJson);
    if (spec == null || spec.colId == null) return const [];
    final rect = rectOf(sheet, spec);
    final col = sheet.columns.indexOf(spec.colId!);
    if (rect == null || col < 0) return const [];
    final filters = DataTools.of(ed).filters;
    final input = FilterInput.resolve(
      sheet: sheet,
      range: rect,
      criteria: FilterCriteria(),
      source: filters.source(sheet.id),
      conditions: filters.conditions,
    );
    return FilterEngine.checklist(input, col);
  }

  Set<String> _hidden(
    SheetModel sheet,
    EmbeddedObjectRecord o,
    ColumnCriteria? criteria,
  ) {
    final spec = SlicerSpec.tryParse(o.specJson);
    if (spec == null || spec.colId == null || criteria == null) return {};
    if (criteria.isEmpty) return {};
    final rect = rectOf(sheet, spec);
    if (rect == null || rect.rowCount < 2) return {};
    final filters = DataTools.of(ed).filters;
    try {
      final vis = FilterEngine.compute(
        FilterInput.resolve(
          sheet: sheet,
          range: rect,
          criteria: FilterCriteria({spec.colId!: criteria}),
          source: filters.source(sheet.id),
          conditions: filters.conditions,
        ),
      );
      return vis.hiddenRowIds(sheet.rows);
    } catch (e) {
      debugPrint('Slicer: $e');
      return {};
    }
  }

  /// Recomputes the slicer layers of [sheetId].
  void refresh(String sheetId) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return;
    final slicers = slicersOn(sheetId);
    final shared = <String>{};
    final shown = <String>{};
    var anyOverride = false;
    for (final o in slicers) {
      final synced = SlicerSpec.tryParse(o.specJson)?.criteria;
      final h = _hidden(sheet, o, synced);
      shared.addAll(h);
      if (_overrides.containsKey(o.id)) {
        anyOverride = true;
        shown.addAll(_hidden(sheet, o, _overrides[o.id]));
      } else {
        shown.addAll(h);
      }
    }
    final rows = sheet.rows;
    var changed = false;
    if (!setEquals(rows.hiddenLayer(HiddenLayers.slicer), shared)) {
      rows.setHiddenLayer(HiddenLayers.slicer, shared);
      ed.engine.filterVisibilityChanged(sheetId);
      changed = true;
    }
    final view = anyOverride ? shown : <String>{};
    if (!setEquals(rows.hiddenLayer(slicerViewLayer), view)) {
      rows.setHiddenLayer(slicerViewLayer, view);
      changed = true;
    }
    if (rows.isLayerSuppressed(HiddenLayers.slicer) != anyOverride) {
      rows.setLayerSuppressed(HiddenLayers.slicer, anyOverride);
      changed = true;
    }
    if (changed && sheetId == ed.activeSheetId) {
      ed.contentSignal.fire();
      ed.overlaySignal.fire();
    }
    if (changed) notifyListeners();
  }

  Iterable<String> _slicerSheets() sync* {
    for (final s in model.sheets) {
      if (s.objects.values.any((o) => o.kind == EmbeddedObjectKind.slicer)) {
        yield s.id;
      }
    }
  }

  void _schedule(Iterable<String> ids) {
    _pending.addAll(ids);
    if (_pending.isEmpty) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 60), () {
      final ids = {..._pending};
      _pending.clear();
      ids.forEach(refresh);
    });
  }

  void _onBatch(WorkbookChangeBatch batch) {
    final now = <String>{};
    for (final e in batch.events) {
      switch (e) {
        case RulesChanged(:final sheetId, :final kind)
            when kind == RuleKind.object:
          now.add(sheetId);
          // Overrides of deleted slicers end.
          _overrides.removeWhere((id, _) => find(id) == null);
        case CellsChanged(:final sheetId):
          if (slicersOn(sheetId).isNotEmpty) now.add(sheetId);
        case StructureChanged(:final sheetId):
          if (slicersOn(sheetId).isNotEmpty) now.add(sheetId);
        case SheetsChanged():
          now.addAll(model.sheets.map((s) => s.id));
        default:
          break;
      }
    }
    for (final id in now) {
      refresh(id);
    }
    if (now.isNotEmpty) notifyListeners();
  }
}
