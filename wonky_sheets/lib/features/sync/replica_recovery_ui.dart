import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/sheets_l10n.dart';
import '../import_export/sheets_io.dart' show saveBytes;
import 'replica_recovery.dart';

/// Tells the user that the local replica couldn't be opened and offers the
/// unsynced spreadsheets as a ZIP ("Download unsynced changes", suite 12
/// §2.5). The toast stays for ten minutes; the ZIP is built when asked for,
/// off the UI thread.
void offerRecoveryDownload(ShellServices services, ReplicaRecovery recovery) {
  final l = sheetsL10nOf(services);
  services.toasts.show(
    l.recoveryTitle,
    description: l.recoveryDescription(recovery.spreadsheets.length),
    actionLabel: l.recoveryDownload,
    duration: const Duration(minutes: 10),
    onAction: () async {
      try {
        final bytes = await compute(_zip, recovery);
        await saveBytes(
          bytes,
          fileName: ReplicaRecovery.fileName(DateTime.now()),
          mimeType: 'application/zip',
        );
      } catch (e) {
        debugPrint('Recovery download failed: $e');
        services.toasts.error(l.recoveryFailed);
      }
    },
  );
}

Uint8List _zip(ReplicaRecovery r) => r.toZip();
