import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;

import '../../l10n/drive_l10n.dart';
import 'upload_host.dart';
import 'upload_queue.dart';

/// Drive's [ImportHandler] (Drive 05 §1): *File upload…* (`shell.drive
/// .upload`) and drops on the home upload every file type as a `file`
/// item through the upload queue instead of importing it. The files are
/// staged and handed to `drive.upload.files` (one undo step per batch).
class DriveUploadHandler implements ImportHandler {
  const DriveUploadHandler();

  /// Every extension: Drive stores any file (the shell's drop handler
  /// checks `HomeScope.uploadsFiles` instead of this set).
  @override
  Set<String> get extensions => const {};

  @override
  Future<List<ImportFile>> pickFiles(BuildContext context) async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: driveL10n(context).uploadPickTitle,
    );
    return [
      for (final f in picked)
        ImportFile(
          name: f.name,
          bytes: await f.readAsBytes(),
          mimeType: f.xFile.mimeType,
          lastModified: await _lastModified(f),
        ),
    ];
  }

  static Future<DateTime?> _lastModified(PlatformFile f) async {
    try {
      return await f.xFile.lastModified();
    } on Object {
      return null;
    }
  }

  /// Queues [files] for [parentUuid]; returns no items (they appear in the
  /// list when each upload completes).
  @override
  Future<List<DriveItemView>> importFiles(
    BuildContext context,
    ShellServices services,
    List<ImportFile> files, {
    UuidValue? parentUuid,
  }) async {
    final host = UploadHost.of(services);
    final staged = host.stage([
      for (final f in files)
        UploadFile(
          name: f.name,
          bytes: f.bytes is Uint8List
              ? f.bytes as Uint8List
              : Uint8List.fromList(f.bytes),
          mimeType: f.mimeType,
          lastModified: f.lastModified,
          folderPath: f.folderPath,
        ),
    ]);
    await services.dispatcher.invoke(
      'drive.upload.files',
      args: {'staged': staged, 'parentUuid': ?parentUuid?.uuid},
      source: InvocationSource.ui,
      context: context.mounted ? context : null,
    );
    // Not used by a cancelled dialog.
    host.takeStaged(staged);
    return const [];
  }
}
