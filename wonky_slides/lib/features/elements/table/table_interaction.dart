import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource, KeyScope;
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../canvas/canvas_interactions.dart';
import '../../canvas/canvas_tokens.dart';
import '../../text_editing/text_edit_geometry.dart';
import '../../text_editing/text_editing_host.dart';
import 'table_cells.dart';

enum _TableDrag { none, cells, column, row }

/// Table cells on the canvas (03 §6.6, `slidesTable` scope): with one
/// table selected, a click into a cell edits its text (the text editing
/// overlay, SL-13), a drag across cells (or Shift+click) selects a cell
/// range, and dragging an inner border resizes the columns or the row
/// (one step, `slides.table.resizeAxes`). The range is highlighted; a
/// right-click opens the table context menu.
class TableCanvasMode extends CanvasInteraction {
  TableCanvasMode(super.c) {
    _cells = TableCellSelection.of(c.editor)..addListener(c.refresh);
  }

  late final TableCellSelection _cells;

  _TableDrag _drag = _TableDrag.none;
  String? _table;
  TableGridCell? _pressCell;
  Offset _pressSu = Offset.zero;
  bool _moved = false;
  int _border = 0;
  double? _borderAt;

  /// The single selected table, or null.
  String? get _selectedTable {
    final ids = c.editor.selectedElementIds;
    if (ids.length != 1) return null;
    final e = c.elements?[ids.single];
    return TableGeometry.isTable(e) ? e!.id : null;
  }

  double get _tol => 4 / math.max(c.viewport.scale, 1e-3);

  /// What is under [local] of [grid]: an inner border (`column`/`row` with
  /// its index), the outer edge zone (null), or a cell.
  (_TableDrag, int)? _hit(TableGrid grid, Offset local) {
    final t = _tol;
    final w = grid.width, h = grid.height;
    if (local.dx < -t ||
        local.dy < -t ||
        local.dx > w + t ||
        local.dy > h + t) {
      return null;
    }
    // The outer edge belongs to the table (move, resize handles).
    if (local.dx < t * 1.5 ||
        local.dy < t * 1.5 ||
        local.dx > w - t * 1.5 ||
        local.dy > h - t * 1.5) {
      return null;
    }
    if (c.editor.canEdit) {
      for (var i = 1; i < grid.columnX.length - 1; i++) {
        if ((local.dx - grid.columnX[i]).abs() <= t) {
          return (_TableDrag.column, i);
        }
      }
      for (var i = 1; i < grid.rowY.length; i++) {
        if ((local.dy - grid.rowY[i]).abs() <= t && i < grid.rowY.length - 1) {
          return (_TableDrag.row, i);
        }
      }
    }
    return (_TableDrag.cells, 0);
  }

  @override
  bool down(CanvasPointer p) {
    final id = _selectedTable;
    if (id == null) return false;
    final grid = TableGeometry.gridOf(c, id);
    final local = TableGeometry.localOf(c, id, p.su);
    if (grid == null || local == null) return false;
    final hit = _hit(grid, local);
    if (hit == null) return false;
    _table = id;
    _moved = false;
    _pressSu = p.su;
    switch (hit.$1) {
      case _TableDrag.column || _TableDrag.row:
        _drag = hit.$1;
        _border = hit.$2;
        _borderAt = null;
      case _TableDrag.cells:
        final cell = grid.cellAtPoint(local.dx, local.dy);
        if (cell == null) return false;
        _drag = _TableDrag.cells;
        _pressCell = cell;
        final key = (rowId: cell.rowId, columnId: cell.columnId);
        if (p.modifiers.shift &&
            _cells.tableId == id &&
            _cells.anchor != null) {
          _cells.select(id, _cells.anchor!, key);
          _moved = true;
        }
      case _TableDrag.none:
        return false;
    }
    return true;
  }

  @override
  void move(CanvasPointer p) {
    final id = _table;
    if (id == null) return;
    final grid = TableGeometry.gridOf(c, id);
    final local = TableGeometry.localOf(c, id, p.su);
    if (grid == null || local == null) return;
    switch (_drag) {
      case _TableDrag.cells:
        final cell = grid.cellAtPoint(
          local.dx.clamp(0, grid.width - 0.01),
          local.dy.clamp(0, grid.height - 0.01),
        );
        final press = _pressCell;
        if (cell == null || press == null) return;
        if (!_moved &&
            identical(cell, press) &&
            (p.su - _pressSu).distance < 2) {
          return;
        }
        if (!_moved && !identical(cell, press)) _moved = true;
        if (_moved) {
          textEditingOf(c.editor).end(select: false);
          _cells.select(
            id,
            (rowId: press.rowId, columnId: press.columnId),
            (rowId: cell.rowId, columnId: cell.columnId),
          );
        }
      case _TableDrag.column:
        final lo = grid.columnX[_border - 1] + 8;
        final hi = grid.columnX[_border + 1] - 8;
        _borderAt = local.dx.clamp(lo, math.max(lo, hi));
        c.refresh();
      case _TableDrag.row:
        final lo = grid.rowY[_border - 1] + 8;
        _borderAt = math.max(lo, local.dy);
        c.refresh();
      case _TableDrag.none:
        break;
    }
  }

  @override
  void up(CanvasPointer p) {
    final id = _table;
    final drag = _drag;
    _drag = _TableDrag.none;
    _table = null;
    if (id == null) return;
    switch (drag) {
      case _TableDrag.cells:
        final cell = _pressCell;
        _pressCell = null;
        if (_moved || cell == null) return;
        final key = (rowId: cell.rowId, columnId: cell.columnId);
        final text = textEditingOf(c.editor);
        if (c.editor.canEdit && text.canEdit(id, cell: true)) {
          _cells.clear();
          unawaited(text.begin(id, at: p.su, cell: key));
        } else {
          _cells.select(id, key);
        }
      case _TableDrag.column || _TableDrag.row:
        final at = _borderAt;
        _borderAt = null;
        c.refresh();
        if (at != null) unawaited(_commitBorder(id, drag, at));
      case _TableDrag.none:
        break;
    }
  }

  @override
  void cancel() {
    _drag = _TableDrag.none;
    _table = null;
    _pressCell = null;
    _borderAt = null;
    c.refresh();
  }

  /// Writes the dragged border: the two columns beside it (every column
  /// keeps its current width, so the shares stay), or the row's height.
  Future<void> _commitBorder(String id, _TableDrag drag, double at) async {
    final grid = TableGeometry.gridOf(c, id);
    if (grid == null) return;
    double r(double v) => (v * 100).roundToDouble() / 100;
    final sizes = <String, double>{};
    if (drag == _TableDrag.column) {
      for (var i = 0; i < grid.columns; i++) {
        var w = grid.columnX[i + 1] - grid.columnX[i];
        if (i == _border - 1) w = at - grid.columnX[i];
        if (i == _border) w = grid.columnX[i + 1] - at;
        sizes[grid.columnIds[i]] = r(w);
      }
    } else {
      sizes[grid.rowIds[_border - 1]] = r(at - grid.rowY[_border - 1]);
    }
    await c.editor.invokeCommand('slides.table.resizeAxes', {
      'id': id,
      'sizes': sizes,
    }, InvocationSource.ui);
  }

  @override
  MouseCursor? cursorAt(Offset su) {
    final id = _selectedTable;
    if (id == null || !c.editor.canEdit) return null;
    final grid = TableGeometry.gridOf(c, id);
    final local = TableGeometry.localOf(c, id, su);
    if (grid == null || local == null) return null;
    return switch (_hit(grid, local)?.$1) {
      _TableDrag.column => SystemMouseCursors.resizeColumn,
      _TableDrag.row => SystemMouseCursors.resizeRow,
      _TableDrag.cells => SystemMouseCursors.text,
      _ => null,
    };
  }

  @override
  String? contextMenuAt(Offset su) {
    final id = _selectedTable;
    if (id == null) return null;
    final cell = TableGeometry.cellAt(c, id, su);
    if (cell == null) return null;
    final range = _cells.range;
    if (range == null ||
        range.tableId != id ||
        !range.contains(cell.row, cell.column)) {
      _cells.select(id, (rowId: cell.rowId, columnId: cell.columnId));
    }
    return 'context.table';
  }

  @override
  List<KeyScope> get keyScopes =>
      !_cells.isEmpty && !textEditingOf(c.editor).isEditing
      ? [SlidesKeyScopes.table]
      : const [];

  @override
  void paint(Canvas canvas, CanvasTokens tokens) {
    final id = _selectedTable;
    if (id == null) return;
    final range = _cells.range;
    final drawRange = range != null && range.tableId == id;
    if (!drawRange && _borderAt == null) return;
    final grid = TableGeometry.gridOf(c, id);
    final f = c.frameOf(id);
    if (grid == null || f == null) return;
    final v = c.viewport;
    canvas.save();
    canvas.translate(v.origin.dx, v.origin.dy);
    canvas.scale(v.scale);
    canvas.transform(
      TextEditGeometry.elementMatrix(
        SuRect(f.x, f.y, f.width, f.height),
        rotation: f.rotation,
        flipH: f.flipH,
        flipV: f.flipV,
      ).storage,
    );
    final px = 1 / math.max(v.scale, 1e-3);
    if (drawRange) {
      final fill = Paint()..color = tokens.tableSelection;
      final x0 = grid.columnX[range.c0], x1 = grid.columnX[range.c1 + 1];
      final y0 = grid.rowY[range.r0], y1 = grid.rowY[range.r1 + 1];
      final rect = Rect.fromLTRB(x0, y0, x1, y1);
      canvas.drawRect(rect, fill);
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * px
          ..color = tokens.selection,
      );
    }
    final at = _borderAt;
    if (at != null) {
      final guide = Paint()
        ..strokeWidth = 2 * px
        ..color = tokens.guide;
      if (_drag == _TableDrag.column) {
        canvas.drawLine(Offset(at, 0), Offset(at, grid.height), guide);
      } else {
        canvas.drawLine(Offset(0, at), Offset(grid.width, at), guide);
      }
    }
    canvas.restore();
  }

  @override
  void dispose() {
    _cells.removeListener(c.refresh);
  }
}
