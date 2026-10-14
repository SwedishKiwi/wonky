import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/model.dart' as core;

import '../../platform/cluster/cluster.dart';
import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/files/file_service.dart';
import '../../platform/sharing/access_service.dart';
import '../headless/headless_workbook_provider.dart';
import '../mcp/sheets_bulk_writer.dart';
import '../mcp/sheets_mcp_support.dart';
import '../mcp/sheets_writes.dart';
import '../spaces/space_service.dart';
import 'sheets_import_service.dart';

/// Server import jobs into an existing spreadsheet (Sheets 11 §3.3, A-11-2).
///
/// `importInto` queues a [SheetsImportJob] for an uploaded file
/// (`StoredFileKind.importSource`) and returns its id; the instance that
/// queued it runs the user's jobs one at a time (a lease in the row keeps
/// other instances from running a second job of the same user): parse (in
/// an isolate for big files) → `IrToRowsPlanner` on the headless model →
/// [SheetsBulkWriter.apply] in chunks of ≤ 5,000 row changes (progress per
/// chunk, cancel checked between chunks) → one [ServerChangeRecord] (undo:
/// `sheets.serverChange`). A cancelled job reverts the chunks already
/// written. `watch` streams [SheetsImportProgress] until the job ends.
abstract final class SheetsImportJobs {
  /// How long a running job's lease lasts without renewal (renewed per
  /// chunk). A job whose lease ran out was interrupted (server restart).
  static Duration leaseDuration = const Duration(minutes: 2);

  /// How often `watch` reads the job row.
  static Duration pollInterval = const Duration(milliseconds: 300);

  /// Row changes written per progress step.
  static int chunkSize = SheetsBulkWriter.chunkSize;

  /// Test hook: runs before each written chunk (index, total chunks: -1,
  /// the chunks are planned while writing).
  // Visible for testing.
  static Future<void> Function(int chunk, int chunks)? beforeChunk;

  static const _running = {
    SheetsImportStatus.parsing,
    SheetsImportStatus.writing,
    SheetsImportStatus.finalizing,
  };

  static const _terminal = {
    SheetsImportStatus.done,
    SheetsImportStatus.failed,
    SheetsImportStatus.cancelled,
  };

  /// Users whose jobs this instance is draining.
  static final Map<int, Future<void>> _draining = {};

  /// Queues the import of the upload [uploadId] into [spreadsheetUuid].
  static Future<UuidValue> importInto(
    Session session,
    Actor actor,
    UuidValue spreadsheetUuid,
    UuidValue uploadId, {
    String? optionsJson,
    String? activeSheetId,
  }) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      spreadsheetUuid,
      Role.editor,
    );
    if (item.kind != DriveItemKind.spreadsheet || item.contentRef == null) {
      throw Errors.invalid('This item is not a spreadsheet.');
    }
    if (item.trashedAt != null) {
      throw Errors.invalid('The spreadsheet is in the trash.');
    }
    final file = await FileService.requireOwnReadyFile(
      session,
      actor,
      uploadId,
      kind: StoredFileKind.importSource,
    );
    final format = _formatOf(file.fileName);
    if (!SheetsImportService.formats.contains(format)) {
      throw Errors.invalid(
        format == 'xls'
            ? 'Legacy .xls files cannot be imported. Save the file as .xlsx '
                  'and import it again.'
            : 'Files of type "$format" cannot be imported as spreadsheets.',
      );
    }
    final options = _options(optionsJson);
    if (options.location == core.ImportLocation.createNew) {
      throw Errors.invalid(
        'Use drive.import to import a file as a new spreadsheet.',
      );
    }
    final now = clock.now().toUtc();
    final job = await SheetsImportJob.db.insertRow(
      session,
      SheetsImportJob(
        uuid: const Uuid().v7obj(),
        userId: actor.userId,
        authUserId: actor.authUserId,
        spreadsheetUuid: item.uuid,
        uploadFileId: uploadId,
        fileName: file.fileName,
        format: format == 'txt' ? 'csv' : format,
        optionsJson: jsonEncode(options.toJson()),
        activeSheetId: activeSheetId,
        status: SheetsImportStatus.queued,
        progressDone: 0,
        progressTotal: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    kick(session.serverpod, actor.userId);
    return job.uuid;
  }

  /// The current progress of [jobId] (the caller's own jobs only).
  static Future<SheetsImportProgress> progress(
    Session session,
    Actor actor,
    UuidValue jobId,
  ) async {
    final job = await _own(session, actor, jobId);
    return _progressOf(session, await _expireLease(session, job));
  }

  /// Streams the progress of [jobId] until it ends (the last event is
  /// `done`, `failed` or `cancelled`).
  static Stream<SheetsImportProgress> watch(
    Session session,
    Actor actor,
    UuidValue jobId,
  ) async* {
    var job = await _own(session, actor, jobId);
    SheetsImportProgress? last;
    while (true) {
      job = await _expireLease(session, job);
      final p = await _progressOf(session, job);
      if (last == null || !_same(last, p)) {
        last = p;
        yield p;
      }
      if (_terminal.contains(job.status)) return;
      if (job.status == SheetsImportStatus.queued) {
        kick(session.serverpod, job.userId);
      }
      await Future<void>.delayed(pollInterval);
      final next = await SheetsImportJob.db.findById(session, job.id!);
      if (next == null) return;
      job = next;
    }
  }

  /// Cancels [jobId]: a queued job ends right away; a running one stops
  /// after the current chunk and reverts what it wrote.
  static Future<SheetsImportProgress> cancel(
    Session session,
    Actor actor,
    UuidValue jobId,
  ) async {
    var job = await _own(session, actor, jobId);
    if (_terminal.contains(job.status)) return _progressOf(session, job);
    if (job.status == SheetsImportStatus.queued) {
      final rows = await session.db.unsafeQuery(
        r'''
        UPDATE sheets_import_job SET status = 'cancelled',
          "cancelRequested" = true, "updatedAt" = @now
        WHERE id = @id AND status = 'queued' RETURNING id
        ''',
        parameters: QueryParameters.named({
          'id': job.id,
          'now': clock.now().toUtc(),
        }),
      );
      if (rows.isNotEmpty) {
        await _deleteUpload(session, job);
        job = (await SheetsImportJob.db.findById(session, job.id!))!;
        return _progressOf(session, job);
      }
    }
    job = (await SheetsImportJob.db.findById(session, job.id!))!;
    if (!_terminal.contains(job.status)) {
      job = await SheetsImportJob.db.updateRow(
        session,
        job.copyWith(cancelRequested: true, updatedAt: clock.now().toUtc()),
        columns: (t) => [t.cancelRequested, t.updatedAt],
      );
    }
    return _progressOf(session, job);
  }

  /// Starts draining [userId]'s queued jobs on this instance (no-op while
  /// it already runs).
  static void kick(Serverpod pod, int userId) {
    if (_draining.containsKey(userId)) return;
    _draining[userId] = _drain(pod, userId).whenComplete(
      () => _draining.remove(userId),
    );
  }

  /// Completes when this instance has no more work for [userId] (tests).
  // Visible for testing.
  static Future<void> idle(int userId) async {
    while (_draining[userId] != null) {
      await _draining[userId];
    }
  }

  static Future<void> _drain(Serverpod pod, int userId) async {
    // Let the request that queued the job finish first.
    await Future<void>.delayed(Duration.zero);
    while (true) {
      final session = await pod.createSession(enableLogging: false);
      try {
        final job = await _claim(session, userId);
        if (job == null) return;
        await _run(session, job);
      } on Object catch (e, st) {
        session.log(
          'Import job of user $userId failed: $e',
          level: LogLevel.error,
          exception: e,
          stackTrace: st,
        );
        return;
      } finally {
        await session.close();
      }
    }
  }

  /// Leases the user's oldest queued job unless another one runs.
  static Future<SheetsImportJob?> _claim(Session session, int userId) async {
    final now = clock.now().toUtc();
    final rows = await session.db.unsafeQuery(
      r'''
      UPDATE sheets_import_job SET status = 'parsing', "leaseOwner" = @owner,
        "leaseUntil" = @until, "updatedAt" = @now
      WHERE id = (
        SELECT id FROM sheets_import_job
        WHERE "userId" = @user AND status = 'queued'
        ORDER BY "createdAt", id LIMIT 1)
      AND NOT EXISTS (
        SELECT 1 FROM sheets_import_job
        WHERE "userId" = @user
          AND status IN ('parsing', 'writing', 'finalizing')
          AND "leaseUntil" > @now)
      RETURNING id
      ''',
      parameters: QueryParameters.named({
        'owner': Cluster.instanceId,
        'until': now.add(leaseDuration),
        'now': now,
        'user': userId,
      }),
    );
    if (rows.isEmpty) return null;
    return SheetsImportJob.db.findById(session, rows.first.first as int);
  }

  static Future<SheetsImportJob> _update(
    Session session,
    SheetsImportJob job, {
    SheetsImportStatus? status,
    int? done,
    int? total,
  }) async {
    final now = clock.now().toUtc();
    return SheetsImportJob.db.updateRow(
      session,
      job.copyWith(
        status: status ?? job.status,
        progressDone: done ?? job.progressDone,
        progressTotal: total ?? job.progressTotal,
        updatedAt: now,
        leaseUntil: now.add(leaseDuration),
      ),
      columns: (t) => [
        t.status,
        t.progressDone,
        t.progressTotal,
        t.updatedAt,
        t.leaseUntil,
      ],
    );
  }

  static Future<bool> _cancelRequested(
    Session session,
    SheetsImportJob job,
  ) async =>
      (await SheetsImportJob.db.findById(session, job.id!))?.cancelRequested ??
      true;

  static Future<void> _finish(
    Session session,
    SheetsImportJob job,
    SheetsImportStatus status, {
    String? errorCode,
    String? error,
    String? reportJson,
    String? sheetIdsJson,
    UuidValue? changeId,
  }) async {
    await SheetsImportJob.db.updateRow(
      session,
      job.copyWith(
        status: status,
        errorCode: errorCode,
        error: error,
        reportJson: reportJson,
        sheetIdsJson: sheetIdsJson,
        changeId: changeId,
        updatedAt: clock.now().toUtc(),
        leaseUntil: null,
        leaseOwner: null,
      ),
    );
    await _deleteUpload(session, job);
  }

  static Future<void> _deleteUpload(
    Session session,
    SheetsImportJob job,
  ) async {
    try {
      await FileService.deleteFile(session, job.uploadFileId);
    } on Object catch (e) {
      session.log(
        'Deleting the import upload ${job.uploadFileId} failed: $e',
        level: LogLevel.warning,
      );
    }
  }

  static Future<void> _run(Session session, SheetsImportJob job) async {
    final actor = Actor(userId: job.userId, authUserId: job.authUserId);
    try {
      await _execute(session, actor, job);
    } on _Cancelled {
      await _finish(session, job, SheetsImportStatus.cancelled);
    } on WonkyException catch (e) {
      await _finish(
        session,
        job,
        SheetsImportStatus.failed,
        errorCode: e.code.name,
        error: e.message,
      );
    } on core.PlanException catch (e) {
      await _finish(
        session,
        job,
        SheetsImportStatus.failed,
        errorCode: e.code == 'cell_limit_exceeded' ? 'limit' : 'invalid',
        error: e.message,
      );
    } on Object catch (e, st) {
      session.log(
        'Import job ${job.uuid} failed: $e',
        level: LogLevel.error,
        exception: e,
        stackTrace: st,
      );
      await _finish(
        session,
        job,
        SheetsImportStatus.failed,
        errorCode: 'internal',
        error: 'The import failed.',
      );
    }
  }

  static Future<void> _execute(
    Session session,
    Actor actor,
    SheetsImportJob job,
  ) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      job.spreadsheetUuid,
      Role.editor,
    );
    await SpaceService.ensureWriter(
      session,
      actor,
      item,
      reason: SubscriptionReason.open,
    );
    final space = item.contentRef!;
    final file = await FileService.byUuid(session, job.uploadFileId);
    if (file == null) throw Errors.notFound('Upload');
    final data = await FileService.readBytes(session, file);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final options = _options(job.optionsJson);
    if (await _cancelRequested(session, job)) throw const _Cancelled();

    var wb = await HeadlessWorkbookProvider.open(session, space);
    final parsed = await SheetsImportService.parse(
      bytes,
      fileName: job.fileName,
      format: job.format,
      options: options,
      locale: options.locale ?? wb.model.spreadsheet.locale,
    );
    if (await _cancelRequested(session, job)) throw const _Cancelled();

    // Plan against the current model (refreshed after the parse).
    wb = await HeadlessWorkbookProvider.open(session, space);
    final model = wb.model;
    final activeSheetId =
        job.activeSheetId != null && model.sheet(job.activeSheetId!) != null
        ? job.activeSheetId
        : null;
    final ctx = core.PlanContext(
      userId: actor.authUserId.uuid,
      now: clock.now().toUtc(),
      formulas: wb.hooks,
      values: wb.engine,
      locale: model.spreadsheet.locale,
      maxCells: SheetsMcp.maxCells,
    );
    // Chunked planning (11 §3.5): the head (sheets, rows, columns, rules,
    // objects) first, then ≤ [chunkSize] cells per chunk, each applied to
    // the headless model (in-place writes read it) and written before the
    // next is planned, so the job never holds every row change at once.
    final chunks = core.IrToRowsPlanner.planChunked(
      parsed.document,
      model,
      ctx,
      options: options,
      activeSheetId: activeSheetId,
      fileName: job.fileName,
      chunkCells: chunkSize,
    );
    final label = chunks.head.label;
    var done = 0;
    job = await _update(
      session,
      job,
      status: SheetsImportStatus.writing,
      done: 0,
      total: chunks.totalCells,
    );

    // Image files first, so the objects never point at missing files.
    for (final img in chunks.imageUploads) {
      final f = await FileService.storeServerFile(
        session,
        ownerId: actor.userId,
        itemId: item.id,
        kind: StoredFileKind.image,
        fileName: img.name ?? 'image',
        mimeType: img.mimeType,
        bytes: img.bytes,
        fileUuid: UuidValue.fromString(img.fileUuid),
      );
      await FileService.attachToItem(session, f, item);
    }

    final applied = <core.RowChange>[];
    var written = 0;
    try {
      var i = 0;
      for (
        core.MutationPlan? plan = chunks.head;
        plan != null;
        plan = chunks.next(), i++
      ) {
        model.applyPlan(plan);
        // The head can exceed one bulk-writer chunk (big grids).
        for (var j = 0; j < plan.changes.length; j += chunkSize) {
          if (await _cancelRequested(session, job)) throw const _Cancelled();
          await beforeChunk?.call(written++, -1);
          final part = plan.changes.sublist(
            j,
            j + chunkSize > plan.changes.length
                ? plan.changes.length
                : j + chunkSize,
          );
          final r = await SheetsBulkWriter.apply(
            session,
            actor: actor,
            spaceUuid: space,
            changes: part,
            label: label,
            plans: i == 0 && j == 0 ? [plan] : const [],
            kinds: const {core.ChangeKinds.import},
          );
          applied.addAll(r.applied);
          done += part.where((c) => c.table == core.SheetsTables.cell).length;
          job = await _update(
            session,
            job,
            done: done > chunks.totalCells ? chunks.totalCells : done,
          );
        }
      }
    } on _Cancelled {
      await _revert(session, actor, space, applied, label);
      rethrow;
    } on Object {
      // A failed chunk: undo the chunks that were written.
      await _revert(session, actor, space, applied, label);
      rethrow;
    } finally {
      HeadlessWorkbookProvider.markStale(space);
    }
    final result = chunks.result;

    job = await _update(session, job, status: SheetsImportStatus.finalizing);
    final changeId = await SheetsChangeRecords.store(
      session,
      actor: actor,
      item: item,
      label: label,
      applied: applied,
    );
    await SheetsWrites.afterCommit(session, space);
    await _finish(
      session,
      job,
      SheetsImportStatus.done,
      reportJson: jsonEncode(result.report.toJson()),
      sheetIdsJson: jsonEncode(result.sheetIds),
      changeId: changeId,
    );
  }

  /// Reverts the chunks [applied] so far (cancel, failure).
  static Future<void> _revert(
    Session session,
    Actor actor,
    UuidValue space,
    List<core.RowChange> applied,
    String label,
  ) async {
    if (applied.isEmpty) return;
    final inverse = [for (final c in applied.reversed) c.inverse()];
    await SheetsBulkWriter.apply(
      session,
      actor: actor,
      spaceUuid: space,
      changes: inverse,
      label: 'Cancel $label',
      plans: const [],
      skipChanged: true,
      kinds: const {core.ChangeKinds.import},
    );
    await SheetsWrites.afterCommit(session, space);
  }

  // ------------------------------------------------------------- helpers

  static core.ImportOptions _options(String? json) {
    Map<String, Object?> m = const {};
    if (json != null && json.trim().isNotEmpty) {
      try {
        final d = jsonDecode(json);
        if (d is Map) m = d.cast<String, Object?>();
      } on FormatException {
        throw Errors.invalid('optionsJson is not valid JSON.');
      }
    }
    return core.ImportOptions.fromJson(m);
  }

  static String _formatOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static Future<SheetsImportJob> _own(
    Session session,
    Actor actor,
    UuidValue jobId,
  ) async {
    final job = await SheetsImportJob.db.findFirstRow(
      session,
      where: (t) => t.uuid.equals(jobId),
    );
    if (job == null || job.userId != actor.userId) {
      throw Errors.notFound('Import');
    }
    return job;
  }

  /// Marks a running job whose lease ran out as failed (its instance
  /// stopped).
  static Future<SheetsImportJob> _expireLease(
    Session session,
    SheetsImportJob job,
  ) async {
    final until = job.leaseUntil;
    if (!_running.contains(job.status) ||
        until == null ||
        until.isAfter(clock.now().toUtc())) {
      return job;
    }
    final failed = job.copyWith(
      status: SheetsImportStatus.failed,
      errorCode: 'unavailable',
      error: 'The import was interrupted. Import the file again.',
      updatedAt: clock.now().toUtc(),
    );
    await SheetsImportJob.db.updateRow(session, failed);
    kick(session.serverpod, job.userId);
    return failed;
  }

  static Future<SheetsImportProgress> _progressOf(
    Session session,
    SheetsImportJob job,
  ) async {
    var position = 0;
    if (job.status == SheetsImportStatus.queued) {
      position = await SheetsImportJob.db.count(
        session,
        where: (t) =>
            t.userId.equals(job.userId) &
            t.status.inSet(const {
              SheetsImportStatus.queued,
              SheetsImportStatus.parsing,
              SheetsImportStatus.writing,
              SheetsImportStatus.finalizing,
            }) &
            (t.createdAt < job.createdAt),
      );
    }
    List<String>? sheetIds;
    final ids = job.sheetIdsJson;
    if (ids != null) {
      sheetIds = [
        for (final s in jsonDecode(ids) as List<dynamic>)
          if (s is String) s,
      ];
    }
    return SheetsImportProgress(
      jobId: job.uuid,
      status: job.status,
      done: job.progressDone,
      total: job.progressTotal,
      queuePosition: position,
      reportJson: job.reportJson,
      changeId: job.changeId,
      sheetIds: sheetIds,
      errorCode: job.errorCode,
      error: job.error,
    );
  }

  static bool _same(SheetsImportProgress a, SheetsImportProgress b) =>
      a.status == b.status &&
      a.done == b.done &&
      a.total == b.total &&
      a.queuePosition == b.queuePosition;
}

class _Cancelled implements Exception {
  const _Cancelled();
}
