import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../settings_screen.dart';

/// Settings › Appearance (suite 04 §4.2): theme with preview cards, accent,
/// density, reduce motion.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final p = services.prefs;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsGroup(
            title: l.settingsTheme,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (mode, label) in [
                    (AppThemeMode.system, l.themeSystem),
                    (AppThemeMode.light, l.themeLight),
                    (AppThemeMode.dark, l.themeDark),
                  ])
                    _ThemePreview(
                      key: ValueKey<String>('settings.theme.${mode.name}'),
                      mode: mode,
                      label: label,
                      selected: p.appTheme == mode,
                      onTap: () => services.dispatcher.invoke(
                        'shell.appearance.setTheme',
                        args: {'mode': mode.name},
                        source: InvocationSource.ui,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SettingsGroup(
            title: l.settingsAccent,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AccentSwatch(
                    color: ShadTheme.of(context).colorScheme.foreground,
                    label: l.settingsAccentNeutral,
                    selected: p.accent == null,
                    onTap: () => p.setAccent(null),
                  ),
                  for (final a in WonkyTheme.accents)
                    _AccentSwatch(
                      color: WonkyTheme.of(ShadTheme.of(context).brightness, WonkyThemeConfig(accent: a)).colorScheme.primary,
                      label: a,
                      selected: p.accent == a,
                      onTap: () => p.setAccent(a),
                    ),
                ],
              ),
            ],
          ),
          SettingsGroup(
            title: l.settingsLayout,
            children: [
              SettingsRow(
                label: l.settingsDensity,
                control: ShadSelect<UiDensity>(
                  key: const ValueKey<String>('settings.density'),
                  initialValue: p.density,
                  options: [
                    ShadOption(value: UiDensity.comfortable, child: Text(l.densityComfortable)),
                    ShadOption(value: UiDensity.compact, child: Text(l.densityCompact)),
                  ],
                  selectedOptionBuilder: (context, v) => Text(v == UiDensity.compact ? l.densityCompact : l.densityComfortable),
                  onChanged: (v) {
                    if (v != null) p.setDensity(v);
                  },
                ),
              ),
              SettingsRow(
                label: l.settingsReduceMotion,
                description: l.settingsReduceMotionHint,
                control: ShadSwitch(
                  key: const ValueKey<String>('settings.reduceMotion'),
                  value: p.reduceMotion,
                  onChanged: p.setReduceMotion,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({super.key, required this.mode, required this.label, required this.selected, required this.onTap});

  final AppThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    Widget mini(Brightness b) {
      final c = WonkyTheme.of(b, const WonkyThemeConfig()).colorScheme;
      return Container(
        color: c.background,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 8, width: 60, color: c.muted),
            const SizedBox(height: 6),
            Container(height: 6, width: 90, color: c.border),
            const SizedBox(height: 4),
            Container(height: 6, width: 70, color: c.border),
            const Spacer(),
            Container(height: 12, width: 40, decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(3))),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            children: [
              Container(
                width: 150,
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? theme.colorScheme.ring : theme.colorScheme.border, width: selected ? 2 : 1),
                ),
                child: switch (mode) {
                  AppThemeMode.light => mini(Brightness.light),
                  AppThemeMode.dark => mini(Brightness.dark),
                  AppThemeMode.system => Row(children: [Expanded(child: mini(Brightness.light)), Expanded(child: mini(Brightness.dark))]),
                },
              ),
              const SizedBox(height: 6),
              Text(label, style: theme.textTheme.small),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.color, required this.label, required this.selected, required this.onTap});

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) => Text(label),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? theme.colorScheme.ring : const Color(0x00000000), width: 2),
            ),
            child: DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
        ),
      ),
    );
  }
}
