import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wonky_sheets_core/model.dart';

import '../data_tools/data_tools.dart';
import '../grid/selection/grid_selection.dart';
import '../model/local_view_state.dart';
import '../protection/protection_controller.dart';
import 'sheet_editor_controller.dart';

/// Restores and keeps the `LocalViewState` of an open spreadsheet (02 §4):
/// active sheet, selection per sheet, scroll, zoom, the open side panel and
/// temporary filter views. Saves 800 ms after the last change and when the
/// editor closes.
class ViewStateBinding {
  ViewStateBinding._(this.editor, this.store);

  /// Attaches to [editor]: restores the cached state (the route's sheet and
  /// range win: pass [restoreSheet] / [restoreSelection] false) and starts
  /// saving.
  static ViewStateBinding attach(
    SheetEditorController editor,
    LocalViewStateStore store, {
    bool restoreSheet = true,
    bool restoreSelection = true,
  }) {
    final b = ViewStateBinding._(editor, store);
    final saved = store.cached(editor.session.spreadsheetId);
    if (saved != null) {
      b._restore(saved, sheet: restoreSheet, selection: restoreSelection);
    }
    b._listen();
    editor.onDispose(b._dispose);
    return b;
  }

  final SheetEditorController editor;
  final LocalViewStateStore store;
  Timer? _debounce;
  bool _disposed = false;
  late final List<Listenable> _sources;

  WorkbookModel get _model => editor.model;

  void _restore(
    LocalViewState s, {
    required bool sheet,
    required bool selection,
  }) {
    final sheetId = s.activeSheetId;
    if (sheet && sheetId != null) {
      final target = _model.sheet(sheetId);
      if (target != null && !(target.record?.hidden ?? false)) {
        editor.activateSheet(sheetId);
      }
    }
    ProtectionController.of(editor).showStripes = s.showProtectedRanges;
    if (s.zoom != editor.scroll.zoom) {
      editor.scroll.setZoom(s.zoom);
      editor.notifyZoom();
    }
    if (selection) {
      final active = editor.activeSheetId;
      final entries = s.selections.entries.toList()
        ..sort((a, b) => (a.key == active ? 1 : 0) - (b.key == active ? 1 : 0));
      for (final e in entries) {
        final sel = GridSelection.fromJson(e.value);
        // Restoring a selection switches the controller to its sheet; the
        // active sheet's selection comes last.
        if (sel != null && _resolves(sel)) editor.selection.restore(sel);
      }
      if (editor.selection.sheetId != active) editor.selection.setSheet(active);
    }
    if (sheetId == null || sheetId == editor.activeSheetId) {
      editor.scroll.jumpTo(s.scrollX, s.scrollY);
    }
    // The side panel (precedence, 02 §4 `LocalViewState`): a panel this
    // spreadsheet opens while it starts (a `?comment=` deep link, a pivot
    // or chart editor, …) wins over the saved one; the saved one wins over
    // a panel still open from the previous document (the shell's panel host
    // is shared). A saved "no panel" leaves a carried-over panel open.
    final panel = s.panelId;
    final panels = editor.services.panels;
    if (panel != null && panels.activePanelId != panel) {
      final carried = panels.activePanelId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || panels.activePanelId != carried) return;
        panels.open(panel);
      });
    }
    if (s.temporaryViews.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _restoreTemporaryViews(s.temporaryViews);
      });
    }
  }

  bool _resolves(GridSelection sel) {
    final s = _model.sheet(sel.sheetId);
    if (s == null) return false;
    final a = sel.active;
    return (a.rowId.isEmpty || s.rows.indexOf(a.rowId) >= 0) &&
        (a.colId.isEmpty || s.columns.indexOf(a.colId) >= 0);
  }

  void _restoreTemporaryViews(List<SavedTemporaryView> views) {
    final filters = DataTools.of(editor).filters;
    if (filters.temporaryViews.isNotEmpty) return;
    for (final v in views) {
      final range = GridRange.tryParse(v.rangeJson);
      if (range == null || _model.sheet(v.sheetId) == null) continue;
      final created = filters.createTemporary(
        v.sheetId,
        range,
        criteria: FilterCriteria.fromJson(v.criteriaJson),
        name: v.name,
      );
      // createTemporary activates the view; keep only the saved active one.
      if (!v.active) filters.activate(v.sheetId, null);
      if (v.active) filters.activate(v.sheetId, created.id);
    }
  }

  void _listen() {
    _sources = [
      editor,
      editor.scroll,
      editor.selection,
      editor.services.panels,
      DataTools.of(editor).filters,
      ProtectionController.of(editor),
    ];
    for (final l in _sources) {
      l.addListener(_changed);
    }
  }

  void _changed() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), save);
  }

  /// The current view state.
  LocalViewState capture() {
    final sheet = editor.activeSheet;
    final zoom = editor.scroll.zoom;
    final filters = DataTools.of(editor).filters;
    return LocalViewState(
      savedAt: DateTime.now().toUtc(),
      activeSheetId: editor.activeSheetId,
      selections: {
        for (final s in _model.sheets)
          if (editor.selection.selectionOf(s.id) case final sel?)
            s.id: sel.toJson(),
      },
      scrollX: editor.scroll.x,
      scrollY: editor.scroll.y,
      topRow: sheet == null || sheet.rows.length == 0
          ? 0
          : sheet.rows.indexAtOffset(editor.scroll.y / zoom),
      zoom: zoom,
      panelId: editor.services.panels.activePanelId,
      temporaryViews: [
        for (final v in filters.temporaryViews)
          SavedTemporaryView(
            sheetId: v.sheetId,
            name: v.name,
            rangeJson: v.range.toJson(),
            criteriaJson: v.criteria.toJson(),
            active: filters.activeViewId(v.sheetId) == v.id,
          ),
      ],
      showProtectedRanges: ProtectionController.of(editor).showStripes,
    );
  }

  /// Saves now.
  Future<void> save() async {
    _debounce?.cancel();
    if (_model.sheets.isEmpty) return;
    await store.write(editor.session.spreadsheetId, capture());
  }

  void _dispose() {
    if (_disposed) return;
    unawaited(save());
    _disposed = true;
    _debounce?.cancel();
    for (final l in _sources) {
      l.removeListener(_changed);
    }
  }
}
