import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../../content/cell_content.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../formula/model/workbook_view.dart';
import '../../formula/values/format_hint.dart';
import '../../formula/values/fvalue.dart';
import 'number_formatter.dart';

/// Displays cells' effective values with their effective number format in
/// the spreadsheet locale (06 §5.9, §5.11): the grid, clipboard, exports, MCP
/// `formatted` values and filters use the same text.
///
/// The effective number format is the explicit one (cell ▸ row ▸ column ▸
/// sheet); with Automatic, formula results use their format hint (e.g. a
/// date for `=A1+1` on a date). [CellSource.numberFormatAt] already applies
/// that rule (the formula engine and `ModelCellSource`).
final class CellTextFormatter {
  /// Creates the formatter over computed [values] in [locale]
  /// (`Spreadsheet.locale`).
  CellTextFormatter(
    this.values, {
    this.locale = 'en_US',
    NumberFormatter? formatter,
  }) : formatter = formatter ?? NumberFormatter.instance;

  /// Computed values and effective number formats.
  final CellSource values;

  /// Spreadsheet locale.
  final String locale;

  /// The cached formatter.
  final NumberFormatter formatter;

  /// The effective number format of the cell (pattern or `preset:*`), or
  /// null for Automatic.
  String? numberFormatAt(String sheetId, int row, int col) =>
      values.numberFormatAt(sheetId, row, col);

  /// The computed value of the cell.
  CellValue valueAt(String sheetId, int row, int col) =>
      values.valueAt(sheetId, row, col).toCellValue();

  /// The formatted value of the cell (segments, `[Red]`/`[ColorN]` color,
  /// whether `####` applies when it doesn't fit).
  FormattedValue formattedAt(String sheetId, int row, int col) =>
      formatter.format(
        valueAt(sheetId, row, col),
        numberFormatAt(sheetId, row, col),
        locale: locale,
      );

  /// The display text of the cell.
  String textAt(String sheetId, int row, int col) =>
      formattedAt(sheetId, row, col).plainText;

  /// Formats a computed value: [explicitFormat] (null/Automatic when the
  /// cell has none) wins; with Automatic, the engine's [hint] applies to
  /// numbers. [value] may be a model [CellValue] or an engine [FValue]
  /// (whose own hint is used when [hint] is none).
  static FormattedValue formatValue(
    Object value, {
    String? explicitFormat,
    FormatHint hint = FormatHint.none,
    String locale = 'en_US',
    NumberFormatter? formatter,
  }) {
    final v = switch (value) {
      final CellValue c => c,
      final FValue f => f.toCellValue(),
      _ => CellValue.from(value),
    };
    final h = hint.kind == FormatHintKind.none && value is FNumber
        ? value.hint
        : hint;
    final f = formatter ?? NumberFormatter.instance;
    if (!NumberFormatPresets.isAutomatic(explicitFormat)) {
      return f.format(v, explicitFormat, locale: locale);
    }
    return f.formatWithHint(
      v,
      null,
      locale: locale,
      hintPattern: NumberFormatter.hintFor(h, locale),
    );
  }
}
