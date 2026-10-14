import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/export/sheets_downloads.dart';
import '../features/import/import_dialog.dart';
import '../features/import/import_pipeline.dart';
import '../features/import/server_import.dart';
import '../features/history/server_change_undo.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import '../features/import_export/io_report_dialog.dart';
import '../features/import_export/pending_uploads.dart';
import '../features/import_export/progress_dialog.dart';
import '../features/import_export/sheets_io.dart';
import '../l10n/sheets_l10n.dart';
import 'sheets_command.dart';

String _file(SheetsLocalizations l) => l.categoryFile;

/// Parsed files handed from the dialog to `sheets.file.importData`.
final Map<String, ParsedImportFile> _parsedByToken = {};

/// The `options` argument (ImportOptions JSON, 11 §9).
ImportOptions? _optionsArg(JsonArgs a) {
  final raw = a.values['options'];
  return raw is Map
      ? ImportOptions.fromJson(raw.cast<String, Object?>())
      : null;
}

/// The file of `fileToken` or `fileName` + `contentBase64`.
ImportFileData? _fileArg(JsonArgs a, {bool take = true}) {
  final token = a.string('fileToken');
  final f = take
      ? ImportFileRegistry.take(token)
      : ImportFileRegistry.peek(token);
  if (f != null) return f;
  final name = a.string('fileName');
  final b64 = a.string('contentBase64');
  final text = a.string('text');
  if (name == null || (b64 == null && text == null)) return null;
  return ImportFileData(
    name: name,
    bytes: b64 != null
        ? base64Decode(b64)
        : Uint8List.fromList(utf8.encode(text!)),
  );
}

const _importSchema = JsonSchema.object(
  properties: {
    'fileName': JsonSchema.string(
      description: 'File name with extension (csv, tsv, txt, xlsx, ods).',
    ),
    'contentBase64': JsonSchema.string(description: 'File content (base64).'),
    'text': JsonSchema.string(description: 'CSV/TSV content as text.'),
    'fileToken': JsonSchema.string(),
    'options': JsonSchema.object(
      description:
          'ImportOptions: {location: createNew|insertSheets|'
          'replaceSpreadsheet|replaceSheet|append|replaceAtCell, cell?, '
          'separator?, encoding?, locale?, convert?, sheets?, '
          'unsupportedFormulas?}. With a file and options the import runs '
          'without the dialog.',
      additionalProperties: true,
    ),
    'showDialog': JsonSchema.boolean(),
    'onServer': JsonSchema.boolean(
      description:
          'Import into the open spreadsheet with a server job (true) or on '
          'this device (false). Default: big files on the server while '
          'online.',
    ),
  },
);

/// The summary toast text of [r] (11 §2.3).
String importSummaryText(SheetsLocalizations l, ImportReport r) {
  final base = l.importSummary(r.sheets.length, r.cellCount);
  return r.warnings.isEmpty
      ? base
      : l.importSummaryWarnings(base, r.warnings.length);
}

/// Opens the import summary of [r].
Future<void> showImportReport(BuildContext context, ImportReport r) {
  final l = sheetsL10n(context);
  return showIoReportDialog(
    context,
    title: l.importSummaryTitle,
    summary: r.sheets.isEmpty && r.warnings.isEmpty
        ? (r.fileName ?? '')
        : importSummaryText(l, r),
    sheets: r.sheets,
    warnings: r.warnings,
  );
}

/// Keeps [file] for *Recent uploads* of the import dialog.
void _rememberImport(ShellServices s, ImportFileData file) {
  final q = SheetsPendingUploads.of(s);
  if (q != null) unawaited(q.recordRecentImport(file.name, file.bytes));
}

void _showImportToast(
  ShellServices s,
  SheetsLocalizations l,
  ImportReport report,
) => s.toasts.show(
  importSummaryText(l, report),
  actionLabel: report.warnings.isEmpty ? null : l.importView,
  onAction: report.warnings.isEmpty
      ? null
      : () {
          final nc = s.navigatorContext;
          if (nc != null) showImportReport(nc, report);
        },
);

/// Imports [file] into the open spreadsheet with a server job (11 §3.3):
/// progress with cancel, one `sheets.serverChange` undo step. Null when the
/// server can't be reached (the caller imports on the client).
Future<CommandResult?> _importOnServer(
  CommandContext ctx,
  SheetEditorController ed,
  ImportFileData file,
  ImportOptions options,
) async {
  final s = ed.services;
  final l = ed.l10n;
  Future<ServerImportResult> work(IoProgress p) => runServerImport(
    ed,
    file,
    options,
    p,
    uploadingText: l.importPhaseUploading,
    queuedText: l.importPhaseQueued,
    readingText: l.importPhaseReading,
    writingText: l.importPhaseWritingCells,
    finalizingText: l.importPhaseFinalizing,
  );
  final c = ctx.dialogContext;
  final ServerImportResult? r;
  try {
    r = c == null
        ? await work(IoProgress())
        : await runWithProgress(
            c,
            title: l.importProgressTitle(file.name),
            work: work,
          );
  } on IoCancelled {
    return const CommandResult.cancelled();
  } catch (e) {
    if (isServerUnavailable(e)) return null;
    showIoError(s, l.importFailed, e);
    return CommandResult.failed(errorMessage(e));
  }
  if (r == null) return const CommandResult.cancelled();
  if (ctx.transaction != null) {
    ctx.record(
      SheetsServerChangeEntry(
        changeId: r.changeId,
        label: l.importUndoLabel(file.name),
      ),
    );
  }
  lastImportReport.value = r.report;
  _rememberImport(s, file);
  if (options.location.createsSheets && r.sheetIds.isNotEmpty) {
    unawaited(activateWhenSynced(ed, r.sheetIds.first));
  }
  _showImportToast(s, l, r.report);
  return CommandResult.ok({
    ...r.report.toJson(),
    'server': true,
    'changeId': r.changeId,
  });
}

/// Activates [sheetId] once the sync delivered it (server imports).
Future<void> activateWhenSynced(
  SheetEditorController ed,
  String sheetId, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (ed.model.sheet(sheetId) != null) {
      ed.activateSheet(sheetId);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

/// Import, import report and download commands (11 §9, 04 §3.1).
List<Command<CommandArgs>> fileIoCommands(ShellServices s) {
  // Durable image uploads of imports (signed-in app only).
  if (s.client != null) SheetsPendingUploads.install(s);
  Future<CommandResult> createNew(
    CommandContext ctx,
    ImportFileData file,
    ImportOptions options,
  ) async {
    final l = sheetsL10nOf(s);
    final c = ctx.dialogContext;
    Future<ImportedSpreadsheet> work(IoProgress p) async {
      await p.step(
        s.connectivity.online ? l.importPhaseUploading : l.importPhaseReading,
      );
      return importAsNewSpreadsheet(
        s,
        file,
        options,
        parentUuid: s.currentFolder.value?.uuid,
      );
    }

    final ImportedSpreadsheet? r;
    try {
      r = c == null
          ? await work(IoProgress())
          : await runWithProgress(
              c,
              title: l.importProgressTitle(file.name),
              cancellable: false,
              work: work,
            );
    } catch (e) {
      showIoError(s, l.importFailed, e);
      return CommandResult.failed(errorMessage(e));
    }
    if (r == null) return const CommandResult.cancelled();
    final created = r;
    _rememberImport(s, file);
    s.toasts.show(
      l.importCreated(created.name),
      description: created.report.warnings.isEmpty
          ? null
          : l.importWarningsCount(created.report.warnings.length),
      actionLabel: l.importOpen,
      onAction: () => s.router.go('/s/${created.uuid.uuid}'),
    );
    return CommandResult.ok({
      'itemUuid': created.uuid.uuid,
      'name': created.name,
      'warnings': [for (final w in created.report.warnings) w.toJson()],
    });
  }

  return [
    SheetsCommand(
      'sheets.file.import',
      label: (l) => l.cmdFileImport,
      icon: LucideIcons.fileUp,
      categoryName: _file,
      keyScope: KeyScope.global,
      argsSchema: _importSchema,
      run: (ctx, ed, a) async {
        final c = ctx.dialogContext;
        var file = _fileArg(a);
        var options = _optionsArg(a);
        ParsedImportFile? parsed;
        if (file == null ||
            options == null ||
            a.boolean('showDialog') == true) {
          if (c == null) {
            return const CommandResult.failed(
              'Pass fileName + contentBase64 (or text) and options.',
            );
          }
          final r = await showImportDialog(
            c,
            file: file,
            location: options?.location,
            canEdit: ed.canEdit,
            spreadsheetLocale: ed.locale,
            activeCell: ed.activeA1,
            exclude: ed.session.itemUuid,
            estimate: (p, o) => estimateImport(
              p,
              ed.model,
              o,
              activeSheetId: ed.activeSheetId,
              start: o.location == ImportLocation.replaceAtCell
                  ? startCellOf(ed, o)
                  : null,
              maxCells: ed.session.planContext().maxCells,
            ),
          );
          if (r == null) return const CommandResult.cancelled();
          file = r.file;
          options = r.options;
          parsed = r.parsed;
        }
        if (options.location == ImportLocation.createNew) {
          return createNew(ctx, file, options);
        }
        if (!ed.canEdit) {
          return CommandResult.failed(ed.l10n.reasonViewAccess);
        }
        final token = ImportFileRegistry.put(file);
        if (parsed != null) _parsedByToken[token] = parsed;
        return s.dispatcher.invoke(
          'sheets.file.importData',
          args: {
            'fileToken': token,
            'options': options.toJson(),
            'onServer': ?a.boolean('onServer'),
          },
          source: ctx.source,
          context: ctx.buildContext,
        );
      },
    ),
    SheetsCommand(
      'sheets.file.importData',
      label: (l) => l.cmdFileImportData,
      icon: LucideIcons.fileUp,
      categoryName: _file,
      mutates: true,
      showInPalette: false,
      argsSchema: _importSchema,
      undoLabelOf: (l, a) {
        final f = _fileArg(a, take: false);
        return f == null ? l.cmdFileImport : l.importUndoLabel(f.name);
      },
      run: (ctx, ed, a) async {
        final l = ed.l10n;
        final token = a.string('fileToken');
        final file = _fileArg(a);
        final options = _optionsArg(a);
        if (file == null || options == null) {
          return const CommandResult.failed('Pass a file and options.');
        }
        if (options.location == ImportLocation.createNew) {
          return const CommandResult.failed(
            'Use sheets.file.import to create a new spreadsheet.',
          );
        }
        var parsed = token == null ? null : _parsedByToken.remove(token);
        final cells = parsed?.document.sheets.fold<int>(
          0,
          (n, sh) => n + sh.cells.length,
        );
        // Big files go to a server import job while online (11 §3.1).
        final onServer = a.boolean('onServer');
        if (onServer == true && ServerImportApi.of(s) == null) {
          return const CommandResult.failed('No server connection.');
        }
        if (onServer ?? runsOnServer(s, file, cells: cells)) {
          final served = await _importOnServer(ctx, ed, file, options);
          if (served != null) return served;
        }
        Future<IrImportResult> work(IoProgress p) async {
          if (parsed == null) {
            await p.step(l.importPhaseReading);
            parsed = await parseImportFile(
              file,
              options,
              spreadsheetLocale: ed.locale,
            );
          }
          await p.step(l.importPhaseWriting);
          return applyImport(
            ed,
            ctx,
            parsed!,
            options,
            fileName: file.name,
            progress: p,
          );
        }

        final c = ctx.dialogContext;
        final IrImportResult? r;
        try {
          r = c == null || !c.mounted
              ? await work(IoProgress())
              : await runWithProgress(
                  c,
                  title: l.importProgressTitle(file.name),
                  work: work,
                );
        } on PlanException catch (e) {
          showIoError(s, l.importFailed, e.message);
          return CommandResult.failed(e.message);
        } on ImportFileException catch (e) {
          showIoError(s, l.importFailed, e.message);
          return CommandResult.failed(e.message);
        }
        if (r == null) return const CommandResult.cancelled();
        final result = r;
        if (options.location.createsSheets && result.sheetIds.isNotEmpty) {
          ed.activateSheet(result.sheetIds.first);
        }
        final report = result.report;
        _rememberImport(s, file);
        _showImportToast(s, l, report);
        return CommandResult.ok(report.toJson());
      },
    ),
    SheetsCommand(
      'sheets.file.cancelImport',
      label: (l) => l.cmdFileCancelImport,
      icon: LucideIcons.circleX,
      categoryName: _file,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'jobId': JsonSchema.string(
            description: 'Server import job (default: the running one).',
          ),
        },
      ),
      enabled: (ed, a) =>
          a.string('jobId') != null || runningServerImport.value != null,
      run: (ctx, ed, a) async {
        final raw = a.string('jobId');
        final job = raw == null
            ? runningServerImport.value
            : UuidValue.withValidation(raw);
        final api = ServerImportApi.of(s);
        if (job == null || api == null) {
          return const CommandResult.failed('No import is running.');
        }
        await api.cancel(job);
        return CommandResult.ok({'jobId': job.uuid});
      },
    ),
    SheetsCommand(
      'sheets.file.showImportReport',
      label: (l) => l.cmdFileShowImportReport,
      icon: LucideIcons.fileText,
      categoryName: _file,
      enabled: (ed, a) => lastImportReport.value != null,
      run: (ctx, ed, a) async {
        final r = lastImportReport.value;
        if (r == null) return CommandResult.failed(ed.l10n.importNoReport);
        final c = ctx.dialogContext;
        if (c != null) await showImportReport(c, r);
        return CommandResult.ok(r.toJson());
      },
    ),
    SheetsCommand(
      'sheets.file.download',
      label: (l) => l.cmdFileDownload,
      icon: LucideIcons.download,
      categoryName: _file,
      keyScope: KeyScope.global,
      argsSchema: JsonSchema.object(
        properties: {
          'format': JsonSchema.string(
            enumValues: [for (final f in SheetsExportFormat.values) f.name],
          ),
        },
      ),
      enabled: (ed, a) => canDownload(ed),
      run: (ctx, ed, a) async {
        final l = ed.l10n;
        final format =
            SheetsExportFormat.tryParse(a.string('format')) ??
            SheetsExportFormat.xlsx;
        if (format == SheetsExportFormat.pdf) {
          s.router.go('/s/${ed.session.itemUuid.uuid}/print?export=1');
          return ok();
        }
        final c = ctx.dialogContext;
        final SheetsExportArtifact? artifact;
        try {
          artifact = c == null
              ? await buildDownload(ed, format)
              : await runWithProgress(
                  c,
                  title: l.exportProgressTitle(downloadFormatLabel(l, format)),
                  work: (p) => buildDownload(ed, format, progress: p),
                );
        } catch (e) {
          showIoError(s, l.exportFailed, e);
          return CommandResult.failed(errorMessage(e));
        }
        if (artifact == null) return const CommandResult.cancelled();
        final saved = await saveBytes(
          artifact.bytes,
          fileName: artifact.fileName,
          mimeType: artifact.mimeType,
          dialogTitle: l.exportSaveDialogTitle(artifact.fileName),
        );
        if (!saved) return const CommandResult.cancelled();
        final warnings = artifact.warnings;
        if (warnings.isNotEmpty) {
          final file = artifact.fileName;
          s.toasts.show(
            l.exportDoneWithNotes(file, warnings.length),
            actionLabel: l.importView,
            onAction: () {
              final nc = s.navigatorContext;
              if (nc == null) return;
              showIoReportDialog(
                nc,
                title: l.exportReportTitle,
                summary: l.exportReportSummary(file),
                warnings: warnings,
              );
            },
          );
        }
        return CommandResult.ok({
          'fileName': artifact.fileName,
          'sizeBytes': artifact.bytes.length,
          'warnings': [for (final w in warnings) w.toJson()],
        });
      },
    ),
  ];
}
