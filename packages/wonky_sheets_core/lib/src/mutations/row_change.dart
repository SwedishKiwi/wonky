import 'dart:convert';

import 'package:collection/collection.dart';

import '../model/schema.dart';

/// Operation on a synced row.
enum RowOp { insert, update, delete }

/// One synced-row change of a [MutationPlan] (02 §7, 13 §4.1).
///
/// - insert: [columnsAfter] holds every column of the new row (incl. `id`),
///   [columnsBefore] is empty.
/// - update: both maps hold only the touched columns (the writer names exactly
///   these columns in `columnValues`).
/// - delete: [columnsBefore] holds every column of the deleted row (so undo can
///   revive it with the same id), [columnsAfter] is empty.
final class RowChange {
  /// Creates a change.
  RowChange({
    required this.table,
    required this.rowId,
    required this.op,
    Map<String, Object?>? columnsBefore,
    Map<String, Object?>? columnsAfter,
  }) : columnsBefore = Map.unmodifiable(columnsBefore ?? const {}),
       columnsAfter = Map.unmodifiable(columnsAfter ?? const {});

  /// An insert of a full row.
  factory RowChange.insert(
    String table,
    String rowId,
    Map<String, Object?> columns,
  ) => RowChange(
    table: table,
    rowId: rowId,
    op: RowOp.insert,
    columnsAfter: {...columns, Cols.id: rowId},
  );

  /// An update naming only the touched columns.
  factory RowChange.update(
    String table,
    String rowId,
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) => RowChange(
    table: table,
    rowId: rowId,
    op: RowOp.update,
    columnsBefore: before,
    columnsAfter: after,
  );

  /// A delete with the full previous row.
  factory RowChange.delete(
    String table,
    String rowId,
    Map<String, Object?> fullRow,
  ) => RowChange(
    table: table,
    rowId: rowId,
    op: RowOp.delete,
    columnsBefore: {...fullRow, Cols.id: rowId},
  );

  /// Table name ([SheetsTables]).
  final String table;

  /// Row id (canonical UUID string).
  final String rowId;

  /// Operation.
  final RowOp op;

  /// Column values before the change (see class doc).
  final Map<String, Object?> columnsBefore;

  /// Column values after the change (see class doc).
  final Map<String, Object?> columnsAfter;

  /// Alias of [columnsBefore] (13 §4.1 naming).
  Map<String, Object?> get before => columnsBefore;

  /// Alias of [columnsAfter] (13 §4.1 naming).
  Map<String, Object?> get after => columnsAfter;

  /// Names of the touched columns (for `columnValues`).
  Set<String> get touchedColumns => switch (op) {
    RowOp.insert => columnsAfter.keys.toSet(),
    RowOp.update => columnsAfter.keys.toSet(),
    RowOp.delete => columnsBefore.keys.toSet(),
  };

  /// The inverse change (undo): insert ↔ delete, update swaps before/after.
  RowChange inverse() => switch (op) {
    RowOp.insert => RowChange(
      table: table,
      rowId: rowId,
      op: RowOp.delete,
      columnsBefore: columnsAfter,
    ),
    RowOp.delete => RowChange(
      table: table,
      rowId: rowId,
      op: RowOp.insert,
      columnsAfter: columnsBefore,
    ),
    RowOp.update => RowChange(
      table: table,
      rowId: rowId,
      op: RowOp.update,
      columnsBefore: columnsAfter,
      columnsAfter: columnsBefore,
    ),
  };

  /// JSON (DateTimes as ISO strings).
  Map<String, Object?> toJson() => {
    'table': table,
    'rowId': rowId,
    'op': op.name,
    'before': _jsonColumns(columnsBefore),
    'after': _jsonColumns(columnsAfter),
  };

  /// From [toJson] output. Values of `createdAt`/`at`/`…At` columns are parsed
  /// back to `DateTime`.
  static RowChange fromJson(Map<String, Object?> m) => RowChange(
    table: m['table']! as String,
    rowId: m['rowId']! as String,
    op: RowOp.values.byName(m['op']! as String),
    columnsBefore: _fromJsonColumns(m['before']),
    columnsAfter: _fromJsonColumns(m['after']),
  );

  static Map<String, Object?> _jsonColumns(Map<String, Object?> c) => {
    for (final e in c.entries)
      e.key: e.value is DateTime
          ? {'\$date': (e.value! as DateTime).toUtc().toIso8601String()}
          : e.value,
  };

  static Map<String, Object?> _fromJsonColumns(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        e.key
            as String: e.value is Map && (e.value as Map).containsKey('\$date')
            ? DateTime.parse((e.value as Map)['\$date'] as String)
            : e.value,
    };
  }

  static const _eq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is RowChange &&
      other.table == table &&
      other.rowId == rowId &&
      other.op == op &&
      _eq.equals(other.columnsBefore, columnsBefore) &&
      _eq.equals(other.columnsAfter, columnsAfter);

  @override
  int get hashCode => Object.hash(table, rowId, op, _eq.hash(columnsAfter));

  @override
  String toString() =>
      'RowChange(${op.name} $table $rowId ${jsonEncode(toJson()['after'])})';
}

/// Kinds listed in `ChangeLog.summaryJson.kinds`.
abstract final class ChangeKinds {
  static const values = 'values';
  static const format = 'format';
  static const structure = 'structure';
  static const sheets = 'sheets';
  static const rules = 'rules';
  static const objects = 'objects';
  static const names = 'names';
  static const protection = 'protection';
  static const filters = 'filters';
  static const notes = 'notes';
  static const settings = 'settings';
  static const scripts = 'scripts';
  static const import = 'import';
  static const restore = 'restore';
}

/// `ChangeLog.summaryJson` (02 §3.7, 10 A-10-1).
final class ChangeSummary {
  /// Creates a summary.
  ChangeSummary({
    Set<String>? sheets,
    List<Map<String, Object?>>? ranges,
    Set<String>? kinds,
    Map<String, List<String>>? deleted,
    Map<String, List<String>>? revived,
    this.structureOverflow = false,
  }) : sheets = sheets ?? {},
       ranges = ranges ?? [],
       kinds = kinds ?? {},
       deleted = deleted ?? {},
       revived = revived ?? {};

  /// Max ids per deleted/revived list before [structureOverflow].
  static const maxIds = 1000;

  /// Max ranges kept (bigger edits keep the bounding ranges).
  static const maxRanges = 1000;

  final Set<String> sheets;

  /// GridRange JSON maps.
  final List<Map<String, Object?>> ranges;
  final Set<String> kinds;

  /// `{rows: [...], cols: [...], sheets: [...]}`.
  final Map<String, List<String>> deleted;
  final Map<String, List<String>> revived;
  bool structureOverflow;

  /// Records a deleted entity of [kind] (`rows`, `cols`, `sheets`).
  void addDeleted(String kind, String id) => _add(deleted, kind, id);

  /// Records a revived entity.
  void addRevived(String kind, String id) => _add(revived, kind, id);

  void _add(Map<String, List<String>> m, String kind, String id) {
    final l = m.putIfAbsent(kind, () => []);
    if (l.length >= maxIds) {
      structureOverflow = true;
      return;
    }
    l.add(id);
  }

  /// Adds a range (GridRange JSON map).
  void addRange(Map<String, Object?> range) {
    if (ranges.length >= maxRanges) return;
    if (ranges.any((r) => const DeepCollectionEquality().equals(r, range))) {
      return;
    }
    ranges.add(range);
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
    'sheets': sheets.toList()..sort(),
    'ranges': ranges,
    'kinds': kinds.toList()..sort(),
    if (deleted.isNotEmpty) 'deleted': deleted,
    if (revived.isNotEmpty) 'revived': revived,
    if (structureOverflow) 'structureOverflow': true,
  };

  /// `summaryJson` string.
  String encode() => jsonEncode(toJson());

  /// Parses `summaryJson`.
  static ChangeSummary parse(String json) {
    final m = jsonDecode(json) as Map<String, Object?>;
    List<String> strs(Object? v) =>
        v is List ? v.map((e) => e.toString()).toList() : [];
    Map<String, List<String>> lists(Object? v) => v is Map
        ? {for (final e in v.entries) e.key.toString(): strs(e.value)}
        : {};
    return ChangeSummary(
      sheets: strs(m['sheets']).toSet(),
      ranges: m['ranges'] is List
          ? [
              for (final r in m['ranges']! as List)
                (r as Map).cast<String, Object?>(),
            ]
          : [],
      kinds: strs(m['kinds']).toSet(),
      deleted: lists(m['deleted']),
      revived: lists(m['revived']),
      structureOverflow: m['structureOverflow'] == true,
    );
  }
}

/// One cell's before/after content in `ChangeLog.detailJson` (≤ 200 cells).
typedef CellDetail = ({
  String sheetId,
  String rowId,
  String colId,
  String? before,
  String? after,
});

/// A planned transaction: ordered row changes + undo label + change log data.
final class MutationPlan {
  /// Creates a plan.
  MutationPlan({
    required this.label,
    required this.summary,
    required List<RowChange> changes,
    this.detail,
    this.warnings = const [],
    this.result = const {},
  }) : changes = List.unmodifiable(changes);

  /// Max cells listed in [detail].
  static const maxDetailCells = 200;

  /// Max row changes per writer transaction (02 §7).
  static const chunkSize = 5000;

  /// Undo label ("Paste", "Insert 3 rows").
  final String label;

  /// `ChangeLog.summaryJson`.
  final ChangeSummary summary;

  /// Ordered row changes.
  final List<RowChange> changes;

  /// `ChangeLog.detailJson` map (`{"cells": [...]}`) or null when > 200 cells.
  final Map<String, Object?>? detail;

  /// Non-fatal warnings for the caller (MCP `warnings`, toasts).
  final List<String> warnings;

  /// Operation results (e.g. `{"sheetId": …}`, `{"ruleId": …}`, `{"replaced": 12}`).
  final Map<String, Object?> result;

  /// Whether the plan changes nothing.
  bool get isEmpty => changes.isEmpty;

  /// The changes split into writer chunks of ≤ [chunkSize] (one undo step).
  List<List<RowChange>> get chunks => [
    for (var i = 0; i < changes.length; i += chunkSize)
      changes.sublist(
        i,
        i + chunkSize > changes.length ? changes.length : i + chunkSize,
      ),
  ];

  /// `ChangeLog.detailJson` string or null.
  String? get detailJson => detail == null ? null : jsonEncode(detail);

  /// The inverse plan (undo), with changes in reverse order. The writer applies
  /// it with the per-column skip rule ([UndoInverter]).
  MutationPlan inverse({String? label}) => MutationPlan(
    label: label ?? this.label,
    summary: summary,
    changes: [for (final c in changes.reversed) c.inverse()],
  );

  /// Columns of the `ChangeLog` row written in the same transaction as the
  /// plan (02 §3.7). [chunk]/[chunks] annotate chunked bulk steps.
  Map<String, Object?> changeLogColumns({
    required String spreadsheetId,
    required String userId,
    required ActorKind actorKind,
    required String sessionId,
    required DateTime at,
  }) => {
    Cols.spreadsheetId: spreadsheetId,
    'userId': userId,
    'actorKind': actorKind.name,
    'sessionId': sessionId,
    'label': label,
    'summaryJson': summary.encode(),
    'detailJson': detailJson,
    'at': at,
  };

  /// Number of distinct cells touched.
  int get cellCount =>
      changes.where((c) => c.table == SheetsTables.cell).length;

  @override
  String toString() => 'MutationPlan($label, ${changes.length} changes)';
}

/// Reads current column values of synced rows (implemented by the model and by
/// writers over their database).
abstract interface class CurrentRowReader {
  /// Current columns of the row, or null when it does not exist.
  Map<String, Object?>? currentColumns(String table, String rowId);
}

/// Builds the undo of a plan against the current state with the suite skip
/// rule (08 §3.3, 02 §7): a column whose current value differs from what the
/// plan wrote (someone else changed it since) is skipped.
abstract final class UndoInverter {
  /// The changes that undo [plan] given [current]. [skipped] receives
  /// `(table, rowId, column)` triples that were skipped.
  static List<RowChange> invert(
    MutationPlan plan,
    CurrentRowReader current, {
    void Function(String table, String rowId, String column)? skipped,
  }) => invertChanges(plan.changes, current, skipped: skipped);

  /// [invert] for a raw change list.
  static List<RowChange> invertChanges(
    List<RowChange> changes,
    CurrentRowReader current, {
    void Function(String table, String rowId, String column)? skipped,
  }) {
    final out = <RowChange>[];
    for (final c in changes.reversed) {
      final now = current.currentColumns(c.table, c.rowId);
      switch (c.op) {
        case RowOp.insert:
          // Undo an insert = delete, unless the row is gone already.
          if (now == null) continue;
          out.add(RowChange.delete(c.table, c.rowId, now));
        case RowOp.delete:
          if (now != null) {
            // Revived by someone else: restore the columns we can.
            final before = <String, Object?>{};
            final after = <String, Object?>{};
            c.columnsBefore.forEach((k, v) {
              if (k == Cols.id) return;
              if (!_eq(now[k], v)) {
                before[k] = now[k];
                after[k] = v;
              }
            });
            if (after.isNotEmpty) {
              out.add(RowChange.update(c.table, c.rowId, before, after));
            }
          } else {
            out.add(RowChange.insert(c.table, c.rowId, c.columnsBefore));
          }
        case RowOp.update:
          if (now == null) {
            for (final k in c.columnsAfter.keys) {
              skipped?.call(c.table, c.rowId, k);
            }
            continue;
          }
          final before = <String, Object?>{};
          final after = <String, Object?>{};
          c.columnsAfter.forEach((k, v) {
            if (_eq(now[k], v)) {
              before[k] = v;
              after[k] = c.columnsBefore[k];
            } else {
              skipped?.call(c.table, c.rowId, k);
            }
          });
          if (after.isNotEmpty) {
            out.add(RowChange.update(c.table, c.rowId, before, after));
          }
      }
    }
    return out;
  }

  static bool _eq(Object? a, Object? b) {
    if (a is num && b is num) return a.toDouble() == b.toDouble();
    if (a is DateTime && b is DateTime) return a.isAtSameMomentAs(b);
    return a == b;
  }
}
