import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart';

import '../../shell/shell_services.dart';
import '../board_hub.dart';

/// The lists (tabs) of the board page (specs/16 §4.3–4.4).
enum BoardTab {
  improvements('/improvements'),
  bugs('/improvements/bugs'),
  tasks('/improvements/tasks'),
  done('/improvements/done'),
  review('/improvements/review');

  const BoardTab(this.path);

  final String path;

  /// Whether the list shows posts (a post opened from it stays under it).
  bool get hasPosts => this != BoardTab.tasks;

  /// Whether the list shows tasks (a task opened from it stays under it).
  bool get hasTasks =>
      this == BoardTab.tasks ||
      this == BoardTab.done ||
      this == BoardTab.review;

  static BoardTab? byName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// Whether [location] is a board route (`/improvements…`).
bool isBoardLocation(String location) =>
    location == '/improvements' ||
    location.startsWith('/improvements/') ||
    location.startsWith('/improvements?') ||
    location.startsWith('/improvements#');

/// Where closing the board goes (specs/16 §4.3): the last visited route that
/// is not a board page, else home.
String boardBackTarget(ShellServices s) {
  final h = s.navHistory;
  for (var i = s.navIndex; i >= 0 && i < h.length; i--) {
    if (!isBoardLocation(h[i])) return h[i];
  }
  return '/';
}

/// Closes the board: back to [boardBackTarget] (the app icon crumb).
void closeBoard(ShellServices s) => s.router.go(boardBackTarget(s));

/// A place on the board as a breadcrumb trail (specs/16 §4.3): the board
/// root › [list] › [task] › [post], or the contribute page. The trail is
/// derived from the board's hierarchy, never from the browser history, and
/// travels in the URL query (`/improvements/p/5?list=tasks&task=1`), so a
/// reload or a shared link keeps it.
///
/// A null [list] on a post or task means "the item's own list": the post's
/// kind (*Bugs* or *Improvements*; *Up for grabs* under a task), the task's
/// status (*Done* when done or shipped, else *Up for grabs*); see
/// [resolve].
@immutable
class BoardTrail {
  const BoardTrail({this.list, this.task, this.post, this.contribute = false})
    : assert(!contribute || (list == null && task == null && post == null));

  /// The board root (the *Improvements* list).
  static const root = BoardTrail(list: BoardTab.improvements);

  final BoardTab? list;
  final int? task;
  final int? post;
  final bool contribute;

  /// A list page (no item below the list).
  bool get isList => !contribute && task == null && post == null;

  /// A task page (the task is the last step).
  bool get isTask => task != null && post == null;

  bool get isPost => post != null;

  /// The trail of a board [uri]; null when it is not a board route.
  /// Unknown or contradictory query values fall back to the defaults.
  static BoardTrail? parse(Uri uri) {
    final seg = uri.pathSegments.where((x) => x.isNotEmpty).toList();
    if (seg.isEmpty || seg.first != 'improvements') return null;
    final q = uri.queryParameters;
    if (seg.length == 1) return root;
    if (seg.length == 2) {
      if (seg[1] == 'contribute') return const BoardTrail(contribute: true);
      final tab = BoardTab.byName(seg[1]);
      // `/improvements` itself is the Improvements list.
      return tab == null || tab == BoardTab.improvements
          ? null
          : BoardTrail(list: tab);
    }
    if (seg.length != 3) return null;
    final n = int.tryParse(seg[2]);
    if (n == null) return null;
    var list = BoardTab.byName(q['list']);
    switch (seg[1]) {
      case 'p':
        final task = int.tryParse(q['task'] ?? '');
        if (task != null && list != null && !list.hasTasks) list = null;
        if (list != null && task == null && !list.hasPosts) list = null;
        return BoardTrail(list: list, task: task, post: n);
      case 't':
        if (list != null && !list.hasTasks) list = null;
        return BoardTrail(list: list, task: n);
    }
    return null;
  }

  /// The trail of the current route of [s] with its defaults resolved from
  /// what the board last showed ([resolve]).
  static BoardTrail? here(ShellServices s) {
    final t = parse(s.router.routerDelegate.currentConfiguration.uri);
    return t?.resolve(BoardHub.of(s));
  }

  /// Fills in a missing [list] from the item: a post under a task is in
  /// *Up for grabs*; a post in its kind's list; a task in *Done* when done
  /// or shipped, else *Up for grabs*. Stays null while the item is unknown.
  BoardTrail resolve(
    BoardHub hub, {
    BoardPostKind? postKind,
    BoardTaskStatus? taskStatus,
  }) {
    if (list != null || contribute) return this;
    final BoardTab? l;
    if (post case final p?) {
      if (task != null) {
        l = BoardTab.tasks;
      } else {
        l = switch (postKind ?? hub.postKinds[p]) {
          BoardPostKind.bug => BoardTab.bugs,
          BoardPostKind.idea => BoardTab.improvements,
          _ => null,
        };
      }
    } else if (task case final t?) {
      l = switch (taskStatus ?? hub.taskStatuses[t]) {
        BoardTaskStatus.done || BoardTaskStatus.shipped => BoardTab.done,
        null => null,
        _ => BoardTab.tasks,
      };
    } else {
      l = null;
    }
    return l == null ? this : BoardTrail(list: l, task: task, post: post);
  }

  /// The route of this trail: the page's path with the trail's query.
  String get location {
    if (contribute) return '/improvements/contribute';
    final query = <String>[
      if (list != null && !isList) 'list=${list!.name}',
      if (post != null && task != null) 'task=$task',
    ];
    final path = switch ((post, task)) {
      (final int p, _) => '/improvements/p/$p',
      (null, final int t) => '/improvements/t/$t',
      _ => (list ?? BoardTab.improvements).path,
    };
    return query.isEmpty ? path : '$path?${query.join('&')}';
  }

  /// Opening post [number] from here (specs/16 §4.3):
  /// - from a list: root › list › post (the list's own when it has no
  ///   posts: *Up for grabs* → the post's kind);
  /// - from a task: root › list › task › post;
  /// - from a post: the new post replaces this one (siblings: similar posts,
  ///   merged duplicates, *duplicate of*);
  /// - the post already here: unchanged.
  BoardTrail openPost(int number) {
    if (post == number) return this;
    if (post != null || task != null) {
      return BoardTrail(list: list, task: task, post: number);
    }
    if (contribute) return BoardTrail(post: number);
    final l = list;
    return BoardTrail(list: l != null && l.hasPosts ? l : null, post: number);
  }

  /// Opening task [number] from here: the task in the trail truncates the
  /// trail to it (a post's own task: root › list › T-n, never post › task ›
  /// post); any other task replaces the trail below the list, keeping the
  /// list when it shows tasks (else the task's own list).
  BoardTrail openTask(int number) {
    if (task == number) return BoardTrail(list: list, task: number);
    final l = list;
    return BoardTrail(list: l != null && l.hasTasks ? l : null, task: number);
  }

  /// Opening list [tab] (a tab, the root crumb).
  BoardTrail openList(BoardTab tab) => BoardTrail(list: tab);

  /// Whether going from here to [next] stays at the same depth (switching
  /// tabs, a post to a sibling post, a task to another task): such moves
  /// replace the history entry, so Back never walks through loops.
  bool isSiblingOf(BoardTrail next) {
    if (isList && next.isList) return true;
    if (isPost && next.isPost) return task == next.task && post != next.post;
    if (isTask && next.isTask) return task != next.task;
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is BoardTrail &&
      other.list == list &&
      other.task == task &&
      other.post == post &&
      other.contribute == contribute;

  @override
  int get hashCode => Object.hash(list, task, post, contribute);

  @override
  String toString() => 'BoardTrail($location)';
}

/// Navigates the board to [next] (specs/16 §4.3): `router.go` to its
/// location, replacing the history entry when the move stays at the same
/// depth ([BoardTrail.isSiblingOf]), so the shell's Back (`Mod+[`, the
/// browser's back) still steps through real history without loops. With
/// [merged], the post page says it came from that merged duplicate.
void boardGo(
  ShellServices s,
  BoardTrail next, {
  BuildContext? context,
  bool replace = false,
  int? merged,
}) {
  var location = next.location;
  if (merged != null) {
    location += '${location.contains('?') ? '&' : '?'}merged=$merged';
  }
  final here = BoardTrail.here(s);
  if (replace || (here != null && here.isSiblingOf(next))) {
    s.goReplacing(location, context: context);
  } else {
    s.router.go(location);
  }
}

/// Opens post [number] from the current board page ([BoardTrail.openPost]).
void boardOpenPost(ShellServices s, int number, {BuildContext? context}) =>
    boardGo(
      s,
      (BoardTrail.here(s) ?? BoardTrail.root).openPost(number),
      context: context,
    );

/// Opens task [number] from the current board page ([BoardTrail.openTask]).
void boardOpenTask(ShellServices s, int number, {BuildContext? context}) =>
    boardGo(
      s,
      (BoardTrail.here(s) ?? BoardTrail.root).openTask(number),
      context: context,
    );

/// Opens list [tab] (a tab switch replaces the history entry).
void boardOpenList(ShellServices s, BoardTab tab, {BuildContext? context}) =>
    boardGo(s, BoardTrail(list: tab), context: context);

/// Opens *How to contribute*.
void boardOpenContribute(ShellServices s) =>
    boardGo(s, const BoardTrail(contribute: true));
