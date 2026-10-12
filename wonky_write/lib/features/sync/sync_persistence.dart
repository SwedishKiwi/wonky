import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:wonky_client/wonky_client.dart';

/// One local change waiting for the server (suite 12 §1.1 `LocalPendingOp`):
/// the in-flight op or a chunk of the buffer. Every op is expressed against
/// the server document at [baseRevision] composed with the ops before it.
@immutable
class PendingOpRecord {
  const PendingOpRecord({
    required this.clientOpId,
    required this.seq,
    required this.baseRevision,
    required this.delta,
    required this.kind,
    required this.createdAt,
    this.groupId,
    this.inflight = false,
  });

  final UuidValue clientOpId;

  /// Order in the outbox (0 = oldest).
  final int seq;
  final int baseRevision;
  final Delta delta;
  final DocumentOpKind kind;
  final String? groupId;
  final DateTime createdAt;

  /// Whether this op may already have been sent (it is resent with the
  /// same [clientOpId]; the server is idempotent on it).
  final bool inflight;
}

/// What the sync controller hands to its [SyncPersistence] at a flush: a
/// consistent picture of the server document and the outbox.
@immutable
class SyncCapture {
  const SyncCapture({
    required this.revision,
    required this.serverDocument,
    required this.outbox,
    this.meta,
    this.role,
  });

  final int revision;

  /// The server document at [revision] (written when the op log is
  /// compacted).
  final Delta serverDocument;
  final List<PendingOpRecord> outbox;
  final DocumentMetaView? meta;
  final AccessRole? role;
}

/// The durable state of a document's sync session, as restored on open
/// (stale-while-revalidate, Write 03 §3.1).
@immutable
class SyncLocalState {
  const SyncLocalState({
    required this.revision,
    required this.serverDocument,
    this.outbox = const [],
    this.meta,
    this.role,
  });

  final int revision;
  final Delta serverDocument;
  final List<PendingOpRecord> outbox;
  final DocumentMetaView? meta;
  final AccessRole? role;
}

/// Durable storage of one document's sync state (the offline outbox, suite
/// 12 §1.2): implemented on SQLite by `features/offline`.
///
/// The controller reports every change of the server document and marks
/// the state dirty after every change of the outbox; the persistence
/// captures the whole state ([SyncCapture]) when it flushes, so what is
/// stored is always consistent. Local ops are only sent once
/// [whenDurable] completes ("written before sending").
abstract interface class SyncPersistence {
  /// Called once by the controller; [capture] returns the current state.
  void attach(SyncCapture Function() capture);

  /// The server document advanced by [op] to [revision].
  void serverOp(int revision, Delta op);

  /// The server document was replaced (first load, resync).
  void serverReset(Delta document, int revision);

  /// The outbox, metadata or role changed.
  void markDirty();

  /// Completes when everything reported so far is stored.
  Future<void> whenDurable();

  /// Flushes and releases resources.
  Future<void> close();
}
