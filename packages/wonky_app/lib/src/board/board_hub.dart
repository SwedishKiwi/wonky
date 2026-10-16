import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../shell/shell_services.dart';
import 'board_repository.dart';

/// What changed on the board (a command ran, an undo or redo applied it):
/// open board pages reload the matching post, task or list.
@immutable
class BoardChange {
  const BoardChange({this.post, this.task, this.lists = true});

  /// The post number that changed (null: none in particular).
  final int? post;

  /// The task number that changed.
  final int? task;

  /// Whether lists (board tabs, review queue) should reload too.
  final bool lists;

  bool touchesPost(int n) => post == null && task == null || post == n;
  bool touchesTask(int n) => post == null && task == null || task == n;
}

/// Client state of Bugs & improvements for one [ShellServices]
/// (specs/16 §4): the caller's [BoardMe] (admin UI, blocked state), a
/// change feed for open board pages, and small caches the commands use to
/// record undo inverses without an extra round trip (votes, comment
/// bodies).
class BoardHub {
  BoardHub._(this.services) {
    services.auth.addListener(_onAuth);
  }

  static final _hubs = Expando<BoardHub>('board');

  /// The hub of [s] (created on first use).
  static BoardHub of(ShellServices s) => _hubs[s] ??= BoardHub._(s);

  final ShellServices services;

  BoardRepository get repository => services.repositories.board;

  /// The caller as the board sees them; null until [loadMe] finished.
  final ValueNotifier<BoardMe?> me = ValueNotifier(null);

  Future<BoardMe?>? _loading;

  bool get isAdmin => me.value?.isAdmin == true;
  bool get signedIn => services.auth.isSignedIn;

  /// Signed in and not blocked from the board.
  bool get canWrite => signedIn && me.value?.blocked != true;

  /// Loads (or reloads with [force]) [me]. Never throws: a failure leaves
  /// the previous value.
  Future<BoardMe?> loadMe({bool force = false}) {
    if (!force && me.value != null) return Future.value(me.value);
    return _loading ??= () async {
      try {
        me.value = await repository.me();
        services.registry.notifyStateChanged();
      } catch (_) {
        // Keep the last value; admin UI stays hidden.
      } finally {
        _loading = null;
      }
      return me.value;
    }();
  }

  void _onAuth() {
    me.value = null;
    myVotes.clear();
    unawaited(loadMe());
  }

  final _changes = StreamController<BoardChange>.broadcast(sync: true);

  /// Changes made through commands, undo and redo.
  Stream<BoardChange> get changes => _changes.stream;

  void changed({int? post, int? task, bool lists = true}) {
    if (_changes.isClosed) return;
    _changes.add(BoardChange(post: post, task: task, lists: lists));
  }

  /// The caller's last known vote per post (from loaded lists and pages).
  final Map<int, int> myVotes = {};

  /// Last known comment bodies by uuid (undo of *Edit comment*).
  final Map<String, String> commentBodies = {};

  /// Last known post kinds (vote keyboard shortcuts).
  final Map<int, BoardPostKind> postKinds = {};

  /// Remembers what a list or page showed.
  void notePosts(Iterable<BoardPostListItem> items) {
    for (final i in items) {
      myVotes[i.number] = i.myVote;
      postKinds[i.number] = i.kind;
    }
  }

  void notePost(BoardPostView p) {
    myVotes[p.number] = p.myVote;
    postKinds[p.number] = p.kind;
  }

  void noteComments(Iterable<BoardCommentView> comments) {
    for (final c in comments) {
      commentBodies[c.uuid.uuid] = c.body;
    }
  }
}
