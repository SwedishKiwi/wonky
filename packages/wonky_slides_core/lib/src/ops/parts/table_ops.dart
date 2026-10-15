part of '../operations.dart';

// Tables (02 §3.6, §12.1 "Tables", 03 §6.7).

/// Inserts [count] rows/columns at [index] (0-based, in the dimension).
final class InsertTableAxes extends SlidesOperation {
  const InsertTableAxes(
    this.elementId,
    this.dimension,
    this.index, {
    this.count = 1,
  });

  final String elementId;
  final TableAxisDimension dimension;
  final int index;
  final int count;

  @override
  String get name => 'InsertTableAxes';
}

/// Deletes rows/columns (and their cells, listed for undo).
final class DeleteTableAxes extends SlidesOperation {
  const DeleteTableAxes(this.elementId, this.axisIds);

  final String elementId;
  final List<String> axisIds;

  @override
  String get name => 'DeleteTableAxes';
}

/// Moves rows/columns to [toIndex].
final class MoveTableAxes extends SlidesOperation {
  const MoveTableAxes(this.elementId, this.axisIds, this.toIndex);

  final String elementId;
  final List<String> axisIds;
  final int toIndex;

  @override
  String get name => 'MoveTableAxes';
}

/// Sets axis sizes (null = even split).
final class ResizeTableAxes extends SlidesOperation {
  const ResizeTableAxes(this.elementId, this.sizes);

  final String elementId;

  /// Axis id → size in su (null = even split).
  final Map<String, double?> sizes;

  @override
  String get name => 'ResizeTableAxes';
}

/// One cell write of [SetCells]: the `SlideTableCell` columns to set
/// (`text`, `fill`, `border*`, `vAlign`, `padding`).
final class CellWrite {
  const CellWrite(this.rowId, this.columnId, this.columns);

  final String rowId;
  final String columnId;
  final Map<String, Object?> columns;
}

/// Writes cells (deterministic ids `SlidesIds.tableCellId`; created on
/// write, 02 §3.6).
final class SetCells extends SlidesOperation {
  const SetCells(this.elementId, this.writes);

  final String elementId;
  final List<CellWrite> writes;

  @override
  String get name => 'SetCells';
}

/// Merges a cell range (writes `rowSpan`/`colSpan` together on the origin).
final class MergeCells extends SlidesOperation {
  const MergeCells(
    this.elementId, {
    required this.rowId,
    required this.columnId,
    required this.rowSpan,
    required this.colSpan,
  });

  final String elementId;
  final String rowId;
  final String columnId;
  final int rowSpan;
  final int colSpan;

  @override
  String get name => 'MergeCells';
}

/// Unmerges merge origins.
final class UnmergeCells extends SlidesOperation {
  const UnmergeCells(this.elementId, this.cellIds);

  final String elementId;
  final List<String> cellIds;

  @override
  String get name => 'UnmergeCells';
}

/// Table options (`dataJson.options`/`style`, 02 §6.5) as a merge patch.
final class SetTableOptions extends SlidesOperation {
  const SetTableOptions(this.elementId, this.patch);

  final String elementId;
  final Map<String, Object?> patch;

  @override
  String get name => 'SetTableOptions';
}
