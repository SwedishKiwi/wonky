import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../data/api.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/dialogs.dart';
import '../shell/page_frame.dart';
import '../shell/shell_services.dart';

/// Unknown route.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return ShellPageFrame(
      services: services,
      title: l.notFoundTitle,
      child: WonkyEmptyState(
        illustration: EmptyIllustration.search,
        title: l.notFoundTitle,
        description: l.notFoundBody,
        actions: [ShadButton(onPressed: () => services.router.go('/'), child: Text(l.goHome))],
      ),
    );
  }
}

/// The in-app **No access** page (suite 03 §2): request access or switch
/// account.
class NoAccessPage extends StatelessWidget {
  const NoAccessPage({super.key, required this.services, this.itemUuid});

  final ShellServices services;
  final String? itemUuid;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return ShellPageFrame(
      services: services,
      title: l.noAccessTitle,
      child: WonkyEmptyState(
        key: const ValueKey<String>('shell.noAccess'),
        illustration: EmptyIllustration.noAccess,
        title: l.noAccessTitle,
        description: l.noAccessBody(services.me?.email ?? ''),
        actions: [
          if (itemUuid != null)
            ShadButton(
              key: const ValueKey<String>('shell.noAccess.request'),
              onPressed: () => showRequestAccessDialog(context, services, UuidValue.fromString(itemUuid!)),
              child: Text(l.requestAccessTitle),
            ),
          ShadButton.outline(
            onPressed: () async {
              await services.auth.signOut();
            },
            child: Text(l.switchAccount),
          ),
          ShadButton.ghost(onPressed: () => services.router.go('/'), child: Text(l.goHome)),
        ],
      ),
    );
  }
}

/// `/invite/:token` — resolves a share link and opens the item.
class InvitePage extends StatefulWidget {
  const InvitePage({super.key, required this.services, required this.token});

  final ShellServices services;
  final String token;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final r = await widget.services.repositories.sharing.resolveInvite(widget.token);
      final path = r.kind == DriveItemKind.spreadsheet ? '/s/${r.itemUuid.uuid}' : '/d/${r.itemUuid.uuid}';
      if (r.kind == DriveItemKind.folder) {
        widget.services.router.go('/drive/${r.itemUuid.uuid}');
      } else {
        await widget.services.openPath(path);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return ShellPageFrame(
      services: widget.services,
      title: l.inviteTitle,
      child: _error == null
          ? const Center(child: ShadSpinner())
          : WonkyEmptyState(
              illustration: EmptyIllustration.noAccess,
              title: l.inviteInvalid,
              description: errorMessage(_error!),
              actions: [ShadButton(onPressed: () => widget.services.router.go('/'), child: Text(l.goHome))],
            ),
    );
  }
}

/// Help center (in-app docs route).
class HelpPage extends StatelessWidget {
  const HelpPage({super.key, required this.services, this.topic});

  final ShellServices services;
  final String? topic;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final topics = [
      (LucideIcons.house, l.helpTopicDriveTitle, l.helpTopicDriveBody),
      (LucideIcons.userPlus, l.helpTopicSharingTitle, l.helpTopicSharingBody),
      (LucideIcons.messageSquare, l.helpTopicCommentsTitle, l.helpTopicCommentsBody),
      (LucideIcons.history, l.helpTopicHistoryTitle, l.helpTopicHistoryBody),
      (LucideIcons.keyboard, l.helpTopicShortcutsTitle, l.helpTopicShortcutsBody),
      (LucideIcons.cloudOff, l.helpTopicOfflineTitle, l.helpTopicOfflineBody),
    ];
    return ShellPageFrame(
      services: services,
      title: l.cmdHelpCenter,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.cmdHelpCenter, style: theme.textTheme.h2),
                  const SizedBox(height: 16),
                  for (final (icon, title, body) in topics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShadCard(
                        title: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(title)]),
                        child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(body)),
                      ),
                    ),
                  Row(
                    children: [
                      ShadButton.outline(
                        onPressed: () => services.dispatcher.invoke('shell.help.shortcuts', context: context),
                        child: Text(l.cmdKeyboardShortcuts),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.outline(
                        onPressed: () => services.dispatcher.invoke('shell.help.feedback', context: context),
                        child: Text(l.cmdReportProblem),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
