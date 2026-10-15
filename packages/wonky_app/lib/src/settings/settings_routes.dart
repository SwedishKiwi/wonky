import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../bootstrap/app_urls.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';
import 'settings_catalog.dart';
import 'settings_screen.dart';

/// The settings routes (suite 03 §2, suite 04 §4):
///
/// - `/settings` → `/settings/account`;
/// - `/settings/app` → the app's first section (`/settings/app/<id>`), or
///   `/settings/account` when the app has no settings of its own;
/// - `/settings/app/:section` — the app's settings;
/// - `/settings/:section` — Wonky Work settings. The v1 ids of the apps'
///   sections redirect (`write`, `themes` → Write's `/settings/app/editor`,
///   `/settings/app/themes`; `sheets` → Sheets' `/settings/app/defaults`);
///   in another app they hand over to that app ([SettingsHandoffPage]).
List<RouteBase> settingsRoutes(
  ShellServices s,
  Page<void> Function(GoRouterState state, Widget child) page,
) {
  String firstAppSection() {
    final sections = s.config.appSettingsSections(s);
    return sections.isEmpty
        ? '/settings/account'
        : '/settings/app/${sections.first.id}';
  }

  return [
    GoRoute(path: '/settings', redirect: (c, st) => '/settings/account'),
    GoRoute(
      path: '/settings/app',
      redirect: (c, st) =>
          st.uri.path == '/settings/app' || st.uri.path == '/settings/app/'
          ? firstAppSection()
          : null,
      routes: [
        GoRoute(
          path: ':section',
          redirect: (c, st) => s.config.appSettingsSections(s).isEmpty
              ? '/settings/account'
              : null,
          pageBuilder: (c, st) => page(
            st,
            SettingsScreen(
              services: s,
              area: SettingsArea.app,
              section: st.pathParameters['section']!,
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/settings/:section',
      redirect: (c, st) {
        final target = legacySettingsTarget(st.pathParameters['section']!);
        if (target == null || target.app != s.config.app) return null;
        return '/settings/app/${target.section}';
      },
      pageBuilder: (c, st) {
        final id = st.pathParameters['section']!;
        final target = legacySettingsTarget(id);
        return page(
          st,
          target == null
              ? SettingsScreen(services: s, section: id)
              : SettingsHandoffPage(
                  services: s,
                  app: target.app,
                  path: '/settings/app/${target.section}',
                ),
        );
      },
    ),
  ];
}

/// Opens [path] in [app] (a v1 settings link of another app, e.g.
/// `/settings/sheets` in Write → Sheets' `/settings/app/defaults`): a
/// full page load on web, so this page shows only for a moment.
class SettingsHandoffPage extends StatefulWidget {
  const SettingsHandoffPage({
    super.key,
    required this.services,
    required this.app,
    required this.path,
  });

  final ShellServices services;
  final WonkyAppKind app;
  final String path;

  @override
  State<SettingsHandoffPage> createState() => _SettingsHandoffPageState();
}

class _SettingsHandoffPageState extends State<SettingsHandoffPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.services.crossApp.open(widget.app, widget.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final name = widget.app.productName.replaceFirst(RegExp(r'^Wonky '), '');
    return ColoredBox(
      color: theme.colorScheme.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                l.settingsOpeningOtherApp(l.cmdAppSettings(name)),
                key: const ValueKey<String>('settings.handoff'),
                textAlign: TextAlign.center,
                style: theme.textTheme.muted,
              ),
              ShadButton.link(
                onPressed: () => widget.services.router.go(
                  settingsBackTarget(widget.services),
                ),
                child: Text(l.actionBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
