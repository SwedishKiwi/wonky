import 'dart:convert';
import 'dart:typed_data';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../format/number_format/number_formatter.dart';
import '../../formula/model/workbook_view.dart';
import '../../formula/values/dates.dart';
import '../../model/workbook_model.dart';
import '../numfmt/excel_number_formats.dart';

/// Value mode of a CSV export (11 §6.5).
enum CsvValueMode {
  /// As displayed (number formats applied).
  formatted,

  /// Unformatted: shortest numbers, ISO dates, `TRUE`/`FALSE`.
  raw,
}

/// Options of a CSV/TSV export.
final class CsvExportOptions {
  /// Creates options.
  const CsvExportOptions({
    this.delimiter = ',',
    this.values = CsvValueMode.formatted,
    this.includeBom = false,
    this.protectFormulaInjection = false,
    this.lineEnding = '\r\n',
    this.locale,
  });

  /// TSV options.
  const CsvExportOptions.tsv({
    this.values = CsvValueMode.formatted,
    this.includeBom = false,
    this.protectFormulaInjection = false,
    this.lineEnding = '\r\n',
    this.locale,
  }) : delimiter = '\t';

  /// `,` (CSV) or `\t` (TSV; tabs/newlines in values become spaces).
  final String delimiter;
  final CsvValueMode values;

  /// UTF-8 BOM for Excel.
  final bool includeBom;

  /// Prefix text starting with `= + - @`, tab or CR with `'`.
  final bool protectFormulaInjection;
  final String lineEnding;

  /// Formatting locale (default: the spreadsheet locale).
  final String? locale;

  /// Whether this is a TSV export.
  bool get isTsv => delimiter == '\t';
}

/// Exports one sheet (or range) as CSV/TSV (11 §6.5).
abstract final class CsvExporter {
  /// CSV text of [sheetId] (or [range] on it) using computed values from
  /// [source]. Hidden and filtered rows are included; trailing empty rows
  /// and columns are trimmed.
  static String exportText(
    WorkbookModel model,
    CellSource source, {
    required String sheetId,
    GridRect? range,
    CsvExportOptions options = const CsvExportOptions(),
  }) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) throw ArgumentError.value(sheetId, 'sheetId', 'Unknown sheet');
    final locale = options.locale ?? model.spreadsheet.locale;
    final grid = sheet.gridRect;
    if (grid == null) return '';
    var rect = range ?? grid;
    rect = rect.intersection(grid) ?? rect;
    // Trim to the last row/column with a value (formulas/overlays included).
    final used = sheet.usedRect();
    var lastRow = -1, lastCol = -1;
    final rows = <List<String>>[];
    final maxRow = range == null && used != null ? used.bottom : rect.bottom;
    final maxColScan = range == null && used != null ? used.right : rect.right;
    for (var r = rect.top; r <= (maxRow < rect.bottom ? maxRow : rect.bottom); r++) {
      final line = <String>[];
      for (var c = rect.left; c <= (maxColScan < rect.right ? maxColScan : rect.right); c++) {
        final v = source.valueAt(sheetId, r, c).toCellValue();
        final text = _text(v, source.numberFormatAt(sheetId, r, c), options, locale);
        line.add(text);
        if (text.isNotEmpty) {
          if (r > lastRow) lastRow = r;
          if (c - rect.left > lastCol) lastCol = c - rect.left;
        }
      }
      rows.add(line);
    }
    final b = StringBuffer();
    for (var i = 0; i <= lastRow - rect.top; i++) {
      final line = rows[i];
      for (var j = 0; j <= lastCol; j++) {
        if (j > 0) b.write(options.delimiter);
        b.write(_encodeField(j < line.length ? line[j] : '', options));
      }
      b.write(options.lineEnding);
    }
    return b.toString();
  }

  /// [exportText] as UTF-8 bytes (with BOM when requested).
  static Uint8List export(
    WorkbookModel model,
    CellSource source, {
    required String sheetId,
    GridRect? range,
    CsvExportOptions options = const CsvExportOptions(),
  }) {
    final text = exportText(model, source, sheetId: sheetId, range: range, options: options);
    final body = utf8.encode(text);
    if (!options.includeBom) return Uint8List.fromList(body);
    return Uint8List.fromList([0xef, 0xbb, 0xbf, ...body]);
  }

  /// Encodes rows of field texts (shared by tests and the property test).
  static String encodeRows(List<List<String>> rows, [CsvExportOptions options = const CsvExportOptions()]) {
    final b = StringBuffer();
    for (final r in rows) {
      for (var j = 0; j < r.length; j++) {
        if (j > 0) b.write(options.delimiter);
        b.write(_encodeField(r[j], options));
      }
      b.write(options.lineEnding);
    }
    return b.toString();
  }

  static String _text(CellValue v, String? pattern, CsvExportOptions o, String locale) {
    var s = switch (v) {
      EmptyValue() => '',
      TextValue(:final text) => text,
      BoolValue(:final value) => value ? 'TRUE' : 'FALSE',
      ErrorValue(:final kind) => kind.literal,
      NumberValue(:final number) =>
        o.values == CsvValueMode.raw ? _rawNumber(number, pattern) : NumberFormatter.instance.formatText(v, pattern, locale: locale),
    };
    if (o.protectFormulaInjection && v is TextValue && s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
    return s;
  }

  static String _rawNumber(double n, String? pattern) {
    final date = ExcelNumberFormats.isDatePattern(pattern);
    final time = ExcelNumberFormats.isTimePattern(pattern);
    if (!date) return CellContent.formatNumber(n);
    final ymd = DateSerial.toYmd(n);
    String two(int x) => x.toString().padLeft(2, '0');
    final d = '${ymd.year.toString().padLeft(4, '0')}-${two(ymd.month)}-${two(ymd.day)}';
    if (!time && n == n.floorToDouble()) return d;
    final t = DateSerial.timeOf(n);
    return '${d}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  static String _encodeField(String s, CsvExportOptions o) {
    if (o.isTsv) return s.replaceAll(RegExp('\r\n|[\t\r\n]'), ' ');
    if (s.contains(o.delimiter) || s.contains('"') || s.contains('\r') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
