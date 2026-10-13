import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart'
    show InvocationSource, presenceColorIndex;
import 'package:wonky_ui/wonky_ui.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show SuggestionInfo;

import '../../l10n/write_l10n.dart';
import '../document/write_document_session.dart';

/// Runs a Write collaboration command through the dispatcher (undo
/// transaction, role checks) and falls back to [fallback] when the command
/// is not registered (widget tests, previews).
Future<void> invokeCollabCommand(
  WriteDocumentSession session,
  String id,
  Map<String, Object?> args,
  void Function() fallback, {
  BuildContext? context,
}) async {
  final s = session.services;
  if (s.registry.byId(id) == null) {
    fallback();
    return;
  }
  try {
    await s.dispatcher.invoke(
      id,
      args: args,
      source: InvocationSource.ui,
      context: context,
    );
  } catch (e) {
    s.toasts.error(writeL10nOf(s).suggestionActionFailed, description: '$e');
  }
}

/// A suggestion card (Write 08 §2.7): author, time, ✨ badge for agent
/// suggestions, the summary ("Replace: ‘red’ with ‘blue’"), *Accept* /
/// *Reject* (Editors) or *Withdraw* (the author), and the replies (comments
/// in the suggestion's thread) with a reply box.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.session,
    required this.suggestion,
    this.active = false,
  });

  final WriteDocumentSession session;
  final SuggestionInfo suggestion;

  /// Expanded and ringed (the caret is in the suggestion or it was
  /// selected).
  final bool active;

  static String keyOf(String id) => 'write.suggestion.$id';

  String _author(WriteLocalizations l) {
    final s = suggestion;
    final thread = session.suggestions.threadOf(s.id);
    final name = thread?.createdBy?.displayName;
    if (name != null) return name;
    if (s.by == session.userUuid) {
      return session.services.me?.displayName ?? l.suggestionYou;
    }
    for (final p in session.presence.participants) {
      if (p.userUuid.uuid == s.by) return p.displayName;
    }
    return l.suggestionSomeone;
  }

  String _time(BuildContext context) {
    final at = DateTime.fromMillisecondsSinceEpoch(suggestion.at);
    final l = Localizations.of<WonkyAppLocalizations>(
      context,
      WonkyAppLocalizations,
    );
    if (l != null) return timeAgo(l, at);
    final w = writeL10n(context);
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return w.suggestionJustNow;
    if (diff.inHours < 1) return w.suggestionMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return w.suggestionHoursAgo(diff.inHours);
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final s = suggestion;
    final c = session.suggestions;
    final color = theme.colorScheme.presence(presenceColorIndex(s.by));
    final key = keyOf(s.id);
    final own = c.isOwn(s);
    final l = writeL10n(context);
    final author = _author(l);
    final via = s.via == 'mcp' ? l.suggestionViaMcp : l.suggestionViaAi;
    final thread = c.threadOf(s.id);
    final comments = session.comments.controller;
    final rejectLabel = own && !c.canDecide
        ? l.suggestionWithdraw
        : l.cmdSuggestionsReject;
    return GestureDetector(
      key: ValueKey<String>(key),
      behavior: HitTestBehavior.opaque,
      onTap: () => c.activate(s.id),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: color, width: 2) : null,
        ),
        child: ShadCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  WonkyAvatar(name: author, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author,
                          style: theme.textTheme.small,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _time(context),
                          style: theme.textTheme.muted.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (s.via != null)
                    ShadTooltip(
                      builder: (_) => Text(via),
                      child: Icon(
                        LucideIcons.sparkles,
                        semanticLabel: via,
                        size: 14,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.summary,
                key: ValueKey<String>('$key.summary'),
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.normal,
                ),
                maxLines: active ? 6 : 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (c.canDecide || c.canReject(s)) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (c.canDecide)
                      ShadTooltip(
                        builder: (_) => Text(l.cmdSuggestionsAccept),
                        child: ShadIconButton.ghost(
                          key: ValueKey<String>('$key.accept'),
                          width: 30,
                          height: 30,
                          iconSize: 16,
                          semanticLabel: l.cmdSuggestionsAccept,
                          icon: const Icon(LucideIcons.check),
                          onPressed: () => invokeCollabCommand(
                            session,
                            'write.suggestions.accept',
                            {
                              'suggestionIds': [s.id],
                            },
                            () => c.accept({s.id}),
                            context: context,
                          ),
                        ),
                      ),
                    if (c.canReject(s))
                      ShadTooltip(
                        builder: (_) => Text(rejectLabel),
                        child: ShadIconButton.ghost(
                          key: ValueKey<String>('$key.reject'),
                          width: 30,
                          height: 30,
                          iconSize: 16,
                          semanticLabel: rejectLabel,
                          icon: const Icon(LucideIcons.x),
                          onPressed: () => invokeCollabCommand(
                            session,
                            'write.suggestions.reject',
                            {
                              'suggestionIds': [s.id],
                            },
                            () => c.reject({s.id}),
                            context: context,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (thread != null && comments != null) ...[
                const SizedBox(height: 8),
                CommentThreadBody(
                  key: ValueKey<String>('$key.thread'),
                  services: session.services,
                  controller: comments,
                  thread: thread,
                  canResolve: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
