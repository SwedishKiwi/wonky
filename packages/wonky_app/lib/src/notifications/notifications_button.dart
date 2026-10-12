import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../drive/drive_format.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';

/// The in-app notifications popover (suite 07 §4): unread badge, list,
/// mark-all-read; live via `notification.watch`.
class NotificationsButton extends StatefulWidget {
  const NotificationsButton({super.key, required this.services});

  final ShellServices services;

  @override
  State<NotificationsButton> createState() => _NotificationsButtonState();
}

class _NotificationsButtonState extends State<NotificationsButton> {
  final _popover = ShadPopoverController();
  List<NotificationView> _items = const [];
  int _unread = 0;
  bool _loading = false;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    s.supervisor.supervise<NotificationEvent>(
      'notifications',
      s.repositories.notifications.watch,
      (e) {
        if (!mounted) return;
        setState(() {
          _unread = e.unreadCount;
          final n = e.notification;
          if (n != null && !_items.any((x) => x.id == n.id)) {
            _items = [n, ..._items];
          }
        });
      },
    );
  }

  @override
  void dispose() {
    unawaited(s.supervisor.cancel('notifications'));
    _popover.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await s.repositories.notifications.list(limit: 30);
      if (mounted) {
        setState(() {
          _items = p.items;
          _unread = p.unreadCount;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _text(WonkyAppLocalizations l, NotificationView n) {
    final who = n.actor?.displayName ?? l.someone;
    final what = n.itemName ?? '';
    return switch (n.kind) {
      NotificationKind.mention => l.notifMention(who, what),
      NotificationKind.reply => l.notifReply(who, what),
      NotificationKind.assigned => l.notifAssigned(who, what),
      NotificationKind.shared => l.notifShared(who, what),
      NotificationKind.accessRequest => l.notifAccessRequest(who, what),
      NotificationKind.suggestion => l.notifSuggestion(who, what),
      NotificationKind.suggestionDecided => l.notifSuggestionDecided(who, what),
      NotificationKind.ownershipTransfer => l.notifOwnership(who, what),
      NotificationKind.scriptFailure => l.notifScriptFailure(what),
    };
  }

  Future<void> _open(NotificationView n) async {
    _popover.hide();
    if (n.readAt == null) {
      unawaited(
        s.repositories.notifications.markRead([n.id]).catchError((Object _) {}),
      );
      setState(() {
        _unread = (_unread - 1).clamp(0, 1 << 30);
        _items = [
          for (final x in _items)
            x.id == n.id ? x.copyWith(readAt: DateTime.now()) : x,
        ];
      });
    }
    final uuid = n.itemUuid;
    if (uuid == null) return;
    final path = switch (n.itemKind) {
      DriveItemKind.spreadsheet => '/s/${uuid.uuid}',
      DriveItemKind.folder => '/drive/${uuid.uuid}',
      _ => '/d/${uuid.uuid}',
    };
    await s.openPath(path);
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return ShadPopover(
      controller: _popover,
      anchor: const ShadAnchor(
        childAlignment: AlignmentDirectional.bottomEnd,
        overlayAlignment: AlignmentDirectional.topEnd,
        offset: Offset(0, 6),
      ),
      popover: (context) => SizedBox(
        width: 360,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.notificationsTitle,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ShadButton.link(
                  size: ShadButtonSize.sm,
                  enabled: _unread > 0,
                  onPressed: () async {
                    await s.repositories.notifications.markAllRead();
                    setState(() {
                      _unread = 0;
                      _items = [
                        for (final x in _items)
                          x.copyWith(readAt: x.readAt ?? DateTime.now()),
                      ];
                    });
                  },
                  child: Text(l.notificationsMarkAllRead),
                ),
              ],
            ),
            const ShadSeparator.horizontal(),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const Center(child: ShadSpinner())
                  : _items.isEmpty
                  ? WonkyEmptyState(
                      illustration: EmptyIllustration.notifications,
                      title: l.notificationsEmpty,
                      size: 72,
                    )
                  : ListView(
                      children: [
                        for (final n in _items)
                          GestureDetector(
                            onTap: () => _open(n),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  color: n.readAt == null
                                      ? theme.colorScheme.accent
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    WonkyAvatar(
                                      name: n.actor?.displayName ?? '?',
                                      color: n.actor == null
                                          ? theme.colorScheme.muted
                                          : parseHexColor(n.actor!.avatarColor),
                                      imageUrl: n.actor?.avatarUrl,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _text(l, n),
                                            style: theme.textTheme.small
                                                .copyWith(
                                                  fontWeight: FontWeight.normal,
                                                ),
                                          ),
                                          Text(
                                            timeAgo(l, n.createdAt),
                                            style: theme.textTheme.muted
                                                .copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      child: ShadTooltip(
        builder: (_) => Text(l.notificationsTitle),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ShadIconButton.ghost(
              key: const ValueKey<String>('shell.notifications'),
              semanticLabel: _unread > 0
                  ? l.notificationsUnread(_unread)
                  : l.notificationsTitle,
              icon: const Icon(LucideIcons.bell, size: 18),
              onPressed: () {
                _popover.toggle();
                if (_popover.isOpen) unawaited(_load());
              },
            ),
            if (_unread > 0)
              Positioned(
                right: 4,
                top: 4,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.destructive,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _unread > 99 ? '99+' : '$_unread',
                        style: TextStyle(
                          color: theme.colorScheme.destructiveForeground,
                          fontSize: 10,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
