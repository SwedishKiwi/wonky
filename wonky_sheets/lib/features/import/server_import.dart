import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        SheetsImportProgress,
        SheetsImportStatus,
        StoredFileKind,
        UuidValue,
        WonkyErrorCode,
        WonkyException;
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters;
import 'package:wonky_sheets_core/model.dart';

import '../import_export/progress_dialog.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'import_pipeline.dart';

/// The server side of imports into the open spreadsheet (11 §3.3):
/// upload, queue, watch, cancel. Tests install a fake with [install].
abstract class ServerImportApi {
  /// Uploads [file] as an import source; returns the upload id.
  Future<UuidValue> upload(ImportFileData file);

  /// Queues the import job; returns its id.
  Future<UuidValue> importInto(
    UuidValue spreadsheet,
    UuidValue upload,
    ImportOptions options, {
    String? activeSheetId,
  });

  Stream<SheetsImportProgress> watch(UuidValue job);

  Future<void> cancel(UuidValue job);

  /// Another spreadsheet of Drive as an XLSX file (*Import › Drive*).
  Future<ImportFileData> driveFile(UuidValue item, String name);

  static final Expando<ServerImportApi> _apis = Expando('ServerImportApi');

  /// The API of [s] (null when there is no server client).
  static ServerImportApi? of(ShellServices s) {
    final installed = _apis[s];
    if (installed != null) return installed;
    if (s.client == null) return null;
    return _apis[s] = _ClientServerImportApi(s);
  }

  /// Installs [api] for [s] (widget tests).
  static void install(ShellServices s, ServerImportApi api) => _apis[s] = api;
}

class _ClientServerImportApi implements ServerImportApi {
  _ClientServerImportApi(this.s);

  final ShellServices s;

  @override
  Future<UuidValue> upload(ImportFileData file) async {
    final r = await s.repositories.files.upload(
      fileUuid: s.ids.next(),
      fileName: file.name,
      mimeType: SheetsFileImporter.mimeType(
        file.format ?? SheetsFileFormat.csv,
      ),
      bytes: file.bytes,
      kind: StoredFileKind.importSource,
    );
    return r.fileUuid;
  }

  @override
  Future<UuidValue> importInto(
    UuidValue spreadsheet,
    UuidValue upload,
    ImportOptions options, {
    String? activeSheetId,
  }) => s.client!.sheetsImport.importInto(
    spreadsheet,
    upload,
    jsonEncode(options.toJson()),
    activeSheetId,
  );

  @override
  Stream<SheetsImportProgress> watch(UuidValue job) =>
      s.client!.sheetsImport.watchImport(job);

  @override
  Future<void> cancel(UuidValue job) =>
      s.client!.sheetsImport.cancelImport(job);

  @override
  Future<ImportFileData> driveFile(UuidValue item, String name) async {
    final r = await s.client!.sheetsImport.sourceFromDrive(item);
    final res = await http.get(Uri.parse(r.downloadUrl));
    if (res.statusCode != 200) {
      throw ServerImportException('The spreadsheet could not be downloaded.');
    }
    final base = name.trim().isEmpty ? 'Spreadsheet' : name.trim();
    return ImportFileData(name: '$base.xlsx', bytes: res.bodyBytes);
  }
}

/// The result of a finished server import.
typedef ServerImportResult = ({
  ImportReport report,
  String changeId,
  List<String> sheetIds,
});

/// Thrown when a server import job failed.
class ServerImportException implements Exception {
  const ServerImportException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Whether [file] (with [cells] cells when known) is imported by the
/// server (11 §3.1): online with a client, and above the client limits
/// (CSV/TSV > 20 MB or > 300k cells; XLSX/ODS > 5 MB or > 200k cells).
bool runsOnServer(ShellServices s, ImportFileData file, {int? cells}) {
  if (ServerImportApi.of(s) == null || !s.connectivity.online) return false;
  if (Api.simulatedOffline) return false;
  final fmt = file.format;
  if (fmt == null) return false;
  if (ImportThresholds.isLarge(file)) return true;
  final limit = fmt.isText
      ? ImportThresholds.csvCells
      : ImportThresholds.workbookCells;
  return (cells ?? 0) > limit;
}

/// The options sent to the server: the start cell of *Replace data at
/// selected cell* resolved to A1 (the server has no selection).
ImportOptions serverOptions(SheetEditorController ed, ImportOptions o) {
  if (o.location != ImportLocation.replaceAtCell) return o;
  final (r, c) = startCellOf(ed, o);
  return o.copyWith(cell: '${ColumnLetters.fromIndex(c)}${r + 1}');
}

/// Runs the import of [file] into the open spreadsheet of [ed] on the
/// server, reporting phases and cell progress to [p]. *Cancel* in the
/// progress dialog cancels the job (the server reverts what it wrote).
Future<ServerImportResult> runServerImport(
  SheetEditorController ed,
  ImportFileData file,
  ImportOptions options,
  IoProgress p, {
  required String uploadingText,
  required String queuedText,
  required String readingText,
  required String Function(int done, int total) writingText,
  required String finalizingText,
}) async {
  final api = ServerImportApi.of(ed.services)!;
  await p.step(uploadingText);
  final upload = await api.upload(file);
  p.check();
  final job = await api.importInto(
    ed.session.itemUuid,
    upload,
    serverOptions(ed, options),
    activeSheetId: ed.activeSheetId,
  );
  var cancelSent = false;
  void cancel() {
    if (cancelSent) return;
    cancelSent = true;
    unawaited(
      api.cancel(job).catchError((Object e) {
        debugPrint('Cancelling import $job failed: $e');
      }),
    );
  }

  p.onCancel = cancel;
  if (p.cancelled) cancel();
  runningServerImport.value = job;
  SheetsImportProgress? last;
  try {
    await for (final ev in api.watch(job)) {
      last = ev;
      switch (ev.status) {
        case SheetsImportStatus.queued:
          p.phase.value = queuedText;
          p.value.value = null;
        case SheetsImportStatus.parsing:
          p.phase.value = readingText;
          p.value.value = null;
        case SheetsImportStatus.writing:
          p.phase.value = writingText(ev.done, ev.total);
          p.value.value = ev.total <= 0 ? null : ev.done / ev.total;
        case SheetsImportStatus.finalizing:
          p.phase.value = finalizingText;
          p.value.value = 1;
        case SheetsImportStatus.done ||
            SheetsImportStatus.failed ||
            SheetsImportStatus.cancelled:
          break;
      }
    }
  } finally {
    if (runningServerImport.value == job) runningServerImport.value = null;
  }
  p.onCancel = null;
  final end = last;
  if (end == null) {
    throw const ServerImportException('The import did not start.');
  }
  switch (end.status) {
    case SheetsImportStatus.done:
      final reportJson = end.reportJson;
      final report = reportJson == null
          ? ImportReport(sheets: const [], warnings: const [])
          : ImportReport.fromJson(
              (jsonDecode(reportJson) as Map).cast<String, Object?>(),
            );
      return (
        report: report,
        changeId: end.changeId!.uuid,
        sheetIds: end.sheetIds ?? const [],
      );
    case SheetsImportStatus.cancelled:
      throw const IoCancelled();
    default:
      throw ServerImportException(
        end.error ?? 'The import failed.',
        code: end.errorCode,
      );
  }
}

/// The server import job running in this window (`sheets.file.cancelImport`).
final ValueNotifier<UuidValue?> runningServerImport = ValueNotifier(null);

/// Whether [e] means the server path can't be used right now (fall back to
/// the client import).
bool isServerUnavailable(Object e) =>
    isOfflineError(e) ||
    (e is WonkyException && e.code == WonkyErrorCode.unavailable);
