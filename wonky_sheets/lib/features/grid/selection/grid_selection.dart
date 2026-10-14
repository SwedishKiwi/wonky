import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

/// A cell by ids (03 §6.1): survives remote inserts/deletes/moves.
@immutable
class CellRef {
  const CellRef(this.rowId, this.colId);

  final String rowId;
  final String colId;

  @override
  bool operator ==(Object other) =>
      other is CellRef && other.rowId == rowId && other.colId == colId;

  @override
  int get hashCode => Object.hash(rowId, colId);

  Map<String, Object?> toJson() => {'r': rowId, 'c': colId};

  static CellRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final r = json['r'];
    final c = json['c'];
    return r is String && c is String ? CellRef(r, c) : null;
  }

  @override
  String toString() => 'CellRef($rowId, $colId)';
}

/// What a selection range covers.
enum SelectionKind { cells, rows, columns, all }

/// One range of a selection, by ids (null bounds are open: whole rows have
/// no column ids, whole columns no row ids, `all` none).
@immutable
class SelectionRange {
  const SelectionRange({
    required this.kind,
    this.r1,
    this.r2,
    this.c1,
    this.c2,
    this.display = false,
  });

  final SelectionKind kind;
  final String? r1;
  final String? r2;
  final String? c1;
  final String? c2;

  /// Rows [r1]..[r2] are a range in the **display** order of a sorted
  /// filter view (07 §4.4: selected on screen); it resolves to the model
  /// rows shown between them (several ranges). Without a display order it
  /// is a plain range.
  final bool display;

  Map<String, Object?> toJson() => {
    'k': kind.name,
    'r1': ?r1,
    'r2': ?r2,
    'c1': ?c1,
    'c2': ?c2,
    if (display) 'd': true,
  };

  static SelectionRange? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = SelectionKind.values
        .where((k) => k.name == json['k'])
        .firstOrNull;
    if (kind == null) return null;
    return SelectionRange(
      kind: kind,
      r1: json['r1'] as String?,
      r2: json['r2'] as String?,
      c1: json['c1'] as String?,
      c2: json['c2'] as String?,
      display: json['d'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SelectionRange &&
      other.kind == kind &&
      other.r1 == r1 &&
      other.r2 == r2 &&
      other.c1 == c1 &&
      other.c2 == c2 &&
      other.display == display;

  @override
  int get hashCode => Object.hash(kind, r1, r2, c1, c2, display);
}

/// The selection of one sheet (03 §6.1): ranges by ids, the active range,
/// the active cell (typing target) and the anchor (fixed corner for
/// Shift-extend). Immutable; view state, never undoable.
@immutable
class GridSelection {
  const GridSelection({
    required this.sheetId,
    required this.ranges,
    required this.activeRangeIndex,
    required this.active,
    required this.anchor,
  });

  final String sheetId;
  final List<SelectionRange> ranges;
  final int activeRangeIndex;
  final CellRef active;
  final CellRef anchor;

  Map<String, Object?> toJson() => {
    'sheet': sheetId,
    'ranges': [for (final r in ranges) r.toJson()],
    'i': activeRangeIndex,
    'active': active.toJson(),
    'anchor': anchor.toJson(),
  };

  static GridSelection? fromJson(Object? json) {
    if (json is! Map) return null;
    final sheet = json['sheet'];
    final active = CellRef.fromJson(json['active']);
    final anchor = CellRef.fromJson(json['anchor']);
    final raw = json['ranges'];
    if (sheet is! String || active == null || anchor == null || raw is! List) {
      return null;
    }
    final ranges = [for (final r in raw) ?SelectionRange.fromJson(r)];
    if (ranges.isEmpty) return null;
    final i = (json['i'] as num?)?.toInt() ?? 0;
    return GridSelection(
      sheetId: sheet,
      ranges: ranges,
      activeRangeIndex: i.clamp(0, ranges.length - 1),
      active: active,
      anchor: anchor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GridSelection &&
      other.sheetId == sheetId &&
      listEquals(other.ranges, ranges) &&
      other.activeRangeIndex == activeRangeIndex &&
      other.active == active &&
      other.anchor == anchor;

  @override
  int get hashCode => Object.hash(
    sheetId,
    Object.hashAll(ranges),
    activeRangeIndex,
    active,
    anchor,
  );
}

/// A selection range resolved to indices.
@immutable
class ResolvedSelectionRange {
  const ResolvedSelectionRange(
    this.kind,
    this.rect, {
    this.displayRect,
    this.group = -1,
  });

  final SelectionKind kind;

  /// Model rows/columns.
  final GridRect rect;

  /// For a part of a display range (07 §4.4): the whole range in display
  /// rows (paint it as one rectangle); null for model ranges.
  final GridRect? displayRect;

  /// Index of the [GridSelection.ranges] entry this range comes from.
  final int group;

  bool get wholeRows => kind == SelectionKind.rows || kind == SelectionKind.all;
  bool get wholeColumns =>
      kind == SelectionKind.columns || kind == SelectionKind.all;

  @override
  bool operator ==(Object other) =>
      other is ResolvedSelectionRange &&
      other.kind == kind &&
      other.rect == rect &&
      other.displayRect == displayRect;

  @override
  int get hashCode => Object.hash(kind, rect, displayRect);
}

/// A [GridSelection] in index space (03 §6.1 `ResolvedSelection`).
@immutable
class ResolvedSelection {
  const ResolvedSelection({
    required this.sheetId,
    required this.ranges,
    required this.activeRangeIndex,
    required this.activeRow,
    required this.activeCol,
    required this.anchorRow,
    required this.anchorCol,
  });

  final String sheetId;
  final List<ResolvedSelectionRange> ranges;
  final int activeRangeIndex;
  final int activeRow;
  final int activeCol;
  final int anchorRow;
  final int anchorCol;

  ResolvedSelectionRange get activeRange => ranges[activeRangeIndex];

  /// Whether the selection is a single range.
  bool get isSingleRange => ranges.length == 1;

  /// Whether exactly one cell (or one merge) is selected.
  bool get isSingleCell =>
      ranges.length == 1 && ranges.first.rect.cellCount == 1;

  /// Whether every range comes from one selected range: one rectangle on
  /// screen, possibly several model ranges in a sorted filter view (07 §4.4).
  bool get isSingleGroup =>
      ranges.isNotEmpty && ranges.every((r) => r.group == ranges.first.group);

  /// The ranges of the active range's group (one, or the model parts of a
  /// display range in display order).
  List<ResolvedSelectionRange> get activeGroup {
    final g = activeRange.group;
    if (g < 0) return [activeRange];
    return [
      for (final r in ranges)
        if (r.group == g) r,
    ];
  }

  /// The ranges as core [ResolvedRange]s.
  List<ResolvedRange> toResolvedRanges() => [
    for (final r in ranges)
      ResolvedRange(
        sheetId,
        r.rect,
        wholeRows: r.wholeRows,
        wholeColumns: r.wholeColumns,
      ),
  ];

  /// Whether (row, col) lies in any range.
  bool contains(int row, int col) =>
      ranges.any((r) => r.rect.contains(row, col));

  /// Whether any range covers whole rows including [row].
  bool rowFullySelected(int row) => ranges.any(
    (r) => r.wholeRows && row >= r.rect.top && row <= r.rect.bottom,
  );

  bool columnFullySelected(int col) => ranges.any(
    (r) => r.wholeColumns && col >= r.rect.left && col <= r.rect.right,
  );

  bool rowIntersects(int row) =>
      ranges.any((r) => row >= r.rect.top && row <= r.rect.bottom);

  bool columnIntersects(int col) =>
      ranges.any((r) => col >= r.rect.left && col <= r.rect.right);
}
