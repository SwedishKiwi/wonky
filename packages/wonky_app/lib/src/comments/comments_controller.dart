import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../data/api.dart';
import '../shell/shell_services.dart';
import 'comment_anchor.dart';

/// Filters of the comments (suite 07 §2.3): unresolved threads, or the
/// unresolved threads that mention or are assigned to the signed-in user.
enum CommentsFilter { open, forYou }

/// Sort of the comments panel.
enum CommentsSort { position, date }

/// Live comment threads of one file: loads, watches (`comment.watch`) and
/// runs comment operations. Commands (`shell.comments.*`) call it; widgets
/// listen to it.
class CommentsController extends ChangeNotifier {
  CommentsController({
    required this.services,
    required this.itemUuid,
    this.anchors,
  });

  final ShellServices services;
  final UuidValue itemUuid;

  /// The app's anchor provider (null on the home screen).
  CommentAnchorProvider? anchors;

  List<CommentThreadView> _threads = const [];
  bool _loading = true;
  Object? _error;
  CommentsFilter _filter = CommentsFilter.open;
  CommentsSort _sort = CommentsSort.position;
  NewCommentAnchor? _draft;
  String? _active;
  bool _disposed = false;

  List<CommentThreadView> get threads => _threads;
  bool get loading => _loading;
  Object? get error => _error;
  CommentsFilter get filter => _filter;
  CommentsSort get sort => _sort;

  /// The anchor of the composer being written, if any.
  NewCommentAnchor? get draftAnchor => _draft;

  String? get activeThreadUuid => _active;

  int get openCount =>
      _threads.where((t) => t.status == CommentStatus.open).length;

  CommentThreadView? thread(String uuid) {
    for (final t in _threads) {
      if (t.uuid.uuid == uuid) return t;
    }
    return null;
  }

  String get _streamKey => 'comments:${itemUuid.uuid}';

  /// Loads threads and starts the live stream.
  Future<void> start() async {
    await reload();
    services.supervisor.supervise<CommentEvent>(
      _streamKey,
      () => services.repositories.comments.watch(itemUuid),
      _onEvent,
      onConnected: () => unawaited(reload()),
    );
  }

  Future<void> reload() async {
    try {
      _threads = await services.repositories.comments.listThreads(itemUuid);
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _onEvent(CommentEvent e) {
    switch (e.kind) {
      case CommentEventKind.threadDeleted:
        _threads = [
          for (final t in _threads)
            if (t.uuid != e.threadUuid) t,
        ];
      case CommentEventKind.threadCreated:
      case CommentEventKind.threadUpdated:
      case CommentEventKind.statusChanged:
        final t = e.thread;
        if (t != null) _upsert(t);
    }
    _notify();
  }

  void _upsert(CommentThreadView t) {
    final i = _threads.indexWhere((x) => x.uuid == t.uuid);
    _threads = i < 0 ? [..._threads, t] : ([..._threads]..[i] = t);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Whether [t] passes the current [filter].
  bool passesFilter(CommentThreadView t) {
    // Open includes orphaned threads (unresolved, their text deleted).
    if (t.status == CommentStatus.resolved) return false;
    if (_filter == CommentsFilter.open) return true;
    final me = services.me?.id;
    return t.assignee?.id == me ||
        t.comments.any((c) => c.mentions.any((m) => m.id == me));
  }

  /// Threads after filter and sort.
  List<CommentThreadView> get visible {
    final out = [
      for (final t in _threads)
        if (passesFilter(t)) t,
    ];
    if (_sort == CommentsSort.date) {
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      final a = anchors;
      if (a != null) {
        out.sort((x, y) => a.positionOf(x).compareTo(a.positionOf(y)));
      } else {
        out.sort((x, y) => x.createdAt.compareTo(y.createdAt));
      }
    }
    return out;
  }

  void setFilter(CommentsFilter f) {
    _filter = f;
    _notify();
  }

  void setSort(CommentsSort s) {
    _sort = s;
    _notify();
  }

  void startDraft(NewCommentAnchor anchor) {
    _draft = anchor;
    _notify();
  }

  void cancelDraft() {
    _draft = null;
    _notify();
  }

  void activate(String? threadUuid) {
    _active = threadUuid;
    final t = threadUuid == null ? null : thread(threadUuid);
    if (t != null) anchors?.reveal(t);
    _notify();
  }

  // ---- Operations (called by shell.comments.* and the undo handler) ----

  Future<CommentThreadView> createThread({
    required NewCommentAnchor anchor,
    required String body,
    List<int> mentions = const [],
    int? assigneeId,
    UuidValue? threadUuid,
  }) async {
    final t = await services.repositories.comments.createThread(
      threadUuid: threadUuid ?? services.ids.next(),
      itemUuid: itemUuid,
      anchorKind: anchor.kind,
      anchorJson: anchor.anchorJson,
      quotedText: anchor.quotedText,
      body: body,
      mentions: mentions,
      assigneeId: assigneeId,
    );
    _draft = null;
    _upsert(t);
    _active = t.uuid.uuid;
    anchors?.onThreadCreated(t);
    _notify();
    return t;
  }

  Future<CommentThreadView> reply(
    String threadUuid,
    String body, {
    List<int> mentions = const [],
  }) async {
    final t = await services.repositories.comments.reply(
      UuidValue.fromString(threadUuid),
      body: body,
      mentions: mentions,
      commentUuid: services.ids.next(),
    );
    _upsert(t);
    _notify();
    return t;
  }

  Future<CommentThreadView> resolve(String threadUuid) async {
    final t = await services.repositories.comments.resolve(
      UuidValue.fromString(threadUuid),
    );
    _upsert(t);
    _notify();
    return t;
  }

  Future<CommentThreadView> reopen(String threadUuid) async {
    final t = await services.repositories.comments.reopen(
      UuidValue.fromString(threadUuid),
    );
    _upsert(t);
    _notify();
    return t;
  }

  Future<void> deleteThread(String threadUuid) async {
    final existing = thread(threadUuid);
    await services.repositories.comments.deleteThread(
      UuidValue.fromString(threadUuid),
    );
    _threads = [
      for (final t in _threads)
        if (t.uuid.uuid != threadUuid) t,
    ];
    if (existing != null) anchors?.onThreadDeleted(existing);
    _notify();
  }

  Future<void> deleteComment(int commentId) async {
    await services.repositories.comments.delete(commentId);
    await reload();
  }

  Future<CommentView> edit(int commentId, String body) async {
    final c = await services.repositories.comments.edit(commentId, body);
    await reload();
    return c;
  }

  Future<void> react(int commentId, String emoji) async {
    await services.repositories.comments.react(commentId, emoji);
    await reload();
  }

  /// Seconds since [t] for relative times (tests use a fixed clock).
  Duration ageOf(DateTime t) => clock.now().difference(t);

  /// User-facing message for [e].
  String messageOf(Object e) => errorMessage(e);

  @override
  void dispose() {
    _disposed = true;
    unawaited(services.supervisor.cancel(_streamKey));
    super.dispose();
  }
}
