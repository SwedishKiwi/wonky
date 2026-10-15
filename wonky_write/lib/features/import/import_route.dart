import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        DriveImportOptions,
        DriveItemKind,
        FileUploadState,
        ImportReportView,
        UuidValue;
import 'package:wonky_core/files.dart' show FileTypes;

import '../../l10n/write_l10n.dart';
import 'import_service.dart';

/// The server call of Write's `/import` route: `drive.convertFile` imports
/// a Drive file's stored bytes as a document (Drive 02 §7.2). Tests install
/// a fake with [install].
abstract class WriteDriveFileApi {
  /// Imports the `file` item [fileItemUuid] as a document into the file's
  /// folder (or My Drive when the caller can't edit it), named after the
  /// file without its extension.
  Future<ImportReportView> convert(UuidValue fileItemUuid);

  static final Expando<WriteDriveFileApi> _apis = Expando('WriteDriveFileApi');

  /// The API of [s] (null without a server client).
  static WriteDriveFileApi? of(ShellServices s) {
    final installed = _apis[s];
    if (installed != null) return installed;
    final client = s.client;
    if (client == null) return null;
    return _apis[s] = _ClientWriteDriveFileApi(s);
  }

  /// Installs [api] for [s] (widget tests).
  static void install(ShellServices s, WriteDriveFileApi api) => _apis[s] = api;
}

class _ClientWriteDriveFileApi implements WriteDriveFileApi {
  _ClientWriteDriveFileApi(this.s);

  final ShellServices s;

  @override
  Future<ImportReportView> convert(UuidValue fileItemUuid) => s.client!.drive
      .convertFile(fileItemUuid, DriveItemKind.document, DriveImportOptions());
}

/// A problem of the `/import` route shown as the route's error toast.
class ImportRouteProblem implements Exception {
  const ImportRouteProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `/import?file=<fileItemUuid>` of Wonky Write (Drive 02 §7.2, Write 05
/// §2): *Open with ▸ Wonky Write* in Drive navigates here; the Drive file is
/// imported on the server through the Write import pipeline (Write 07 §3.2:
/// images stored with the document, the import warnings shown by the banner
/// when it opens) into the file's folder, and the shell opens the new
/// document. The original file is kept.
///
/// Returns null when the user closes the *Out of storage* dialog (the shell
/// goes back to Drive); problems (offline, not a Write file, still
/// uploading, server errors) are thrown and shown as the route's toast.
Future<UuidValue?> importDriveFileAsDocument(
  BuildContext context,
  ShellServices s,
  ImportRouteRequest request,
) async {
  final l = writeL10nOf(s);
  final api = WriteDriveFileApi.of(s);
  if (api == null || !s.connectivity.online) {
    throw ImportRouteProblem(l.importRouteOffline);
  }
  final file = await s.drive.get(request.fileItemUuid);
  switch (file.kind) {
    case DriveItemKind.document:
      return file.uuid; // Already a document (e.g. a reloaded link).
    case DriveItemKind.file:
      break;
    case _:
      throw ImportRouteProblem(l.importRouteNotAFile);
  }
  final ext = FileTypes.extensionOf(file.name);
  if (!writeImportExtensions.contains(ext) || ext == 'zip') {
    throw ImportRouteProblem(l.importRouteUnsupported(file.name));
  }
  if (file.uploadState != null && file.uploadState != FileUploadState.ready) {
    throw ImportRouteProblem(l.importRouteUploading(file.name));
  }
  // Drive 03 §7.2: the new document counts against the importing user;
  // the server checks again (estimate = file size, then the real size).
  if (!await s.storageChecks.ensureRoom(
    file.sizeBytes,
    reason: QuotaReasons.convert,
  )) {
    return null;
  }
  try {
    final report = await api.convert(file.uuid);
    s.refreshDrive();
    return report.item.uuid;
  } catch (e) {
    final problem = s.quotaErrors.problemOf(
      e,
      itemKind: DriveItemKind.document,
      reason: QuotaReasons.convert,
    );
    if (problem == null) rethrow;
    await s.quotaErrors.show(problem);
    return null;
  }
}
