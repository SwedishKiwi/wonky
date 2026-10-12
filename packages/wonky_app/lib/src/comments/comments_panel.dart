import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../data/api.dart';
import '../drive/drive_format.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';
import 'comments_controller.dart';

/// The comments side panel (suite 07 §2.3): filters, search, sort, the
/// composer for a new comment and thread cards. Every action is a
/// `shell.comments.*` command (undoable).
class CommentsPanel extends StatelessWidget {
  const CommentsPanel({super.key, required this.services, required this.controller});

  final ShellServices services;
  final CommentsController controller;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final threads = c.visible;
        final canComment = services.activeDocument.value?.role.canComment ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadTabs<CommentsFilter>(
                    value: c.filter,
                    onChanged: c.setFilter,
                    tabs: [
                      for (final f in CommentsFilter.values)
                        ShadTab(
                          value: f,
                          child: Text(switch (f) {
                            CommentsFilter.all => l.commentsAll,
                            CommentsFilter.open => l.commentsOpen,
                            CommentsFilter.resolved => l.commentsResolved,
                            CommentsFilter.forYou => l.commentsForYou,
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ShadInput(
                          key: const ValueKey<String>('comments.search'),
                          placeholder: Text(l.commentsSearch),
                          leading: const Icon(LucideIcons.search, size: 14),
                          onChanged: c.setQuery,
                        ),
                      ),
                      const SizedBox(width: 6),
                      WonkyDropdownMenu(
                        entries: () => [
                          WonkyMenuRadioItem(label: l.commentsSortPosition, selected: c.sort == CommentsSort.position, onSelected: () => c.setSort(CommentsSort.position)),
                          WonkyMenuRadioItem(label: l.commentsSortDate, selected: c.sort == CommentsSort.date, onSelected: () => c.setSort(CommentsSort.date)),
                        ],
                        builder: (context, ctl) => ShadIconButton.outline(
                          semanticLabel: l.commentsSort,
                          icon: const Icon(LucideIcons.arrowDownUp, size: 14),
                          onPressed: ctl.toggle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: c.loading
                  ? const Center(child: ShadSpinner())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      children: [
                        if (c.draftAnchor != null && canComment)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: NewCommentCard(services: services, controller: c),
                          ),
                        if (threads.isEmpty && c.draftAnchor == null)
                          WonkyEmptyState(
                            illustration: EmptyIllustration.comments,
                            title: l.commentsEmptyTitle,
                            description: canComment ? l.commentsEmptyBody(services.keymap.shortcutTextOf('shell.comments.create') ?? '') : null,
                            size: 80,
                          ),
                        for (final t in threads)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CommentThreadCard(
                              key: ValueKey<String>('comments.thread.${t.uuid.uuid}'),
                              services: services,
                              controller: c,
                              thread: t,
                            ),
                          ),
                        if (c.error != null)
                          Text(errorMessage(c.error!), style: theme.textTheme.muted),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// A text box with `@` mention autocomplete. Reports the plain text and
/// the mentioned user ids.
class MentionField extends StatefulWidget {
  const MentionField({
    super.key,
    required this.services,
    required this.controller,
    required this.onSubmit,
    this.placeholder,
    this.autofocus = false,
    this.onMentionsChanged,
    this.fieldKey,
  });

  final ShellServices services;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String? placeholder;
  final bool autofocus;
  final ValueChanged<List<UserSummary>>? onMentionsChanged;
  final String? fieldKey;

  @override
  State<MentionField> createState() => MentionFieldState();
}

class MentionFieldState extends State<MentionField> {
  final List<UserSummary> mentions = [];
  List<UserSummary> _suggestions = const [];
  int _active = 0;
  Timer? _debounce;
  String? _query;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  String? _mentionQuery() {
    final t = widget.controller.text;
    final sel = widget.controller.selection.baseOffset;
    if (sel < 0 || sel > t.length) return null;
    final before = t.substring(0, sel);
    final m = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(before);
    return m?.group(1);
  }

  void _onChanged(String _) {
    final q = _mentionQuery();
    _query = q;
    _debounce?.cancel();
    if (q == null) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final r = await widget.services.repositories.users.searchUsers(q.isEmpty ? '' : q, limit: 6);
        if (mounted && _query == q) {
          setState(() {
            _suggestions = r;
            _active = 0;
          });
        }
      } catch (_) {}
    });
  }

  void _pick(UserSummary u) {
    final c = widget.controller;
    final sel = c.selection.baseOffset;
    final before = c.text.substring(0, sel);
    final start = before.lastIndexOf('@');
    final insert = '@${u.displayName} ';
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, sel, insert),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    if (!mentions.any((m) => m.id == u.id)) mentions.add(u);
    widget.onMentionsChanged?.call(mentions);
    setState(() => _suggestions = const []);
  }

  /// Mentions still present in the text.
  List<int> get mentionIds => [
    for (final m in mentions)
      if (widget.controller.text.contains('@${m.displayName}')) m.id,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter, meta: true): widget.onSubmit,
            const SingleActivator(LogicalKeyboardKey.enter, control: true): widget.onSubmit,
            if (_suggestions.isNotEmpty) ...{
              const SingleActivator(LogicalKeyboardKey.arrowDown): () => setState(() => _active = (_active + 1) % _suggestions.length),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () => setState(() => _active = (_active - 1 + _suggestions.length) % _suggestions.length),
              const SingleActivator(LogicalKeyboardKey.enter): () => _pick(_suggestions[_active]),
              const SingleActivator(LogicalKeyboardKey.tab): () => _pick(_suggestions[_active]),
              const SingleActivator(LogicalKeyboardKey.escape): () => setState(() => _suggestions = const []),
            },
          },
          child: ShadTextarea(
            key: widget.fieldKey == null ? null : ValueKey<String>(widget.fieldKey!),
            controller: widget.controller,
            autofocus: widget.autofocus,
            minHeight: 56,
            maxHeight: 200,
            placeholder: widget.placeholder == null ? null : Text(widget.placeholder!),
            onChanged: _onChanged,
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.popover,
              border: Border.all(color: theme.colorScheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _suggestions.length; i++)
                  GestureDetector(
                    onTap: () => _pick(_suggestions[i]),
                    child: Container(
                      color: i == _active ? theme.colorScheme.accent : null,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          WonkyAvatar(name: _suggestions[i].displayName, color: parseHexColor(_suggestions[i].avatarColor), size: 22),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${_suggestions[i].displayName} · ${_suggestions[i].email}', overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The composer for a new thread at the draft anchor.
class NewCommentCard extends StatefulWidget {
  const NewCommentCard({super.key, required this.services, required this.controller});

  final ShellServices services;
  final CommentsController controller;

  @override
  State<NewCommentCard> createState() => _NewCommentCardState();
}

class _NewCommentCardState extends State<NewCommentCard> {
  final _text = TextEditingController();
  final _field = GlobalKey<MentionFieldState>();
  bool _assign = false;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _text.text.trim();
    final anchor = widget.controller.draftAnchor;
    if (body.isEmpty || anchor == null) return;
    setState(() => _busy = true);
    final mentions = _field.currentState?.mentionIds ?? const <int>[];
    try {
      await widget.services.dispatcher.invoke(
        'shell.comments.create',
        args: {
          'body': body,
          'anchorKind': anchor.kind.name,
          'anchorJson': anchor.anchorJson,
          'quotedText': ?anchor.quotedText,
          'mentions': mentions,
          if (_assign && mentions.isNotEmpty) 'assigneeId': mentions.first,
        },
        source: InvocationSource.ui,
      );
      _text.clear();
    } catch (e) {
      widget.services.toasts.error(widget.services.l10n?.commentFailed ?? 'Error', description: errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final anchor = widget.controller.draftAnchor!;
    final me = widget.services.me;
    return ShadCard(
      key: const ValueKey<String>('comments.new'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (me != null) WonkyAvatar(name: me.displayName, color: parseHexColor(me.avatarColor), imageUrl: me.avatarUrl, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(me?.displayName ?? '', style: theme.textTheme.small)),
            ],
          ),
          if (anchor.quotedText != null || anchor.label != null) ...[
            const SizedBox(height: 8),
            _Quote(text: anchor.label ?? anchor.quotedText!),
          ],
          const SizedBox(height: 8),
          MentionField(
            key: _field,
            fieldKey: 'comments.new.body',
            services: widget.services,
            controller: _text,
            autofocus: true,
            placeholder: l.commentPlaceholder,
            onSubmit: _submit,
            onMentionsChanged: (_) => setState(() {}),
          ),
          if ((_field.currentState?.mentions.isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            ShadCheckbox(
              value: _assign,
              onChanged: (v) => setState(() => _assign = v),
              label: Text(l.commentAssign(_field.currentState!.mentions.first.displayName)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShadButton.ghost(size: ShadButtonSize.sm, onPressed: widget.controller.cancelDraft, child: Text(l.actionCancel)),
              const SizedBox(width: 6),
              ShadButton(
                key: const ValueKey<String>('comments.new.submit'),
                size: ShadButtonSize.sm,
                enabled: !_busy,
                onPressed: _submit,
                child: Text(l.commentAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.colorScheme.commentHighlightActive, width: 3))),
      child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.muted.copyWith(fontSize: 12)),
    );
  }
}

/// A thread: comments, reply box, resolve/reopen, ⋮ menu.
class CommentThreadCard extends StatefulWidget {
  const CommentThreadCard({super.key, required this.services, required this.controller, required this.thread});

  final ShellServices services;
  final CommentsController controller;
  final CommentThreadView thread;

  @override
  State<CommentThreadCard> createState() => _CommentThreadCardState();
}

class _CommentThreadCardState extends State<CommentThreadCard> {
  final _reply = TextEditingController();
  final _field = GlobalKey<MentionFieldState>();
  bool _replying = false;
  bool _expanded = false;
  int? _editing;
  final _edit = TextEditingController();

  ShellServices get s => widget.services;

  @override
  void dispose() {
    _reply.dispose();
    _edit.dispose();
    super.dispose();
  }

  Future<void> _invoke(String id, Map<String, Object?> args) async {
    try {
      await s.dispatcher.invoke(id, args: args, source: InvocationSource.ui);
    } catch (e) {
      s.toasts.error(s.l10n?.commentFailed ?? 'Error', description: errorMessage(e));
    }
  }

  Future<void> _sendReply() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    await _invoke('shell.comments.reply', {
      'threadUuid': widget.thread.uuid.uuid,
      'body': body,
      'mentions': _field.currentState?.mentionIds ?? const <int>[],
    });
    _reply.clear();
    setState(() => _replying = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final t = widget.thread;
    final c = widget.controller;
    final active = c.activeThreadUuid == t.uuid.uuid;
    final resolved = t.status == CommentStatus.resolved;
    final orphaned = t.status == CommentStatus.orphaned;
    final role = s.activeDocument.value?.role ?? Role.viewer;
    final collapsed = resolved && !_expanded && !active;
    final label = c.anchors?.labelFor(t) ?? t.quotedText;
    return GestureDetector(
      onTap: () => _invoke('shell.comments.activate', {'threadUuid': t.uuid.uuid}),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? theme.colorScheme.ring : theme.colorScheme.border, width: active ? 2 : 1),
          boxShadow: active ? const [BoxShadow(color: Color(0x1a000000), blurRadius: 8, offset: Offset(0, 2))] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null && label.isNotEmpty) ...[_Quote(text: label), const SizedBox(height: 8)],
            if (orphaned) ...[
              ShadBadge.outline(child: Text(l.commentOrphaned)),
              const SizedBox(height: 6),
            ],
            if (collapsed)
              Row(
                children: [
                  Icon(LucideIcons.circleCheck, size: 14, color: theme.colorScheme.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.comments.firstOrNull?.body ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.muted,
                    ),
                  ),
                  ShadButton.link(size: ShadButtonSize.sm, onPressed: () => setState(() => _expanded = true), child: Text(l.commentShow)),
                ],
              )
            else ...[
              for (var i = 0; i < t.comments.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _commentRow(context, t, t.comments[i], first: i == 0, role: role),
              ],
              const SizedBox(height: 10),
              if (role.canComment && !resolved)
                _replying
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MentionField(
                            key: _field,
                            fieldKey: 'comments.reply.${t.uuid.uuid}',
                            services: s,
                            controller: _reply,
                            autofocus: true,
                            placeholder: l.replyPlaceholder,
                            onSubmit: _sendReply,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ShadButton.ghost(size: ShadButtonSize.sm, onPressed: () => setState(() => _replying = false), child: Text(l.actionCancel)),
                              const SizedBox(width: 6),
                              ShadButton(
                                key: ValueKey<String>('comments.reply.${t.uuid.uuid}.send'),
                                size: ShadButtonSize.sm,
                                onPressed: _sendReply,
                                child: Text(l.cmdReply),
                              ),
                            ],
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: () => setState(() => _replying = true),
                        child: Container(
                          key: ValueKey<String>('comments.reply.${t.uuid.uuid}.open'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.input),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(l.replyPlaceholder, style: theme.textTheme.muted),
                        ),
                      ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _commentRow(BuildContext context, CommentThreadView t, CommentView cm, {required bool first, required Role role}) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final mine = cm.author?.id == s.me?.id;
    final resolved = t.status == CommentStatus.resolved;
    if (cm.systemEvent != null) {
      return Text(
        '${cm.author?.displayName ?? l.someone} · ${switch (cm.systemEvent!) {
          CommentSystemEvent.resolved => l.commentEventResolved,
          CommentSystemEvent.reopened => l.commentEventReopened,
          CommentSystemEvent.assigned => l.commentEventAssigned,
          _ => cm.systemEvent!.name,
        }}',
        style: theme.textTheme.muted.copyWith(fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            WonkyAvatar(
              name: cm.author?.displayName ?? '?',
              color: cm.author == null ? theme.colorScheme.muted : parseHexColor(cm.author!.avatarColor),
              imageUrl: cm.author?.avatarUrl,
              icon: cm.authorKind.name == 'user' ? null : LucideIcons.bot,
              size: 26,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cm.author?.displayName ?? l.someone, style: theme.textTheme.small, overflow: TextOverflow.ellipsis),
                  Text(
                    '${timeAgo(l, cm.createdAt)}${cm.editedAt != null ? ' · ${l.commentEdited}' : ''}',
                    style: theme.textTheme.muted.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (first && role.canComment)
              ShadTooltip(
                builder: (_) => Text(resolved ? l.cmdReopen : l.cmdResolve),
                child: ShadIconButton.ghost(
                  key: ValueKey<String>('comments.thread.${t.uuid.uuid}.${resolved ? 'reopen' : 'resolve'}'),
                  width: 28,
                  height: 28,
                  iconSize: 16,
                  semanticLabel: resolved ? l.cmdReopen : l.cmdResolve,
                  icon: Icon(resolved ? LucideIcons.rotateCcw : LucideIcons.check),
                  onPressed: () => _invoke(resolved ? 'shell.comments.reopen' : 'shell.comments.resolve', {'threadUuid': t.uuid.uuid}),
                ),
              ),
            if (!cm.deleted && (mine || role.canEdit))
              WonkyDropdownMenu(
                anchor: const ShadAnchor(childAlignment: AlignmentDirectional.bottomEnd, overlayAlignment: AlignmentDirectional.topEnd),
                entries: () => [
                  if (mine)
                    WonkyMenuItem(
                      label: l.commentEdit,
                      icon: LucideIcons.pencil,
                      onSelected: () => setState(() {
                        _editing = cm.id;
                        _edit.text = cm.body;
                      }),
                    ),
                  WonkyMenuItem(
                    label: first ? l.commentDeleteThread : l.commentDelete,
                    icon: LucideIcons.trash2,
                    destructive: true,
                    onSelected: () => _invoke('shell.comments.delete', {
                      'threadUuid': t.uuid.uuid,
                      if (!first) 'commentId': cm.id,
                    }),
                  ),
                  WonkyMenuItem(
                    label: l.commentLink,
                    icon: LucideIcons.link,
                    onSelected: () {
                      final item = s.currentItem.value;
                      if (item == null) return;
                      final url = '${s.urls.urlFor(s.config.app, s.config.itemPath(item.uuid.uuid))}?comment=${t.uuid.uuid}';
                      Clipboard.setData(ClipboardData(text: url));
                      s.toasts.show(l.toastLinkCopied);
                    },
                  ),
                ],
                builder: (context, ctl) => ShadIconButton.ghost(
                  width: 28,
                  height: 28,
                  iconSize: 16,
                  semanticLabel: l.moreActions,
                  icon: const Icon(LucideIcons.ellipsisVertical),
                  onPressed: ctl.toggle,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_editing == cm.id)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadTextarea(controller: _edit, minHeight: 56),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShadButton.ghost(size: ShadButtonSize.sm, onPressed: () => setState(() => _editing = null), child: Text(l.actionCancel)),
                  ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: () async {
                      final body = _edit.text.trim();
                      setState(() => _editing = null);
                      if (body.isNotEmpty && body != cm.body) await widget.controller.edit(cm.id, body);
                    },
                    child: Text(l.actionSave),
                  ),
                ],
              ),
            ],
          )
        else
          Text(cm.deleted ? l.commentDeleted : cm.body, style: cm.deleted ? theme.textTheme.muted : theme.textTheme.small.copyWith(fontWeight: FontWeight.normal)),
      ],
    );
  }
}
