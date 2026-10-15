/// Character rules for rich text (Write 02 §1.4, Slides 02 §4.1).
library;

/// Character rules for document text.
abstract final class TextRules {
  /// Whether UTF-16 code unit [unit] is never allowed in text (ignoring
  /// surrogate pairing, `\n` and `\t`, which have contextual rules).
  static bool isForbiddenUnit(int unit) =>
      (unit < 0x20 && unit != 0x0A && unit != 0x09) ||
      (unit >= 0x7F && unit <= 0x9F) ||
      unit == 0x2029 ||
      unit == 0xFFFC ||
      unit == 0xFFFE ||
      unit == 0xFFFF;

  /// Index of the first unpaired surrogate in [s], or -1.
  static int firstLoneSurrogate(String s) {
    for (var i = 0; i < s.length; i++) {
      final u = s.codeUnitAt(i);
      if (u >= 0xD800 && u <= 0xDBFF) {
        if (i + 1 < s.length) {
          final n = s.codeUnitAt(i + 1);
          if (n >= 0xDC00 && n <= 0xDFFF) {
            i++;
            continue;
          }
        }
        return i;
      }
      if (u >= 0xDC00 && u <= 0xDFFF) return i;
    }
    return -1;
  }

  /// Allowed code block language: `[A-Za-z0-9_+#.-]{0,32}`.
  static final codeLanguage = RegExp(r'^[A-Za-z0-9_+#.\-]{0,32}$');
}
