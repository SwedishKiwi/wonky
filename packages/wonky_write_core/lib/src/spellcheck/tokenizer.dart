/// Splitting text into spell-checkable words (Write 04 §28.2).
library;

/// A word of a text, with UTF-16 offsets [start, end).
final class SpellToken {
  /// Creates a token for `text.substring(start, end) == word`.
  const SpellToken(
    this.start,
    this.end,
    this.word, {
    this.followedByPeriod = false,
  });

  /// UTF-16 offset of the first character.
  final int start;

  /// UTF-16 offset just past the last character.
  final int end;

  /// The word text.
  final String word;

  /// Whether a `.` directly follows the word (abbreviations such as
  /// `etc.`; see `SpellChecker.checkToken`).
  final bool followedByPeriod;

  @override
  bool operator ==(Object other) =>
      other is SpellToken &&
      other.start == start &&
      other.end == end &&
      other.word == word &&
      other.followedByPeriod == followedByPeriod;

  @override
  int get hashCode => Object.hash(start, end, word, followedByPeriod);

  @override
  String toString() => 'SpellToken($start, $end, "$word")';
}

/// Splits text into checkable words and applies the skip rules of
/// Write 04 §28.2.
///
/// Words are runs of Unicode letters and marks (plus digits, `_` and the
/// letter-like [wordChars]), joined by single inner apostrophes (`'`, `’`),
/// hyphens and the punctuation in [wordChars]; leading and trailing joiners
/// are not part of a word. Hyphenated compounds come back as one token (the
/// checker splits them).
///
/// Skipped: URLs (`scheme://…`, `www.…`), e-mail addresses, words with
/// digits or `_`, ALL-CAPS words (when [skipAllCaps]), CamelCase/mixedCase
/// words (`iPhone`, `JavaScript`), words shorter than 2 characters and
/// words overlapping a caller-provided skip range (inline code, links,
/// mentions).
final class SpellTokenizer {
  /// Creates a tokenizer; pass the dictionary's `wordChars`.
  const SpellTokenizer({this.wordChars = '', this.skipAllCaps = true});

  /// Extra word characters (Hunspell `WORDCHARS`).
  final String wordChars;

  /// Whether ALL-CAPS words (acronyms) are skipped.
  final bool skipAllCaps;

  static final Map<String, RegExp> _wordPatterns = {};

  static final RegExp _url = RegExp(
    r'''(?:\b[A-Za-z][A-Za-z0-9+.\-]*://|\bwww\.|\bmailto:)[^\s<>"'`]+''',
  );
  static final RegExp _email = RegExp(
    r'[\p{L}\p{N}._%+\-]+@[\p{L}\p{N}\-]+(?:\.[\p{L}\p{N}\-]+)+',
    unicode: true,
  );
  static final RegExp _digitOrUnderscore = RegExp(r'[\p{N}_]', unicode: true);
  static final RegExp _segmentSplit = RegExp(r"['’\-]");

  /// The checkable words of [text], in order. [skipRanges] are
  /// `(start, end)` UTF-16 ranges whose words are skipped.
  List<SpellToken> tokenize(
    String text, {
    List<(int, int)> skipRanges = const [],
  }) {
    final skips = <(int, int)>[
      ...skipRanges,
      for (final m in _url.allMatches(text)) (m.start, m.end),
      for (final m in _email.allMatches(text)) (m.start, m.end),
    ];
    final out = <SpellToken>[];
    for (final m in _pattern(wordChars).allMatches(text)) {
      final start = m.start;
      final end = m.end;
      if (_overlaps(skips, start, end)) continue;
      final word = m[0]!;
      if (_skip(word)) continue;
      out.add(
        SpellToken(
          start,
          end,
          word,
          followedByPeriod: end < text.length && text.codeUnitAt(end) == 0x2E,
        ),
      );
    }
    return out;
  }

  static bool _overlaps(List<(int, int)> ranges, int start, int end) {
    for (final (s, e) in ranges) {
      if (s < end && e > start) return true;
    }
    return false;
  }

  bool _skip(String word) {
    if (word.runes.length < 2) return true;
    if (_digitOrUnderscore.hasMatch(word)) return true;
    final upper = word.toUpperCase();
    final lower = word.toLowerCase();
    if (upper == lower) return false;
    if (word == upper) return skipAllCaps;
    for (final segment in word.split(_segmentSplit)) {
      if (_isMixedCase(segment)) return true;
    }
    return false;
  }

  /// `iPhone`, `JavaScript`, `ALLCAPs`: an uppercase letter after the first
  /// character in a segment that also has lowercase letters.
  static bool _isMixedCase(String segment) {
    if (segment.length < 2) return false;
    final lower = segment.toLowerCase();
    if (lower == segment) return false;
    final upper = segment.toUpperCase();
    if (upper == segment) return false;
    final rest = segment.substring(1);
    return rest != rest.toLowerCase();
  }

  static RegExp _pattern(String wordChars) => _wordPatterns.putIfAbsent(
    wordChars,
    () {
      final core = StringBuffer(r'\p{L}\p{M}\p{N}_');
      final join = StringBuffer(r"'\u{2019}\-");
      final letterLike = RegExp(r'[\p{L}\p{M}\p{N}_]', unicode: true);
      for (final r in wordChars.runes) {
        final ch = String.fromCharCode(r);
        if (ch == "'" || ch == '’' || ch == '-') continue;
        final escaped = '\\u{${r.toRadixString(16)}}';
        if (letterLike.hasMatch(ch)) {
          core.write(escaped);
        } else if (ch.trim().isNotEmpty) {
          join.write(escaped);
        }
      }
      final c = '[$core]';
      return RegExp('$c+(?:[$join]$c+)*', unicode: true);
    },
  );
}
