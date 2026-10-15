import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../core/stream_supervisor.dart';
import '../../data/api.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../board_hub.dart';
import 'board_labels.dart';
import 'board_widgets.dart';

/// The claim state of a task: *Claimed by Ada · 31 h left*, *In review*,
/// or *Up for grabs*.
String boardClaimState(WonkyAppLocalizations l, BoardTaskView t) {
  final by = t.claimedBy?.displayName;
  final until = t.claimExpiresAt;
  switch (t.status) {
    case BoardTaskStatus.claimed when by != null && until != null:
      final hours = until.difference(clock.now()).inHours.clamp(0, 999);
      return l.boardClaimedBy(by, hours);
    case BoardTaskStatus.inReview:
      return by == null ? l.boardTaskInReview : l.boardInReviewBy(by);
    case BoardTaskStatus.published:
      return l.boardUpForGrabs;
    default:
      return l.boardTaskStatusName(t.status);
  }
}

/// Tasks with [statuses] (*Up for grabs*: published, claimed and in
/// review; Done: done and shipped). [live] follows `board.watchTasks`.
class BoardTaskList extends StatefulWidget {
  const BoardTaskList({
    super.key,
    required this.services,
    required this.statuses,
    this.live = false,
    this.compact = false,
    this.title,
    this.horizontalPadding = 24,
  });

  final ShellServices services;
  final List<BoardTaskStatus> statuses;
  final bool live;

  /// Shrink-wrapped (a section above the Done posts); nothing when empty.
  final bool compact;
  final String? title;
  final double horizontalPadding;

  @override
  State<BoardTaskList> createState() => _BoardTaskListState();
}

class _BoardTaskListState extends State<BoardTaskList> {
  ShellServices get s => widget.services;

  final List<BoardTaskView> _items = [];
  String? _cursor;
  bool _loading = true;
  Object? _error;
  SupervisedStream? _watch;
  StreamSubscription<BoardChange>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = BoardHub.of(s).changes.listen((c) {
      if (c.task != null || c.lists) unawaited(_load());
    });
    if (widget.live) {
      _watch = s.supervisor.supervise<BoardPostEvent>(
        'board.tasks.list',
        () => s.repositories.board.watchTasks(),
        (_) => unawaited(_load()),
      );
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    unawaited(_watch?.cancel());
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    try {
      final page = await s.repositories.board.listTasks(
        widget.statuses,
        cursor: more ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final pad = widget.horizontalPadding;
    if (widget.compact) {
      if (_items.isEmpty) return const SizedBox.shrink();
      return ListView(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(horizontal: pad),
        children: [
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(widget.title!, style: theme.textTheme.small),
            ),
          for (final t in _items) BoardTaskRow(services: s, task: t),
        ],
      );
    }
    if (_loading) return const Center(child: ShadProgress());
    if (_error != null && _items.isEmpty) {
      return WonkyEmptyState(
        illustration: EmptyIllustration.error,
        title: l.boardLoadFailed,
        description: errorMessage(_error!),
        actions: [
          ShadButton.outline(onPressed: _load, child: Text(l.actionRetry)),
        ],
      );
    }
    if (_items.isEmpty) {
      return WonkyEmptyState(
        key: const ValueKey<String>('board.tasks.empty'),
        illustration: EmptyIllustration.documents,
        title: l.boardEmptyTasks,
        description: l.boardEmptyTasksHint,
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
      children: [
        for (final t in _items) BoardTaskRow(services: s, task: t),
        if (_cursor != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: ShadButton.outline(
                key: const ValueKey<String>('board.tasks.loadMore'),
                onPressed: () => _load(more: true),
                child: Text(l.boardLoadMore),
              ),
            ),
          ),
      ],
    );
  }
}

/// One task: `T-12`, title, labels, status and claim state, post count.
class BoardTaskRow extends StatelessWidget {
  const BoardTaskRow({super.key, required this.services, required this.task});

  final ShellServices services;
  final BoardTaskView task;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final muted = theme.textTheme.muted.copyWith(fontSize: 12);
    final t = task;
    void open() => services.router.go('/improvements/t/${t.number}');
    return Semantics(
      button: true,
      label: 'T-${t.number} ${t.title}, ${boardClaimState(l, t)}',
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              open();
              return null;
            },
          ),
        },
        child: GestureDetector(
          key: ValueKey<String>('board.task.${t.number}'),
          behavior: HitTestBehavior.opaque,
          onTap: open,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Text('T-${t.number}', style: muted),
                    Expanded(
                      child: Text(
                        t.title,
                        style: theme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...boardLabelChips(l, area: t.area, size: t.size),
                    BoardStatusBadge(
                      status: t.status,
                      label: l.boardTaskStatusName(t.status),
                    ),
                    Text(boardClaimState(l, t), style: muted),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 3,
                      children: [
                        Icon(
                          LucideIcons.layers,
                          size: 13,
                          color: theme.colorScheme.mutedForeground,
                        ),
                        Text(l.boardPostCount(t.posts.length), style: muted),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
