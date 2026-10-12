import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../../write/content/write_content.dart';
import '../../write/ot/document_store.dart';
import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../config/wonky_config.dart';
import '../files/file_service.dart';
import 'drive_service.dart';
import 'templates/builtin_templates.dart';

/// Server-side imports (`drive.import`, Write 07 §3.2, Sheets 11): Markdown
/// and plain text become documents, CSV/TSV become spreadsheets.
abstract final class ImportService {
  static const documentFormats = {'md', 'markdown', 'mdown', 'mkd', 'txt', 'text'};
  static const spreadsheetFormats = {'csv', 'tsv'};

  static String _format(StoredFile file, DriveImportOptions options) {
    final explicit = options.format?.toLowerCase().trim();
    if (explicit != null && explicit.isNotEmpty && explicit != 'auto') {
      return explicit;
    }
    final name = file.fileName.toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot >= 0) return name.substring(dot + 1);
    return switch (file.mimeType) {
      'text/csv' => 'csv',
      'text/tab-separated-values' => 'tsv',
      'text/plain' => 'txt',
      _ => 'md',
    };
  }

  static String _baseName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.trim().isEmpty ? 'Imported' : base.trim();
  }

  static Future<ImportReportView> import(
    Session session,
    Actor actor,
    UuidValue uploadId,
    DriveItemKind kind,
    DriveImportOptions options,
  ) async {
    final file = await FileService.requireOwnReadyFile(
      session,
      actor,
      uploadId,
      kind: StoredFileKind.importSource,
    );
    final format = _format(file, options);
    final bytes = await FileService.readBytes(session, file);
    final text = utf8.decode(
      bytes.buffer.asUint8List(0, bytes.lengthInBytes),
      allowMalformed: true,
    );
    final ImportReportView report;
    switch (kind) {
      case DriveItemKind.document:
        if (!documentFormats.contains(format)) {
          throw Errors.invalid('Files of type "$format" cannot be imported as documents.');
        }
        report = await _document(session, actor, file, format, text, options);
      case DriveItemKind.spreadsheet:
        if (!spreadsheetFormats.contains(format)) {
          throw Errors.invalid('Files of type "$format" cannot be imported as spreadsheets.');
        }
        report = await _spreadsheet(session, actor, file, format, text, options);
      case DriveItemKind.folder:
        throw Errors.invalid('Folders cannot be imported.');
    }
    await FileService.deleteFile(session, file.fileUuid);
    return report;
  }

  static Future<ImportReportView> _document(
    Session session,
    Actor actor,
    StoredFile file,
    String format,
    String text,
    DriveImportOptions options,
  ) async {
    final isText = format == 'txt' || format == 'text';
    final soft = isText &&
        (jsonDecode(options.optionsJson ?? '{}') as Map)['lineBreaks'] == 'soft';
    final converted = isText
        ? WriteContent.fromPlainText(text, softBreaks: soft)
        : null;
    final markdown = isText ? null : WriteContent.fromMarkdown(text);
    final delta = converted?.delta ?? markdown!.delta;
    final warnings = converted?.warnings ?? markdown!.warnings;
    if (text.length > WonkyConfig.current.maxDocumentChars) {
      throw Errors.tooLarge(
        'The file is too large to import. Split it into smaller files.',
      );
    }
    final name = options.name ?? markdown?.title ?? _baseName(file.fileName);
    final view = await DriveService.createDocumentFromContent(
      session,
      actor,
      name: name.length > 255 ? name.substring(0, 255) : name,
      parentUuid: options.parentUuid,
      content: delta,
      frontMatter: markdown?.frontMatter,
      activitySummary: {'importedFrom': isText ? 'txt' : 'md'},
    );
    if (warnings.isNotEmpty) {
      final doc = await DocumentStore.byUuid(session, view.contentRef!);
      if (doc != null) {
        await DocumentImportReport.db.insertRow(
          session,
          DocumentImportReport(
            documentId: doc.id!,
            userId: actor.userId,
            warningsJson: jsonEncode([for (final w in warnings) w.toJson()]),
            createdAt: nowUtc(),
          ),
        );
      }
    }
    return ImportReportView(item: view, warnings: warnings);
  }

  static Future<ImportReportView> _spreadsheet(
    Session session,
    Actor actor,
    StoredFile file,
    String format,
    String text,
    DriveImportOptions options,
  ) async {
    final opts = (jsonDecode(options.optionsJson ?? '{}') as Map)
        .cast<String, dynamic>();
    final delimiter = (opts['delimiter'] as String?) ??
        (format == 'tsv' ? '\t' : _guessDelimiter(text));
    final rows = parseDelimited(text, delimiter);
    final columns = rows.fold(0, (m, r) => r.length > m ? r.length : m);
    final warnings = <ImportWarningView>[];
    if (columns > 26) {
      warnings.add(
        ImportWarningView(
          kind: 'columnsTruncated',
          message: 'Only the first 26 columns were imported.',
        ),
      );
    }
    final cells = rows.length * (columns > 26 ? 26 : columns);
    if (cells > WonkyConfig.current.maxCellsPerSpreadsheet) {
      throw Errors.limit(
        'This file would exceed the limit of '
        '${WonkyConfig.current.maxCellsPerSpreadsheet} cells.',
      );
    }
    final convert = opts['convertNumbers'] != false;
    final formulas = opts['formulas'] == true;
    // A leading apostrophe forces text, as when typing into a cell.
    final sheetRows = [
      for (final r in rows)
        [
          for (final v in r.take(26))
            (!convert && double.tryParse(v.trim()) != null) ||
                    (!formulas && v.startsWith('=')) ||
                    v.startsWith("'")
                ? "'$v"
                : v,
        ],
    ];
    final name = options.name ?? _baseName(file.fileName);
    final header = opts['headerRow'] == true;
    final view = await DriveService.createSpreadsheetFromSheets(
      session,
      actor,
      name: name.length > 255 ? name.substring(0, 255) : name,
      parentUuid: options.parentUuid,
      sheets: [
        TemplateSheet(
          name: 'Sheet1',
          rows: sheetRows,
          boldRows: header ? {0} : const {},
          frozenRows: header ? 1 : 0,
        ),
      ],
      summary: {'importedFrom': format},
    );
    return ImportReportView(item: view, warnings: warnings);
  }

  static String _guessDelimiter(String text) {
    final firstLine = text.split('\n').first;
    final candidates = {',': 0, ';': 0, '\t': 0, '|': 0};
    for (final c in candidates.keys.toList()) {
      candidates[c] = c.allMatches(firstLine).length;
    }
    final best = candidates.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.value == 0 ? ',' : best.key;
  }

  /// RFC 4180 parsing with [delimiter] (quotes, escaped quotes, CRLF).
  static List<List<String>> parseDelimited(String text, String delimiter) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var i = 0;
    final s = text.startsWith('﻿') ? text.substring(1) : text;
    while (i < s.length) {
      final ch = s[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < s.length && s[i + 1] == '"') {
            field.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
        } else {
          field.write(ch);
        }
        i++;
        continue;
      }
      if (ch == '"' && field.isEmpty) {
        inQuotes = true;
      } else if (s.startsWith(delimiter, i)) {
        row.add(field.toString());
        field.clear();
        i += delimiter.length;
        continue;
      } else if (ch == '\n' || ch == '\r') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
        if (ch == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
      } else {
        field.write(ch);
      }
      i++;
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
