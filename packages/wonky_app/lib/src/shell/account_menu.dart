import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../bootstrap/app_urls.dart';
import '../drive/drive_format.dart';
import '../l10n/wonky_app_localizations.dart';
import 'shell_services.dart';

void _invoke(ShellServices s, BuildContext context, String id, [Map<String, Object?> args = const {}]) {
  s.dispatcher.invoke(id, args: args, source: InvocationSource.menu, context: context);
}

/// The account avatar menu (suite 05 §3.1): name, email, Settings, switch
/// app, theme, Sign out.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key, required this.services, this.size = 32});

  final ShellServices services;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return ValueListenableBuilder<UserProfileView?>(
      valueListenable: services.currentUser,
      builder: (context, me, _) {
        final summary = me?.summary;
        final other = services.config.app == WonkyAppKind.write ? l.cmdOpenSheets : l.cmdOpenWrite;
        return WonkyDropdownMenu(
          anchor: const ShadAnchor(
            childAlignment: AlignmentDirectional.bottomEnd,
            overlayAlignment: AlignmentDirectional.topEnd,
            offset: Offset(0, 6),
          ),
          entries: () => [
            if (summary != null) WonkyMenuLabel('${summary.displayName} · ${summary.email}'),
            WonkyMenuItem(
              key: const ValueKey<String>('account.settings'),
              label: l.cmdSettings,
              icon: LucideIcons.settings,
              onSelected: () => _invoke(services, context, 'shell.settings.open', {'section': 'account'}),
            ),
            WonkyMenuItem(
              key: const ValueKey<String>('account.switchApp'),
              label: other,
              icon: LucideIcons.arrowLeftRight,
              onSelected: () => _invoke(services, context, 'shell.account.switchApp'),
            ),
            const WonkyMenuSeparator(),
            WonkyMenuItem(
              key: const ValueKey<String>('account.signOut'),
              label: l.cmdSignOut,
              icon: LucideIcons.logOut,
              onSelected: () => _invoke(services, context, 'shell.account.signOut'),
            ),
          ],
          builder: (context, c) => ShadTooltip(
            builder: (_) => Text(summary == null ? l.accountMenu : '${summary.displayName}\n${summary.email}'),
            child: GestureDetector(
              key: const ValueKey<String>('shell.account'),
              onTap: c.toggle,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Semantics(
                  button: true,
                  label: l.accountMenu,
                  child: WonkyAvatar(
                    name: summary?.displayName ?? '?',
                    color: summary == null
                        ? ShadTheme.of(context).colorScheme.muted
                        : parseHexColor(summary.avatarColor),
                    imageUrl: summary?.avatarUrl,
                    size: size,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Light / dark / system cycle (top bar, status bar).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.services, this.size = 32});

  final ShellServices services;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return ListenableBuilder(
      listenable: services.prefs,
      builder: (context, _) {
        final mode = services.prefs.appTheme;
        final (icon, label) = switch (mode) {
          AppThemeMode.system => (LucideIcons.sunMoon, l.themeSystem),
          AppThemeMode.light => (LucideIcons.sun, l.themeLight),
          AppThemeMode.dark => (LucideIcons.moon, l.themeDark),
        };
        return ShadTooltip(
          builder: (_) => Text(l.themeToggleTooltip(label)),
          child: ShadIconButton.ghost(
            key: const ValueKey<String>('shell.themeToggle'),
            width: size,
            height: size,
            semanticLabel: l.themeToggleTooltip(label),
            icon: Icon(icon, size: 18),
            onPressed: () => _invoke(services, context, 'shell.appearance.setTheme', {'mode': 'cycle'}),
          ),
        );
      },
    );
  }
}

/// Help menu (shortcuts, docs, feedback, about).
class HelpMenuButton extends StatelessWidget {
  const HelpMenuButton({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return WonkyDropdownMenu(
      anchor: const ShadAnchor(
        childAlignment: AlignmentDirectional.bottomEnd,
        overlayAlignment: AlignmentDirectional.topEnd,
        offset: Offset(0, 6),
      ),
      entries: () => [
        for (final (id, label, icon) in [
          ('shell.help.open', l.cmdHelpCenter, LucideIcons.bookOpen),
          ('shell.help.shortcuts', l.cmdKeyboardShortcuts, LucideIcons.keyboard),
          ('shell.nav.commandPalette', l.cmdCommandPalette, LucideIcons.squareTerminal),
          ('shell.help.feedback', l.cmdReportProblem, LucideIcons.messageCircleWarning),
          ('shell.help.whatsNew', l.cmdWhatsNew, LucideIcons.gift),
          ('shell.help.about', l.cmdAbout, LucideIcons.info),
        ])
          WonkyMenuItem(
            label: label,
            icon: icon,
            shortcut: services.keymap.labelsOf(id),
            onSelected: () => _invoke(services, context, id),
          ),
      ],
      builder: (context, c) => ShadTooltip(
        builder: (_) => Text(l.helpMenu),
        child: ShadIconButton.ghost(
          key: const ValueKey<String>('shell.help'),
          semanticLabel: l.helpMenu,
          icon: const Icon(LucideIcons.circleQuestionMark, size: 18),
          onPressed: c.toggle,
        ),
      ),
    );
  }
}
