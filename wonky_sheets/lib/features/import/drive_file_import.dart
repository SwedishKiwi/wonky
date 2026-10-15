import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        DriveImportOptions,
        DriveItemKind,
        FileUploadState,
        ImportReportView,
        UuidValue;
import 'package:wonky_core/files.dart' show FileTypes;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../formatting/sheets_user_defaults.dart';
import 'import_dialog.dart';
import 'import_pipeline.dart';

/// The server calls of Sheets' `/import` route (Drive 02 §7.2): the Drive
/// file's bytes for the import dialog's preview, and `drive.convertFile`,
/// which imports the stored bytes with the chosen options. Tests install a
/// fake with [install].
abstract class DriveFileImportApi {
  /// The bytes of the `file` item [fileItemUuid] (`drive.fileContentUrl`).
  Future<Uint8List> download(UuidValue fileItemUuid);

  /// Imports the file as a new spreadsheet into its folder (or My Drive)
  /// with [options] (`drive.convertFile`).
  Future<ImportReportView> convert(
    UuidValue fileItemUuid,
    DriveImportOptions options,
  );

  static final Expando<DriveFileImportApi> _apis = Expando(
    'DriveFileImportApi',
  );

  /// The API of [s] (null without a server client).
  static DriveFileImportApi? of(ShellServices s) {
    final installed = _apis[s];
    if (installed != null) return installed;
    if (s.client == null) return null;
    return _apis[s] = _ClientDriveFileImportApi(s);
  }

  /// Installs [api] for [s] (widget tests).
  static void install(ShellServices s, DriveFileImportApi api) =>
      _apis[s] = api;
}

class _ClientDriveFileImportApi implements DriveFileImportApi {
  _ClientDriveFileImportApi(this.s);

  final ShellServices s;

  @override
  Future<Uint8List> download(UuidValue fileItemUuid) async {
    final view = await s.client!.drive.fileContentUrl(
      fileItemUuid,
      download: false,
    );
    final url = view.url;
    if (url == null) {
      throw ImportRouteProblem(sheetsL10nOf(s).importRouteDownloadFailed);
    }
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw ImportRouteProblem(sheetsL10nOf(s).importRouteDownloadFailed);
    }
    return res.bodyBytes;
  }

  @override
  Future<ImportReportView> convert(
    UuidValue fileItemUuid,
    DriveImportOptions options,
  ) => s.client!.drive.convertFile(
    fileItemUuid,
    DriveItemKind.spreadsheet,
    options,
  );
}

/// A problem of the `/import` route, shown as the route's error toast.
class ImportRouteProblem implements Exception {
  const ImportRouteProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// `/import?file=<fileItemUuid>` of Wonky Sheets (Drive 02 §7.2, 04 §12):
/// *Open with ▸ Wonky Sheets* in Drive navigates here. The file's bytes are
/// loaded for the import dialog (04 §11.15, *Create new spreadsheet* only:
/// separator, encoding, locale, conversions, sheets, preview), then the
/// server imports the stored file with those options into the file's
/// folder (or My Drive), named after the file without its extension, and
/// the shell opens the new spreadsheet. The original file is kept.
///
/// Returns null when the dialog is cancelled or the *Out of storage* dialog
/// was shown (the shell goes back to Drive); problems (offline, not a
/// spreadsheet file, still uploading, download or server errors) are thrown
/// and shown as the route's toast.
Future<UuidValue?> importDriveFileAsSpreadsheet(
  BuildContext context,
  ShellServices s,
  ImportRouteRequest request,
) async {
  final l = sheetsL10nOf(s);
  final api = DriveFileImportApi.of(s);
  if (api == null || !s.connectivity.online) {
    throw ImportRouteProblem(l.importRouteOffline);
  }
  final file = await s.drive.get(request.fileItemUuid);
  switch (file.kind) {
    case DriveItemKind.spreadsheet:
      return file.uuid; // Already a spreadsheet (e.g. a reloaded link).
    case DriveItemKind.file:
      break;
    case _:
      throw ImportRouteProblem(l.importRouteNotAFile);
  }
  final ext = FileTypes.extensionOf(file.name);
  if (ext == 'xls') throw ImportRouteProblem(l.importLegacyXls);
  if (!SheetsFileImporter.extensions.contains(ext)) {
    throw ImportRouteProblem(l.importRouteUnsupported(file.name));
  }
  if (file.uploadState != null && file.uploadState != FileUploadState.ready) {
    throw ImportRouteProblem(l.importRouteUploading(file.name));
  }
  // Drive 03 §7.2: the new spreadsheet counts against the importing user;
  // the server checks again (estimate = file size, then the real size).
  if (!await s.storageChecks.ensureRoom(
    file.sizeBytes,
    reason: QuotaReasons.convert,
  )) {
    return null;
  }
  final bytes = await api.download(file.uuid);
  if (!context.mounted) return null;
  final picked = await showImportDialog(
    context,
    file: ImportFileData(name: file.name, bytes: bytes),
    location: ImportLocation.createNew,
    canEdit: false,
    spreadsheetLocale: SheetsUserDefaults.of(s).locale ?? 'en_US',
  );
  if (picked == null) return null;
  final options = picked.options.copyWith(location: ImportLocation.createNew);
  try {
    final r = await api.convert(
      file.uuid,
      DriveImportOptions(optionsJson: jsonEncode(options.toJson())),
    );
    lastImportReport.value = ImportReport(
      fileName: file.name,
      sheets: const [],
      warnings: [
        for (final w in r.warnings)
          ImportWarning(code: w.kind, message: w.message),
      ],
    );
    s.refreshDrive();
    return r.item.uuid;
  } catch (e) {
    final problem = s.quotaErrors.problemOf(
      e,
      itemKind: DriveItemKind.spreadsheet,
      reason: QuotaReasons.convert,
    );
    if (problem == null) rethrow;
    await s.quotaErrors.show(problem);
    return null;
  }
}
