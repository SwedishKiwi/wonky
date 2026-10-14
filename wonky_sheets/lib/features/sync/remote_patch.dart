import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets_core/model.dart';

/// Builds the `RowChange`s that bring a [WorkbookModel] in line with rows
/// read from the replica (Sheets 02 §6 change ingestion).
///
/// Rows still queued for the writer (`pending`, oldest first) are overlaid
/// on the replica rows, so a remote patch never undoes an optimistic local
/// edit that isn't stored yet. Rows whose model columns already equal the
/// replica (the echo of the device's own writes) produce no change.
abstract final class RemotePatch {
  /// Changes for the rows [changed] (table → ids) given their current
  /// replica values [rows] (table → id → columns; missing = not visible).
  static List<RowChange> build(
    WorkbookModel model,
    Map<String, Set<UuidValue>> changed,
    Map<String, Map<String, Map<String, Object?>>> rows,
    List<RowChange> pending,
  ) {
    final targets = <String, Map<String, Map<String, Object?>?>>{};
    for (final e in changed.entries) {
      final byId = rows[e.key] ?? const {};
      final t = targets.putIfAbsent(e.key, () => {});
      for (final id in e.value) {
        t[id.uuid] = byId[id.uuid];
      }
    }
    _overlay(targets, pending);
    return _diff(model, targets);
  }

  /// Changes that turn [model] into exactly [all] (every model row of the
  /// space, as read by `SheetsReplica.loadSpace`) plus [pending].
  static List<RowChange> reconcile(
    WorkbookModel model,
    List<(String, Map<String, Object?>)> all,
    List<RowChange> pending,
  ) {
    final targets = <String, Map<String, Map<String, Object?>?>>{};
    for (final (table, columns) in all) {
      targets.putIfAbsent(table, () => {})['${columns[Cols.id]}'] = columns;
    }
    for (final (table, columns) in model.allRows()) {
      targets
          .putIfAbsent(table, () => {})
          .putIfAbsent('${columns[Cols.id]}', () => null);
    }
    _overlay(targets, pending);
    return _diff(model, targets);
  }

  static void _overlay(
    Map<String, Map<String, Map<String, Object?>?>> targets,
    List<RowChange> pending,
  ) {
    for (final c in pending) {
      final t = targets[c.table];
      if (t == null || !t.containsKey(c.rowId)) continue;
      final row = t[c.rowId];
      t[c.rowId] = switch (c.op) {
        RowOp.insert => {...c.columnsAfter, Cols.id: c.rowId},
        RowOp.update => row == null ? null : {...row, ...c.columnsAfter},
        RowOp.delete => null,
      };
    }
  }

  static List<RowChange> _diff(
    WorkbookModel model,
    Map<String, Map<String, Map<String, Object?>?>> targets,
  ) {
    final tables = targets.keys.toList()
      ..sort((a, b) => SheetsTables.rank(a).compareTo(SheetsTables.rank(b)));
    final deletes = <RowChange>[];
    final upserts = <RowChange>[];
    for (final table in tables) {
      for (final e in targets[table]!.entries) {
        final current = model.currentColumns(table, e.key);
        final next = e.value;
        if (next == null) {
          if (current != null) {
            deletes.add(
              RowChange(table: table, rowId: e.key, op: RowOp.delete),
            );
          }
        } else if (current == null || !sameColumns(current, next)) {
          upserts.add(RowChange.insert(table, e.key, next));
        }
      }
    }
    return [...deletes.reversed, ...upserts];
  }

  /// Whether every column of [next] has the same value in [current]
  /// (numbers by value, times to the millisecond).
  static bool sameColumns(
    Map<String, Object?> current,
    Map<String, Object?> next,
  ) {
    for (final e in next.entries) {
      if (_norm(current[e.key]) != _norm(e.value)) return false;
    }
    return true;
  }

  static Object? _norm(Object? v) => switch (v) {
    num() => v.toDouble(),
    DateTime() => v.toUtc().millisecondsSinceEpoch,
    Enum() => v.name,
    _ => v,
  };
}
