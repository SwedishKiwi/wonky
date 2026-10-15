import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../../comments/comments_panel.dart';
import '../../core/stream_supervisor.dart';
import '../../data/api.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/dialogs.dart';
import '../../shell/form_dialog.dart';
import '../../shell/page_frame.dart';
import '../../shell/shell_services.dart';
import '../board_commands.dart';
import '../board_hub.dart';
import 'board_comment_actions.dart';
import 'board_labels.dart';
import 'board_widgets.dart';
import 'contribute_page.dart';
import 'task_list.dart';

/// The task page (`/improvements/t/:number`, specs/16 §4.6): status and
/// claim, *Claim this task* / *Release*, the claimant's claim code and PR
/// lines, linked posts, *How to build it* with the prompt, the pull request
/// and its review, activity and discussion, and the admin actions.
class BoardTaskPage extends StatefulWidget {
  const BoardTaskPage({
    super.key,
    required this.services,
    required this.number,
  });

  final ShellServices services;
  final int number;

  @override
  State<BoardTaskPage> createState() => _BoardTaskPageState();
}

class _BoardTaskPageState extends State<BoardTaskPage> {
  ShellServices get s => widget.services;
  BoardHub get hub => BoardHub.of(s);
  int get n => widget.number;

  BoardTaskView? _task;
  List<BoardCommentView> _comments = const [];
  Object? _error;
  bool _loading = true;
  bool _howToOpen = true;
  SupervisedStream? _watch;
  StreamSubscription<BoardChange>? _changes;

  static const _howToSeenKey = 'board.howToSeen';

  @override
  void initState() {
    super.initState();
    hub.me.addListener(_onMe);
    unawaited(hub.loadMe());
    _changes = hub.changes.listen((c) {
      if (c.touchesTask(n) || c.post != null) unawaited(_load());
    });
    _watch = s.supervisor.supervise<BoardPostEvent>(
      'board.task.$n',
      () => s.repositories.board.watchTasks(),
      (e) {
        if (e.number == n) unawaited(_load());
      },
    );
    unawaited(_initHowTo());
    unawaited(_load());
  }

  Future<void> _initHowTo() async {
    try {
      final seen = await s.deviceStore.read(_howToSeenKey) == true;
      if (seen && mounted) setState(() => _howToOpen = false);
      if (!seen) await s.deviceStore.write(_howToSeenKey, true);
    } catch (_) {}
  }

  @override
  void dispose() {
    hub.me.removeListener(_onMe);
    _changes?.cancel();
    unawaited(_watch?.cancel());
    super.dispose();
  }

  void _onMe() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final repo = s.repositories.board;
    try {
      final t = await repo.getTask(n);
      final comments = await repo.listTaskComments(n);
      hub
        ..notePosts(t.posts)
        ..noteComments(comments);
      if (!mounted) return;
      setState(() {
        _task = t;
        _comments = comments;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<CommandResult?> _invoke(String id, [Map<String, Object?>? args]) =>
      boardInvoke(s, id, args ?? {'taskNumber': n}, context: context);

  Future<void> _editPrompt() async {
    final r = await _invoke('shell.board.admin.setPrompt');
    final data = r?.data;
    if (r?.isOk == true && data is Map && data['publish'] == true) {
      await _invoke('shell.board.admin.publishTask');
    }
  }

  Future<void> _addPosts() async {
    final l = WonkyAppLocalizations.of(context);
    final r = await showWonkyFormDialog(
      context,
      WonkyDialogSpec(
        title: l.boardAddPosts,
        dialogKey: 'dialog.board.addPosts',
        fields: [
          TextFieldSpec(
            id: 'posts',
            label: l.boardFieldPostNumbers,
            placeholder: '#412, #388',
            validator: (v) =>
                _numbers(v).isEmpty ? l.boardInvalidPostNumber : null,
          ),
        ],
        buttons: [
          DialogButtonSpec(id: 'cancel', label: l.actionCancel),
          DialogButtonSpec(id: 'ok', label: l.boardActionAdd, primary: true),
        ],
      ),
    );
    if (r?.buttonId != 'ok') return;
    await _invoke('shell.board.admin.setTaskPosts', {
      'taskNumber': n,
      'add': _numbers(r!.text('posts')),
    });
  }

  static List<int> _numbers(String v) => [
    for (final m in RegExp(r'\d+').allMatches(v)) int.parse(m[0]!),
  ];

  List<WonkyMenuEntry> _adminMenu(WonkyAppLocalizations l, BoardTaskView t) {
    WonkyMenuItem item(
      String key,
      String label,
      IconData icon,
      VoidCallback f, {
      bool destructive = false,
    }) => WonkyMenuItem(
      key: ValueKey<String>('board.task.menu.$key'),
      label: label,
      icon: icon,
      destructive: destructive,
      onSelected: f,
    );
    final active = {
      BoardTaskStatus.published,
      BoardTaskStatus.claimed,
      BoardTaskStatus.inReview,
    }.contains(t.status);
    return [
      item(
        'editTask',
        l.cmdBoardEditTask,
        LucideIcons.pencil,
        () => _invoke('shell.board.admin.updateTask'),
      ),
      item('addPosts', l.boardAddPosts, LucideIcons.listPlus, _addPosts),
      if (t.claimedBy != null)
        item(
          'releaseClaim',
          l.boardReleaseClaim,
          LucideIcons.undo2,
          () => _invoke('shell.board.release'),
        ),
      if (active)
        item(
          'linkPr',
          l.cmdBoardLinkPr,
          LucideIcons.gitPullRequest,
          () => _invoke('shell.board.admin.linkPullRequest'),
        ),
      if (t.status != BoardTaskStatus.done &&
          t.status != BoardTaskStatus.shipped &&
          t.status != BoardTaskStatus.draft)
        item(
          'markDone',
          l.cmdBoardMarkDone,
          LucideIcons.circleCheck,
          () => _invoke('shell.board.admin.markDone'),
        ),
      if (t.status == BoardTaskStatus.done)
        item(
          'markShipped',
          l.cmdBoardMarkShipped,
          LucideIcons.rocket,
          () => _invoke('shell.board.admin.markShipped'),
        ),
      if (t.status != BoardTaskStatus.cancelled)
        item(
          'cancel',
          l.cmdBoardCancelTask,
          LucideIcons.circleX,
          () => _invoke('shell.board.admin.cancelTask'),
          destructive: true,
        ),
    ];
  }

  Widget _header(
    WonkyAppLocalizations l,
    ShadThemeData theme,
    BoardTaskView t,
  ) {
    final admin = hub.isAdmin;
    final signedIn = s.auth.isSignedIn;
    final claimable = t.status == BoardTaskStatus.published;
    final until = t.claimExpiresAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text('T-${t.number}', style: theme.textTheme.muted),
                  Semantics(
                    header: true,
                    child: Text(
                      t.title,
                      key: const ValueKey<String>('board.task.title'),
                      style: theme.textTheme.h3,
                    ),
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
                      Text(
                        boardClaimState(l, t),
                        key: const ValueKey<String>('board.task.claimState'),
                        style: theme.textTheme.small,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (admin)
              WonkyDropdownMenu(
                anchor: const ShadAnchor(
                  childAlignment: AlignmentDirectional.bottomEnd,
                  overlayAlignment: AlignmentDirectional.topEnd,
                ),
                entries: () => _adminMenu(l, t),
                builder: (context, ctl) => ShadIconButton.ghost(
                  key: const ValueKey<String>('board.task.menu'),
                  semanticLabel: l.boardAdminActions,
                  icon: const Icon(LucideIcons.ellipsisVertical),
                  onPressed: ctl.toggle,
                ),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (claimable && signedIn)
              ShadButton(
                key: const ValueKey<String>('board.task.claim'),
                leading: const Icon(LucideIcons.hand, size: 16),
                enabled: hub.canWrite,
                onPressed: () => _invoke('shell.board.claim'),
                child: Text(l.boardClaimTask),
              ),
            if (claimable && !signedIn)
              ShadButton.outline(
                key: const ValueKey<String>('board.task.signInToClaim'),
                onPressed: () => boardSignIn(s),
                child: Text(l.boardSignInToClaim),
              ),
            if (t.isMine)
              ShadButton.outline(
                key: const ValueKey<String>('board.task.release'),
                leading: const Icon(LucideIcons.undo2, size: 16),
                onPressed: () => _invoke('shell.board.release'),
                child: Text(l.cmdBoardRelease),
              ),
            if (admin && t.status == BoardTaskStatus.draft) ...[
              ShadButton(
                key: const ValueKey<String>('board.task.editPrompt'),
                leading: const Icon(LucideIcons.squarePen, size: 16),
                onPressed: _editPrompt,
                child: Text(l.cmdBoardEditPrompt),
              ),
              ShadButton.outline(
                key: const ValueKey<String>('board.task.publish'),
                leading: const Icon(LucideIcons.send, size: 16),
                // The prompt needs a review after the AI wrote it.
                enabled: !t.promptPending,
                onPressed: () => _invoke('shell.board.admin.publishTask'),
                child: Text(l.cmdBoardPublishTask),
              ),
            ] else if (admin) ...[
              ShadButton.outline(
                key: const ValueKey<String>('board.task.editPrompt'),
                leading: const Icon(LucideIcons.squarePen, size: 16),
                onPressed: _editPrompt,
                child: Text(l.cmdBoardEditPrompt),
              ),
              if (t.status == BoardTaskStatus.claimed ||
                  t.status == BoardTaskStatus.published)
                ShadButton.outline(
                  key: const ValueKey<String>('board.task.linkPr'),
                  leading: const Icon(LucideIcons.gitPullRequest, size: 16),
                  onPressed: () => _invoke('shell.board.admin.linkPullRequest'),
                  child: Text(l.cmdBoardLinkPr),
                ),
            ],
          ],
        ),
        // Like the *Copy this token now* alert of Settings › Developer.
        if (t.isMine && t.claimCode != null)
          ShadAlert(
            key: const ValueKey<String>('board.task.claimCode'),
            icon: const Icon(LucideIcons.keyRound, size: 16),
            titleStyle: theme.textTheme.small,
            title: Text(l.boardYourClaimCode),
            description: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                const SizedBox(height: 2),
                Row(
                  spacing: 8,
                  children: [
                    Flexible(
                      child: Text(
                        t.claimCode!,
                        key: const ValueKey<String>(
                          'board.task.claimCode.text',
                        ),
                        style: boardCodeStyle(theme).copyWith(fontSize: 16),
                      ),
                    ),
                    ShadButton.outline(
                      key: const ValueKey<String>('board.task.copyClaimCode'),
                      size: ShadButtonSize.sm,
                      leading: const Icon(LucideIcons.copy, size: 14),
                      onPressed: () => _invoke('shell.board.copyClaimCode'),
                      child: Text(l.boardCopy),
                    ),
                  ],
                ),
                if (until != null && t.status == BoardTaskStatus.claimed)
                  Text(
                    l.boardTimeLeft(
                      until.difference(clock.now()).inHours.clamp(0, 999),
                    ),
                  ),
                Text(l.boardClaimCodeHint),
              ],
            ),
          ),
      ],
    );
  }

  Widget _howTo(WonkyAppLocalizations l, ShadThemeData theme, BoardTaskView t) {
    final code = t.isMine ? t.claimCode : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: BoardDisclosure(
            tapKey: 'board.task.howTo',
            open: _howToOpen,
            iconSize: 18,
            onToggle: () => setState(() => _howToOpen = !_howToOpen),
            label: Text(l.boardHowToBuild, style: theme.textTheme.h4),
          ),
        ),
        if (_howToOpen)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Text(l.boardStepSetup, style: theme.textTheme.small),
              for (final (i, c) in boardSetupCommands(
                boardRepository(s),
              ).indexed)
                BoardCopyLine(text: c, copyKey: 'board.task.setup.$i'),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ShadButton.link(
                  key: const ValueKey<String>('board.task.contribute'),
                  size: ShadButtonSize.sm,
                  padding: EdgeInsets.zero,
                  onPressed: () => s.router.go('/improvements/contribute'),
                  child: Text(l.boardFullGuide),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.boardStepPrompt,
                      style: theme.textTheme.small,
                    ),
                  ),
                  ShadButton.outline(
                    key: const ValueKey<String>('board.task.copyPrompt'),
                    size: ShadButtonSize.sm,
                    leading: const Icon(LucideIcons.copy, size: 14),
                    onPressed: () => _invoke('shell.board.copyPrompt'),
                    child: Text(l.cmdBoardCopyPrompt),
                  ),
                ],
              ),
              // The code block style of BoardCopyLine and the Markdown
              // code blocks.
              Container(
                key: const ValueKey<String>('board.task.prompt'),
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(maxHeight: 420),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: Text(t.prompt, style: boardCodeStyle(theme)),
                ),
              ),
              Text(l.boardStepPr, style: theme.textTheme.small),
              Text(l.boardPrRules, style: theme.textTheme.muted),
              BoardCopyLine(
                text: boardPrLines(
                  t.number,
                  code ?? l.boardClaimCodePlaceholder,
                ),
                copyKey: 'board.task.prLines',
              ),
            ],
          ),
      ],
    );
  }

  /// The latest PR review (specs/16 §13.5; shape in
  /// `platform/board/github/README.md`): summary, a verdict per acceptance
  /// criterion, tests and specs, risks and unrelated changes.
  Widget _review(WonkyAppLocalizations l, ShadThemeData theme, String json) {
    Map<String, Object?> r;
    try {
      r = (jsonDecode(json) as Map).cast<String, Object?>();
    } catch (_) {
      return Text(json, style: theme.textTheme.muted);
    }
    final cs = theme.colorScheme;
    final muted = theme.textTheme.muted;
    String verdict(Object? v) => switch (v) {
      'met' => l.boardVerdictMet,
      'partly' => l.boardVerdictPartly,
      'notMet' => l.boardVerdictNotMet,
      'cantTell' => l.boardVerdictCantTell,
      'added' => l.boardVerdictAdded,
      'updated' => l.boardVerdictUpdated,
      'missing' => l.boardVerdictMissing,
      'notNeeded' => l.boardVerdictNotNeeded,
      _ => '$v',
    };
    Color tone(Object? v) => switch (v) {
      'met' || 'added' || 'updated' || 'notNeeded' => cs.success,
      'partly' || 'cantTell' => cs.warning,
      'notMet' || 'missing' => cs.destructive,
      _ => cs.mutedForeground,
    };
    Widget verdictRow(Object? v, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 96),
          child: BoardStatusBadge(
            status: BoardPostStatus.open,
            label: verdict(v),
            color: tone(v),
          ),
        ),
        Expanded(child: Text(text, style: muted)),
      ],
    );
    String notes(Map<String, Object?> m, List<String> keys) =>
        keys.map((k) => m[k]).whereType<String>().join(' — ');
    final criteria = [
      ...?(r['criteria'] as List?),
    ].whereType<Map<String, Object?>>();
    final risks = [...?(r['risks'] as List?)].whereType<Map<String, Object?>>();
    final unrelated = [
      ...?(r['unrelatedChanges'] as List?),
    ].whereType<Map<String, Object?>>();
    final sha = r['sha'];
    return Column(
      key: const ValueKey<String>('board.task.review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        if (r['summary'] case final String summary)
          Text(summary, style: theme.textTheme.small),
        for (final c in criteria)
          verdictRow(c['verdict'], notes(c, const ['criterion', 'note'])),
        for (final (k, label) in [
          ('tests', l.boardReviewTests),
          ('specs', l.boardReviewSpecs),
        ])
          if (r[k] case final Map<String, Object?> m)
            verdictRow(
              m['verdict'],
              [label, ?(m['note'] as String?)].join(' — '),
            ),
        if (risks.isNotEmpty) ...[
          Text(l.boardReviewRisks, style: theme.textTheme.small),
          for (final x in risks)
            Text(notes(x, const ['kind', 'path', 'note']), style: muted),
        ],
        if (unrelated.isNotEmpty) ...[
          Text(l.boardReviewUnrelated, style: theme.textTheme.small),
          for (final x in unrelated)
            Text(notes(x, const ['path', 'note']), style: muted),
        ],
        if (sha is String && sha.isNotEmpty)
          Text(
            l.boardReviewedSha(sha.length > 7 ? sha.substring(0, 7) : sha),
            style: muted.copyWith(fontSize: 12),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final t = _task;
    Widget body;
    if (_loading && t == null) {
      body = const Center(child: ShadSpinner());
    } else if (t == null) {
      final notFound =
          _error is WonkyException &&
          (_error! as WonkyException).code == WonkyErrorCode.notFound;
      body = WonkyEmptyState(
        key: const ValueKey<String>('board.task.notFound'),
        illustration: notFound
            ? EmptyIllustration.noAccess
            : EmptyIllustration.error,
        title: notFound ? l.boardTaskNotFound(n) : l.boardLoadFailed,
        description: notFound ? null : errorMessage(_error ?? ''),
        actions: [
          ShadButton.outline(
            onPressed: () => s.router.go('/improvements/tasks'),
            child: Text(l.boardBackToBoard),
          ),
        ],
      );
    } else {
      final cs = theme.colorScheme;
      final pr = t.pullRequestUrl;
      final admin = hub.isAdmin;
      body = ShellPageBody(
        key: const ValueKey<String>('board.task'),
        spacing: 10,
        children: [
          if (t.status == BoardTaskStatus.draft)
            BoardNotice(
              key: const ValueKey<String>('board.task.notice.draft'),
              icon: LucideIcons.eyeOff,
              text: l.boardDraftNotice,
              tone: cs.warning,
            ),
          if (t.promptPending && admin)
            const BoardPromptPendingNotice(
              key: ValueKey<String>('board.task.notice.promptPending'),
            )
          else if (t.promptNote case final note? when admin)
            BoardNotice(
              key: const ValueKey<String>('board.task.notice.promptNote'),
              icon: LucideIcons.triangleAlert,
              text: l.boardPromptNote(note),
              tone: cs.warning,
            ),
          if (t.status == BoardTaskStatus.cancelled)
            BoardNotice(
              icon: LucideIcons.circleX,
              text: l.boardTaskCancelledNotice,
              tone: cs.destructive,
            ),
          _header(l, theme, t),
          BoardSectionTitle(l.boardLinkedPosts),
          for (final p in t.posts)
            _LinkedPost(
              services: s,
              post: p,
              onRemove:
                  hub.isAdmin &&
                      t.posts.length > 1 &&
                      t.status != BoardTaskStatus.done &&
                      t.status != BoardTaskStatus.shipped
                  ? () => _invoke('shell.board.admin.setTaskPosts', {
                      'taskNumber': n,
                      'remove': [p.number],
                    })
                  : null,
            ),
          if (t.posts.isEmpty)
            Text(l.boardNoLinkedPosts, style: theme.textTheme.muted),
          _howTo(l, theme, t),
          if (pr != null) ...[
            BoardSectionTitle(l.boardPullRequest),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ShadButton.link(
                  key: const ValueKey<String>('board.task.prLink'),
                  size: ShadButtonSize.sm,
                  padding: EdgeInsets.zero,
                  onPressed: () => confirmExternalLink(context, s, url: pr),
                  child: Text(
                    t.prNumber == null ? pr : l.boardPrNumber(t.prNumber!),
                  ),
                ),
                if (t.prAuthorLogin != null)
                  Text(
                    l.boardPrBy(t.prAuthorLogin!),
                    style: theme.textTheme.muted,
                  ),
              ],
            ),
            if (t.reviewJson case final json?) ...[
              Text(l.boardLatestReview, style: theme.textTheme.small),
              _review(l, theme, json),
            ],
          ],
          BoardSectionTitle(l.boardActivityAndDiscussion),
          CommentThreadBody.custom(
            key: ValueKey<String>('board.task.comments.$n'),
            services: s,
            actions: BoardCommentActions(
              services: s,
              taskNumber: n,
              open: t.status != BoardTaskStatus.cancelled,
            ),
            comments: boardThreadComments(l, _comments),
          ),
        ],
      );
    }
    return BoardFrame(services: s, title: l.boardTitle, child: body);
  }
}

class _LinkedPost extends StatelessWidget {
  const _LinkedPost({
    required this.services,
    required this.post,
    this.onRemove,
  });

  final ShellServices services;
  final BoardPostListItem post;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final p = post;
    return BoardListTile(
      key: ValueKey<String>('board.task.post.${p.number}'),
      semanticLabel: '#${p.number} ${p.title}',
      onTap: () => services.router.go('/improvements/p/${p.number}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        spacing: 8,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              l.boardScore(p.score),
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              '#${p.number} ${p.title}',
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          BoardChip(label: l.boardKindName(p.kind)),
          if (p.hasScreenshot)
            Semantics(
              label: l.boardHasScreenshot,
              excludeSemantics: true,
              child: Icon(
                LucideIcons.camera,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          if (onRemove != null)
            ShadIconButton.ghost(
              key: ValueKey<String>('board.task.post.${p.number}.remove'),
              width: 28,
              height: 28,
              iconSize: 14,
              semanticLabel: l.boardRemoveFromTask,
              icon: const Icon(LucideIcons.x),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
