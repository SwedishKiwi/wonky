import '../../addressing/a1.dart';
import '../formula/function_map.dart';
import '../csv/csv_importer.dart';
import '../csv/encoding.dart';
import '../xlsx/xlsx_importer.dart';

/// Where an import writes its data (11 §2.2).
enum ImportLocation {
  /// A new spreadsheet (new Drive item). Not undoable.
  createNew,

  /// New sheets after the active sheet ("Name (2)" on conflicts).
  insertSheets,

  /// Deletes every sheet (with rules and objects) and inserts the imported
  /// sheets. Title, sharing, comments and scripts stay.
  replaceSpreadsheet,

  /// Clears the active sheet and writes the data from A1 (CSV).
  replaceSheet,

  /// Writes after the last row with content of the active sheet, column A
  /// (CSV).
  append,

  /// Writes starting at a cell of the active sheet, overwriting (CSV).
  replaceAtCell;

  /// Whether the location creates sheets (any file type) rather than
  /// writing into the active sheet (CSV only in the dialog).
  bool get createsSheets =>
      this == createNew || this == insertSheets || this == replaceSpreadsheet;

  /// By name; null for unknown names.
  static ImportLocation? byName(Object? name) {
    for (final l in values) {
      if (l.name == name) return l;
    }
    return null;
  }
}

/// `ImportOptions` JSON shared by the import dialog, the
/// `sheets.file.import` command and MCP (11 §9):
///
/// ```jsonc
/// {"location": "insertSheets", "cell": "B4", "separator": "auto",
///  "encoding": "auto", "locale": "de_DE", "convert": true,
///  "sheets": ["Orders"], "unsupportedFormulas": "value"}
/// ```
final class ImportOptions {
  /// Creates options.
  const ImportOptions({
    this.location = ImportLocation.createNew,
    this.cell,
    this.separator,
    this.encoding,
    this.locale,
    this.convert = true,
    this.sheets,
    this.unsupportedFormulas = UnsupportedFormulaMode.value,
  });

  /// Target location.
  final ImportLocation location;

  /// Start cell (A1) for [ImportLocation.replaceAtCell].
  final String? cell;

  /// CSV field separator; null = detect (`"auto"` in JSON).
  final String? separator;

  /// CSV encoding; null = detect (`"auto"` in JSON).
  final TextEncoding? encoding;

  /// Locale for CSV numbers and dates; null = the spreadsheet locale.
  final String? locale;

  /// Convert CSV text to numbers, dates and formulas.
  final bool convert;

  /// XLSX/ODS sheet names to import; null = all.
  final List<String>? sheets;

  /// XLSX/ODS formulas with functions Wonky lacks.
  final UnsupportedFormulaMode unsupportedFormulas;

  /// Parses the JSON map (unknown values fall back to defaults).
  static ImportOptions fromJson(Map<String, Object?> json) {
    String? str(String k) {
      final v = json[k];
      return v is String && v.isNotEmpty ? v : null;
    }

    final sep = str('separator');
    final enc = str('encoding');
    final sheets = json['sheets'];
    return ImportOptions(
      location:
          ImportLocation.byName(json['location']) ?? ImportLocation.createNew,
      cell: str('cell'),
      separator: sep == null || sep == 'auto' ? null : sep,
      encoding: enc == null || enc == 'auto' ? null : TextEncoding.byId(enc),
      locale: str('locale'),
      convert: json['convert'] is bool ? json['convert']! as bool : true,
      sheets: sheets is List ? [for (final s in sheets) '$s'] : null,
      unsupportedFormulas: json['unsupportedFormulas'] == 'text'
          ? UnsupportedFormulaMode.text
          : UnsupportedFormulaMode.value,
    );
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
    'location': location.name,
    'cell': ?cell,
    'separator': separator ?? 'auto',
    'encoding': encoding?.id ?? 'auto',
    'locale': ?locale,
    'convert': convert,
    'sheets': ?sheets,
    'unsupportedFormulas': unsupportedFormulas.name,
  };

  /// Copy with changes.
  ImportOptions copyWith({
    ImportLocation? location,
    String? cell,
    String? separator,
    TextEncoding? encoding,
    String? locale,
    bool? convert,
    List<String>? sheets,
    UnsupportedFormulaMode? unsupportedFormulas,
  }) => ImportOptions(
    location: location ?? this.location,
    cell: cell ?? this.cell,
    separator: separator ?? this.separator,
    encoding: encoding ?? this.encoding,
    locale: locale ?? this.locale,
    convert: convert ?? this.convert,
    sheets: sheets ?? this.sheets,
    unsupportedFormulas: unsupportedFormulas ?? this.unsupportedFormulas,
  );

  /// The start cell `(row, col)` of [cell], or null when missing/invalid.
  (int, int)? get startCell {
    final c = cell;
    if (c == null) return null;
    final a = A1Area.tryParse(c.trim());
    if (a == null || a.row1 == null || a.col1 == null) return null;
    return (a.row1!, a.col1!);
  }

  /// Options for [CsvImporter]. [spreadsheetLocale] is used when [locale]
  /// is not set; inject [today] for deterministic partial dates.
  CsvImportOptions csv({
    String? fileName,
    String spreadsheetLocale = 'en_US',
    DateTime? today,
  }) => CsvImportOptions(
    delimiter: separator,
    encoding: encoding,
    locale: locale ?? spreadsheetLocale,
    convert: convert,
    fileName: fileName,
    today: today,
  );

  /// Options for [XlsxImporter] (functions are checked against the Wonky
  /// function catalog).
  XlsxImportOptions xlsx() => XlsxImportOptions(
    sheets: sheets?.toSet(),
    unsupportedFormulas: unsupportedFormulas,
    themeColorReferences: true,
    isSupportedFunction: isWonkyFunction,
  );

  /// Whether Wonky implements the function [upperName].
  static bool isWonkyFunction(String upperName) =>
      FunctionMap.isWonkyFunction(upperName);
}
