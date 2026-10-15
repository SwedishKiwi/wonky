/// Grapheme clusters and monospace cell widths (Slides 07 §3.3): each
/// grapheme takes one column, East Asian Wide/Fullwidth and emoji graphemes
/// take two, a tab advances to the next multiple of the tab size.
///
/// The segmentation is a deterministic, dependency-free approximation of
/// Unicode extended grapheme clusters that covers what code contains: CRLF,
/// combining marks, variation selectors, emoji modifiers, ZWJ sequences,
/// regional-indicator pairs, keycaps and tag sequences.
abstract final class CodeColumns {
  /// UTF-16 offsets of the grapheme boundaries of [s] in `[from, to)`,
  /// starting with `from` and ending with `to` (`to` defaults to the length).
  static List<int> boundaries(String s, [int from = 0, int? to]) {
    final end = to ?? s.length;
    final out = <int>[from];
    var i = from;
    while (i < end) {
      i = nextBoundary(s, i, end);
      out.add(i);
    }
    return out;
  }

  /// The end of the grapheme starting at [i] (≤ [end]).
  static int nextBoundary(String s, int i, [int? end]) {
    final limit = end ?? s.length;
    if (i >= limit) return limit;
    var cp = _codePointAt(s, i);
    var j = i + _len(cp);
    if (cp == 0x0D && j < limit && s.codeUnitAt(j) == 0x0A) return j + 1;
    if (cp == 0x0A || cp == 0x0D || cp == 0x09) return j;
    final regional = _isRegional(cp);
    var regionalCount = regional ? 1 : 0;
    while (j < limit) {
      final next = _codePointAt(s, j);
      if (_isExtend(next)) {
        j += _len(next);
        continue;
      }
      if (cp == 0x200D || next == 0x200D) {
        // ZWJ joins with the following pictograph.
        if (next == 0x200D) {
          cp = next;
          j += _len(next);
          continue;
        }
        if (_isPictographic(next)) {
          cp = next;
          j += _len(next);
          continue;
        }
        break;
      }
      if (regional && _isRegional(next) && regionalCount.isOdd) {
        regionalCount++;
        j += _len(next);
        continue;
      }
      break;
    }
    return j;
  }

  /// Columns taken by the grapheme `s[start, end)` (a tab is handled by the
  /// caller: it depends on the column).
  static int widthOf(String s, int start, int end) {
    if (end <= start) return 0;
    final cp = _codePointAt(s, start);
    if (isWide(cp)) return 2;
    // Emoji presentation selector or ZWJ / keycap / modifier sequences.
    for (var i = start + _len(cp); i < end;) {
      final c = _codePointAt(s, i);
      if (c == 0xFE0F || c == 0x200D || (c >= 0x1F3FB && c <= 0x1F3FF)) {
        return 2;
      }
      i += _len(c);
    }
    if (_isRegional(cp)) return 2;
    return 1;
  }

  /// Columns of [line] (no line breaks) with tabs expanded to [tabSize].
  static int columnsOf(String line, {int tabSize = 4}) {
    var col = 0;
    var i = 0;
    while (i < line.length) {
      final j = nextBoundary(line, i);
      col = advance(line, i, j, col, tabSize);
      i = j;
    }
    return col;
  }

  /// The column after the grapheme `s[start, end)` placed at [column].
  static int advance(String s, int start, int end, int column, int tabSize) {
    if (s.codeUnitAt(start) == 0x09) {
      final t = tabSize < 1 ? 1 : tabSize;
      return (column ~/ t + 1) * t;
    }
    return column + widthOf(s, start, end);
  }

  /// [line] with tabs expanded to spaces (for painters that lay text out as
  /// a flow; the grid stays exact for single-width characters).
  static String expandTabs(
    String line, {
    int tabSize = 4,
    int startColumn = 0,
  }) {
    if (!line.contains('\t')) return line;
    final b = StringBuffer();
    var col = startColumn;
    var i = 0;
    while (i < line.length) {
      final j = nextBoundary(line, i);
      final next = advance(line, i, j, col, tabSize);
      if (line.codeUnitAt(i) == 0x09) {
        b.write(' ' * (next - col));
      } else {
        b.write(line.substring(i, j));
      }
      col = next;
      i = j;
    }
    return b.toString();
  }

  /// Whether [cp] is East Asian Wide or Fullwidth (or an emoji with default
  /// emoji presentation).
  static bool isWide(int cp) {
    if (cp < 0x1100) return false;
    for (final (lo, hi) in _wide) {
      if (cp < lo) return false;
      if (cp <= hi) return true;
    }
    return false;
  }

  static const _wide = <(int, int)>[
    (0x1100, 0x115F),
    (0x231A, 0x231B),
    (0x2329, 0x232A),
    (0x23E9, 0x23EC),
    (0x23F0, 0x23F0),
    (0x23F3, 0x23F3),
    (0x25FD, 0x25FE),
    (0x2614, 0x2615),
    (0x2648, 0x2653),
    (0x267F, 0x267F),
    (0x2693, 0x2693),
    (0x26A1, 0x26A1),
    (0x26AA, 0x26AB),
    (0x26BD, 0x26BE),
    (0x26C4, 0x26C5),
    (0x26CE, 0x26CE),
    (0x26D4, 0x26D4),
    (0x26EA, 0x26EA),
    (0x26F2, 0x26F3),
    (0x26F5, 0x26F5),
    (0x26FA, 0x26FA),
    (0x26FD, 0x26FD),
    (0x2705, 0x2705),
    (0x270A, 0x270B),
    (0x2728, 0x2728),
    (0x274C, 0x274C),
    (0x274E, 0x274E),
    (0x2753, 0x2755),
    (0x2757, 0x2757),
    (0x2795, 0x2797),
    (0x27B0, 0x27B0),
    (0x27BF, 0x27BF),
    (0x2B1B, 0x2B1C),
    (0x2B50, 0x2B50),
    (0x2B55, 0x2B55),
    (0x2E80, 0x303E),
    (0x3041, 0x33FF),
    (0x3400, 0x4DBF),
    (0x4E00, 0x9FFF),
    (0xA000, 0xA4CF),
    (0xA960, 0xA97F),
    (0xAC00, 0xD7A3),
    (0xF900, 0xFAFF),
    (0xFE10, 0xFE19),
    (0xFE30, 0xFE6F),
    (0xFF00, 0xFF60),
    (0xFFE0, 0xFFE6),
    (0x16FE0, 0x16FE4),
    (0x17000, 0x18CFF),
    (0x1B000, 0x1B2FF),
    (0x1F004, 0x1F004),
    (0x1F0CF, 0x1F0CF),
    (0x1F18E, 0x1F18E),
    (0x1F191, 0x1F19A),
    (0x1F200, 0x1F202),
    (0x1F210, 0x1F23B),
    (0x1F240, 0x1F248),
    (0x1F250, 0x1F251),
    (0x1F260, 0x1F265),
    (0x1F300, 0x1F320),
    (0x1F32D, 0x1F335),
    (0x1F337, 0x1F37C),
    (0x1F37E, 0x1F393),
    (0x1F3A0, 0x1F3CA),
    (0x1F3CF, 0x1F3D3),
    (0x1F3E0, 0x1F3F0),
    (0x1F3F4, 0x1F3F4),
    (0x1F3F8, 0x1F43E),
    (0x1F440, 0x1F440),
    (0x1F442, 0x1F4FC),
    (0x1F4FF, 0x1F53D),
    (0x1F54B, 0x1F54E),
    (0x1F550, 0x1F567),
    (0x1F57A, 0x1F57A),
    (0x1F595, 0x1F596),
    (0x1F5A4, 0x1F5A4),
    (0x1F5FB, 0x1F64F),
    (0x1F680, 0x1F6C5),
    (0x1F6CC, 0x1F6CC),
    (0x1F6D0, 0x1F6D2),
    (0x1F6D5, 0x1F6D7),
    (0x1F6DC, 0x1F6DF),
    (0x1F6EB, 0x1F6EC),
    (0x1F6F4, 0x1F6FC),
    (0x1F7E0, 0x1F7EB),
    (0x1F7F0, 0x1F7F0),
    (0x1F90C, 0x1F93A),
    (0x1F93C, 0x1F945),
    (0x1F947, 0x1F9FF),
    (0x1FA70, 0x1FAFF),
    (0x20000, 0x2FFFD),
    (0x30000, 0x3FFFD),
  ];

  static int _codePointAt(String s, int i) {
    final c = s.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
      final d = s.codeUnitAt(i + 1);
      if (d >= 0xDC00 && d <= 0xDFFF) {
        return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00);
      }
    }
    return c;
  }

  static int _len(int cp) => cp > 0xFFFF ? 2 : 1;

  static bool _isRegional(int cp) => cp >= 0x1F1E6 && cp <= 0x1F1FF;

  static bool _isPictographic(int cp) =>
      (cp >= 0x1F000 && cp <= 0x1FAFF) ||
      (cp >= 0x2600 && cp <= 0x27BF) ||
      (cp >= 0x2300 && cp <= 0x23FF) ||
      (cp >= 0x2B00 && cp <= 0x2BFF) ||
      cp == 0x00A9 ||
      cp == 0x00AE ||
      cp == 0x203C ||
      cp == 0x2049 ||
      cp == 0x2122 ||
      cp == 0x2139;

  /// Grapheme extenders: combining marks, variation selectors, emoji
  /// modifiers, enclosing keycap, tags, zero-width non-joiner.
  static bool _isExtend(int cp) =>
      (cp >= 0x0300 && cp <= 0x036F) ||
      (cp >= 0x0483 && cp <= 0x0489) ||
      (cp >= 0x0591 && cp <= 0x05BD) ||
      (cp >= 0x0610 && cp <= 0x061A) ||
      (cp >= 0x064B && cp <= 0x065F) ||
      (cp >= 0x0900 && cp <= 0x0903) ||
      (cp >= 0x093A && cp <= 0x094F) ||
      (cp >= 0x0E31 && cp <= 0x0E3A && cp != 0x0E32 && cp != 0x0E33) ||
      (cp >= 0x0E47 && cp <= 0x0E4E) ||
      (cp >= 0x1AB0 && cp <= 0x1AFF) ||
      (cp >= 0x1DC0 && cp <= 0x1DFF) ||
      cp == 0x200C ||
      (cp >= 0x20D0 && cp <= 0x20FF) ||
      (cp >= 0x302A && cp <= 0x302F) ||
      (cp >= 0x3099 && cp <= 0x309A) ||
      (cp >= 0xFE00 && cp <= 0xFE0F) ||
      (cp >= 0xFE20 && cp <= 0xFE2F) ||
      (cp >= 0x1F3FB && cp <= 0x1F3FF) ||
      (cp >= 0xE0020 && cp <= 0xE007F) ||
      (cp >= 0xE0100 && cp <= 0xE01EF);
}
