import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../settings_screen.dart';

/// Wonky Work settings › Sign-in & security (`security`, suite 04 §4.1):
/// change the password (reset flow) and sign out. The Google account link
/// status and *Sign out of all devices* (P2) are open (TODO.md).
class SecuritySection extends StatelessWidget {
  const SecuritySection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final s = services;
    return SettingsGroup(
      title: l.settingsSecurity,
      children: [
        SettingsRow(
          label: l.authPassword,
          description: l.settingsPasswordHint,
          control: ShadButton.outline(
            key: const ValueKey<String>('settings.account.password'),
            onPressed: () async {
              await s.auth.signOut();
              s.router.go('/reset');
            },
            child: Text(l.settingsChangePassword),
          ),
        ),
        SettingsRow(
          label: l.cmdSignOut,
          description: l.settingsSignOutHint,
          control: ShadButton.outline(
            key: const ValueKey<String>('settings.account.signOut'),
            onPressed: () => s.dispatcher.invoke('shell.account.signOut'),
            child: Text(l.cmdSignOut),
          ),
        ),
      ],
    );
  }
}
