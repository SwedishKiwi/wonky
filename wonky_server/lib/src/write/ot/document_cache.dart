import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/common/models.dart';
import 'document_store.dart';

/// A recently applied op kept in memory.
class CachedOp {
  CachedOp(this.revision, this.delta);
  final int revision;
  final Delta delta;
}

/// In-memory state of one document on this server instance (Write 03 §2):
/// head content, recent ops (last 1,000) and overlay counts. Shared by all
/// connections of the document on this instance; disposed 60 s after the
/// last one leaves. The database row lock stays authoritative across
/// instances, so the state catches up from the op log when it is behind.
class DocumentState {
  DocumentState._(
    this.documentUuid,
    this.documentId,
    this.content,
    this.revision,
  ) : overlays = OverlayIndex()..reset(content);

  final UuidValue documentUuid;
  final int documentId;
  Delta content;
  int revision;
  final OverlayIndex overlays;
  final List<CachedOp> recent = [];
  int connections = 0;
  Timer? _disposeTimer;

  /// Throttles for side effects (drive modifiedAt, search text, activity).
  DateTime lastModifiedTouch = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastSearchTextUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<int, DateTime> lastUserEdit = {};

  Future<void> _tail = Future.value();

  static const maxRecent = 1000;

  /// Runs [action] exclusively for this document on this instance.
  Future<T> lock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  void remember(int revision, Delta delta) {
    recent.add(CachedOp(revision, delta));
    if (recent.length > maxRecent) {
      recent.removeRange(0, recent.length - maxRecent);
    }
  }

  /// Cached ops after [fromRevision] up to the head, or null when not all
  /// of them are cached.
  List<Delta>? opsSince(int fromRevision) {
    if (fromRevision >= revision) return const [];
    if (recent.isEmpty || recent.first.revision > fromRevision + 1) return null;
    return [
      for (final op in recent)
        if (op.revision > fromRevision) op.delta,
    ];
  }

  /// The revision a pending [ensureAtLeast] catches up to.
  int _catchingUpTo = 0;
  Future<void>? _catchingUp;

  /// Makes sure the state is at [minRevision] or later when the database
  /// has it: another instance committed ops that this instance only saw on
  /// the bus (or not at all). Coalesces concurrent calls.
  Future<void> ensureAtLeast(Session session, int minRevision) {
    if (minRevision <= revision) return Future.value();
    final pending = _catchingUp;
    if (pending != null && minRevision <= _catchingUpTo) return pending;
    _catchingUpTo = minRevision;
    late final Future<void> future;
    future =
        lock(() async {
          if (minRevision <= revision) return;
          final fresh = await Document.db.findById(session, documentId);
          if (fresh == null) return;
          await catchUp(session, fresh.headRevision);
        }).whenComplete(() {
          if (identical(_catchingUp, future)) _catchingUp = null;
        });
    _catchingUp = future;
    return future;
  }

  /// Brings the state up to [headRevision] from the op log (another
  /// instance committed ops).
  Future<void> catchUp(
    Session session,
    int headRevision, {
    Transaction? transaction,
  }) async {
    if (headRevision <= revision) return;
    final ops = await DocumentOp.db.find(
      session,
      where: (t) =>
          t.documentId.equals(documentId) &
          (t.revision > revision) &
          (t.revision <= headRevision),
      orderBy: (t) => t.revision,
      transaction: transaction,
    );
    if (ops.length != headRevision - revision) {
      final doc = await Document.db.findById(
        session,
        documentId,
        transaction: transaction,
      );
      content = await DocumentStore.head(
        session,
        doc!,
        transaction: transaction,
      );
      revision = doc.headRevision;
      overlays.reset(content);
      recent.clear();
      return;
    }
    for (final op in ops) {
      final delta = DocumentStore.decodeDelta(op.deltaJson);
      overlays.apply(delta, DocumentStore.decodeDelta(op.inverseJson));
      content = WonkyOt.apply(content, delta);
      revision = op.revision;
      remember(op.revision, delta);
    }
  }
}

/// Registry of [DocumentState]s of this instance.
abstract final class DocumentCache {
  static final Map<String, DocumentState> _states = {};
  static final Map<String, Future<DocumentState>> _loading = {};

  static const disposeAfter = Duration(seconds: 60);

  /// The state of [doc], loading it on first use.
  static Future<DocumentState> of(Session session, Document doc) async {
    final key = doc.uuid.uuid;
    final existing = _states[key];
    if (existing != null) return existing;
    final loading = _loading[key];
    if (loading != null) return loading;
    final future = () async {
      final content = await DocumentStore.head(session, doc);
      final state = DocumentState._(
        doc.uuid,
        doc.id!,
        content,
        doc.headRevision,
      );
      final ops = await DocumentOp.db.find(
        session,
        where: (t) =>
            t.documentId.equals(doc.id!) &
            (t.revision > doc.headRevision - 200),
        orderBy: (t) => t.revision,
      );
      for (final op in ops) {
        state.remember(op.revision, DocumentStore.decodeDelta(op.deltaJson));
      }
      _states[key] = state;
      return state;
    }();
    _loading[key] = future;
    try {
      return await future;
    } finally {
      _loading.removeWhere((k, _) => k == key);
    }
  }

  /// A connection starts using [state].
  static void retain(DocumentState state) {
    state.connections++;
    state._disposeTimer?.cancel();
    state._disposeTimer = null;
  }

  /// A connection stopped using [state]; disposes it after [disposeAfter].
  static void release(DocumentState state) {
    state.connections--;
    if (state.connections > 0) return;
    state._disposeTimer?.cancel();
    state._disposeTimer = Timer(disposeAfter, () {
      if (state.connections <= 0) _states.remove(state.documentUuid.uuid);
    });
  }

  /// Drops the cached state (document deleted, tests).
  static void evict(UuidValue documentUuid) {
    final state = _states.remove(documentUuid.uuid);
    state?._disposeTimer?.cancel();
  }

  static void clear() {
    for (final s in _states.values) {
      s._disposeTimer?.cancel();
    }
    _states.clear();
  }
}
