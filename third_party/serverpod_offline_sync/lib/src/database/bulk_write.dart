part of 'database.dart';

/// One row of an [OfflineSyncDatabase.bulkWrite] (patch OS-7).
final class BulkRowWrite<T extends TableRow> {
  /// Inserts [row] (its id must be set). A tombstoned id is revived with
  /// [row]'s values; an id that is already visible is updated with [row]'s
  /// values of [columnsIfVisible] (every synced column when null).
  BulkRowWrite.insert(T this.row, {List<Column>? columnsIfVisible})
    : id = row.id as UuidValue,
      columns = columnsIfVisible,
      values = null;

  /// Updates exactly the columns of [values] of the row [id]. Skipped
  /// (reported in [BulkWriteResult.skipped]) when the row is not visible.
  BulkRowWrite.updateColumns(this.id, List<ColumnValue> this.values)
    : row = null,
      columns = [for (final v in values) v.column];

  /// The row id.
  final UuidValue id;

  /// The inserted row (null for updates).
  final T? row;

  /// The written columns: an update's columns, or an insert's columns if
  /// the id is visible (null: all).
  final List<Column>? columns;

  /// The values of an update (null for inserts).
  final List<ColumnValue>? values;

  /// Whether this is an insert.
  bool get isInsert => row != null;
}

/// A domain row of a set-based update: its id and [values] by field name (the shape
/// `toJsonForDatabase` reads). Only its table, id and values are read; it is
/// never deserialized.
final class _ValuesRow implements TableRow<UuidValue?> {
  _ValuesRow(this.table, this.id, List<ColumnValue> values)
    : _json = {
        table.id.fieldName: id,
        for (final v in values) v.column.fieldName: v.value,
      };

  @override
  final Table<UuidValue?> table;

  @override
  final UuidValue id;

  final Map<String, dynamic> _json;

  @override
  dynamic toJson() => _json;
}

/// What an [OfflineSyncDatabase.bulkWrite] did with each row.
final class BulkWriteResult {
  /// Ids inserted as new rows.
  final Set<UuidValue> inserted = {};

  /// Tombstoned ids revived by an insert.
  final Set<UuidValue> revived = {};

  /// Visible ids updated (updates, and inserts of visible ids).
  final Set<UuidValue> updated = {};

  /// Updates of ids that are not visible (deleted or never inserted).
  final Set<UuidValue> skipped = {};
}

extension _OfflineSyncBulkWrite on OfflineSyncDatabase {
  Future<BulkWriteResult> _bulkWrite<T extends TableRow>(
    List<BulkRowWrite<T>> writes,
    Transaction? transaction,
  ) async {
    final result = BulkWriteResult();
    if (writes.isEmpty) return result;
    await _ensureInitialized();
    final table =
        serializationManager.getTableForType(T) ??
        (throw ArgumentError('bulkWrite needs a table row type, not $T'));
    if (!_recorder.isCrdtTracked<T>(table)) {
      throw ArgumentError.value(
        table.tableName,
        'writes',
        'bulkWrite needs a CRDT-tracked table',
      );
    }
    final ids = <UuidValue>{};
    for (final w in writes) {
      if (w.row case final T row when row.table.tableName != table.tableName) {
        throw ArgumentError.value(
          row.table.tableName,
          'writes',
          'bulkWrite writes one table (${table.tableName})',
        );
      }
      if (!ids.add(w.id)) {
        throw ArgumentError.value(w.id.uuid, 'writes', 'Duplicate row id');
      }
    }

    return _runTrackedWrite(transaction, (tx) async {
      final crdtRows = {
        for (final r in await _recorder.crdtRowsWithTombstones(
          table.tableName,
          ids,
          tx,
        ))
          r.uuidRowId: r,
      };
      final fresh = <T>[];
      final revive = <T>[];
      final reviveCrdt = <CrdtDataRow>[];
      final updates = <String, _UpdateGroup<T>>{};
      void addUpdate(BulkRowWrite<T> w, Iterable<Column> columns, CrdtDataRow crdt) {
        final cols = columns.crdtSyncableColumns.toList();
        if (cols.isEmpty) return;
        final key = [for (final c in cols) c.columnName].join('\u0000');
        (updates[key] ??= _UpdateGroup(cols)).add(w, crdt);
      }

      for (final w in writes) {
        final crdt = crdtRows[w.id];
        if (w.isInsert) {
          if (crdt == null) {
            fresh.add(w.row!);
            result.inserted.add(w.id);
          } else if (crdt.isHidden) {
            revive.add(w.row!);
            reviveCrdt.add(crdt);
            result.revived.add(w.id);
          } else {
            addUpdate(w, w.columns ?? table.managedColumns, crdt);
            result.updated.add(w.id);
          }
        } else if (crdt == null || crdt.isHidden) {
          result.skipped.add(w.id);
        } else {
          addUpdate(w, w.columns!, crdt);
          result.updated.add(w.id);
        }
      }

      if (fresh.isNotEmpty &&
          !await _recorder.bulkInsertNew(
            _prepareRowsForInsert(fresh, tx).rows,
            tx,
          )) {
        // The ordinary insert plans the projection of the new rows.
        await insert<T>(fresh, transaction: tx, noReturn: true);
      }
      if (revive.isNotEmpty) await _bulkRevive(revive, reviveCrdt, tx);
      for (final group in updates.values) {
        await _bulkUpdate(table, group, tx);
      }
      return result;
    });
  }

  /// Revives tombstoned rows with their new values. When the projection
  /// provably stays unchanged this is one batched domain update and a few
  /// batched metadata writes; otherwise the ordinary insert (which plans
  /// the projection of each revived row) runs.
  Future<void> _bulkRevive<T extends TableRow>(
    List<T> rows,
    List<CrdtDataRow> crdtRows,
    Transaction transaction,
  ) async {
    final prepared = _prepareRowsForInsert(rows, transaction);
    final eligible =
        crdtRows.every((r) => r.deleted?.isDeleted ?? false) &&
        await _recorder.canReviveWithoutProjection(prepared.rows, transaction);
    if (!eligible) {
      await insert<T>(rows, transaction: transaction, noReturn: true);
      return;
    }
    _recorder.validateAuthoredRows(prepared.rows, null);
    await _delegate.update<T>(
      prepared.rows,
      transaction: transaction,
      noReturn: true,
    );
    await _recorder.afterBulkReinsert(crdtRows, transaction);
  }

  /// Updates exactly the group's columns of its visible rows. Columns that
  /// cannot change a projection are written in one batched statement plus
  /// one batched field-metadata upsert; others run the ordinary per-row
  /// paths.
  Future<void> _bulkUpdate<T extends TableRow>(
    Table table,
    _UpdateGroup<T> group,
    Transaction transaction,
  ) async {
    final columns = group.columns;
    if (_recorder.updateNeedsProjection(table.tableName, {
      for (final c in columns) c.columnName,
    })) {
      for (final w in group.writes) {
        if (w.row case final T row) {
          await update<T>(
            [row],
            columns: columns,
            transaction: transaction,
            noReturn: true,
          );
        } else {
          await updateWhere<T>(
            columnValues: [
              for (final v in w.values!)
                if (columns.any((c) => c.columnName == v.column.columnName)) v,
            ],
            where: table.id.equals(w.id),
            transaction: transaction,
            noReturn: true,
          );
        }
      }
      return;
    }
    final rows = <TableRow<UuidValue?>>[
      for (final w in group.writes)
        if (w.row case final T row)
          row as TableRow<UuidValue?>
        else
          _ValuesRow(table as Table<UuidValue?>, w.id, w.values!),
    ];
    await _delegate.update<TableRow<UuidValue?>>(
      rows,
      columns: columns,
      transaction: transaction,
      noReturn: true,
    );
    await _recorder.afterBulkUpdate(rows, group.crdt, columns, transaction);
  }
}

/// Updates of one column set in a [OfflineSyncDatabase.bulkWrite].
final class _UpdateGroup<T extends TableRow> {
  _UpdateGroup(this.columns);

  final List<Column> columns;
  final List<BulkRowWrite<T>> writes = [];
  final List<CrdtDataRow> crdt = [];

  void add(BulkRowWrite<T> write, CrdtDataRow row) {
    writes.add(write);
    crdt.add(row);
  }
}
