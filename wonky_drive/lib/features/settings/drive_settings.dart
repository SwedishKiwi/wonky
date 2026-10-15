import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;

import '../../l10n/drive_l10n.dart';
import 'drive_settings_keys.dart';

/// Drive settings (Drive 04 §8, suite 04 §4): the app settings of Wonky
/// Drive at `/settings/app/drive`.
List<SettingsSectionSpec> driveSettingsSections(ShellServices services) => [
  SettingsSectionSpec(
    id: 'drive',
    title: (c) => driveL10n(c).driveSettingsSection,
    icon: LucideIcons.hardDrive,
    builder: (_) => DriveSettingsSection(services: services),
  ),
];

/// Drive settings › Drive: list defaults (layout, sort, folders on top,
/// file extensions) and uploads (name conflicts, converting), stored in
/// `UserPreferences.driveDefaults`. Every change is `drive.prefs.set
/// {key, value}` (MCP-operable, not undoable).
class DriveSettingsSection extends StatelessWidget {
  const DriveSettingsSection({super.key, required this.services});

  final ShellServices services;

  void _set(String key, Object? value) => unawaited(
    services.dispatcher.invoke(
      'drive.prefs.set',
      args: {'key': key, 'value': value},
      source: InvocationSource.ui,
    ),
  );

  Widget _switch(String key, bool value) => ShadSwitch(
    key: ValueKey<String>('settings.drive.$key'),
    value: value,
    onChanged: (v) => _set(key, v),
  );

  Widget _select<T>({
    required String key,
    required T value,
    required List<(T, String)> options,
    required void Function(T v) onChanged,
    double width = 200,
  }) {
    String label(T v) =>
        options.where((o) => o.$1 == v).firstOrNull?.$2 ?? '$v';
    return SizedBox(
      width: width,
      child: ShadSelect<T>(
        key: ValueKey<String>('settings.drive.$key'),
        initialValue: value,
        minWidth: width,
        options: [
          for (final (v, text) in options)
            ShadOption(value: v, child: Text(text)),
        ],
        selectedOptionBuilder: (context, v) =>
            Text(label(v), overflow: TextOverflow.ellipsis),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final s = services;
    return ListenableBuilder(
      listenable: s.prefs,
      builder: (context, _) {
        final field = DriveSettings.sortFieldOf(s);
        return Column(
          key: const ValueKey<String>('settings.drive'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              title: l.driveSettingsList,
              description: l.driveSettingsListHint,
              children: [
                SettingsRow(
                  label: l.driveSettingsLayout,
                  control: _select<DriveLayout>(
                    key: DriveSettings.layout,
                    value: DriveSettings.layoutOf(s),
                    width: 160,
                    options: [
                      (DriveLayout.list, l.driveSettingsLayoutList),
                      (DriveLayout.grid, l.driveSettingsLayoutGrid),
                    ],
                    onChanged: (v) => _set(DriveSettings.layout, v.name),
                  ),
                ),
                SettingsRow(
                  label: l.driveSettingsSort,
                  control: _select<DriveSortField>(
                    key: DriveSettings.sortField,
                    value: field,
                    options: [
                      for (final f in DriveSettings.sortFields)
                        (f, sortFieldLabel(la, f)),
                    ],
                    onChanged: (v) => _set(DriveSettings.sortField, v.name),
                  ),
                ),
                SettingsRow(
                  label: l.driveSettingsSortOrder,
                  control: _select<bool>(
                    key: DriveSettings.sortDescending,
                    value: DriveSettings.sortDescendingOf(s),
                    width: 160,
                    options: [
                      (false, l.driveSettingsAscending),
                      (true, l.driveSettingsDescending),
                    ],
                    onChanged: (v) => _set(DriveSettings.sortDescending, v),
                  ),
                ),
                SettingsRow(
                  label: la.foldersOnTop,
                  control: _switch(
                    DriveSettings.foldersOnTop,
                    DriveSettings.foldersOnTopOf(s),
                  ),
                ),
                SettingsRow(
                  label: l.driveSettingsShowExtensions,
                  description: l.driveSettingsShowExtensionsHint,
                  control: _switch(
                    DriveSettings.showExtensions,
                    DriveSettings.showsExtensions(s),
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: l.driveSettingsUploads,
              children: [
                SettingsRow(
                  label: l.driveSettingsAskOnConflict,
                  description: l.driveSettingsAskOnConflictHint,
                  control: _switch(
                    DriveSettings.askOnNameConflict,
                    DriveSettings.asksOnNameConflict(s),
                  ),
                ),
                SettingsRow(
                  label: l.driveSettingsConvertUploads,
                  description: l.driveSettingsConvertUploadsHint,
                  control: _switch(
                    DriveSettings.convertUploads,
                    DriveSettings.convertsUploads(s),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// "Name", "Last modified", … (the filter bar's sort labels).
String sortFieldLabel(WonkyAppLocalizations l, DriveSortField f) => switch (f) {
  DriveSortField.name => l.sortName,
  DriveSortField.modifiedAt => l.sortModified,
  DriveSortField.lastOpenedByMe => l.sortOpenedByMe,
  DriveSortField.lastModifiedByMe => l.sortModifiedByMe,
  DriveSortField.size => l.sortSize,
  DriveSortField.createdAt => l.sortCreated,
};
