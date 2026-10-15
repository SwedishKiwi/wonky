import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_ui/wonky_ui.dart' show SyncState, SyncStatus;

import '../writer/sync_writer.dart';

/// The write path of one open file session (Sheets 02 §7, Slides 02 §12.2):
/// changes already applied to the in-memory model are queued for the
/// [SyncWriter] and stored strictly in order (one transaction per ≤ 5,000
/// changes plus the change-log row). [pendingOverlay] lists what isn't
/// stored yet, so remote patches never undo an optimistic edit
/// (`RowPatch`).
class SpaceWriteQueue {
  SpaceWriteQueue({
    required this.writer,
    required this.spaceUuid,
    required this.sessionId,
    this.onStored,
    this.onFailed,
    this.onChanged,
  });

  final SyncWriter writer;

  /// The space written to.
  final UuidValue spaceUuid;

  /// The change-log `sessionId`.
  final String sessionId;

  /// After each stored write (e.g. kick the sync loop).
  final void Function()? onStored;

  /// After a failed write: the optimistic model change was not stored, so
  /// the session brings its model back in line with the replica.
  final void Function(Object error)? onFailed;

  /// Whenever [pendingChanges], [saveProgress] or [lastError] changed.
  final void Function()? onChanged;

  Future<void> _queue = Future.value();
  final List<List<RowChange>> _pending = [];

  /// Changes of the write in flight already stored (its finished chunks).
  int _written = 0;

  Object? _lastError;

  /// The error of the last write (null after a successful one).
  Object? get lastError => _lastError;

  /// Queues [changes] (already applied to the model). [plan] is set for
  /// planned operations (its summary/detail feed the change-log row).
  void enqueue(
    List<RowChange> changes, {
    MutationPlan<ChangeSummary>? plan,
    required String label,
    required String actorKind,
  }) {
    if (changes.isEmpty) return;
    final write = changes;
    _pending.add(write);
    onChanged?.call();
    _queue = _queue.then((_) async {
      try {
        await writer.write(
          spaceId: spaceUuid,
          changes: changes,
          plan: plan,
          label: label,
          actorKind: actorKind,
          sessionId: sessionId,
          onProgress: (written, _) {
            _written = written;
            onChanged?.call();
          },
        );
        _lastError = null;
        onStored?.call();
      } catch (e, st) {
        debugPrint('Saving "$label" failed: $e\n$st');
        _lastError = e;
        onFailed?.call(e);
      } finally {
        _pending.remove(write);
        _written = 0;
        onChanged?.call();
      }
    });
  }

  /// Completes when everything queued so far is stored (or failed).
  Future<void> flush() => _queue;

  /// Changes queued but not yet stored, oldest first.
  List<RowChange> get pendingOverlay => [for (final w in _pending) ...w];

  /// Number of row changes waiting to be stored.
  int get pendingChanges => _pending.fold(0, (a, w) => a + w.length);

  /// Share of the queued changes stored, for saves bigger than one writer
  /// chunk (shown in the sync status); null for ordinary saves.
  double? get saveProgress {
    final pending = pendingChanges;
    if (pending <= SyncWriter.chunkSize) return null;
    return _written / pending;
  }

  /// The header's sync status given the connection state.
  SyncStatus status({required bool online}) {
    final pending = pendingChanges;
    if (_lastError != null) {
      return SyncStatus(
        state: SyncState.error,
        pendingChanges: pending,
        error: '$_lastError',
      );
    }
    if (pending > 0) {
      return SyncStatus(
        state: SyncState.saving,
        pendingChanges: pending - _written,
        progress: saveProgress,
      );
    }
    if (!online) return const SyncStatus(state: SyncState.offline);
    return SyncStatus.saved;
  }
}
