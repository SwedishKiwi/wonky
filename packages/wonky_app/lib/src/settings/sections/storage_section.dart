import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../../storage/storage_format.dart';
import '../../storage/storage_meter.dart';
import '../settings_screen.dart';

/// Wonky Work settings › Storage (`storage`, suite 04 §4.1, Drive 03 §6.5):
/// the quota meter (D-11's [StorageMeter]), the breakdown by kind, "What
/// counts" and *Manage storage in Wonky Drive* (`shell.storage.open`).
class StorageSection extends StatefulWidget {
  const StorageSection({super.key, required this.services});

  final ShellServices services;

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.services;
    if (s.storage.value != null) return;
    _loading = true;
    s.storage.refresh().catchError((Object _) => null).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final s = widget.services;
    return ValueListenableBuilder<StorageUsage?>(
      valueListenable: s.storage,
      builder: (context, u, _) {
        final children = <Widget>[
          if (u == null)
            Text(
              _loading
                  ? l.settingsStorageLoading
                  : l.settingsStorageUnavailable,
              key: const ValueKey<String>('settings.storage.empty'),
              style: theme.textTheme.muted,
            )
          else ...[
            KeyedSubtree(
              key: const ValueKey<String>('settings.storage.meter'),
              child: StorageMeter(services: s, large: true),
            ),
            for (final (key, label, bytes) in [
              ('documents', l.settingsStorageDocuments, u.documentsBytes),
              (
                'spreadsheets',
                l.settingsStorageSpreadsheets,
                u.spreadsheetsBytes,
              ),
              (
                'presentations',
                l.settingsStoragePresentations,
                u.presentationsBytes,
              ),
              ('files', l.settingsStorageFiles, u.filesBytes),
              ('trash', l.settingsStorageTrash, u.trashBytes),
            ])
              SettingsRow(
                key: ValueKey<String>('settings.storage.$key'),
                label: label,
                control: Text(
                  storageBytes(bytes),
                  style: theme.textTheme.muted,
                ),
              ),
          ],
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              title: l.settingsStorageQuota,
              description: l.settingsStorageQuotaHint,
              children: children,
            ),
            SettingsGroup(
              title: l.settingsStorageWhatCounts,
              description: l.settingsStorageWhatCountsBody,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ShadButton.outline(
                    key: const ValueKey<String>('settings.storage.manage'),
                    leading: const Icon(LucideIcons.chartPie, size: 16),
                    onPressed: () => s.dispatcher.invoke(
                      'shell.storage.open',
                      context: context,
                    ),
                    child: Flexible(
                      child: Text(
                        l.settingsStorageManage,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
