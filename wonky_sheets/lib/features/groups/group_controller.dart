import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';

/// Width of one outline gutter level in px (07 §16.3).
const double kGroupGutterLevel = 16;

/// Applies the collapse mask of row/column groups to the axes
/// (`GroupCollapseMask`, 07 §16.1) and serves the gutter layout.
class GroupController extends ChangeNotifier {
  GroupController(this.ed);

  final SheetEditorController ed;

  WorkbookModel get model => ed.model;

  bool _started = false;
  final Map<(String, Dimension), List<GroupSpan>> _spans = {};

  void start() {
    if (_started) return;
    _started = true;
    model.addListener(_onBatch);
    for (final s in model.sheets) {
      _apply(s.id);
    }
  }

  @override
  void dispose() {
    if (_started) model.removeListener(_onBatch);
    super.dispose();
  }

  /// The layout of [sheetId]'s groups of [dimension].
  GroupLayout layout(String sheetId, Dimension dimension) {
    final s = model.sheet(sheetId)!;
    return GroupLayout(
      sheetId,
      dimension,
      dimension == Dimension.rows ? s.rows : s.columns,
      s.groups.values,
    );
  }

  /// Resolved spans (cached until the groups or the axis change).
  List<GroupSpan> spans(String sheetId, Dimension dimension) =>
      _spans.putIfAbsent((sheetId, dimension), () {
        final s = model.sheet(sheetId);
        if (s == null || s.groups.isEmpty) return const [];
        return layout(sheetId, dimension).spans();
      });

  /// Gutter levels (max depth) of [sheetId] for [dimension].
  int levels(String sheetId, Dimension dimension) =>
      spans(sheetId, dimension).fold(0, (m, s) => s.depth > m ? s.depth : m);

  /// Gutter sizes in px (`GridHooks.gutters`): one level per depth plus the
  /// level of the +/− buttons.
  ({double rows, double cols}) gutters(SheetModel sheet) {
    final r = levels(sheet.id, Dimension.rows);
    final c = levels(sheet.id, Dimension.columns);
    return (
      rows: r == 0 ? 0 : (r + 1) * kGroupGutterLevel,
      cols: c == 0 ? 0 : (c + 1) * kGroupGutterLevel,
    );
  }

  void _apply(String sheetId) {
    _spans.remove((sheetId, Dimension.rows));
    _spans.remove((sheetId, Dimension.columns));
    final s = model.sheet(sheetId);
    if (s == null) return;
    var changed = false;
    for (final d in Dimension.values) {
      final axis = d == Dimension.rows ? s.rows : s.columns;
      final ids = s.groups.isEmpty
          ? <String>{}
          : layout(sheetId, d).collapsedHiddenIds();
      if (!setEquals(axis.hiddenLayer(HiddenLayers.groups), ids)) {
        axis.setHiddenLayer(HiddenLayers.groups, ids);
        changed = true;
      }
    }
    if (changed) ed.engine.filterVisibilityChanged(sheetId);
    if (sheetId == ed.activeSheetId) {
      ed.contentSignal.fire();
      ed.overlaySignal.fire();
    }
    notifyListeners();
  }

  void _onBatch(WorkbookChangeBatch batch) {
    final ids = <String>{};
    var all = false;
    for (final e in batch.events) {
      switch (e) {
        case RulesChanged(:final sheetId, :final kind)
            when kind == RuleKind.group:
          ids.add(sheetId);
        case StructureChanged(:final sheetId, :final order) when order:
          if (model.sheet(sheetId)?.groups.isNotEmpty ?? false) {
            ids.add(sheetId);
          }
        case SheetsChanged():
          all = true;
        default:
          break;
      }
    }
    if (all) {
      _spans.clear();
      for (final s in model.sheets) {
        _apply(s.id);
      }
      return;
    }
    for (final id in ids) {
      _apply(id);
    }
  }
}
