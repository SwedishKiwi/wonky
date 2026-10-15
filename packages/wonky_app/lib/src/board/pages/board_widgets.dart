import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../../data/api.dart';
import '../../drive/drive_format.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/account_menu.dart';
import '../../shell/shell_services.dart';
import 'board_labels.dart';

/// Whether [location] is a board route (`/improvements…`).
bool isBoardLocation(String location) =>
    location == '/improvements' ||
    location.startsWith('/improvements/') ||
    location.startsWith('/improvements?') ||
    location.startsWith('/improvements#');

/// Back from the board (specs/16 §4.3): the last visited route that is not
/// a board page, else home.
String boardBackTarget(ShellServices s) {
  final h = s.navHistory;
  for (var i = s.navIndex; i >= 0 && i < h.length; i--) {
    if (!isBoardLocation(h[i])) return h[i];
  }
  return '/';
}

/// Sends a signed-out visitor to sign-in, coming back to the current page.
void boardSignIn(ShellServices s) {
  final here = s.router.state.uri.toString();
  s.router.go('/signin?next=${Uri.encodeQueryComponent(here)}');
}

/// Invokes a board command from the UI; failures become an error toast.
Future<CommandResult?> boardInvoke(
  ShellServices s,
  String id,
  Map<String, Object?> args, {
  BuildContext? context,
}) async {
  try {
    return await s.dispatcher.invoke(
      id,
      args: args,
      source: InvocationSource.ui,
      context: context,
    );
  } catch (e) {
    final l = s.l10n;
    s.toasts.error(l?.errorGeneric ?? 'Error', description: errorMessage(e));
    return null;
  }
}

/// The board's page chrome: back (to the last non-board route), the app
/// logo, the title, [actions], and the account menu or, signed out, *Sign
/// in*.
class BoardFrame extends StatelessWidget {
  const BoardFrame({
    super.key,
    required this.services,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final ShellServices services;
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final s = services;
    return ColoredBox(
      color: theme.colorScheme.background,
      child: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: Row(
              children: [
                ShadTooltip(
                  builder: (_) => Text(l.actionBack),
                  child: ShadIconButton.ghost(
                    key: const ValueKey<String>('board.back'),
                    semanticLabel: l.actionBack,
                    icon: const Icon(LucideIcons.arrowLeft, size: 18),
                    onPressed: () => s.router.go(boardBackTarget(s)),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: l.goHome,
                  child: GestureDetector(
                    onTap: () => s.router.go('/'),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: s.config.logo(size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.large,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ...actions,
                const SizedBox(width: 8),
                if (s.auth.isSignedIn)
                  AccountMenuButton(services: s)
                else
                  ShadButton.outline(
                    key: const ValueKey<String>('board.signIn'),
                    size: ShadButtonSize.sm,
                    onPressed: () => boardSignIn(s),
                    child: Text(l.boardSignIn),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A centered, width-limited column for page content.
class BoardContent extends StatelessWidget {
  const BoardContent({super.key, required this.child, this.maxWidth = 920});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// The vote control (specs/16 §4.4, §4.7). Ideas: ▲ score ▼ with
/// "Upvote, 14 votes" / "Remove upvote" labels and a pressed state; bugs: a
/// `+1` pill *I hit this too* with the count. [onVote] gets the new value
/// (−1, 0, 1); null disables the buttons (voting closed).
class BoardVoteControl extends StatelessWidget {
  const BoardVoteControl({
    super.key,
    required this.number,
    required this.kind,
    required this.score,
    required this.voteCount,
    required this.myVote,
    required this.onVote,
    this.large = false,
  });

  final int number;
  final BoardPostKind kind;
  final int score;
  final int voteCount;
  final int myVote;
  final ValueChanged<int>? onVote;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final enabled = onVote != null;
    if (kind == BoardPostKind.bug) {
      final pressed = myVote == 1;
      final label = pressed
          ? l.boardHitThisTooRemove(score)
          : l.boardHitThisTooLabel(score);
      return Semantics(
        button: true,
        toggled: pressed,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        onTap: enabled ? () => onVote?.call(pressed ? 0 : 1) : null,
        child: ShadTooltip(
          builder: (_) => Text(label),
          child: ShadButton.raw(
            key: ValueKey<String>('board.vote.$number.hit'),
            variant: pressed
                ? ShadButtonVariant.primary
                : ShadButtonVariant.outline,
            size: large ? ShadButtonSize.regular : ShadButtonSize.sm,
            enabled: enabled,
            onPressed: () => onVote?.call(pressed ? 0 : 1),
            child: Text('+1 ${large ? '${l.boardHitThisToo} · ' : ''}$score'),
          ),
        ),
      );
    }
    Widget arrow(int value) {
      final up = value == 1;
      final pressed = myVote == value;
      final label = up
          ? (pressed ? l.boardRemoveUpvote : l.boardUpvoteLabel(score))
          : (pressed ? l.boardRemoveDownvote : l.boardDownvoteLabel(score));
      return Semantics(
        button: true,
        toggled: pressed,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        onTap: enabled ? () => onVote?.call(pressed ? 0 : value) : null,
        child: ShadTooltip(
          builder: (_) => Text(label),
          child: ShadIconButton.raw(
            key: ValueKey<String>('board.vote.$number.${up ? 'up' : 'down'}'),
            variant: pressed
                ? ShadButtonVariant.secondary
                : ShadButtonVariant.ghost,
            width: large ? 36 : 28,
            height: large ? 30 : 24,
            iconSize: large ? 20 : 16,
            enabled: enabled,
            icon: Icon(
              up ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              color: pressed ? cs.primary : null,
            ),
            onPressed: () => onVote?.call(pressed ? 0 : value),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(1),
        Text(
          '$score',
          key: ValueKey<String>('board.vote.$number.score'),
          style: (large ? theme.textTheme.large : theme.textTheme.small)
              .copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: myVote != 0 ? cs.primary : null,
              ),
        ),
        arrow(-1),
      ],
    );
  }
}

/// A small label chip (area, size, kind); [ai] adds the *AI* marker while
/// the label is not confirmed by an admin.
class BoardChip extends StatelessWidget {
  const BoardChip({super.key, required this.label, this.ai = false, this.icon});

  final String label;
  final bool ai;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return Semantics(
      label: ai ? l.boardAiLabel(label) : label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (icon != null)
              Icon(icon, size: 12, color: theme.colorScheme.mutedForeground),
            Text(label, style: theme.textTheme.small.copyWith(fontSize: 12)),
            if (ai)
              Text(
                l.boardAiMarker,
                style: theme.textTheme.small.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A status badge: a colored dot and the status name (color is never the
/// only signal).
class BoardStatusBadge extends StatelessWidget {
  const BoardStatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.onTap,
    this.color,
  });

  final Enum status;
  final String label;
  final VoidCallback? onTap;

  /// Overrides the status color (review verdicts).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = this.color ?? boardStatusColor(theme.colorScheme, status);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(label, style: theme.textTheme.small.copyWith(fontSize: 12)),
        ],
      ),
    );
    if (onTap == null) return badge;
    return Semantics(
      link: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: badge),
      ),
    );
  }
}

/// An author line: avatar, name, an *Admin* badge (from the server's flag)
/// and the age.
class BoardAuthorLine extends StatelessWidget {
  const BoardAuthorLine({
    super.key,
    required this.author,
    required this.createdAt,
    this.editedAt,
    this.avatar = true,
  });

  final BoardAuthor? author;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final a = author;
    final muted = theme.textTheme.muted.copyWith(fontSize: 12);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        if (avatar)
          WonkyAvatar(
            name: a?.displayName ?? '?',
            color: a == null
                ? theme.colorScheme.muted
                : parseHexColor(a.avatarColor),
            imageUrl: a?.avatarUrl,
            size: 20,
          ),
        Text(a?.displayName ?? l.boardDeletedUser, style: muted),
        if (a?.isAdmin == true)
          ShadBadge.secondary(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(l.boardAdmin, style: const TextStyle(fontSize: 11)),
          ),
        Text('· ${timeAgo(l, createdAt)}', style: muted),
        if (editedAt != null)
          Text('· ${l.boardEdited(timeAgo(l, editedAt!))}', style: muted),
      ],
    );
  }
}

/// A notice above a post or task (state, moderation, kind correction).
class BoardNotice extends StatelessWidget {
  const BoardNotice({
    super.key,
    required this.icon,
    required this.text,
    this.tone,
    this.action,
  });

  final IconData icon;
  final String text;

  /// The accent color (null: muted).
  final Color? tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final c = tone ?? theme.colorScheme.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        border: Border.all(color: c.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(icon, size: 18, color: c),
          Expanded(child: Text(text, style: theme.textTheme.small)),
          ?action,
        ],
      ),
    );
  }
}

/// *Writing the prompt with AI… this takes about a minute* with a spinner:
/// the AI writes a task prompt in the background (specs/16 §10.1); the
/// page refreshes live when it is done.
class BoardPromptPendingNotice extends StatelessWidget {
  const BoardPromptPendingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final c = theme.colorScheme.primary;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          border: Border.all(color: c.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          spacing: 10,
          children: [
            ExcludeSemantics(child: ShadSpinner(size: 16, color: c)),
            Expanded(
              child: Text(l.boardPromptWriting, style: theme.textTheme.small),
            ),
          ],
        ),
      ),
    );
  }
}

/// A command line with a copy button (setup steps, PR lines).
class BoardCopyLine extends StatelessWidget {
  const BoardCopyLine({
    super.key,
    required this.text,
    required this.copyKey,
    this.label,
  });

  final String text;
  final String copyKey;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.small.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          ShadIconButton.ghost(
            key: ValueKey<String>(copyKey),
            width: 32,
            height: 32,
            iconSize: 16,
            semanticLabel: label ?? l.boardCopy,
            icon: const Icon(LucideIcons.copy),
            onPressed: () {
              final sonner = ShadSonner.maybeOf(context);
              Clipboard.setData(ClipboardData(text: text)).then((_) {
                sonner?.show(ShadToast(title: Text(l.boardCopied)));
              });
            },
          ),
        ],
      ),
    );
  }
}

/// A section heading on board pages.
class BoardSectionTitle extends StatelessWidget {
  const BoardSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: theme.textTheme.h4),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The post's labels: kind (optional), area and size with the AI marker.
List<Widget> boardLabelChips(
  WonkyAppLocalizations l, {
  BoardPostKind? kind,
  BoardArea? area,
  BoardSize? size,
  bool ai = false,
}) => [
  if (kind != null)
    BoardChip(
      label: l.boardKindName(kind),
      icon: kind == BoardPostKind.bug ? LucideIcons.bug : LucideIcons.lightbulb,
    ),
  if (area != null) BoardChip(label: l.boardAreaName(area), ai: ai),
  if (size != null) BoardChip(label: l.boardSizeName(size), ai: ai),
];
