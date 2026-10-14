import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';
import '../../theme/wonky_colors.dart';
import '../../theme/wonky_theme.dart';
import 'avatar.dart';

/// What a collaborator is doing.
enum PresenceActivity { editing, viewing, idle, away, offline }

/// One collaborator session shown in a [PresenceAvatarStack].
@immutable
class PresenceParticipant {
  const PresenceParticipant({
    required this.sessionId,
    required this.userKey,
    required this.displayName,
    required this.colorIndex,
    this.activity = PresenceActivity.viewing,
    this.avatarUrl,
    this.isSelf = false,
    this.isAgent = false,
    this.detail,
  });

  final String sessionId;

  /// Groups sessions of the same user (two tabs → one avatar).
  final String userKey;
  final String displayName;

  /// 0–11, see `presenceColorIndex`.
  final int colorIndex;
  final PresenceActivity activity;
  final String? avatarUrl;
  final bool isSelf;

  /// MCP / AI participant ("Claude via MCP (Anna)").
  final bool isAgent;

  /// App-specific activity shown under the name ("Editing Sheet1!B4").
  final String? detail;
}

/// A user with all their sessions.
class PresenceGroup {
  PresenceGroup(this.sessions);

  final List<PresenceParticipant> sessions;

  PresenceParticipant get primary {
    // Prefer the most active session.
    final sorted = [...sessions]
      ..sort((a, b) => a.activity.index.compareTo(b.activity.index));
    return sorted.first;
  }

  int get tabs => sessions.length;

  /// Groups [participants] by user, keeping first-seen order.
  static List<PresenceGroup> of(Iterable<PresenceParticipant> participants) {
    final map = <String, List<PresenceParticipant>>{};
    for (final p in participants) {
      map.putIfAbsent(p.userKey, () => []).add(p);
    }
    return [for (final v in map.values) PresenceGroup(v)];
  }
}

/// Overlapping avatars of collaborators in the file (max 4 + "+N"), ringed in
/// their presence color (suite 02 §4.7). Tooltip: name + activity. Clicking an
/// avatar jumps to their cursor; "+N" opens a list popover.
class PresenceAvatarStack extends StatefulWidget {
  const PresenceAvatarStack({
    super.key,
    required this.participants,
    this.onJumpTo,
    this.onFollow,
    this.maxVisible,
    this.size = 28,
    this.showSelf = false,
  });

  final List<PresenceParticipant> participants;
  final ValueChanged<PresenceParticipant>? onJumpTo;
  final ValueChanged<PresenceParticipant>? onFollow;
  final int? maxVisible;
  final double size;
  final bool showSelf;

  @override
  State<PresenceAvatarStack> createState() => _PresenceAvatarStackState();
}

class _PresenceAvatarStackState extends State<PresenceAvatarStack> {
  final _more = ShadPopoverController();

  @override
  void dispose() {
    _more.dispose();
    super.dispose();
  }

  String _activity(WonkyUiLocalizations l10n, PresenceActivity a) =>
      switch (a) {
        PresenceActivity.editing => l10n.presenceEditing,
        PresenceActivity.viewing => l10n.presenceViewing,
        PresenceActivity.idle => l10n.presenceIdle,
        PresenceActivity.away => l10n.presenceAway,
        PresenceActivity.offline => l10n.presenceOffline,
      };

  String _name(WonkyUiLocalizations l10n, PresenceGroup g) {
    final p = g.primary;
    if (p.isSelf) {
      return g.tabs > 1 ? l10n.presenceYouTabs(g.tabs) : l10n.presenceYou;
    }
    return g.tabs > 1
        ? l10n.presenceTabs(p.displayName, g.tabs)
        : p.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = WonkyUiLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final max =
        widget.maxVisible ?? WonkyThemeScope.of(context).presenceMaxAvatars;
    final groups = PresenceGroup.of(
      widget.participants.where((p) => widget.showSelf || !p.isSelf),
    );
    if (groups.isEmpty) return const SizedBox.shrink();
    final visible = groups.take(max).toList();
    final hidden = groups.skip(max).toList();
    final overlap = widget.size * 0.3;

    Widget avatarFor(PresenceGroup g) {
      final p = g.primary;
      final color = theme.colorScheme.presence(p.colorIndex);
      final dim =
          p.activity == PresenceActivity.idle ||
          p.activity == PresenceActivity.away;
      return ShadTooltip(
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _name(l10n, g),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(p.detail ?? _activity(l10n, p.activity)),
          ],
        ),
        child: GestureDetector(
          onTap: widget.onJumpTo == null ? null : () => widget.onJumpTo!(p),
          // Long-press / right-click follows (suite 07 §1.2).
          onLongPress: widget.onFollow == null || p.isSelf
              ? null
              : () => widget.onFollow!(p),
          onSecondaryTap: widget.onFollow == null || p.isSelf
              ? null
              : () => widget.onFollow!(p),
          child: MouseRegion(
            cursor: widget.onJumpTo == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            child: Opacity(
              opacity: dim ? 0.55 : 1,
              child: Semantics(
                button: widget.onJumpTo != null,
                label: '${_name(l10n, g)}, ${_activity(l10n, p.activity)}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.background,
                      width: 2,
                    ),
                  ),
                  child: WonkyAvatar(
                    key: ValueKey<String>('presence.avatar.${p.userKey}'),
                    name: p.displayName,
                    color: color,
                    imageUrl: p.avatarUrl,
                    size: widget.size,
                    ringColor: color,
                    icon: p.isAgent ? LucideIcons.bot : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final children = <Widget>[
      for (final g in visible) avatarFor(g),
      if (hidden.isNotEmpty)
        ShadPopover(
          controller: _more,
          popover: (context) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280, maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      l10n.presenceInFile,
                      style: theme.textTheme.small,
                    ),
                  ),
                  for (final g in groups)
                    ShadButton.ghost(
                      height: 36,
                      mainAxisAlignment: MainAxisAlignment.start,
                      onPressed: widget.onJumpTo == null
                          ? null
                          : () {
                              _more.hide();
                              widget.onJumpTo!(g.primary);
                            },
                      leading: WonkyAvatar(
                        name: g.primary.displayName,
                        color: theme.colorScheme.presence(g.primary.colorIndex),
                        imageUrl: g.primary.avatarUrl,
                        size: 22,
                        icon: g.primary.isAgent ? LucideIcons.bot : null,
                      ),
                      trailing: widget.onFollow == null || g.primary.isSelf
                          ? null
                          : ShadButton.link(
                              height: 24,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _more.hide();
                                widget.onFollow!(g.primary);
                              },
                              child: Text(l10n.presenceFollow),
                            ),
                      child: Expanded(
                        child: Text(
                          '${_name(l10n, g)} · ${_activity(l10n, g.primary.activity)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          child: GestureDetector(
            onTap: _more.toggle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Semantics(
                button: true,
                label: l10n.presenceMoreLabel(hidden.length),
                child: Container(
                  key: const ValueKey<String>('presence.more'),
                  width: widget.size + 4,
                  height: widget.size + 4,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.muted,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.background,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    l10n.presenceMore(hidden.length),
                    style: theme.textTheme.small.copyWith(
                      fontSize: widget.size * 0.36,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];

    final step = widget.size + 4 - overlap;
    return SizedBox(
      height: widget.size + 4,
      width: step * (children.length - 1) + widget.size + 4,
      child: Stack(
        children: [
          for (var i = 0; i < children.length; i++)
            Positioned(left: i * step, top: 0, child: children[i]),
        ],
      ),
    );
  }
}
