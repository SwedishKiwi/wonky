// API skeleton — the full locale-aware implementation is built in this folder
// (03 §8.6, 06 §5.9). Signatures are a contract used by the planner, CSV
// import, clipboard paste, split text and MCP: keep them stable.

import '../content/cell_content.dart';

/// Result of parsing typed input.
final class ParsedInput {
  /// Creates a result.
  const ParsedInput({
    this.content,
    this.formulaA1,
    this.autoNumberFormat,
    this.autoLinkUrl,
  });

  /// Literal content to store; null with [formulaA1] null = clear the value.
  final CellContent? content;

  /// The formula as typed (A1 form, starting with `=`, in the input locale);
  /// the caller converts it with `FormulaHooks.toStored`.
  final String? formulaA1;

  /// Number format to write when the target cell's effective format is
  /// Automatic (06 §5.9), e.g. `0%`, `"$"#,##0.00`, `preset:date`.
  final String? autoNumberFormat;

  /// Whole-cell link detected from a URL/email input (03 §14.4).
  final String? autoLinkUrl;

  /// Whether the input is a formula.
  bool get isFormula => formulaA1 != null;

  /// Whether the input clears the value.
  bool get isClear => content == null && formulaA1 == null;
}

/// Parses user-entered text like typing into a cell.
final class InputParser {
  /// Creates a parser.
  InputParser();

  /// Shared instance.
  static final InputParser instance = InputParser();

  /// Parses [input] in [locale]. [targetNumberFormat] is the target cell's
  /// effective number format (`@` forces text; non-Automatic formats suppress
  /// auto-detection). [today] is used for partial dates (`1/2` → Jan 2 of
  /// the current year); inject it for determinism.
  ParsedInput parse(
    String input, {
    String locale = 'en_US',
    String? targetNumberFormat,
    DateTime? today,
  }) {
    if (input.isEmpty) return const ParsedInput();
    if (targetNumberFormat == '@') return ParsedInput(content: TextContent(input));
    if (input.startsWith("'")) return ParsedInput(content: TextContent(input.substring(1)));
    if (input.startsWith('=') && input.length > 1) return ParsedInput(formulaA1: input);
    final t = input.trim();
    final n = double.tryParse(t);
    if (n != null && n.isFinite) return ParsedInput(content: NumberContent(n));
    final upper = t.toUpperCase();
    if (upper == 'TRUE' || upper == 'FALSE') return ParsedInput(content: BoolContent(upper == 'TRUE'));
    final err = CellErrorKind.tryParse(t);
    if (err != null) return ParsedInput(content: ErrorContent(err));
    return ParsedInput(content: TextContent(input));
  }
}
