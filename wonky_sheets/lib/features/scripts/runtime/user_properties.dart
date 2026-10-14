import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';
import 'package:wonky_sync_models/wonky_sync_models.dart'
    show ScriptUserProperty;

import '../../model/workbook_session.dart';
import '../../sync/sheets_replica.dart';
import '../../sync/synced_workbook_session.dart';

/// `PropertiesService.userProperties` on the client (09 §6.9, A-09-4).
///
/// Decision: user properties are `ScriptUserProperty` rows in the user's
/// **personal space** (space UUID = auth user id) of the local replica. The
/// sync engine syncs that space for every signed-in client, so the values
/// follow the user to other devices and to server runs
/// (`ServerUserProperties`), and work offline. Scripts read synchronously:
/// the rows of the spreadsheet are loaded once ([load]) and kept in memory;
/// writes update the memory at once and are written to the replica in the
/// background (one transaction per change, then a sync is requested).
class ReplicaUserProperties implements PropertyStore {
  ReplicaUserProperties._(this._replica, this._kick, this.spreadsheetId);

  /// The store of [session]'s user for its spreadsheet; a memory store for
  /// sessions without a replica (tests, previews).
  static Future<PropertyStore> forSession(WorkbookSession session) async {
    if (session is! SyncedWorkbookSession) return MemoryPropertyStore();
    final store = ReplicaUserProperties._(
      session.host.replica,
      session.host.kick,
      UuidValue.fromString(session.spreadsheetId),
    );
    await store.load();
    return store;
  }

  final SheetsReplica _replica;
  final VoidCallback _kick;

  /// The spreadsheet (space uuid).
  final UuidValue spreadsheetId;

  final Map<String, ScriptUserProperty> _rows = {};
  final Map<String, String> _values = {};
  Future<void> _writes = Future.value();

  /// Reads the rows of [spreadsheetId] from the replica.
  Future<void> load() async {
    final rows = await ScriptUserProperty.db.find(
      _replica.session,
      where: (t) => t.spreadsheetId.equals(spreadsheetId),
      orderBy: (t) => t.createdAt,
    );
    _rows.clear();
    _values.clear();
    for (final r in rows) {
      _rows[r.key] = r;
      _values[r.key] = r.value;
    }
  }

  /// Completes when the queued writes are stored.
  Future<void> flush() => _writes;

  @override
  Map<String, String> all() => Map.of(_values);

  @override
  void set(String key, String value) {
    if (_values[key] == value) return;
    _values[key] = value;
    _enqueue(key);
  }

  @override
  void delete(String key) {
    if (_values.remove(key) != null) _enqueue(key);
  }

  void _enqueue(String key) {
    _writes = _writes.then((_) => _write(key)).catchError((Object e) {
      debugPrint('Storing user property "$key" failed: $e');
    });
  }

  Future<void> _write(String key) async {
    final user = _replica.userUuid;
    final s = _replica.session;
    final value = _values[key];
    await _replica.db.transactionForUser(user, (tx) async {
      final row = _rows[key];
      if (value == null) {
        if (row != null) {
          await ScriptUserProperty.db.deleteRow(s, row, transaction: tx);
        }
        _rows.remove(key);
      } else if (row == null) {
        _rows[key] = await ScriptUserProperty.db.insertRow(
          s,
          ScriptUserProperty(
            spreadsheetId: spreadsheetId,
            key: key,
            value: value,
            createdAt: clock.now().toUtc(),
          ),
          transaction: tx,
        );
      } else {
        _rows[key] = await ScriptUserProperty.db.updateRow(
          s,
          row.copyWith(value: value),
          columns: (t) => [t.value],
          transaction: tx,
        );
      }
    }, spaceId: user);
    _kick();
  }
}
