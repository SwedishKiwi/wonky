import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../../data/api.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/page_frame.dart';
import '../../shell/shell_services.dart';
import '../board_hub.dart';
import 'board_labels.dart';
import 'board_widgets.dart';
import 'task_list.dart';

/// The admins' Review tab (`/improvements/review`, specs/16 §9.2): Held,
/// Check, Unchecked, Possible duplicates, Suggested bundles and Draft
/// tasks, each with its count and actions.
class BoardReviewTab extends StatefulWidget {
  const BoardReviewTab({super.key, required this.services});

  final ShellServices services;

  @override
  State<BoardReviewTab> createState() => _BoardReviewTabState();
}

/// The moderation scores that put a post in the review queue (the server's
/// [BoardPostView.reviewScores]: at or above their review band), best
/// first: `spam 0.91 · not_actionable 0.62`. Null when there are none.
String? boardReviewScoresText(Map<String, double>? scores) {
  if (scores == null || scores.isEmpty) return null;
  final sorted = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in sorted) '${e.key} ${e.value.toStringAsFixed(2)}',
  ].join(' · ');
}

class _BoardReviewTabState extends State<BoardReviewTab> {
  ShellServices get s => widget.services;

  BoardReviewCounts? _counts;
  final Map<BoardReviewSection, List<BoardReviewItem>> _items = {};
  List<BoardBundleSuggestionView> _bundles = const [];
  bool _loading = true;
  bool _suggesting = false;
  Object? _error;
  StreamSubscription<BoardChange>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = BoardHub.of(s).changes.listen((_) => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = s.repositories.board;
    try {
      final counts = await repo.reviewCounts();
      final items = {
        for (final x in BoardReviewSection.values) x: await repo.reviewQueue(x),
      };
      final bundles = await repo.listSuggestions();
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _items
          ..clear()
          ..addAll(items);
        _bundles = bundles;
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

  Future<CommandResult?> _invoke(String id, Map<String, Object?> args) =>
      boardInvoke(s, id, args, context: context);

  /// Creates a task and opens it (the AI writes its prompt in the
  /// background, specs/16 §10.1).
  Future<void> _createTask(Map<String, Object?> args) async {
    final r = await _invoke('shell.board.admin.createTask', args);
    final t = (r?.data as Map?)?['taskNumber'];
    if (r?.isOk == true && t is int && mounted) {
      s.router.go('/improvements/t/$t');
    }
  }

  Future<void> _suggest() async {
    setState(() => _suggesting = true);
    await _invoke('shell.board.admin.suggestBundles', const {});
    if (mounted) setState(() => _suggesting = false);
  }

  int _count(BoardReviewSection x) {
    final c = _counts;
    if (c == null) return _items[x]?.length ?? 0;
    return switch (x) {
      BoardReviewSection.held => c.held,
      BoardReviewSection.check => c.check,
      BoardReviewSection.unchecked => c.unchecked,
      BoardReviewSection.duplicates => c.duplicates,
      BoardReviewSection.drafts => c.drafts,
    };
  }

  String _title(WonkyAppLocalizations l, BoardReviewSection x) => switch (x) {
    BoardReviewSection.held => l.boardReviewHeld,
    BoardReviewSection.check => l.boardReviewCheck,
    BoardReviewSection.unchecked => l.boardReviewUnchecked,
    BoardReviewSection.duplicates => l.boardReviewDuplicates,
    BoardReviewSection.drafts => l.boardReviewDrafts,
  };

  Widget _sectionTitle(
    String key,
    String title,
    int count, {
    Widget? trailing,
  }) {
    final theme = ShadTheme.of(context);
    return Padding(
      key: ValueKey<String>('board.review.$key'),
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: Row(
        spacing: 8,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.h4),
          ),
          ShadBadge.secondary(
            key: ValueKey<String>('board.review.$key.count'),
            child: Text('$count'),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }

  Widget _postItem(
    WonkyAppLocalizations l,
    BoardReviewSection section,
    BoardPostView p,
  ) {
    final theme = ShadTheme.of(context);
    final muted = theme.textTheme.muted.copyWith(fontSize: 12);
    final n = p.number;
    Widget button(
      String key,
      String label,
      VoidCallback f, {
      bool primary = false,
    }) => (primary ? ShadButton.new : ShadButton.outline)(
      key: ValueKey<String>('board.review.${section.name}.$n.$key'),
      size: ShadButtonSize.sm,
      onPressed: f,
      child: Text(label),
    );
    void moderate(String action) => _invoke('shell.board.admin.moderate', {
      'postNumber': n,
      'action': action,
    });
    final dup = p.possibleDuplicateOfNumber;
    final actions = switch (section) {
      BoardReviewSection.held => [
        button(
          'approve',
          l.boardActionApprove,
          () => moderate('approve'),
          primary: true,
        ),
        button('remove', l.boardActionRemoveEllipsis, () => moderate('remove')),
        button(
          'editApprove',
          l.boardEditAndApprove,
          () => _invoke('shell.board.admin.editPost', {
            'postNumber': n,
            'approve': true,
          }),
        ),
      ],
      BoardReviewSection.check || BoardReviewSection.unchecked => [
        button(
          'fine',
          l.boardActionLooksFine,
          () => moderate('markChecked'),
          primary: true,
        ),
        button('hold', l.boardActionHold, () => moderate('hold')),
      ],
      BoardReviewSection.duplicates => [
        if (dup != null)
          button(
            'merge',
            l.boardActionMerge,
            () => _invoke('shell.board.admin.merge', {
              'source': n,
              'target': dup,
            }),
            primary: true,
          ),
        button(
          'notDuplicate',
          l.cmdBoardNotDuplicate,
          () =>
              _invoke('shell.board.admin.dismissDuplicate', {'postNumber': n}),
        ),
      ],
      BoardReviewSection.drafts => const <Widget>[],
    };
    final scores = boardReviewScoresText(p.reviewScores);
    final flags = p.flags ?? const [];
    return BoardListTile(
      key: ValueKey<String>('board.review.${section.name}.$n'),
      semanticLabel: '#$n ${p.title}',
      onTap: () => s.router.go('/improvements/p/$n'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(
            '#$n ${p.title}',
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w500),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BoardChip(label: l.boardKindName(p.kind)),
              BoardAuthorLine(author: p.author, createdAt: p.createdAt),
              if (dup != null)
                Text(l.boardPossibleDuplicate(dup), style: muted),
            ],
          ),
          if (p.moderationReason case final r?
              when section == BoardReviewSection.held)
            Text(r, style: muted),
          if (scores != null)
            Text(
              '${l.boardAiScores}: $scores',
              key: ValueKey<String>('board.review.${section.name}.$n.scores'),
              style: muted,
            ),
          if (flags.isNotEmpty)
            Text(
              l.boardFlags(
                flags.length,
                flags.map((f) => l.boardFlagReasonName(f.reason)).join(', '),
              ),
              style: muted,
            ),
          Wrap(spacing: 8, runSpacing: 6, children: actions),
        ],
      ),
    );
  }

  Widget _commentItem(WonkyAppLocalizations l, BoardCommentView c) {
    final theme = ShadTheme.of(context);
    final id = c.uuid.uuid;
    void moderate(String action) => _invoke('shell.board.admin.moderate', {
      'commentUuid': id,
      'action': action,
    });
    final where = c.postNumber != null
        ? '/improvements/p/${c.postNumber}'
        : '/improvements/t/${c.taskNumber}';
    return BoardListTile(
      key: ValueKey<String>('board.review.held.comment.$id'),
      onTap: () => s.router.go(where),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(
            c.postNumber != null
                ? l.boardCommentOnPost(c.postNumber!)
                : l.boardCommentOnTask(c.taskNumber ?? 0),
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w500),
          ),
          BoardAuthorLine(author: c.author, createdAt: c.createdAt),
          Text(
            c.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.normal,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              ShadButton(
                key: ValueKey<String>('board.review.held.comment.$id.approve'),
                size: ShadButtonSize.sm,
                onPressed: () => moderate('approve'),
                child: Text(l.boardActionApprove),
              ),
              ShadButton.outline(
                key: ValueKey<String>('board.review.held.comment.$id.remove'),
                size: ShadButtonSize.sm,
                onPressed: () => moderate('remove'),
                child: Text(l.boardActionRemoveEllipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bundle(WonkyAppLocalizations l, BoardBundleSuggestionView b) {
    final theme = ShadTheme.of(context);
    final numbers = [for (final p in b.posts) p.number];
    final first = b.posts.isEmpty ? null : b.posts.first;
    return BoardListTile(
      key: ValueKey<String>('board.review.bundle.${b.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(
            b.title,
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(b.rationale, style: theme.textTheme.muted),
          for (final p in b.posts)
            GestureDetector(
              onTap: () => s.router.go('/improvements/p/${p.number}'),
              child: Text(
                '#${p.number} ${p.title} (${l.boardScore(p.score)})',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              ShadButton(
                key: ValueKey<String>('board.review.bundle.${b.id}.create'),
                size: ShadButtonSize.sm,
                onPressed: numbers.isEmpty
                    ? null
                    : () => _createTask({
                        'postNumbers': numbers,
                        'title': b.title,
                        'area': (b.area ?? first?.area ?? BoardArea.suite).name,
                        'size': BoardSize.small.name,
                      }),
                child: Text(l.boardActionCreateTask),
              ),
              ShadButton.outline(
                key: ValueKey<String>('board.review.bundle.${b.id}.edit'),
                size: ShadButtonSize.sm,
                onPressed: numbers.isEmpty
                    ? null
                    : () => _createTask({'postNumbers': numbers}),
                child: Text(l.boardEditEllipsis),
              ),
              ShadButton.ghost(
                key: ValueKey<String>('board.review.bundle.${b.id}.dismiss'),
                size: ShadButtonSize.sm,
                onPressed: () => _invoke(
                  'shell.board.admin.dismissSuggestion',
                  {'id': b.id},
                ),
                child: Text(l.boardDismiss),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final rowInset = math.max(
      0.0,
      shellPageInset(MediaQuery.sizeOf(context).width) - 8,
    );
    if (_loading) return const BoardListLoading();
    if (_error != null && _counts == null) {
      return WonkyEmptyState(
        illustration: EmptyIllustration.error,
        title: l.boardLoadFailed,
        description: errorMessage(_error!),
        actions: [
          ShadButton.outline(onPressed: _load, child: Text(l.actionRetry)),
        ],
      );
    }
    final empty = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(l.boardReviewEmpty, style: theme.textTheme.muted),
    );
    final children = <Widget>[];
    for (final x in [
      BoardReviewSection.held,
      BoardReviewSection.check,
      BoardReviewSection.unchecked,
      BoardReviewSection.duplicates,
    ]) {
      final items = _items[x] ?? const [];
      children
        ..add(_sectionTitle(x.name, _title(l, x), _count(x)))
        ..addAll([
          for (final i in items)
            if (i.post case final p?)
              _postItem(l, x, p)
            else if (i.comment case final c?)
              _commentItem(l, c),
        ]);
      if (items.isEmpty) children.add(empty);
    }
    children.add(
      _sectionTitle(
        'bundles',
        l.boardReviewBundles,
        _bundles.length,
        trailing: ShadButton.outline(
          key: const ValueKey<String>('board.review.suggestBundles'),
          size: ShadButtonSize.sm,
          enabled: !_suggesting,
          leading: const Icon(LucideIcons.sparkles, size: 14),
          onPressed: _suggest,
          child: Text(l.cmdBoardSuggestBundles),
        ),
      ),
    );
    children.addAll([for (final b in _bundles) _bundle(l, b)]);
    if (_bundles.isEmpty) children.add(empty);
    final drafts = _items[BoardReviewSection.drafts] ?? const [];
    children.add(
      _sectionTitle(
        'drafts',
        _title(l, BoardReviewSection.drafts),
        _count(BoardReviewSection.drafts),
      ),
    );
    children.addAll([
      for (final i in drafts)
        if (i.task case final t?) BoardTaskRow(services: s, task: t),
    ]);
    if (drafts.isEmpty) children.add(empty);
    // Not lazy: the queue is short, and every section stays findable
    // (tests, MCP).
    return SingleChildScrollView(
      key: const ValueKey<String>('board.review'),
      padding: EdgeInsets.fromLTRB(rowInset, 0, rowInset, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
