import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/offline_storage.dart';
import '../../data/cached_drive_repository.dart';
import '../../drive/drive_format.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/dialogs.dart';
import '../../shell/shell_services.dart';
import '../settings_screen.dart';

/// Device preference key of the "Simulate offline" developer switch; the
/// apps re-apply it at startup.
const simulateOfflinePref = 'dev.simulateOffline';

/// Settings › Offline & storage (suite 12): what is kept on this device,
/// pending changes, *Clear local data* and the *Simulate offline* developer
/// switch.
class OfflineSection extends StatelessWidget {
  const OfflineSection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final d = services.drive;
    final storage = OfflineStorage.of(services);
    return ListenableBuilder(
      listenable: Listenable.merge([
        storage,
        services.connectivity,
        if (d is CachedDriveRepository) d,
      ]),
      builder: (context, _) {
        final usage = storage.usage;
        final driveOps = d is CachedDriveRepository ? d.pendingCount : 0;
        final pending = usage.pendingChanges + driveOps;
        return SettingsGroup(
          title: l.settingsOffline,
          description: l.settingsOfflineHint,
          children: [
            SettingsRow(
              key: const ValueKey<String>('settings.offline.documents'),
              label: l.offlineDocuments,
              description: l.offlinePinnedCount(usage.pinned),
              control: Text(l.offlineDocumentsValue(usage.documents)),
            ),
            SettingsRow(
              key: const ValueKey<String>('settings.offline.pending'),
              label: l.offlinePending,
              control: Text('$pending'),
            ),
            if (usage.pendingUploads > 0)
              SettingsRow(
                label: l.offlineUploads,
                control: Text('${usage.pendingUploads}'),
              ),
            SettingsRow(
              label: l.offlineStorageUsed,
              control: Text(formatBytes(usage.bytes)),
            ),
            SettingsRow(
              label: l.offlineSimulate,
              description: l.offlineSimulateHint,
              control: ShadSwitch(
                key: const ValueKey<String>('settings.offline.simulate'),
                value: services.connectivity.forcedOffline,
                onChanged: (v) {
                  services.connectivity.forceOffline(v);
                  services.prefs.setDevice(simulateOfflinePref, v);
                },
              ),
            ),
            SettingsRow(
              label: l.offlineClear,
              description: l.offlineClearHint,
              control: ShadButton.outline(
                key: const ValueKey<String>('settings.offline.clear'),
                onPressed: () => _clear(context, pending),
                child: Text(l.offlineClear),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clear(BuildContext context, int pending) async {
    final l = WonkyAppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.offlineClear,
      description: pending > 0
          ? '${l.offlineClearHint} ${l.offlineClearUnsynced(pending)}'
          : l.offlineClearHint,
      confirmLabel: l.offlineClear,
      destructive: true,
    );
    if (!ok) return;
    await clearLocalData(services);
    services.toasts.show(l.offlineCleared);
  }
}

/// Clears every local cache of the signed-in user: app data (document
/// caches, outboxes, uploads), the drive cache and the pending drive
/// operations.
Future<void> clearLocalData(ShellServices services) async {
  await OfflineStorage.of(services).clearAll();
  final d = services.drive;
  if (d is CachedDriveRepository) {
    await d.cache.clear();
    await d.queue.clear();
    d.refreshListeners();
  }
}
