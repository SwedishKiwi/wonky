import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/drive_l10n.dart';

/// What the *Upload options* dialog (Drive 02 §3.2) chose.
enum ConflictChoice { keepBoth, skip, cancel }

/// Dialog keys (MCP: `ui.dialog.*`, widget tests).
abstract final class UploadDialogKeys {
  static const conflict = 'drive.upload.conflict';
  static const cancelAll = 'drive.upload.cancelAll';
}

/// *Upload options* (Drive 02 §3.2): files with names that already exist
/// in the target folder — *Keep both* (default; the server numbers them
/// "name (1).ext") or *Skip*. *Replace* (a new version) is P2.
Future<ConflictChoice> showUploadConflictDialog(
  BuildContext context, {
  required List<String> names,
  required String folderName,
}) async {
  final l = driveL10n(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      dialogKey: UploadDialogKeys.conflict,
      title: l.uploadConflictTitle,
      description: names.length == 1
          ? l.uploadConflictBodyOne(names.single, folderName)
          : l.uploadConflictBodyMany(names.length, folderName),
      buttons: [
        DialogButtonSpec(
          id: 'cancel',
          label: l.uploadDialogCancel,
          validates: false,
        ),
        DialogButtonSpec(id: 'skip', label: l.uploadConflictSkip),
        DialogButtonSpec(
          id: 'keepBoth',
          label: l.uploadConflictKeepBoth,
          primary: true,
        ),
      ],
    ),
  );
  return switch (r?.buttonId) {
    'keepBoth' => ConflictChoice.keepBoth,
    'skip' => ConflictChoice.skip,
    _ => ConflictChoice.cancel,
  };
}

/// "Cancel 2 uploads?" (Drive 04 §4: closing the panel while uploads run).
Future<bool> confirmCancelUploads(BuildContext context, int count) async {
  final l = driveL10n(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      dialogKey: UploadDialogKeys.cancelAll,
      alert: true,
      title: l.uploadCancelAllTitle(count),
      description: l.uploadCancelAllBody,
      buttons: [
        DialogButtonSpec(
          id: 'cancel',
          label: l.uploadKeepUploading,
          validates: false,
        ),
        DialogButtonSpec(
          id: 'confirm',
          label: l.uploadCancelAllConfirm,
          primary: true,
          destructive: true,
        ),
      ],
    ),
  );
  return r?.buttonId == 'confirm';
}
