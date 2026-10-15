part of '../slides_planner.dart';

/// Cell columns a `SetCells` write may set.
const _cellStyleColumns = {
  SlidesCols.text,
  TableCellCols.fill,
  TableCellCols.borderTop,
  TableCellCols.borderRight,
  TableCellCols.borderBottom,
  TableCellCols.borderLeft,
  TableCellCols.vAlign,
  TableCellCols.padding,
};

/// Cell content/format columns (a cell row exists iff one is non-null).
const _cellValueColumns = {
  ..._cellStyleColumns,
  TableCellCols.rowSpan,
  TableCellCols.colSpan,
};

extension _TablePart on _Planner {
  SlideElementRec tableOf(String elementId) {
    final e = elementOf(elementId);
    if (e.kind != ElementKind.table) invalid('$elementId is not a table');
    return e;
  }

  /// Inserts [rows] × [cols] axes of a new table.
  void _newTableAxes(String elementId, int rows, int cols) {
    if (rows < 1 || cols < 1) {
      invalid('A table needs at least one row and column');
    }
    if (rows > limits.maxTableRows || cols > limits.maxTableColumns) {
      limit(
        'A table can have at most ${limits.maxTableRows} rows and '
        '${limits.maxTableColumns} columns.',
      );
    }
    for (final (d, n) in [
      (TableAxisDimension.row, rows),
      (TableAxisDimension.column, cols),
    ]) {
      for (final k in OrderKeys.between(null, null, n)) {
        _insertAxis(elementId, d, k);
      }
    }
  }

  String _insertAxis(String elementId, TableAxisDimension d, String key) {
    final id = newId();
    b.insert(SlidesTables.slideTableAxis, {
      SlidesCols.id: id,
      SlidesCols.elementId: elementId,
      TableAxisCols.dimension: d.name,
      SlidesCols.sortKey: key,
      TableAxisCols.size: null,
      TableAxisCols.header: false,
      SlidesCols.createdAt: ctx.now,
    });
    return id;
  }

  /// Writes cell columns (deterministic id; created on write; deleted when
  /// every value column ends up null, 02 §3.6).
  void writeCell(
    String elementId,
    String rowId,
    String columnId,
    Map<String, Object?> columns, {
    Set<String> together = const {},
  }) {
    tableOf(elementId);
    for (final (axis, dim) in [
      (rowId, TableAxisDimension.row),
      (columnId, TableAxisDimension.column),
    ]) {
      final a = b.rec(SlidesTables.slideTableAxis, axis) as SlideTableAxisRec?;
      if (a == null || a.elementId != elementId || a.dimension != dim) {
        notFound('Table ${dim.name}', axis);
      }
    }
    final id = SlidesIds.tableCellId(elementId, rowId, columnId);
    final cur = b.row(SlidesTables.slideTableCell, id);
    if (cur == null) {
      if (columns.values.every((v) => v == null)) return;
      b.insert(SlidesTables.slideTableCell, {
        SlidesCols.id: id,
        SlidesCols.elementId: elementId,
        TableCellCols.rowId: rowId,
        TableCellCols.columnId: columnId,
        SlidesCols.createdAt: ctx.now,
        ...columns,
      });
      return;
    }
    final next = {...cur, ...columns};
    if (_cellValueColumns.every((c) => next[c] == null)) {
      b.delete(SlidesTables.slideTableCell, id);
    } else {
      b.update(SlidesTables.slideTableCell, id, columns, together: together);
    }
  }

  void _checkAxes(String elementId, TableAxisDimension d, int adding) {
    final n = ix.table(elementId).rows.length;
    final m = ix.table(elementId).columns.length;
    if (d == TableAxisDimension.row && n + adding > limits.maxTableRows) {
      limit('A table can have at most ${limits.maxTableRows} rows.');
    }
    if (d == TableAxisDimension.column && m + adding > limits.maxTableColumns) {
      limit('A table can have at most ${limits.maxTableColumns} columns.');
    }
  }

  String insertTableAxes(InsertTableAxes op) {
    tableOf(op.elementId);
    if (op.count < 1) invalid('count must be at least 1');
    _checkAxes(op.elementId, op.dimension, op.count);
    final t = ix.table(op.elementId);
    final axes = op.dimension == TableAxisDimension.row ? t.rows : t.columns;
    if (op.index < 0 || op.index > axes.length) {
      invalid('index ${op.index} is out of range');
    }
    final keys = OrderKeys.at(
      [for (final a in axes) (a.sortKey, a.id)],
      op.index,
      op.count,
    );
    final ids = [
      for (final k in keys) _insertAxis(op.elementId, op.dimension, k),
    ];
    // Merges spanning the insertion point grow (PowerPoint).
    final rows = op.dimension == TableAxisDimension.row;
    for (final m in t.merges) {
      final start = rows ? m.row : m.column;
      final span = rows ? m.rowSpan : m.colSpan;
      if (op.index > start && op.index < start + span) {
        b.set(
          m.origin,
          {
            TableCellCols.rowSpan: rows ? m.rowSpan + op.count : m.rowSpan,
            TableCellCols.colSpan: rows ? m.colSpan : m.colSpan + op.count,
          },
          together: const {TableCellCols.rowSpan, TableCellCols.colSpan},
        );
      }
    }
    result['axisIds'] = ids;
    final what = rows ? 'row' : 'column';
    return op.count == 1 ? 'Insert $what' : 'Insert ${op.count} ${what}s';
  }

  String deleteTableAxes(DeleteTableAxes op) {
    tableOf(op.elementId);
    final t = ix.table(op.elementId);
    final ids = unique(op.axisIds).toSet();
    for (final id in ids) {
      if (t.indexOf(id) < 0) notFound('Table row or column', id);
    }
    final rowsLeft = t.rows.where((a) => !ids.contains(a.id)).length;
    final colsLeft = t.columns.where((a) => !ids.contains(a.id)).length;
    if (rowsLeft == 0 || colsLeft == 0) {
      invalid('A table needs at least one row and one column');
    }
    for (final c in deck.cellsOf(op.elementId)) {
      if (ids.contains(c.rowId) || ids.contains(c.columnId)) b.remove(c);
    }
    // Merges lose the deleted axes they span.
    for (final m in t.merges) {
      if (!b.exists(SlidesTables.slideTableCell, m.origin.id)) continue;
      final lostRows = [
        for (var r = m.row; r < m.row + m.rowSpan; r++)
          if (ids.contains(t.rows[r].id)) r,
      ].length;
      final lostCols = [
        for (var c = m.column; c < m.column + m.colSpan; c++)
          if (ids.contains(t.columns[c].id)) c,
      ].length;
      if (lostRows == 0 && lostCols == 0) continue;
      final rs = m.rowSpan - lostRows, cs = m.colSpan - lostCols;
      writeCell(
        op.elementId,
        m.origin.rowId!,
        m.origin.columnId!,
        {
          TableCellCols.rowSpan: rs > 1 ? rs : null,
          TableCellCols.colSpan: cs > 1 ? cs : null,
        },
        together: const {TableCellCols.rowSpan, TableCellCols.colSpan},
      );
    }
    for (final id in ids) {
      b.delete(SlidesTables.slideTableAxis, id);
    }
    return 'Delete ${ids.length == 1 ? 'row or column' : 'rows or columns'}';
  }

  String moveTableAxes(MoveTableAxes op) {
    tableOf(op.elementId);
    final t = ix.table(op.elementId);
    final ids = unique(op.axisIds).toSet();
    if (ids.isEmpty) return 'Move';
    final first = ids.first;
    final rows = t.rows.any((a) => a.id == first);
    final axes = rows ? t.rows : t.columns;
    for (final id in ids) {
      if (!axes.any((a) => a.id == id)) {
        invalid('Rows and columns can\'t be moved together');
      }
    }
    if (op.toIndex < 0 || op.toIndex > axes.length) {
      invalid('toIndex ${op.toIndex} is out of range');
    }
    final items = [for (final a in axes) (a.sortKey, a.id)];
    final moving = [
      for (final a in axes)
        if (ids.contains(a.id)) a,
    ];
    final keys = OrderKeys.at(items, op.toIndex, moving.length, exclude: ids);
    for (final (i, a) in moving.indexed) {
      b.set(a, {SlidesCols.sortKey: keys[i]});
    }
    return rows ? 'Move rows' : 'Move columns';
  }

  String resizeTableAxes(ResizeTableAxes op) {
    tableOf(op.elementId);
    for (final MapEntry(key: id, value: size) in op.sizes.entries) {
      final a = b.rec(SlidesTables.slideTableAxis, id) as SlideTableAxisRec?;
      if (a == null || a.elementId != op.elementId) {
        notFound('Table row or column', id);
      }
      b.set(a, {TableAxisCols.size: size == null ? null : clampSide(size)});
    }
    return 'Resize';
  }

  String setCells(SetCells op) {
    tableOf(op.elementId);
    for (final w in op.writes) {
      final cols = <String, Object?>{};
      for (final MapEntry(:key, :value) in w.columns.entries) {
        if (!_cellStyleColumns.contains(key)) {
          invalid('Column $key can\'t be set on a cell', {'column': key});
        }
        cols[key] = key == SlidesCols.text ? _body(value as String?) : value;
      }
      writeCell(op.elementId, w.rowId, w.columnId, cols);
    }
    return 'Edit table';
  }

  String mergeCells(MergeCells op) {
    tableOf(op.elementId);
    final t = ix.table(op.elementId);
    final r = t.rows.indexWhere((a) => a.id == op.rowId);
    final c = t.columns.indexWhere((a) => a.id == op.columnId);
    if (r < 0) notFound('Table row', op.rowId);
    if (c < 0) notFound('Table column', op.columnId);
    if (op.rowSpan < 1 ||
        op.colSpan < 1 ||
        r + op.rowSpan > t.rows.length ||
        c + op.colSpan > t.columns.length) {
      invalid('The merge range is outside the table');
    }
    // Merges inside or overlapping the range are dissolved.
    for (final m in [...t.merges, ...t.overlapping]) {
      final overlaps =
          m.row < r + op.rowSpan &&
          r < m.row + m.rowSpan &&
          m.column < c + op.colSpan &&
          c < m.column + m.colSpan;
      if (!overlaps ||
          m.origin.id ==
              SlidesIds.tableCellId(op.elementId, op.rowId, op.columnId)) {
        continue;
      }
      writeCell(
        op.elementId,
        m.origin.rowId!,
        m.origin.columnId!,
        {TableCellCols.rowSpan: null, TableCellCols.colSpan: null},
        together: const {TableCellCols.rowSpan, TableCellCols.colSpan},
      );
    }
    writeCell(
      op.elementId,
      op.rowId,
      op.columnId,
      {
        TableCellCols.rowSpan: op.rowSpan > 1 ? op.rowSpan : null,
        TableCellCols.colSpan: op.colSpan > 1 ? op.colSpan : null,
      },
      together: const {TableCellCols.rowSpan, TableCellCols.colSpan},
    );
    return 'Merge cells';
  }

  String unmergeCells(UnmergeCells op) {
    tableOf(op.elementId);
    for (final id in unique(op.cellIds)) {
      final c = b.rec(SlidesTables.slideTableCell, id) as SlideTableCellRec?;
      if (c == null || c.elementId != op.elementId) notFound('Cell', id);
      writeCell(
        op.elementId,
        c.rowId!,
        c.columnId!,
        {TableCellCols.rowSpan: null, TableCellCols.colSpan: null},
        together: const {TableCellCols.rowSpan, TableCellCols.colSpan},
      );
    }
    return 'Unmerge cells';
  }

  String setTableOptions(SetTableOptions op) {
    final e = tableOf(op.elementId);
    final data = mergePatch(decodeMap(e.dataJson), op.patch);
    data['v'] ??= 1;
    b.set(e, {ElementCols.dataJson: jsonEncode(data)});
    return 'Table options';
  }
}
