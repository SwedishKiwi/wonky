import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;

import '../controller/sync_session_host.dart';
import '../replica/sync_replica.dart';
import '../writer/sync_writer.dart';

/// Brings an open file's in-memory model up to date with its space in the
/// replica after merges (suite 12 §4 U11, Sheets 02 §6, Slides 02 §11).
///
/// After [start] (the model was loaded with the journal tracked and
/// [cursor] set to the journal head read before loading), every [ingest]
/// reads the rows the change journal recorded for the space after
/// [cursor], re-reads them from the replica and hands them to
/// [applyRows] (which patches the model with `RowPatch`, overlaying the
/// session's unstored writes). Concurrent calls coalesce. On errors, and
/// when [needsReload] is set (a failed write, a failed stream of rows), the
/// whole space is re-read and handed to [reloadRows] instead.
class JournalIngestion {
  JournalIngestion({
    required this.host,
    required this.modelTables,
    required this.applyRows,
    required this.reloadRows,
    required this.isDisposed,
    this.afterIngest,
  });

  final SyncSessionHost<SyncReplica, SyncWriter> host;

  /// The tables of the model (others are ignored).
  final Set<String> modelTables;

  /// Patches the model with the replica rows [rows] (table → id → columns;
  /// missing = not visible) of the changed rows [changed].
  final void Function(
    Map<String, Set<UuidValue>> changed,
    Map<String, Map<String, Map<String, Object?>>> rows,
  )
  applyRows;

  /// Replaces the model's contents with [all] (every model row of the
  /// space).
  final void Function(List<(String, Map<String, Object?>)> all) reloadRows;

  /// Whether the session was disposed (stops ingestion).
  final bool Function() isDisposed;

  /// After an incremental ingestion (e.g. sync the role from the membership
  /// cache).
  final Future<void> Function()? afterIngest;

  /// The space's local id (set when the space was loaded).
  int? spaceKey;

  /// Journal position of the last ingested change (null until loaded and
  /// after disposal).
  int? cursor;

  /// Set when the model may differ from the replica: the next [ingest]
  /// re-reads the whole space.
  bool needsReload = false;

  Future<void>? _ingesting;
  bool _again = false;

  /// Applies the rows changed since [cursor]. Coalesces concurrent calls;
  /// completes when the model is current.
  Future<void> ingest() {
    if (isDisposed() || spaceKey == null || cursor == null) {
      return Future.value();
    }
    if (_ingesting != null) {
      _again = true;
      return _ingesting!;
    }
    final f = _loop();
    _ingesting = f;
    return f.whenComplete(() => _ingesting = null);
  }

  /// Consecutive failed attempts within one [ingest] call before it gives up;
  /// the model stays marked for a reload and the next [ingest] (the next
  /// merge) tries again, so a persistent failure never spins forever.
  static const maxAttempts = 5;

  Future<void> _loop() async {
    var failures = 0;
    do {
      _again = false;
      try {
        if (needsReload) {
          await _reload();
        } else {
          await _ingestOnce();
        }
        failures = 0;
      } catch (e, st) {
        debugPrint('Applying remote changes failed, reloading: $e\n$st');
        needsReload = true;
        failures++;
        if (failures >= maxAttempts || isDisposed()) return;
        _again = true;
        // 200 ms, 400 ms, 800 ms … capped at 10 s.
        final delay = 200 * (1 << (failures - 1));
        await Future<void>.delayed(
          Duration(milliseconds: delay > 10000 ? 10000 : delay),
        );
      }
    } while (_again && !isDisposed());
  }

  Future<void> _ingestOnce() async {
    final replica = host.replica;
    while (!isDisposed()) {
      final changes = await replica.journal.changesSince(spaceKey!, cursor!);
      if (changes.head == cursor) break;
      if (!changes.isEmpty) {
        changes.rows.removeWhere((t, _) => !modelTables.contains(t));
        final rows = await replica.readRows(changes.rows);
        if (isDisposed()) return;
        applyRows(changes.rows, rows);
      }
      cursor = changes.head;
      host.journalCursorsChanged();
    }
    await afterIngest?.call();
  }

  /// Fallback after errors: diff the whole space against the model.
  Future<void> _reload() async {
    final replica = host.replica;
    final head = await replica.journal.head();
    final rows = await replica.loadSpace(spaceKey!);
    if (isDisposed()) return;
    reloadRows(rows);
    cursor = head;
    needsReload = false;
    host.journalCursorsChanged();
  }
}
