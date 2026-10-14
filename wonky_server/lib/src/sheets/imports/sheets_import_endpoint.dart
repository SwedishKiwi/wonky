import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import '../exports/sheets_export_service.dart';
import 'sheets_import_jobs.dart';

/// Server import jobs into an existing spreadsheet (Sheets 11 §3.3): big
/// files the client should not parse and plan itself. New spreadsheets are
/// imported with `drive.import`.
class SheetsImportEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Queues the import of the upload [uploadId] (`importSource`) into
  /// [spreadsheetUuid] with [optionsJson] (`ImportOptions`, 11 §9).
  /// [activeSheetId] is the target sheet of the in-sheet locations and the
  /// insert position of new sheets. Returns the job id.
  Future<UuidValue> importInto(
    Session session,
    UuidValue spreadsheetUuid,
    UuidValue uploadId,
    String optionsJson,
    String? activeSheetId,
  ) async => SheetsImportJobs.importInto(
    session,
    await UserService.actorOf(session),
    spreadsheetUuid,
    uploadId,
    optionsJson: optionsJson,
    activeSheetId: activeSheetId,
  );

  /// Progress of [jobId] until it is done, failed or cancelled.
  Stream<SheetsImportProgress> watchImport(
    Session session,
    UuidValue jobId,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* SheetsImportJobs.watch(session, actor, jobId);
  }

  /// The current progress of [jobId].
  Future<SheetsImportProgress> importProgress(
    Session session,
    UuidValue jobId,
  ) async => SheetsImportJobs.progress(
    session,
    await UserService.actorOf(session),
    jobId,
  );

  /// Another spreadsheet the caller can read as an XLSX file to import
  /// (*Import › Drive*, 11 §2.1): a signed download URL (15 min).
  Future<ExportResultView> sourceFromDrive(
    Session session,
    UuidValue itemUuid,
  ) async => SheetsExportService.export(
    session,
    await UserService.actorOf(session),
    itemUuid,
    'xlsx',
  );

  /// Cancels [jobId]; written chunks are reverted.
  Future<SheetsImportProgress> cancelImport(
    Session session,
    UuidValue jobId,
  ) async => SheetsImportJobs.cancel(
    session,
    await UserService.actorOf(session),
    jobId,
  );
}
