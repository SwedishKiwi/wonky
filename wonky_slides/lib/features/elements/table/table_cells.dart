import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Offset, immutable, ChangeNotifier;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';

import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../selection/slide_elements.dart';

/// A rectangular range of table cells by index (inclusive), merges
/// included whole.
@immutable
class TableRange {
  const TableRange(this.tableId, this.r0, this.c0, this.r1, this.c1);

  final String tableId;
  final int r0;
  final int c0;
  final int r1;
  final int c1;

  int get rows => r1 - r0 + 1;
  int get columns => c1 - c0 + 1;

  bool contains(int r, int c) => r >= r0 && r <= r1 && c >= c0 && c <= c1;

  /// The range of the whole table.
  static TableRange? all(TableIndex ix) => ix.rows.isEmpty || ix.columns.isEmpty
      ? null
      : TableRange(
          ix.elementId,
          0,
          0,
          ix.rows.length - 1,
          ix.columns.length - 1,
        );

  /// The range spanning ([ra], [ca]) and ([rb], [cb]), grown until no merge
  /// is cut (03 §6.6).
  static TableRange spanning(TableIndex ix, int ra, int ca, int rb, int cb) {
    var r0 = math.min(ra, rb), r1 = math.max(ra, rb);
    var c0 = math.min(ca, cb), c1 = math.max(ca, cb);
    var changed = true;
    while (changed) {
      changed = false;
      for (final m in ix.merges) {
        final overlaps =
            m.row <= r1 &&
            m.row + m.rowSpan - 1 >= r0 &&
            m.column <= c1 &&
            m.column + m.colSpan - 1 >= c0;
        if (!overlaps) continue;
        final nr0 = math.min(r0, m.row), nc0 = math.min(c0, m.column);
        final nr1 = math.max(r1, m.row + m.rowSpan - 1);
        final nc1 = math.max(c1, m.column + m.colSpan - 1);
        if (nr0 != r0 || nc0 != c0 || nr1 != r1 || nc1 != c1) {
          (r0, c0, r1, c1) = (nr0, nc0, nr1, nc1);
          changed = true;
        }
      }
    }
    return TableRange(ix.elementId, r0, c0, r1, c1);
  }

  /// Whether the range is exactly one visible cell (a cell or a merge).
  bool isSingleCell(TableIndex ix) {
    if (rows == 1 && columns == 1) return true;
    final m = ix.mergeAt(r0, c0);
    return m != null &&
        m.row == r0 &&
        m.column == c0 &&
        m.rowSpan == rows &&
        m.colSpan == columns;
  }

  /// The visible cells (merge origins and unmerged cells) of the range as
  /// `(rowId, columnId)`, row-major.
  List<({String rowId, String columnId, int row, int column})> cells(
    TableIndex ix,
  ) {
    final out = <({String rowId, String columnId, int row, int column})>[];
    for (var r = r0; r <= r1 && r < ix.rows.length; r++) {
      for (var c = c0; c <= c1 && c < ix.columns.length; c++) {
        final m = ix.mergeAt(r, c);
        if (m != null && (m.row != r || m.column != c)) continue;
        out.add((
          rowId: ix.rows[r].id,
          columnId: ix.columns[c].id,
          row: r,
          column: c,
        ));
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is TableRange &&
      other.tableId == tableId &&
      other.r0 == r0 &&
      other.c0 == c0 &&
      other.r1 == r1 &&
      other.c1 == c1;

  @override
  int get hashCode => Object.hash(tableId, r0, c0, r1, c1);

  @override
  String toString() => 'TableRange($tableId, $r0:$c0 – $r1:$c1)';
}

/// The table cell selection of an open deck (03 §6.6, `slidesTable`
/// scope): a range of one table by its anchor and focus cells (axis ids,
/// so it survives inserted rows). View state — not undoable. It clears
/// when the table stops being the single selection or disappears.
class TableCellSelection extends ChangeNotifier {
  TableCellSelection._(this.editor) {
    editor.addListener(_onEditor);
  }

  static final Expando<TableCellSelection> _registry = Expando(
    'slidesTableCells',
  );

  /// The cell selection of [ed].
  static TableCellSelection of(DeckEditorController ed) =>
      _registry[ed] ??= TableCellSelection._(ed);

  final DeckEditorController editor;

  String? _table;
  ({String rowId, String columnId})? _anchor;
  ({String rowId, String columnId})? _focus;

  /// The table whose cells are selected, or null.
  String? get tableId => _table;

  /// The anchor cell (Shift extends from it).
  ({String rowId, String columnId})? get anchor => _anchor;

  /// The focus (active) cell: Enter edits it, typing goes into it.
  ({String rowId, String columnId})? get focus => _focus;

  bool get isEmpty => _table == null;

  /// Selects cells of [tableId] from [anchor] to [focus] (one cell when
  /// [focus] is null).
  void select(
    String tableId,
    ({String rowId, String columnId}) anchor, [
    ({String rowId, String columnId})? focus,
  ]) {
    final f = focus ?? anchor;
    if (_table == tableId && _anchor == anchor && _focus == f) return;
    _table = tableId;
    _anchor = anchor;
    _focus = f;
    notifyListeners();
  }

  /// Selects the cell at indexes ([r], [c]) of [tableId] (extending from
  /// the anchor with [extend]).
  bool selectAt(String tableId, int r, int c, {bool extend = false}) {
    final ix = editor.model.indexes.table(tableId);
    if (r < 0 || c < 0 || r >= ix.rows.length || c >= ix.columns.length) {
      return false;
    }
    final cell = (rowId: ix.rows[r].id, columnId: ix.columns[c].id);
    if (extend && _table == tableId && _anchor != null) {
      select(tableId, _anchor!, cell);
    } else {
      select(tableId, cell);
    }
    return true;
  }

  void clear() {
    if (_table == null) return;
    _table = null;
    _anchor = null;
    _focus = null;
    notifyListeners();
  }

  /// Indexes of [cell] in table [ix], or null when its axes are gone.
  static (int, int)? indexOf(
    TableIndex ix,
    ({String rowId, String columnId}) cell,
  ) {
    final r = ix.rows.indexWhere((a) => a.id == cell.rowId);
    final c = ix.columns.indexWhere((a) => a.id == cell.columnId);
    return r < 0 || c < 0 ? null : (r, c);
  }

  /// The selected range (merges included whole), or null.
  TableRange? get range {
    final t = _table, a = _anchor, f = _focus;
    if (t == null || a == null || f == null) return null;
    if (editor.model.element(t) == null) return null;
    final ix = editor.model.indexes.table(t);
    final pa = indexOf(ix, a), pf = indexOf(ix, f);
    if (pa == null || pf == null) return null;
    return TableRange.spanning(ix, pa.$1, pa.$2, pf.$1, pf.$2);
  }

  void _onEditor() {
    final t = _table;
    if (t == null) return;
    final ids = editor.selectedElementIds;
    if (ids.length != 1 ||
        ids.single != t ||
        editor.model.element(t) == null ||
        range == null) {
      clear();
    }
  }

  @override
  void dispose() {
    editor.removeListener(_onEditor);
    if (_registry[editor] == this) _registry[editor] = null;
    super.dispose();
  }
}

/// Table layout of the canvas (03 §6.6): the laid-out grid of a table on
/// the current slide (the renderer's builder and text engine, memoized per
/// slide revision) and point ↔ cell mapping.
abstract final class TableGeometry {
  static final Expando<Map<String, (String, TableGrid?)>> _memo = Expando(
    'slidesTableGrids',
  );

  /// The grid of table [id] on [c]'s current slide, or null.
  static TableGrid? gridOf(SlideCanvasController c, String id) {
    final slideId = c.editor.currentSlideId;
    final e = c.elements?[id];
    final slide = c.slide;
    if (slideId == null ||
        e == null ||
        slide == null ||
        e.record.kind != ElementKind.table) {
      return null;
    }
    final memo = _memo[c] ??= {};
    final rev = c.renderer.revision(slideId);
    final hit = memo[id];
    if (hit != null && hit.$1 == rev) return hit.$2;
    final grid = c.renderer.builder.tableGrid(
      e,
      SceneContext(
        theme: slide.theme,
        textLayout: c.renderer.textLayout,
        deck: c.renderer.model,
      ),
    );
    memo[id] = (rev, grid);
    return grid;
  }

  /// Slide point [su] in table [id]'s element-local su, or null.
  static Offset? localOf(SlideCanvasController c, String id, Offset su) {
    final f = c.frameOf(id);
    return f == null ? null : SlideCanvasController.slideToLocal(f, su);
  }

  /// The visible cell of table [id] under slide point [su], or null.
  static TableGridCell? cellAt(SlideCanvasController c, String id, Offset su) {
    final grid = gridOf(c, id), l = localOf(c, id, su);
    if (grid == null || l == null) return null;
    return grid.cellAtPoint(l.dx, l.dy);
  }

  /// Whether [e] is a table the canvas modes may act on.
  static bool isTable(ResolvedElement? e) =>
      e != null &&
      e.record.kind == ElementKind.table &&
      SlideElements.selectable(e);
}
