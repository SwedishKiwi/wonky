import 'dart:typed_data';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';

/// The rows of one space that changed after a journal position.
class JournalChanges {
  const JournalChanges(this.rows, this.head);

  /// Changed row ids by table name.
  final Map<String, Set<UuidValue>> rows;

  /// The journal position after these changes.
  final int head;

  bool get isEmpty => rows.isEmpty;

  int get count => rows.values.fold(0, (a, s) => a + s.length);
}

/// "Rows changed in a space since …" for the incremental in-memory models
/// (suite 12 §4 **U11**, Sheets 02 §6, Slides 02 §11).
///
/// The engine stores field HLCs, but merged changes keep the HLC of their
/// author, so a late-arriving offline edit has an *old* HLC: "changed since
/// HLC h" is not a usable cursor. Instead, SQLite triggers on every journaled
/// table and on `crdt_data_rows` (visibility changes: tombstones, revivals
/// and foreign-key projection) append `(space, table, row id)` to the
/// local-only journal table whose integer id is a local, monotonic change
/// sequence. Only spaces listed in the journal-space table (the files open
/// on this device) are journaled, so bulk downloads of other spaces cost
/// nothing.
///
/// An open file keeps a cursor and, after each merge, reads the changed rows
/// of its space after the cursor ([changesSince]); the app then re-reads
/// those rows (visible → upsert, gone → delete) and patches its model
/// (`RowPatch`).
///
/// The bookkeeping tables are the `database: client` tables
/// `sheets_row_journal` and `sheets_journal_space` (`SheetsRowJournal`,
/// `SheetsJournalSpace`), present in every replica of the generated client;
/// each app's replica is its own file, so apps share the table names.
class ChangeJournal {
  ChangeJournal(
    this.session, {
    required List<String> tables,
    this.triggerPrefix = 'sheets_journal',
  }) : tables = List.unmodifiable(tables);

  final DatabaseSession session;

  /// Tables whose writes are journaled (the model tables).
  final List<String> tables;

  /// Prefix of the trigger names (kept stable: renaming would leave the old
  /// triggers of existing replicas in place).
  final String triggerPrefix;

  /// The journal table.
  static const journalTable = 'sheets_row_journal';

  /// The journaled spaces.
  static const spaceTable = 'sheets_journal_space';

  Database get _db => session.db;

  static const _guard = 'IN (SELECT "spaceKey" FROM "$spaceTable")';

  /// Creates the triggers (idempotent) and forgets what a previous run
  /// tracked (no session is open yet).
  Future<void> install() async {
    await _db.unsafeExecute('DELETE FROM "$spaceTable"');
    await _db.unsafeExecute(
      'DELETE FROM "$journalTable" '
      'WHERE "id" < (SELECT max("id") FROM "$journalTable")',
    );
    for (final t in tables) {
      for (final (event, ref) in const [
        ('INSERT', 'NEW'),
        ('UPDATE', 'NEW'),
        ('DELETE', 'OLD'),
      ]) {
        await _db.unsafeExecute(
          'CREATE TRIGGER IF NOT EXISTS "${triggerPrefix}_${t}_${event.toLowerCase()}" '
          'AFTER $event ON "$t" WHEN $ref."spaceId" $_guard BEGIN '
          'INSERT INTO "$journalTable" ("spaceKey", "syncTable", "rowId") '
          "VALUES ($ref.\"spaceId\", '$t', $ref.\"id\"); END",
        );
      }
    }
    final names = tables.map((t) => "'$t'").join(', ');
    for (final event in const ['INSERT', 'UPDATE']) {
      final name = '${triggerPrefix}_crdt_rows_${event.toLowerCase()}';
      await _db.unsafeExecute('DROP TRIGGER IF EXISTS "$name"');
      await _db.unsafeExecute(
        'CREATE TRIGGER "$name" '
        'AFTER $event ON "crdt_data_rows" WHEN NEW."spaceId" $_guard BEGIN '
        'INSERT INTO "$journalTable" ("spaceKey", "syncTable", "rowId") '
        'SELECT NEW."spaceId", t."name", NEW."uuidRowId" '
        'FROM "crdt_schema_tables" t WHERE t."id" = NEW."tblId" '
        'AND t."name" IN ($names); END',
      );
    }
  }

  final Map<int, int> _refs = {};

  /// Starts journaling the space with local id [spaceKey] (reference
  /// counted: one [track] per open session).
  Future<void> track(int spaceKey) async {
    _refs[spaceKey] = (_refs[spaceKey] ?? 0) + 1;
    await _db.unsafeExecute(
      'INSERT OR IGNORE INTO "$spaceTable" ("spaceKey") '
      'VALUES ($spaceKey)',
    );
  }

  /// Ends one [track] of [spaceKey]; the last one stops journaling it and
  /// drops its entries.
  Future<void> untrack(int spaceKey) async {
    final n = (_refs[spaceKey] ?? 1) - 1;
    if (n > 0) {
      _refs[spaceKey] = n;
      return;
    }
    _refs.remove(spaceKey);
    await _db.unsafeExecute(
      'DELETE FROM "$spaceTable" WHERE "spaceKey" = $spaceKey',
    );
    await _db.unsafeExecute(
      'DELETE FROM "$journalTable" WHERE "spaceKey" = $spaceKey '
      'AND "id" < (SELECT max("id") FROM "$journalTable")',
    );
  }

  /// The current journal position (0 when empty).
  Future<int> head() async {
    final r = await _db.unsafeQuery(
      'SELECT coalesce(max("id"), 0) FROM "$journalTable"',
    );
    return r.first[0]! as int;
  }

  /// Rows of [spaceKey] changed after position [after], up to [limit]
  /// entries (callers loop while [JournalChanges.head] advances).
  Future<JournalChanges> changesSince(
    int spaceKey,
    int after, {
    int limit = 50000,
  }) async {
    final r = await _db.unsafeQuery(
      'SELECT "id", "syncTable", "rowId" FROM "$journalTable" '
      'WHERE "spaceKey" = $spaceKey AND "id" > $after '
      'ORDER BY "id" LIMIT $limit',
    );
    final rows = <String, Set<UuidValue>>{};
    var head = after;
    for (final row in r) {
      head = row[0]! as int;
      final bytes = row[2];
      if (bytes is! List<int>) continue;
      rows
          .putIfAbsent(row[1]! as String, () => <UuidValue>{})
          .add(UuidValue.fromByteList(Uint8List.fromList(bytes)));
    }
    return JournalChanges(rows, head);
  }

  /// Deletes entries at or before [upTo] (the smallest cursor of the open
  /// files). The newest entry is always kept so positions stay monotonic
  /// (SQLite reuses `max(id) + 1`).
  Future<void> prune(int upTo) => _db.unsafeExecute(
    'DELETE FROM "$journalTable" WHERE "id" <= $upTo '
    'AND "id" < (SELECT max("id") FROM "$journalTable")',
  );
}
