import 'column_letters.dart';

/// Quoting rules for sheet names in A1 references (05 §3.4).
abstract final class SheetNames {
  /// `Sheet1` → `Sheet1`; `Q3 plan` → `'Q3 plan'`; `It's` → `'It''s'`.
  static String quoteIfNeeded(String name) => needsQuoting(name) ? quote(name) : name;

  static String quote(String name) => "'${name.replaceAll("'", "''")}'";

  /// Removes surrounding quotes and unescapes `''`. Returns [text] unchanged when not quoted.
  static String unquote(String text) {
    if (text.length >= 2 && text.startsWith("'") && text.endsWith("'")) {
      return text.substring(1, text.length - 1).replaceAll("''", "'");
    }
    return text;
  }

  /// Whether [name] must be quoted: not a valid bare identifier (`[A-Za-z_][A-Za-z0-9_]*`),
  /// looks like a cell or R1C1 reference, or is `TRUE`/`FALSE`.
  static bool needsQuoting(String name) {
    if (name.isEmpty) return true;
    final first = name.codeUnitAt(0);
    if (!(ColumnLetters.isLetter(first) || first == 0x5f)) return true;
    for (var i = 1; i < name.length; i++) {
      final c = name.codeUnitAt(i);
      if (!(ColumnLetters.isLetter(c) || ColumnLetters.isDigit(c) || c == 0x5f)) return true;
    }
    final upper = name.toUpperCase();
    if (upper == 'TRUE' || upper == 'FALSE') return true;
    if (looksLikeCell(name) || looksLikeR1C1(name)) return true;
    return false;
  }

  /// `A1`, `ab12`, `ZZZ10000000` (within limits) look like cells.
  static bool looksLikeCell(String text) {
    var i = 0;
    while (i < text.length && ColumnLetters.isLetter(text.codeUnitAt(i))) {
      i++;
    }
    if (i == 0 || i > 3 || i == text.length) return false;
    final digits = text.substring(i);
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return false;
    if (digits.startsWith('0')) return false;
    final row = int.tryParse(digits);
    return row != null && row >= 1 && row <= ColumnLetters.maxRows;
  }

  static final RegExp _r1c1 = RegExp(r'^[Rr]([0-9]*)[Cc]([0-9]*)$|^[Rr][0-9]*$|^[Cc][0-9]*$');

  /// `R1C1`, `R2C`, `RC`, `R`, `C3` look like R1C1 references.
  static bool looksLikeR1C1(String text) => _r1c1.hasMatch(text);
}
