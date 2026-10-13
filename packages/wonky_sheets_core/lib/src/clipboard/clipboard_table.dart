import '../addressing/grid_geometry.dart';
import '../content/cell_content.dart';
import '../content/rich_text.dart';
import '../format/attributes.dart';
import '../input/input_parser.dart';
import '../model/schema.dart';
import 'clipboard_payload.dart';
import 'r1c1_relative.dart';

/// Where clipboard HTML came from (detected from markers in the HTML).
enum ClipboardOrigin { wonky, googleSheets, excel, libreOffice, web }

/// What one pasted external cell writes (content + formats), ready for the
/// paste planner.
final class ClipboardPasteValue {
  /// Creates a paste value.
  ClipboardPasteValue({
    this.content,
    this.formulaA1,
    CellFormat? format,
    this.note,
  }) : format = format ?? CellFormat.empty;

  /// Literal content (null with [formulaA1] null = empty cell).
  final CellContent? content;

  /// A1 formula text (en_US separators for Google/Excel formulas, the paste
  /// locale for typed text) relative to the target cell; convert with
  /// `FormulaHooks.toStored`.
  final String? formulaA1;

  /// Format attributes to write (number format, fonts, colors, borders,
  /// alignment, wrap, `linkUrl`).
  final CellFormat format;
  final String? note;

  @override
  String toString() =>
      'ClipboardPasteValue($content, $formulaA1, $format, $note)';
}

/// One cell of a parsed HTML table (03 §12.5).
final class ClipboardTableCell {
  /// Creates a cell.
  ClipboardTableCell({
    required this.text,
    this.typedValue,
    this.formulaR1C1,
    this.excelFormula,
    this.numberFormat,
    CellFormat? format,
    this.rich,
    this.note,
  }) : format = format ?? CellFormat.empty;

  /// Displayed text (`<br>` → `\n`, whitespace collapsed).
  final String text;

  /// Value typed by `data-sheets-value`, `x:num`/`x:str`/`x:bool`, `sdval`.
  final CellValue? typedValue;

  /// Google `data-sheets-formula` (R1C1 relative to the cell).
  final String? formulaR1C1;

  /// Excel `x:fmla` (A1 relative to an unknown source position; kept as a
  /// hint, values are pasted).
  final String? excelFormula;

  /// Number format from `data-sheets-numberformat`, `mso-number-format` or
  /// `sdnum`.
  final String? numberFormat;

  /// Cell-level formats (incl. `linkUrl` for whole-cell links).
  final CellFormat format;

  /// Partial styling as rich runs (relative to [format]).
  final RichText? rich;
  final String? note;

  /// Converts to what a paste at ([targetRow], [targetCol]) writes. Untyped
  /// text is parsed like typed input in [locale] ([today] for partial dates).
  ClipboardPasteValue resolve({
    required int targetRow,
    required int targetCol,
    String locale = 'en_US',
    DateTime? today,
  }) {
    CellContent? content;
    String? formula;
    String? autoFormat;
    String? autoLink;
    if (formulaR1C1 != null) {
      final f = R1C1Relative.toA1(formulaR1C1!, targetRow, targetCol);
      formula = f.startsWith('=') ? f : '=$f';
    } else if (typedValue != null) {
      content = CellContent.fromValue(typedValue!);
    } else if (text.isNotEmpty) {
      final p = InputParser.instance.parse(
        text,
        locale: locale,
        targetNumberFormat: numberFormat,
        today: today,
      );
      content = p.content;
      formula = p.formulaA1;
      autoFormat = p.autoNumberFormat;
      autoLink = p.autoLinkUrl;
    }
    final r = rich;
    if (content is TextContent &&
        r != null &&
        r.text == content.text &&
        r.runs.isNotEmpty) {
      content = RichTextContent(r);
    }
    var f = format;
    final nf = numberFormat ?? autoFormat;
    if (nf != null && !f.has(FormatAttr.numberFormat)) {
      f = f.withValue(FormatAttr.numberFormat, nf);
    }
    if (autoLink != null && !f.has(FormatAttr.linkUrl)) {
      f = f.withValue(FormatAttr.linkUrl, autoLink);
    }
    // Alignment equal to the general alignment of the value is not explicit.
    final align = f[FormatAttr.hAlign];
    if (align != null && formula == null) {
      final general = switch (content?.literalValue) {
        NumberValue() => HorizontalAlign.right,
        BoolValue() || ErrorValue() => HorizontalAlign.center,
        null => null,
        _ => HorizontalAlign.left,
      };
      if (general == align) f = f.withValue(FormatAttr.hAlign, null);
    }
    return ClipboardPasteValue(
      content: content,
      formulaA1: formula,
      format: f,
      note: note,
    );
  }

  @override
  String toString() =>
      'ClipboardTableCell("$text", $typedValue, $formulaR1C1, $format)';
}

/// A parsed clipboard HTML table: cells on a grid (covered merge cells and
/// missing cells are null), merges, sizes, and Wonky markers.
final class ClipboardTable {
  /// Creates a table.
  const ClipboardTable({
    required this.rowCount,
    required this.colCount,
    required this.cells,
    this.merges = const [],
    this.columnWidths = const [],
    this.rowHeights = const [],
    this.origin = ClipboardOrigin.web,
    this.wonkyClipId,
    this.wonkyPayload,
    this.truncatedCells = 0,
  });

  final int rowCount;
  final int colCount;

  /// `rowCount × colCount`.
  final List<List<ClipboardTableCell?>> cells;

  /// Merges from `colspan`/`rowspan`.
  final List<GridRect> merges;

  /// Column widths (px) from `<col>`/`width`; null = unknown.
  final List<double?> columnWidths;

  /// Row heights (px) from `<tr>` styles; null = unknown.
  final List<double?> rowHeights;
  final ClipboardOrigin origin;

  /// `data-wonky-clip` of the table (matches the in-memory payload).
  final String? wonkyClipId;

  /// Payload decoded from a `<!--wonky:…-->` comment.
  final SheetsClipboardPayload? wonkyPayload;

  /// Cells truncated to 50,000 characters.
  final int truncatedCells;

  /// The cell at (row, col) or null.
  ClipboardTableCell? cellAt(int row, int col) =>
      row < rowCount && col < colCount ? cells[row][col] : null;

  /// Displayed text grid (empty strings for empty/covered cells).
  List<List<String>> get texts => [
    for (final row in cells) [for (final c in row) c?.text ?? ''],
  ];
}
