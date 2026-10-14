import 'package:wonky_sheets_core/model.dart';

/// Column-value autocomplete while typing text (03 §8.5): looks at the
/// contiguous non-empty block above and below the edited cell in the same
/// column (at most [maxCells] cells) and completes the typed prefix when
/// exactly one distinct text value there starts with it (case-insensitive).
abstract final class ColumnAutocomplete {
  static const maxCells = 1000;

  /// The full value to complete [typed] to at ([row], [col]) of [sheet], or
  /// null. Numbers, formulas and empty input never complete.
  static String? suggest(SheetModel sheet, int row, int col, String typed) {
    if (typed.isEmpty || typed.startsWith('=') || typed.startsWith('+')) {
      return null;
    }
    if (num.tryParse(typed.trim()) != null) return null;
    final prefix = typed.toLowerCase();
    String? match;
    var seen = 0;
    bool consider(int r) {
      final text = _textAt(sheet, r, col);
      if (text == null) return false;
      seen++;
      if (text.length > typed.length && text.toLowerCase().startsWith(prefix)) {
        final m = match;
        if (m == null) {
          match = text;
        } else if (m.toLowerCase() != text.toLowerCase()) {
          match = '';
        }
      }
      return true;
    }

    for (var r = row - 1; r >= 0 && seen < maxCells; r--) {
      if (!consider(r)) break;
    }
    for (var r = row + 1; r < sheet.rows.length && seen < maxCells; r++) {
      if (!consider(r)) break;
    }
    final m = match;
    return m == null || m.isEmpty ? null : m;
  }

  /// The text of a text cell; null for empty cells (they end the block);
  /// other contents count as non-empty but never complete.
  static String? _textAt(SheetModel sheet, int r, int c) {
    final rec = sheet.cellAt(r, c);
    final content = rec?.decoded;
    return switch (content) {
      null => null,
      TextContent(:final text) => text,
      RichTextContent(:final rich) => rich.text,
      _ => '',
    };
  }
}
