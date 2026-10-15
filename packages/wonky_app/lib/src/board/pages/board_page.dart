import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../data/api.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../board_hub.dart';
import 'board_labels.dart';
import 'board_widgets.dart';
import 'review_tab.dart';
import 'task_list.dart';

/// The tabs of the board page (specs/16 §4.3–4.4).
enum BoardTab {
  improvements('/improvements'),
  bugs('/improvements/bugs'),
  tasks('/improvements/tasks'),
  done('/improvements/done'),
  review('/improvements/review');

  const BoardTab(this.path);

  final String path;
}

/// Page size of the board list (specs/16 §4.4).
const boardPageSize = 30;

/// The board page (`/improvements…`, specs/16 §4.4): header with *Report a
/// bug* / *Suggest an improvement* and search, the tabs with counts, and
/// the tab's content.
class BoardPage extends StatefulWidget {
  const BoardPage({super.key, required this.services, required this.tab});

  final ShellServices services;
  final BoardTab tab;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _Counts {
  int? ideas;
  int? bugs;
  int? tasks;
  int? held;
}

class _BoardPageState extends State<BoardPage> {
  ShellServices get s => widget.services;
  BoardHub get hub => BoardHub.of(s);

  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  final _counts = _Counts();
  StreamSubscription<BoardChange>? _changes;

  @override
  void initState() {
    super.initState();
    hub.me.addListener(_onMe);
    unawaited(hub.loadMe());
    _changes = hub.changes.listen((c) {
      if (c.lists) unawaited(_loadCounts());
    });
    unawaited(_loadCounts());
  }

  @override
  void dispose() {
    hub.me.removeListener(_onMe);
    _changes?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onMe() {
    if (!mounted) return;
    setState(() {});
    unawaited(_loadCounts());
  }

  Future<void> _loadCounts() async {
    final repo = s.repositories.board;
    Future<int?> total(BoardPostKind kind) async {
      try {
        return (await repo.list(
          BoardListQuery(
            kind: kind,
            statuses: const [BoardPostStatus.open, BoardPostStatus.planned],
            areas: const [],
            sizes: const [],
            sort: BoardSort.trending,
            mine: false,
            limit: 1,
          ),
        )).total;
      } catch (_) {
        return null;
      }
    }

    final ideas = total(BoardPostKind.idea);
    final bugs = total(BoardPostKind.bug);
    int? tasks;
    try {
      tasks = (await repo.listTasks(const [
        BoardTaskStatus.published,
      ], limit: 50)).items.length;
    } catch (_) {}
    int? held;
    if (hub.isAdmin) {
      try {
        held = (await repo.reviewCounts()).held;
      } catch (_) {}
    }
    final i = await ideas;
    final b = await bugs;
    if (!mounted) return;
    setState(() {
      _counts
        ..ideas = i
        ..bugs = b
        ..tasks = tasks
        ..held = held;
    });
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  String _tabLabel(WonkyAppLocalizations l, BoardTab t) {
    final (name, count) = switch (t) {
      BoardTab.improvements => (l.boardTabImprovements, _counts.ideas),
      BoardTab.bugs => (l.boardTabBugs, _counts.bugs),
      BoardTab.tasks => (l.boardTabTasks, _counts.tasks),
      BoardTab.done => (l.boardTabDone, null),
      BoardTab.review => (l.boardTabReview, _counts.held),
    };
    return count == null ? name : '$name $count';
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final tab = widget.tab == BoardTab.review && !hub.isAdmin
        ? (hub.me.value == null ? BoardTab.review : BoardTab.improvements)
        : widget.tab;
    final tabs = [
      BoardTab.improvements,
      BoardTab.bugs,
      BoardTab.tasks,
      BoardTab.done,
      if (hub.isAdmin) BoardTab.review,
    ];
    final header = Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 24, 20, narrow ? 16 : 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ShadButton(
                key: const ValueKey<String>('board.reportBug'),
                leading: const Icon(LucideIcons.bug, size: 16),
                onPressed: () => boardInvoke(s, 'shell.board.report', {
                  'kind': 'bug',
                }, context: context),
                child: Text(l.boardReportBug),
              ),
              ShadButton.outline(
                key: const ValueKey<String>('board.suggest'),
                leading: const Icon(LucideIcons.lightbulb, size: 16),
                onPressed: () => boardInvoke(s, 'shell.board.report', {
                  'kind': 'idea',
                }, context: context),
                child: Text(l.boardSuggestImprovement),
              ),
              SizedBox(
                width: narrow ? double.infinity : 280,
                child: ShadInput(
                  key: const ValueKey<String>('board.search'),
                  controller: _search,
                  placeholder: Text(l.boardSearch),
                  leading: const Icon(LucideIcons.search, size: 16),
                  onChanged: _onSearch,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    setState(() => _query = v.trim());
                  },
                ),
              ),
            ],
          ),
          if (!s.auth.isSignedIn)
            BoardNotice(
              key: const ValueKey<String>('board.signedOutBanner'),
              icon: LucideIcons.logIn,
              text: l.boardSignInToVote,
              tone: theme.colorScheme.info,
              action: ShadButton.outline(
                key: const ValueKey<String>('board.signedOutBanner.signIn'),
                size: ShadButtonSize.sm,
                onPressed: () => boardSignIn(s),
                child: Text(l.boardSignIn),
              ),
            ),
          if (hub.me.value?.blocked == true)
            BoardNotice(
              icon: LucideIcons.ban,
              text: l.boardBlocked,
              tone: theme.colorScheme.destructive,
            ),
          ShadTabs<BoardTab>(
            key: const ValueKey<String>('board.tabs'),
            value: tabs.contains(tab) ? tab : BoardTab.improvements,
            scrollable: true,
            expandTabs: false,
            onChanged: (t) => s.router.go(t.path),
            tabs: [
              for (final t in tabs)
                ShadTab(
                  key: ValueKey<String>('board.tab.${t.name}'),
                  value: t,
                  child: Text(_tabLabel(l, t)),
                ),
            ],
          ),
        ],
      ),
    );
    final Widget body = switch (tab) {
      BoardTab.improvements || BoardTab.bugs || BoardTab.done => BoardPostList(
        key: ValueKey<String>('board.list.${tab.name}'),
        services: s,
        tab: tab,
        query: _query,
      ),
      BoardTab.tasks => BoardTaskList(
        key: const ValueKey<String>('board.tasks'),
        services: s,
        statuses: const [
          BoardTaskStatus.published,
          BoardTaskStatus.claimed,
          BoardTaskStatus.inReview,
        ],
        live: true,
      ),
      BoardTab.review =>
        hub.me.value == null
            ? const Center(child: ShadProgress())
            : BoardReviewTab(services: s),
    };
    return BoardFrame(
      services: s,
      title: l.boardTitle,
      actions: [
        if (!narrow)
          ShadButton.ghost(
            key: const ValueKey<String>('board.contribute'),
            size: ShadButtonSize.sm,
            leading: const Icon(LucideIcons.gitPullRequest, size: 16),
            onPressed: () => s.router.go('/improvements/contribute'),
            child: Text(l.boardContributeLink),
          ),
      ],
      child: BoardContent(
        maxWidth: 1040,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- posts

/// The posts of a board tab (Improvements, Bugs, Done): filter chips, sort,
/// rows, *Load more*, empty states, and the admin selection mode.
class BoardPostList extends StatefulWidget {
  const BoardPostList({
    super.key,
    required this.services,
    required this.tab,
    this.query = '',
  });

  final ShellServices services;
  final BoardTab tab;
  final String query;

  @override
  State<BoardPostList> createState() => _BoardPostListState();
}

class _BoardPostListState extends State<BoardPostList> {
  ShellServices get s => widget.services;
  BoardHub get hub => BoardHub.of(s);

  final List<BoardPostListItem> _items = [];
  String? _cursor;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _generation = 0;

  Set<BoardArea> _areas = {};
  BoardSize? _size;
  late Set<BoardPostStatus> _statuses = _defaultStatuses;
  bool _mine = false;
  BoardSort _sort = BoardSort.trending;

  bool _selecting = false;
  final Set<int> _selected = {};

  StreamSubscription<BoardChange>? _changes;

  bool get _done => widget.tab == BoardTab.done;

  Set<BoardPostStatus> get _defaultStatuses => _done
      ? {BoardPostStatus.done, BoardPostStatus.shipped}
      : {BoardPostStatus.open, BoardPostStatus.planned};

  @override
  void initState() {
    super.initState();
    _changes = hub.changes.listen((c) {
      if (c.lists) unawaited(_load(keep: true));
    });
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BoardPostList old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  BoardListQuery _q(String? cursor, int limit) => BoardListQuery(
    kind: switch (widget.tab) {
      BoardTab.improvements => BoardPostKind.idea,
      BoardTab.bugs => BoardPostKind.bug,
      _ => null,
    },
    statuses: [..._statuses],
    areas: [..._areas],
    sizes: [?_size],
    sort: _sort,
    query: widget.query.isEmpty ? null : widget.query,
    mine: _mine,
    cursor: cursor,
    limit: limit,
  );

  /// Loads the first page; [keep] reloads as many rows as are shown.
  Future<void> _load({bool keep = false}) async {
    final gen = ++_generation;
    final limit = keep && _items.length > boardPageSize
        ? _items.length
        : boardPageSize;
    if (!keep) setState(() => _loading = true);
    try {
      final page = await s.repositories.board.list(_q(null, limit));
      if (!mounted || gen != _generation) return;
      hub.notePosts(page.items);
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _total = page.total;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await s.repositories.board.list(_q(cursor, boardPageSize));
      if (!mounted || gen != _generation) return;
      hub.notePosts(page.items);
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _total = page.total;
      });
    } catch (e) {
      final l = s.l10n;
      if (l != null) {
        s.toasts.error(l.errorGeneric, description: errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _set(VoidCallback change) {
    setState(change);
    unawaited(_load());
  }

  Future<void> _vote(BoardPostListItem item, int value) async {
    if (!s.auth.isSignedIn) return boardSignIn(s);
    final r = await boardInvoke(s, 'shell.board.vote', {
      'postNumber': item.number,
      'value': value,
    }, context: context);
    final data = r?.data;
    if (!mounted || r?.isOk != true || data is! Map) return;
    final i = _items.indexWhere((x) => x.number == item.number);
    if (i < 0) return;
    setState(() {
      _items[i] = _items[i].copyWith(
        score: data['score'] as int?,
        myVote: data['myVote'] as int?,
      );
    });
  }

  Future<void> _createTask() async {
    final r = await boardInvoke(s, 'shell.board.admin.createTask', {
      'postNumbers': [..._selected],
    }, context: context);
    final n = (r?.data as Map?)?['taskNumber'];
    if (r?.isOk == true && mounted) {
      setState(() {
        _selected.clear();
        _selecting = false;
      });
      if (n is int) s.router.go('/improvements/t/$n');
    }
  }

  Future<void> _addToTask() async {
    final r = await boardInvoke(s, 'shell.board.admin.setTaskPosts', {
      'add': [..._selected],
    }, context: context);
    if (r?.isOk == true && mounted) {
      setState(() {
        _selected.clear();
        _selecting = false;
      });
    }
  }

  Widget _filters(WonkyAppLocalizations l, ShadThemeData theme) {
    Widget chip(
      String key,
      String label, {
      required List<WonkyMenuEntry> Function() entries,
      bool active = false,
    }) => WonkyDropdownMenu(
      entries: entries,
      builder: (context, ctl) => ShadButton.raw(
        key: ValueKey<String>('board.filter.$key'),
        variant: active
            ? ShadButtonVariant.secondary
            : ShadButtonVariant.outline,
        size: ShadButtonSize.sm,
        trailing: const Icon(LucideIcons.chevronDown, size: 14),
        onPressed: ctl.toggle,
        child: Text(label),
      ),
    );

    final areaLabel = _areas.isEmpty
        ? l.boardFilterArea
        : '${l.boardFilterArea}: ${_areas.map(l.boardAreaName).join(', ')}';
    final statuses = _done
        ? const [BoardPostStatus.done, BoardPostStatus.shipped]
        : BoardPostStatus.values;
    final hub = this.hub;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip(
          'area',
          areaLabel,
          active: _areas.isNotEmpty,
          entries: () => [
            for (final a in BoardArea.values)
              WonkyMenuCheckItem(
                key: ValueKey<String>('board.filter.area.${a.name}'),
                label: l.boardAreaName(a),
                checked: _areas.contains(a),
                onSelected: () => _set(
                  () => _areas = _areas.contains(a)
                      ? ({..._areas}..remove(a))
                      : {..._areas, a},
                ),
              ),
          ],
        ),
        chip(
          'size',
          _size == null
              ? l.boardFilterSize
              : '${l.boardFilterSize}: ${l.boardSizeName(_size!)}',
          active: _size != null,
          entries: () => [
            WonkyMenuRadioItem(
              key: const ValueKey<String>('board.filter.size.any'),
              label: l.boardFilterAny,
              selected: _size == null,
              onSelected: () => _set(() => _size = null),
            ),
            for (final x in BoardSize.values)
              WonkyMenuRadioItem(
                key: ValueKey<String>('board.filter.size.${x.name}'),
                label: l.boardSizeName(x),
                selected: _size == x,
                onSelected: () => _set(() => _size = x),
              ),
          ],
        ),
        chip(
          'status',
          l.boardFilterStatus,
          active: !_sameSet(_statuses, _defaultStatuses),
          entries: () => [
            for (final x in statuses)
              WonkyMenuCheckItem(
                key: ValueKey<String>('board.filter.status.${x.name}'),
                label: l.boardStatusName(x),
                checked: _statuses.contains(x),
                onSelected: () => _set(() {
                  final next = _statuses.contains(x)
                      ? ({..._statuses}..remove(x))
                      : {..._statuses, x};
                  _statuses = next.isEmpty ? _defaultStatuses : next;
                }),
              ),
          ],
        ),
        if (s.auth.isSignedIn)
          Semantics(
            toggled: _mine,
            button: true,
            child: ShadButton.raw(
              key: const ValueKey<String>('board.filter.mine'),
              variant: _mine
                  ? ShadButtonVariant.secondary
                  : ShadButtonVariant.outline,
              size: ShadButtonSize.sm,
              leading: _mine ? const Icon(LucideIcons.check, size: 14) : null,
              onPressed: () => _set(() => _mine = !_mine),
              child: Text(l.boardFilterMine),
            ),
          ),
        chip(
          'sort',
          '${l.boardSort}: ${l.boardSortName(_sort)}',
          entries: () => [
            for (final x in BoardSort.values)
              WonkyMenuRadioItem(
                key: ValueKey<String>('board.sort.${x.name}'),
                label: l.boardSortName(x),
                selected: _sort == x,
                onSelected: () => _set(() => _sort = x),
              ),
          ],
        ),
        if (hub.isAdmin && !_done)
          ShadButton.ghost(
            key: const ValueKey<String>('board.select'),
            size: ShadButtonSize.sm,
            leading: Icon(
              _selecting ? LucideIcons.x : LucideIcons.squareCheck,
              size: 14,
            ),
            onPressed: () => setState(() {
              _selecting = !_selecting;
              _selected.clear();
            }),
            child: Text(_selecting ? l.boardSelectDone : l.boardSelect),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final pad = narrow ? 16.0 : 24.0;
    final Widget list;
    if (_loading) {
      list = const Center(child: ShadProgress(key: ValueKey('board.loading')));
    } else if (_error != null && _items.isEmpty) {
      list = WonkyEmptyState(
        key: const ValueKey<String>('board.error'),
        illustration: EmptyIllustration.error,
        title: l.boardLoadFailed,
        description: errorMessage(_error!),
        actions: [
          ShadButton.outline(onPressed: _load, child: Text(l.actionRetry)),
        ],
      );
    } else if (_items.isEmpty) {
      list = WonkyEmptyState(
        key: const ValueKey<String>('board.empty'),
        illustration: widget.query.isNotEmpty
            ? EmptyIllustration.search
            : EmptyIllustration.comments,
        title: widget.query.isNotEmpty
            ? l.boardEmptySearch
            : switch (widget.tab) {
                BoardTab.bugs => l.boardEmptyBugs,
                BoardTab.done => l.boardEmptyDone,
                _ => l.boardEmptyIdeas,
              },
        description: widget.query.isNotEmpty || _done ? null : l.boardEmptyHint,
      );
    } else {
      list = ListView.builder(
        key: const ValueKey<String>('board.rows'),
        padding: EdgeInsets.fromLTRB(pad, 4, pad, 24),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Text(
                    l.boardShowing(_items.length, _total),
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                  if (_cursor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ShadButton.outline(
                        key: const ValueKey<String>('board.loadMore'),
                        enabled: !_loadingMore,
                        onPressed: _loadMore,
                        child: Text(l.boardLoadMore),
                      ),
                    ),
                ],
              ),
            );
          }
          final item = _items[i];
          return BoardPostRow(
            key: ValueKey<String>('board.row.${item.number}'),
            services: s,
            item: item,
            narrow: narrow,
            onVote: (v) => _vote(item, v),
            selected: _selecting ? _selected.contains(item.number) : null,
            onSelected: (v) => setState(
              () => v
                  ? _selected.add(item.number)
                  : _selected.remove(item.number),
            ),
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
          child: _filters(l, theme),
        ),
        Expanded(
          child: _done ? _DoneLayout(services: s, posts: list) : list,
        ),
        if (_selecting && _selected.isNotEmpty)
          Container(
            key: const ValueKey<String>('board.selectionBar'),
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              border: Border(top: BorderSide(color: theme.colorScheme.border)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l.boardSelected(_selected.length)),
                ShadButton(
                  key: const ValueKey<String>('board.selection.createTask'),
                  size: ShadButtonSize.sm,
                  onPressed: _createTask,
                  child: Text(l.boardCreateTaskFrom(_selected.length)),
                ),
                ShadButton.outline(
                  key: const ValueKey<String>('board.selection.addToTask'),
                  size: ShadButtonSize.sm,
                  onPressed: _addToTask,
                  child: Text(l.boardAddToTaskEllipsis),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

/// The Done tab: finished tasks above the done and shipped posts.
class _DoneLayout extends StatelessWidget {
  const _DoneLayout({required this.services, required this.posts});

  final ShellServices services;
  final Widget posts;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: BoardTaskList(
            key: const ValueKey<String>('board.doneTasks'),
            services: services,
            statuses: const [BoardTaskStatus.done, BoardTaskStatus.shipped],
            compact: true,
            title: l.boardDoneTasks,
            horizontalPadding: narrow ? 16 : 24,
          ),
        ),
        Expanded(child: posts),
      ],
    );
  }
}

/// One post in the board list (specs/16 §4.4): the vote control, title,
/// labels, status, comment count, author and age, screenshot icon. `+` /
/// `-` on the focused row vote (specs/16 §4.7); Enter opens the post.
class BoardPostRow extends StatefulWidget {
  const BoardPostRow({
    super.key,
    required this.services,
    required this.item,
    required this.onVote,
    this.narrow = false,
    this.selected,
    this.onSelected,
  });

  final ShellServices services;
  final BoardPostListItem item;
  final ValueChanged<int> onVote;
  final bool narrow;

  /// Non-null in the admin selection mode.
  final bool? selected;
  final ValueChanged<bool>? onSelected;

  @override
  State<BoardPostRow> createState() => _BoardPostRowState();
}

class _BoardPostRowState extends State<BoardPostRow> {
  bool _focused = false;
  bool _hover = false;

  BoardPostListItem get item => widget.item;

  bool get _votingOpen =>
      item.status == BoardPostStatus.open ||
      item.status == BoardPostStatus.planned;

  void _open() => widget.services.router.go('/improvements/p/${item.number}');

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final plus =
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd ||
        k == LogicalKeyboardKey.equal ||
        e.character == '+';
    final minus =
        k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract ||
        e.character == '-';
    if (plus || minus) {
      if (!_votingOpen) return KeyEventResult.handled;
      final bug = item.kind == BoardPostKind.bug;
      final int value;
      if (plus) {
        value = item.myVote == 1 ? 0 : 1;
      } else {
        value = bug || item.myVote == -1 ? 0 : -1;
      }
      if (value != item.myVote) widget.onVote(value);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      _open();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.muted.copyWith(fontSize: 12);
    final vote = BoardVoteControl(
      number: item.number,
      kind: item.kind,
      score: item.score,
      voteCount: item.voteCount,
      myVote: item.myVote,
      onVote: _votingOpen ? widget.onVote : null,
    );
    final task = item.task;
    final meta = <Widget>[
      ...boardLabelChips(
        l,
        area: item.area,
        size: item.size,
        ai: item.aiLabels,
      ),
      BoardStatusBadge(
        status: item.status,
        label: task != null && item.status == BoardPostStatus.planned
            ? l.boardPlannedIn(task.number)
            : l.boardStatusName(item.status),
        onTap: task == null
            ? null
            : () => widget.services.router.go('/improvements/t/${task.number}'),
      ),
      if (item.moderation != BoardModeration.visible)
        BoardChip(label: l.boardModerationName(item.moderation)),
      Semantics(
        label: l.boardCommentCount(item.commentCount),
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            Icon(
              LucideIcons.messageSquare,
              size: 13,
              color: cs.mutedForeground,
            ),
            Text('${item.commentCount}', style: muted),
          ],
        ),
      ),
      if (item.hasScreenshot)
        Semantics(
          label: l.boardHasScreenshot,
          excludeSemantics: true,
          child: Icon(LucideIcons.camera, size: 14, color: cs.mutedForeground),
        ),
      BoardAuthorLine(
        author: item.author,
        createdAt: item.createdAt,
        avatar: false,
      ),
    ];
    final title = Text(
      item.title,
      style: theme.textTheme.p.copyWith(
        fontWeight: FontWeight.w500,
        decoration: _hover ? TextDecoration.underline : null,
      ),
      maxLines: widget.narrow ? 3 : 2,
      overflow: TextOverflow.ellipsis,
    );
    final selected = widget.selected;
    return Focus(
      onKeyEvent: _onKey,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Semantics(
        container: true,
        label: '#${item.number} ${item.title}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: _hover || _focused
                    ? cs.muted.withValues(alpha: 0.5)
                    : null,
                border: Border(
                  bottom: BorderSide(color: cs.border),
                  left: BorderSide(
                    color: _focused ? cs.ring : const Color(0x00000000),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ShadCheckbox(
                        key: ValueKey<String>(
                          'board.row.${item.number}.select',
                        ),
                        value: selected,
                        onChanged: widget.onSelected,
                      ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 56),
                    child: Center(widthFactor: 1, child: vote),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6,
                          children: [
                            Text('#${item.number}', style: muted),
                            Expanded(child: title),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: meta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
