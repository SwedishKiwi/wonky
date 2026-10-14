import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../import_export/progress_dialog.dart';
import '../import_export/sheets_io.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// *File › Download* formats in menu order (04 §3.1) with their labels.
String downloadFormatLabel(SheetsLocalizations l, SheetsExportFormat f) =>
    switch (f) {
      SheetsExportFormat.xlsx => l.downloadXlsx,
      SheetsExportFormat.ods => l.downloadOds,
      SheetsExportFormat.pdf => l.downloadPdf,
      SheetsExportFormat.html => l.downloadHtml,
      SheetsExportFormat.csv => l.downloadCsv,
      SheetsExportFormat.tsv => l.downloadTsv,
      SheetsExportFormat.json => l.downloadJson,
    };

/// Whether the user may download/print the open spreadsheet: editors, or
/// anyone when the owner allows non-editors to download (suite 06 §1).
bool canDownload(SheetEditorController ed) {
  if (ed.itemRole >= Role.editor) return true;
  final item = ed.services.knownItem(ed.session.itemUuid);
  return item?.canDownload ?? true;
}

/// The spreadsheet's file title (drive name, else the model title).
String exportTitle(SheetEditorController ed) {
  final item = ed.services.knownItem(ed.session.itemUuid);
  final doc = ed.services.activeDocument.value;
  final docTitle = doc != null && doc.itemUuid == ed.session.itemUuid
      ? doc.title
      : null;
  final name =
      item?.name ??
      (docTitle?.isNotEmpty ?? false ? docTitle! : ed.model.spreadsheet.title);
  return name.trim().isEmpty ? ed.l10n.untitledSpreadsheet : name;
}

/// Builds the file of [format] from the open spreadsheet (11 §6.1): XLSX/ODS
/// convert the live model to the IR on the UI thread and write the file off
/// it; CSV/TSV export the active sheet; HTML zips every visible sheet. PDF
/// goes through the print route (`sheets.print.exportPdf`).
Future<SheetsExportArtifact> buildDownload(
  SheetEditorController ed,
  SheetsExportFormat format, {
  IoProgress? progress,
}) async {
  final l = ed.l10n;
  final model = ed.model;
  final source = ed.engine;
  final title = exportTitle(ed);
  final now = clock.now().toUtc();
  Map<String, Uint8List> images = const {};
  if (format != SheetsExportFormat.csv &&
      format != SheetsExportFormat.tsv &&
      format != SheetsExportFormat.json) {
    if (SheetsWorkbookExporter.imageFiles(model).isNotEmpty) {
      await progress?.step(l.exportPhaseImages);
      images = await fetchImageBytes(ed.services, model);
    }
  }
  switch (format) {
    case SheetsExportFormat.xlsx ||
        SheetsExportFormat.ods ||
        SheetsExportFormat.json:
      await progress?.step(l.exportPhasePreparing, 0.2);
      final doc = SheetsWorkbookExporter.toDocument(
        model,
        values: EngineIrValueSource(source),
        imageBytes: (u) => images[u],
        // Charts without an Excel equivalent become pictures (11 §6.3).
        chartSource: format == SheetsExportFormat.xlsx ? source : null,
      );
      await progress?.step(l.exportPhaseWriting, 0.5);
      final (bytes, warnings) = await runOffThread(
        () => SheetsWorkbookExporter.writeDocument(doc, format, modified: now),
      );
      return SheetsExportArtifact(
        fileName: SheetsWorkbookExporter.fileNameFor(title, format),
        mimeType: format.mimeType,
        bytes: bytes,
        warnings: warnings,
      );
    case SheetsExportFormat.csv || SheetsExportFormat.tsv:
      await progress?.step(l.exportPhaseWriting);
      final sheet = ed.activeSheet!;
      return SheetsExportArtifact(
        fileName: SheetsWorkbookExporter.fileNameFor(
          title,
          format,
          sheetName: sheet.name,
        ),
        mimeType: format.mimeType,
        bytes: SheetsWorkbookExporter.delimited(
          model,
          source,
          sheetId: sheet.id,
          format: format,
        ),
      );
    case SheetsExportFormat.html:
      await progress?.step(l.exportPhaseWriting);
      return SheetsExportArtifact(
        fileName: SheetsWorkbookExporter.fileNameFor(title, format),
        mimeType: format.mimeType,
        bytes: SheetsWorkbookExporter.html(
          model,
          source,
          imageBytes: (u) => images[u],
          conditional: ed.cells.conditional,
          modified: now,
        ),
      );
    case SheetsExportFormat.pdf:
      throw ArgumentError('PDF downloads go through the print route');
  }
}
