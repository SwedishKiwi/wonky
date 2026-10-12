import '../../content/cell_content.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../format/number_format/number_formatter.dart';
import '../../formula/model/workbook_view.dart';

/// Formats a computed value with a number format into its display text
/// (what the grid shows, 06 §5). Injectable so tests control formatting.
abstract interface class DisplayTextProvider {
  /// Display text of [value] formatted with [numberFormat] (null = Automatic).
  String displayText(CellValue value, String? numberFormat);
}

/// [DisplayTextProvider] backed by [NumberFormatter] in a spreadsheet locale.
final class FormatterDisplayText implements DisplayTextProvider {
  /// Creates the provider for [locale] (`Spreadsheet.locale`).
  FormatterDisplayText({this.locale = 'en_US', NumberFormatter? formatter})
    : _formatter = formatter ?? NumberFormatter.instance;

  /// The locale.
  final String locale;
  final NumberFormatter _formatter;

  @override
  String displayText(CellValue value, String? numberFormat) =>
      _formatter.formatText(value, numberFormat, locale: locale);
}

/// [DisplayTextProvider] from a function (tests, adapters).
final class FunctionDisplayText implements DisplayTextProvider {
  /// Creates the provider.
  const FunctionDisplayText(this._format);

  final String Function(CellValue value, String? numberFormat) _format;

  @override
  String displayText(CellValue value, String? numberFormat) => _format(value, numberFormat);
}

/// Reads computed values, number formats and display texts of cells through a
/// [CellSource] (formula results included) and a [DisplayTextProvider].
final class CellTextReader {
  /// Creates the reader.
  const CellTextReader(this.values, this.display);

  /// Computed values.
  final CellSource values;

  /// Display formatting.
  final DisplayTextProvider display;

  /// The computed scalar at the cell.
  CellValue valueAt(String sheetId, int row, int col) => values.valueAt(sheetId, row, col).toCellValue();

  /// The cell's number format (explicit, or the result's format hint).
  String? numberFormatAt(String sheetId, int row, int col) => values.numberFormatAt(sheetId, row, col);

  /// The display text of the cell.
  String displayTextAt(String sheetId, int row, int col) =>
      display.displayText(valueAt(sheetId, row, col), numberFormatAt(sheetId, row, col));
}
