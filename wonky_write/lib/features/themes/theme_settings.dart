import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_write_core/wonky_write_core.dart' show BuiltinThemes;

import 'document_theme.dart';
import 'theme_picker.dart' show ThemeSwatchPreview;

/// Settings › Document themes (Write 06 §10.1): the default theme of new
/// and "Use my default theme" documents, with *Edit…* and *Manage themes…*.
class ThemeSettingsSection extends StatefulWidget {
  const ThemeSettingsSection({
    super.key,
    required this.services,
    required this.themes,
  });

  final ShellServices services;
  final WriteThemeCatalog themes;

  @override
  State<ThemeSettingsSection> createState() => _ThemeSettingsSectionState();
}

class _ThemeSettingsSectionState extends State<ThemeSettingsSection> {
  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    unawaited(widget.themes.loadMine());
  }

  void _invoke(String id, [Map<String, Object?> args = const {}]) => unawaited(
    s.dispatcher.invoke(
      id,
      args: args,
      source: InvocationSource.ui,
      context: context,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([s.prefs, widget.themes]),
      builder: (context, _) {
        final current =
            defaultThemeUuidOf(s.prefs.writeDefaults) ??
            BuiltinThemes.wonkyDefault.uuid;
        final options = [...WriteThemeCatalog.builtins, ...widget.themes.mine];
        final known = options.any((o) => o.uuid == current);
        Widget label(ThemeOption o) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemeSwatchPreview(option: o, size: 14),
            const SizedBox(width: 8),
            Flexible(child: Text(o.name, overflow: TextOverflow.ellipsis)),
          ],
        );
        return SettingsGroup(
          title: 'Document themes',
          description:
              'Themes set fonts, colors and spacing. Documents that use '
              '“my default theme” show your default.',
          children: [
            SettingsRow(
              label: 'Default theme',
              control: SizedBox(
                width: 240,
                child: ShadSelect<String>(
                  key: ValueKey<String>('settings.write.defaultTheme.$current'),
                  initialValue: known ? current : null,
                  placeholder: const Text('Wonky Default'),
                  minWidth: 240,
                  selectedOptionBuilder: (context, v) {
                    final o = options.firstWhere(
                      (o) => o.uuid == v,
                      orElse: () => WriteThemeCatalog.builtins.first,
                    );
                    return label(o);
                  },
                  onChanged: (v) {
                    if (v != null && v != current) {
                      _invoke('write.theme.setAsDefault', {'themeUuid': v});
                    }
                  },
                  options: [
                    for (final o in options)
                      ShadOption(value: o.uuid, child: label(o)),
                  ],
                ),
              ),
            ),
            SettingsRow(
              label: 'Theme editor',
              control: Wrap(
                spacing: 8,
                children: [
                  ShadButton.outline(
                    key: const ValueKey<String>('settings.write.editTheme'),
                    size: ShadButtonSize.sm,
                    onPressed: () => _invoke('write.theme.openEditor', {
                      'themeUuid': current,
                    }),
                    child: const Text('Edit…'),
                  ),
                  ShadButton.ghost(
                    key: const ValueKey<String>('settings.write.manageThemes'),
                    size: ShadButtonSize.sm,
                    onPressed: () => _invoke('write.theme.openManager'),
                    child: const Text('Manage themes…'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
