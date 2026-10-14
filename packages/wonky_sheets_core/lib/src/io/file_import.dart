import 'dart:typed_data';

import 'csv/csv_importer.dart';
import 'csv/encoding.dart';
import 'ir/workbook_document.dart';
import 'json/json_workbook.dart';
import 'ods/ods_importer.dart';
import 'write/import_options.dart';
import 'xlsx/ooxml.dart' show XlsxFormatException;
import 'xlsx/xlsx_importer.dart';

/// File formats the import pipeline reads (11 §2–5).
enum SheetsFileFormat {
  /// Comma-separated (or any delimiter, detected).
  csv,

  /// Tab-separated.
  tsv,

  /// Office Open XML workbook (`.xlsx`, `.xlsm`).
  xlsx,

  /// OpenDocument spreadsheet.
  ods,

  /// Developer JSON (11 §6.7, `JsonWorkbook`).
  json,

  /// Legacy Excel (BIFF8): recognized but not readable (11 §5.4).
  xls;

  /// Whether the format is delimited text (CSV options apply).
  bool get isText => this == csv || this == tsv;

  /// Whether the format is a workbook (sheet list, unsupported formulas).
  bool get isWorkbook => this == xlsx || this == ods || this == json;
}

/// A sheet of a workbook file (import dialog's *Sheets to import*).
final class ImportFileSheet {
  /// Creates an entry.
  const ImportFileSheet(this.name, {this.hidden = false, this.cells = 0});

  final String name;
  final bool hidden;

  /// Estimated cells with values.
  final int cells;
}

/// A file parsed into the IR, with what CSV detection found.
final class ParsedImportFile {
  /// Creates a result.
  const ParsedImportFile({
    required this.document,
    required this.format,
    this.encoding,
    this.encodingReason,
    this.delimiter,
  });

  /// The IR of the file (all sheets; the planner applies
  /// `ImportOptions.sheets`).
  final WorkbookDocument document;
  final SheetsFileFormat format;

  /// CSV: the (detected or chosen) encoding and why (`bom`, `nulBytes`,
  /// `validUtf8`, `fallback`, `option`).
  final TextEncoding? encoding;
  final String? encodingReason;

  /// CSV: the (detected or chosen) delimiter.
  final String? delimiter;
}

/// Thrown for files the pipeline can't read (unknown type, legacy `.xls`,
/// broken zip/XML).
final class ImportFileException implements Exception {
  /// Creates the exception.
  const ImportFileException(this.code, this.message);

  /// `unsupported_format`, `legacy_xls` or `unreadable`.
  final String code;
  final String message;

  @override
  String toString() => 'ImportFileException($code): $message';
}

/// Entry point shared by the app and the server: file name + bytes → IR
/// (11 §3). Planning (`IrToRowsPlanner`) and writing stay with the caller.
abstract final class SheetsFileImporter {
  /// Extensions the import dialog accepts.
  static const extensions = {
    'csv',
    'tsv',
    'txt',
    'xlsx',
    'xlsm',
    'ods',
    'json',
    'xls',
  };

  /// The format of [fileName] (by extension; [head] bytes break ties for
  /// unknown extensions: a zip is XLSX, anything else CSV). Null when the
  /// file isn't importable.
  static SheetsFileFormat? formatOf(String fileName, [List<int>? head]) {
    final name = fileName.toLowerCase();
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1);
    switch (ext) {
      case 'csv' || 'txt':
        return SheetsFileFormat.csv;
      case 'tsv' || 'tab':
        return SheetsFileFormat.tsv;
      case 'xlsx' || 'xlsm':
        return SheetsFileFormat.xlsx;
      case 'ods':
        return SheetsFileFormat.ods;
      case 'json':
        return SheetsFileFormat.json;
      case 'xls':
        return SheetsFileFormat.xls;
    }
    if (head == null || head.isEmpty) return null;
    final zip = head.length > 3 && head[0] == 0x50 && head[1] == 0x4b;
    return zip ? SheetsFileFormat.xlsx : SheetsFileFormat.csv;
  }

  /// MIME type of [format] (uploads).
  static String mimeType(SheetsFileFormat format) => switch (format) {
    SheetsFileFormat.csv => 'text/csv',
    SheetsFileFormat.tsv => 'text/tab-separated-values',
    SheetsFileFormat.xlsx =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    SheetsFileFormat.ods => 'application/vnd.oasis.opendocument.spreadsheet',
    SheetsFileFormat.json => 'application/json',
    SheetsFileFormat.xls => 'application/vnd.ms-excel',
  };

  /// The sheets of a workbook file (empty for CSV/TSV).
  static List<ImportFileSheet> listSheets(
    Uint8List bytes,
    SheetsFileFormat format,
  ) {
    try {
      return switch (format) {
        SheetsFileFormat.xlsx => [
          for (final s in XlsxImporter.listSheets(bytes))
            if (!s.isChart)
              ImportFileSheet(
                s.name,
                hidden: s.hidden,
                cells: s.estimatedCells,
              ),
        ],
        SheetsFileFormat.ods => [
          for (final s in OdsImporter.listSheets(bytes))
            ImportFileSheet(s.name, hidden: s.hidden, cells: s.estimatedCells),
        ],
        SheetsFileFormat.json => [
          for (final s in JsonWorkbook.import(bytes).sheets)
            ImportFileSheet(s.name, hidden: s.hidden, cells: s.cells.length),
        ],
        _ => const [],
      };
    } on XlsxFormatException catch (e) {
      throw ImportFileException('unreadable', e.message);
    } on JsonWorkbookException catch (e) {
      throw ImportFileException('unreadable', e.message);
    }
  }

  /// Parses [bytes] of [fileName] with [options] (CSV: separator, encoding,
  /// locale — default [spreadsheetLocale] —, convert; XLSX/ODS: unsupported
  /// formulas). Every sheet is read; `options.sheets` is applied by the
  /// planner. [format] overrides the detection.
  static ParsedImportFile parse(
    Uint8List bytes, {
    required String fileName,
    ImportOptions options = const ImportOptions(),
    SheetsFileFormat? format,
    String spreadsheetLocale = 'en_US',
    DateTime? today,
  }) {
    final f = format ?? formatOf(fileName, bytes);
    switch (f) {
      case null:
        throw const ImportFileException(
          'unsupported_format',
          'This file type cannot be imported.',
        );
      case SheetsFileFormat.xls:
        throw const ImportFileException(
          'legacy_xls',
          'Save the file as .xlsx and import it again.',
        );
      case SheetsFileFormat.csv || SheetsFileFormat.tsv:
        var csv = options.csv(
          fileName: fileName,
          spreadsheetLocale: spreadsheetLocale,
          today: today,
        );
        if (f == SheetsFileFormat.tsv && csv.delimiter == null) {
          csv = CsvImportOptions(
            delimiter: '\t',
            encoding: csv.encoding,
            locale: csv.locale,
            convert: csv.convert,
            fileName: csv.fileName,
            today: csv.today,
          );
        }
        final r = CsvImporter.import(bytes, csv);
        return ParsedImportFile(
          document: r.document,
          format: f,
          encoding: r.encoding,
          encodingReason: r.encodingReason,
          delimiter: r.delimiter,
        );
      case SheetsFileFormat.xlsx:
        try {
          final x = options.xlsx();
          return ParsedImportFile(
            document: XlsxImporter.import(
              bytes,
              XlsxImportOptions(
                unsupportedFormulas: x.unsupportedFormulas,
                themeColorReferences: x.themeColorReferences,
                isSupportedFunction: x.isSupportedFunction,
              ),
            ),
            format: f,
          );
        } on XlsxFormatException catch (e) {
          throw ImportFileException('unreadable', e.message);
        }
      case SheetsFileFormat.ods:
        try {
          return ParsedImportFile(
            document: OdsImporter.import(
              bytes,
              OdsImportOptions(
                unsupportedFormulas: options.unsupportedFormulas,
                isSupportedFunction: ImportOptions.isWonkyFunction,
              ),
            ),
            format: f,
          );
        } on XlsxFormatException catch (e) {
          throw ImportFileException('unreadable', e.message);
        }
      case SheetsFileFormat.json:
        try {
          return ParsedImportFile(
            document: JsonWorkbook.import(bytes, fileName: fileName),
            format: f,
          );
        } on JsonWorkbookException catch (e) {
          throw ImportFileException('unreadable', e.message);
        }
    }
  }

  /// The file name without its extension ("orders" for `orders.csv`).
  static String baseName(String fileName) {
    final base = fileName.split(RegExp(r'[/\\]')).last;
    final dot = base.lastIndexOf('.');
    final b = (dot > 0 ? base.substring(0, dot) : base).trim();
    return b;
  }
}
