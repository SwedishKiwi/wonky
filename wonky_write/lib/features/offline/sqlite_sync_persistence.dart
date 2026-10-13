import 'dart:async';
import 'dart:convert';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemView;

import '../sync/sync_persistence.dart';
import 'write_local_store.dart';

/// [SyncPersistence] on `write_cache_<userId>.db` (suite 12 §1.2).
///
/// Writes are coalesced per microtask and serialized; each write stores one
/// consistent [SyncCapture]: the server ops since the last write (or a new
/// snapshot when the op log reaches [compactAfter] rows, after a reset and
/// on close) and the outbox rows that changed. A failed write makes the
/// next one a full rewrite, so the stored state never mixes generations.
class SqliteSyncPersistence implements SyncPersistence {
  SqliteSyncPersistence(
    this.store, {
    required this.documentUuid,
    required this.itemUuid,
    this.compactAfter = 200,
    int loggedOps = 0,
    Map<String, String> storedOutbox = const {},
    this.onWritten,
    this.item,
  }) : _logged = loggedOps,
       _stored = {...storedOutbox};

  final WriteLocalStore store;
  final String documentUuid;
  final String itemUuid;
  final int compactAfter;

  /// Called after every successful write (offline availability, usage).
  final VoidCallback? onWritten;

  /// The drive item (title, pin, offline open); stored with snapshots.
  DriveItemView? item;

  SyncCapture Function()? _capture;
  List<(int, Delta)> _ops = [];
  bool _reset = false;
  bool _full = false;
  int _logged;
  Map<String, String> _stored;
  final Map<String, (Delta, String)> _json = {};

  bool _dirty = false;
  bool _scheduled = false;
  Future<void>? _running;
  bool _closed = false;

  /// Writes done (tests).
  @visibleForTesting
  int writes = 0;

  @override
  void attach(SyncCapture Function() capture) => _capture = capture;

  @override
  void serverOp(int revision, Delta op) => _ops.add((revision, op));

  @override
  void serverReset(Delta document, int revision) {
    _ops = [];
    _reset = true;
  }

  @override
  void markDirty() {
    if (_closed || _capture == null) return;
    _dirty = true;
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(_kick);
  }

  void _kick() {
    if (_running != null) return;
    _running = _loop();
  }

  Future<void> _loop() async {
    try {
      while (_dirty) {
        _scheduled = false;
        _dirty = false;
        await _write();
      }
    } finally {
      _running = null;
      _scheduled = false;
      if (_dirty && !_closed) {
        _scheduled = true;
        scheduleMicrotask(_kick);
      }
    }
  }

  String _encode(PendingOpRecord r) {
    final id = r.clientOpId.uuid;
    final cached = _json[id];
    if (cached != null && identical(cached.$1, r.delta)) return cached.$2;
    final j = jsonEncode(r.delta.toJson());
    _json[id] = (r.delta, j);
    return j;
  }

  Future<void> _write({bool forceCompact = false}) async {
    if (_discarded) return;
    final capture = _capture?.call();
    if (capture == null) return;
    final ops = _ops;
    _ops = [];
    final compact =
        forceCompact || _reset || _full || _logged + ops.length >= compactAfter;
    // After a reset or a failed write the stored outbox is replaced as a
    // whole.
    final full = _full || _reset;
    _reset = false;
    _full = false;
    final next = <String, String>{};
    final upserts = <String, String>{};
    final records = <String, PendingOpRecord>{};
    final jsons = <String, String>{};
    for (final r in capture.outbox) {
      final id = r.clientOpId.uuid;
      final j = _encode(r);
      final sig = WriteLocalStore.signature(r, j);
      next[id] = sig;
      if (full || _stored[id] != sig) {
        upserts[id] = sig;
        records[id] = r;
        jsons[id] = j;
      }
    }
    final deletes = {
      for (final id in _stored.keys)
        if (!next.containsKey(id)) id,
    };
    _json.removeWhere((id, _) => !next.containsKey(id));
    try {
      await store.writeSync(
        documentUuid: documentUuid,
        itemUuid: itemUuid,
        capture: capture,
        ops: compact ? const [] : ops,
        compact: compact,
        upserts: upserts,
        records: records,
        deletes: deletes,
        replaceOutbox: full,
        deltaJson: jsons,
        item: item,
      );
      _stored = next;
      _logged = compact ? 0 : _logged + ops.length;
      writes++;
      onWritten?.call();
    } on Object catch (e) {
      debugPrint('Storing the document locally failed: $e');
      _full = true;
    }
  }

  @override
  Future<void> whenDurable() async {
    while (_scheduled || _running != null || _dirty) {
      final r = _running;
      if (r != null) {
        await r;
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  /// Stops writing (the local copy is being deleted).
  void discard() {
    _discarded = true;
    _closed = true;
    _dirty = false;
  }

  bool _discarded = false;

  @override
  Future<void> close() async {
    if (_closed) return;
    await whenDurable();
    _closed = true;
    // Fold the op log into the snapshot so the next open is one read.
    if (_logged > 0 && _capture != null) await _write(forceCompact: true);
  }
}
