/// A pure-Dart, Hunspell-compatible spell checker (04 §28.2): `.aff` + `.dic`
/// with PFX/SFX (conditions, cross products, two-level suffixes through
/// continuation classes), basic compounding, REP/TRY/KEY suggestions and
/// bounded edit-distance-2 search.
library;

import 'dart:math' as math;

/// Flag encoding of an affix file (`FLAG`).
enum FlagMode {
  /// Single characters (default).
  char,

  /// Two-character flags (`FLAG long`).
  long,

  /// Comma-separated numbers (`FLAG num`).
  num,

  /// Unicode code points (`FLAG UTF-8`).
  utf8,
}

/// One affix entry (`PFX`/`SFX` line).
final class AffixEntry {
  /// Creates an entry.
  AffixEntry({
    required this.flag,
    required this.isPrefix,
    required this.crossProduct,
    required this.strip,
    required this.add,
    required this.continuation,
    required String condition,
  }) : _condition = _compileCondition(condition, isPrefix);

  /// Rule flag.
  final String flag;

  /// Prefix (true) or suffix.
  final bool isPrefix;

  /// May combine with the other affix kind.
  final bool crossProduct;

  /// Characters stripped from the stem.
  final String strip;

  /// Characters added.
  final String add;

  /// Continuation flags (two-level affixes, compounding flags…).
  final Set<String> continuation;

  final RegExp? _condition;

  /// Whether [stem] satisfies the condition.
  bool matches(String stem) => _condition == null || _condition.hasMatch(stem);

  static RegExp? _compileCondition(String condition, bool isPrefix) {
    if (condition == '.' || condition.isEmpty) return null;
    final pattern = condition.replaceAll(RegExp(r'[\\^$*+?(){}|]'), r'\$0');
    // Brackets and '.' keep their regex meaning; escape the rest.
    final escaped = condition.split('').map((c) {
      if ('[]^.'.contains(c)) return c;
      return RegExp.escape(c);
    }).join();
    final source = pattern.isEmpty ? '' : escaped;
    try {
      return RegExp(isPrefix ? '^$source' : '$source\$', unicode: true);
    } on FormatException {
      return null;
    }
  }
}

/// Parsed `.aff` data.
final class HunspellAffixes {
  HunspellAffixes._();

  /// Flag mode.
  FlagMode flagMode = FlagMode.char;

  /// `TRY` characters, most frequent first.
  String tryChars = '';

  /// `KEY` keyboard rows (`|`-separated).
  List<String> keyRows = const ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

  /// `REP` pairs.
  final List<(String, String)> replacements = [];

  /// Prefixes by flag.
  final Map<String, List<AffixEntry>> prefixes = {};

  /// Suffixes by flag.
  final Map<String, List<AffixEntry>> suffixes = {};

  /// `COMPOUNDFLAG`.
  String? compoundFlag;

  /// `COMPOUNDBEGIN`.
  String? compoundBegin;

  /// `COMPOUNDMIDDLE`.
  String? compoundMiddle;

  /// `COMPOUNDEND`.
  String? compoundEnd;

  /// `COMPOUNDMIN` (default 3).
  int compoundMin = 3;

  /// `ONLYINCOMPOUND`.
  String? onlyInCompound;

  /// `NEEDAFFIX`.
  String? needAffix;

  /// `FORBIDDENWORD`.
  String? forbiddenWord;

  /// `NOSUGGEST`.
  String? noSuggest;

  /// `KEEPCASE`.
  String? keepCase;

  /// `WORDCHARS`.
  String wordChars = '';

  /// Parses an `.aff` file.
  factory HunspellAffixes.parse(String source) {
    final a = HunspellAffixes._();
    final lines = source.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(RegExp(r'\s+'));
      final key = parts.first;
      String arg(int n) => parts.length > n ? parts[n] : '';
      switch (key) {
        case 'FLAG':
          a.flagMode = switch (arg(1)) {
            'long' => FlagMode.long,
            'num' => FlagMode.num,
            'UTF-8' => FlagMode.utf8,
            _ => FlagMode.char,
          };
        case 'TRY':
          a.tryChars = arg(1);
        case 'KEY':
          a.keyRows = arg(1).split('|');
        case 'WORDCHARS':
          a.wordChars = arg(1);
        case 'REP':
          if (parts.length >= 3) {
            a.replacements.add((parts[1].replaceAll('_', ' '), parts[2].replaceAll('_', ' ')));
          }
        case 'COMPOUNDFLAG':
          a.compoundFlag = arg(1);
        case 'COMPOUNDBEGIN':
          a.compoundBegin = arg(1);
        case 'COMPOUNDMIDDLE':
          a.compoundMiddle = arg(1);
        case 'COMPOUNDEND':
          a.compoundEnd = arg(1);
        case 'COMPOUNDMIN':
          a.compoundMin = int.tryParse(arg(1)) ?? 3;
        case 'ONLYINCOMPOUND':
          a.onlyInCompound = arg(1);
        case 'NEEDAFFIX' || 'PSEUDOROOT':
          a.needAffix = arg(1);
        case 'FORBIDDENWORD':
          a.forbiddenWord = arg(1);
        case 'NOSUGGEST':
          a.noSuggest = arg(1);
        case 'KEEPCASE':
          a.keepCase = arg(1);
        case 'PFX' || 'SFX':
          // Header: PFX flag cross count; entries: PFX flag strip add cond.
          if (parts.length == 4 && int.tryParse(parts[3]) != null && (parts[2] == 'Y' || parts[2] == 'N')) {
            final flag = parts[1];
            final cross = parts[2] == 'Y';
            final count = int.parse(parts[3]);
            final target = key == 'PFX' ? a.prefixes : a.suffixes;
            final list = target.putIfAbsent(flag, () => []);
            for (var k = 0; k < count && i + 1 < lines.length; k++) {
              final e = lines[++i].trim().split(RegExp(r'\s+'));
              if (e.length < 4 || e[0] != key) continue;
              final strip = e[2] == '0' ? '' : e[2];
              var add = e[3];
              var cont = <String>{};
              final slash = add.indexOf('/');
              if (slash >= 0) {
                cont = a.parseFlags(add.substring(slash + 1)).toSet();
                add = add.substring(0, slash);
              }
              if (add == '0') add = '';
              list.add(
                AffixEntry(
                  flag: flag,
                  isPrefix: key == 'PFX',
                  crossProduct: cross,
                  strip: strip,
                  add: add,
                  continuation: cont,
                  condition: e.length > 4 ? e[4] : '.',
                ),
              );
            }
          }
      }
    }
    return a;
  }

  /// Splits a flag string per [flagMode].
  List<String> parseFlags(String s) {
    if (s.isEmpty) return const [];
    switch (flagMode) {
      case FlagMode.long:
        return [for (var i = 0; i + 1 < s.length + 1; i += 2) s.substring(i, math.min(i + 2, s.length))];
      case FlagMode.num:
        return s.split(',').where((x) => x.isNotEmpty).toList();
      case FlagMode.utf8 || FlagMode.char:
        return [for (final r in s.runes) String.fromCharCode(r)];
    }
  }
}

/// Parsed `.dic` data: stem → flag set (a stem may occur with several flag
/// sets; they are unioned per homonym list).
final class HunspellDictionary {
  HunspellDictionary._(this._words);

  final Map<String, List<Set<String>>> _words;

  /// Parses a `.dic` file (first line is the approximate count).
  factory HunspellDictionary.parse(String source, HunspellAffixes affixes) {
    final words = <String, List<Set<String>>>{};
    final lines = source.split(RegExp(r'\r?\n'));
    for (var i = 1; i < lines.length; i++) {
      var line = lines[i];
      if (line.trim().isEmpty) continue;
      final tab = line.indexOf('\t');
      if (tab >= 0) line = line.substring(0, tab);
      line = line.trim();
      // Unescaped slash separates flags.
      var slash = -1;
      for (var k = 0; k < line.length; k++) {
        if (line[k] == '\\') {
          k++;
          continue;
        }
        if (line[k] == '/') {
          slash = k;
          break;
        }
      }
      final word = (slash < 0 ? line : line.substring(0, slash)).replaceAll(r'\/', '/');
      final flags = slash < 0 ? <String>{} : affixes.parseFlags(line.substring(slash + 1).split(' ').first).toSet();
      if (word.isEmpty) continue;
      words.putIfAbsent(word, () => []).add(flags);
    }
    return HunspellDictionary._(words);
  }

  /// Flag sets of [word] (empty when absent).
  List<Set<String>> lookup(String word) => _words[word] ?? const [];

  /// Whether [word] is a stem.
  bool contains(String word) => _words.containsKey(word);

  /// All stems (for suggestions by n-gram similarity).
  Iterable<String> get stems => _words.keys;

  /// Adds [word] with [flags].
  void add(String word, [Set<String> flags = const {}]) => _words.putIfAbsent(word, () => []).add(flags);
}

/// A Hunspell-compatible checker.
final class SpellChecker {
  /// Creates a checker from `.aff` and `.dic` sources.
  factory SpellChecker.parse({required String aff, required String dic}) {
    final affixes = HunspellAffixes.parse(aff);
    return SpellChecker(affixes, HunspellDictionary.parse(dic, affixes));
  }

  /// Creates a checker.
  SpellChecker(this.affixes, this.dictionary);

  /// Affix rules.
  final HunspellAffixes affixes;

  /// Dictionary.
  final HunspellDictionary dictionary;

  final _personal = <String>{};
  final _ignored = <String>{};

  /// Maximum candidate checks per suggestion request (deterministic bound
  /// standing in for the 50 ms budget).
  static const maxSuggestionChecks = 25000;

  /// Adds [word] to the personal dictionary.
  void addPersonal(String word) => _personal.add(word);

  /// Removes [word] from the personal dictionary.
  void removePersonal(String word) => _personal.remove(word);

  /// Ignores [word] (session).
  void ignore(String word) => _ignored.add(word);

  /// Personal dictionary words.
  Set<String> get personalWords => Set.unmodifiable(_personal);

  /// Whether [word] is spelled correctly.
  bool check(String word) {
    if (word.isEmpty) return true;
    if (_personal.contains(word) || _ignored.contains(word)) return true;
    final w = word.replaceAll('’', "'");
    for (final variant in _caseVariants(w)) {
      if (_checkExact(variant.$1, keepCaseAllowed: variant.$2)) return true;
    }
    // Trailing period (abbreviations).
    if (w.endsWith('.') && w.length > 1) return check(w.substring(0, w.length - 1));
    return false;
  }

  /// `(variant, isOriginal)` case variants to try.
  List<(String, bool)> _caseVariants(String w) {
    final lower = w.toLowerCase();
    final out = <(String, bool)>[(w, true)];
    final isAllCaps = w == w.toUpperCase() && w != lower;
    final isTitle = w.isNotEmpty && w[0] != lower[0] && w.substring(1) == lower.substring(1);
    if (isAllCaps) {
      out.add((_capitalize(lower), false));
      out.add((lower, false));
    } else if (isTitle) {
      out.add((lower, false));
    }
    return out;
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  bool _hasFlag(Set<String> flags, String? flag) => flag != null && flags.contains(flag);

  bool _checkExact(String word, {required bool keepCaseAllowed}) {
    // Forbidden?
    for (final flags in dictionary.lookup(word)) {
      if (_hasFlag(flags, affixes.forbiddenWord)) return false;
    }
    for (final flags in dictionary.lookup(word)) {
      if (_hasFlag(flags, affixes.needAffix) || _hasFlag(flags, affixes.onlyInCompound)) continue;
      if (!keepCaseAllowed && _hasFlag(flags, affixes.keepCase)) continue;
      return true;
    }
    if (_affixed(word, keepCaseAllowed: keepCaseAllowed)) return true;
    if (affixes.compoundFlag != null || affixes.compoundBegin != null) {
      if (_compound(word, 0, 0)) return true;
    }
    return false;
  }

  bool _stemHas(String stem, String flag, {Set<String> also = const {}, bool keepCaseAllowed = true}) {
    for (final flags in dictionary.lookup(stem)) {
      if (_hasFlag(flags, affixes.forbiddenWord)) return false;
      if (!keepCaseAllowed && _hasFlag(flags, affixes.keepCase)) continue;
      if (flags.contains(flag) && also.every(flags.contains)) return true;
    }
    return false;
  }

  bool _affixed(String word, {required bool keepCaseAllowed}) {
    // Suffix (+ optional prefix cross product, + optional second suffix).
    for (final entries in affixes.suffixes.values) {
      for (final s in entries) {
        if (!word.endsWith(s.add) || word.length - s.add.length <= 0 && s.strip.isEmpty) continue;
        final stem = word.substring(0, word.length - s.add.length) + s.strip;
        if (stem.isEmpty || !s.matches(stem)) continue;
        if (_stemHas(stem, s.flag, keepCaseAllowed: keepCaseAllowed)) return true;
        // Two-level: stem itself is stem2 + suffix2 where suffix2's
        // continuation contains s.flag.
        for (final entries2 in affixes.suffixes.values) {
          for (final s2 in entries2) {
            if (!s2.continuation.contains(s.flag) || !stem.endsWith(s2.add)) continue;
            final stem2 = stem.substring(0, stem.length - s2.add.length) + s2.strip;
            if (stem2.isEmpty || !s2.matches(stem2)) continue;
            if (_stemHas(stem2, s2.flag, keepCaseAllowed: keepCaseAllowed)) return true;
          }
        }
        // Cross product with a prefix.
        if (s.crossProduct) {
          for (final pEntries in affixes.prefixes.values) {
            for (final p in pEntries) {
              if (!p.crossProduct || !stem.startsWith(p.add)) continue;
              final stem2 = p.strip + stem.substring(p.add.length);
              if (stem2.isEmpty || !p.matches(stem2) || !s.matches(stem2)) continue;
              if (_stemHas(stem2, s.flag, also: {p.flag}, keepCaseAllowed: keepCaseAllowed)) return true;
            }
          }
        }
      }
    }
    // Prefix only.
    for (final entries in affixes.prefixes.values) {
      for (final p in entries) {
        if (!word.startsWith(p.add)) continue;
        final stem = p.strip + word.substring(p.add.length);
        if (stem.isEmpty || !p.matches(stem)) continue;
        if (_stemHas(stem, p.flag, keepCaseAllowed: keepCaseAllowed)) return true;
      }
    }
    return false;
  }

  bool _isCompoundPart(String part, int position, bool last) {
    final role = position == 0
        ? affixes.compoundBegin
        : last
        ? affixes.compoundEnd
        : affixes.compoundMiddle;
    for (final flags in dictionary.lookup(part)) {
      if (_hasFlag(flags, affixes.forbiddenWord)) return false;
      if (_hasFlag(flags, affixes.compoundFlag) || _hasFlag(flags, role)) return true;
    }
    return false;
  }

  bool _compound(String word, int start, int depth) {
    if (depth > 3) return false;
    final min = affixes.compoundMin;
    for (var i = start + min; i <= word.length - min; i++) {
      final part = word.substring(start, i);
      if (!_isCompoundPart(part, depth, false)) continue;
      final rest = word.substring(i);
      if (_isCompoundPart(rest, depth + 1, true)) return true;
      if (_compound(word, i, depth + 1)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Suggestions

  /// Up to [max] suggestions for [word], best first (case restored).
  List<String> suggest(String word, {int max = 5}) {
    if (word.isEmpty || check(word)) return const [];
    final lower = word.toLowerCase();
    final isAllCaps = word == word.toUpperCase() && word != lower;
    final isTitle = !isAllCaps && word[0] != lower[0];
    var budget = maxSuggestionChecks;
    final found = <String, int>{}; // candidate → score (lower is better)

    bool ok(String c) {
      if (budget <= 0) return false;
      budget--;
      if (!check(c)) return false;
      for (final flags in dictionary.lookup(c)) {
        if (_hasFlag(flags, affixes.noSuggest)) return false;
      }
      return true;
    }

    void consider(String c, int score) {
      if (c.isEmpty || c == lower) return;
      final prev = found[c];
      if (prev != null && prev <= score) return;
      if (ok(c)) found[c] = score;
    }

    // REP table.
    for (final (from, to) in affixes.replacements) {
      var idx = lower.indexOf(from);
      while (idx >= 0) {
        consider(lower.replaceRange(idx, idx + from.length, to), 0);
        idx = lower.indexOf(from, idx + 1);
      }
    }
    final alphabet = _alphabet();
    final edits1 = _edits(lower, alphabet).toList();
    for (final (c, cost) in edits1) {
      consider(c, cost);
    }
    // Two words.
    for (var i = 1; i < lower.length; i++) {
      final a = lower.substring(0, i);
      final b = lower.substring(i);
      if (a.length > 1 && b.length > 1 && ok(a) && ok(b)) found.putIfAbsent('$a $b', () => 4);
    }
    // Edit distance 2 (bounded).
    if (found.length < max) {
      for (final (e1, c1) in edits1) {
        if (budget <= 0) break;
        for (final (e2, c2) in _edits(e1, alphabet)) {
          if (budget <= 0) break;
          consider(e2, 2 + c1 + c2);
        }
      }
    }
    final ranked = found.entries.toList()
      ..sort((x, y) {
        final s = x.value.compareTo(y.value);
        if (s != 0) return s;
        final firstX = x.key.isNotEmpty && x.key[0] == lower[0] ? 0 : 1;
        final firstY = y.key.isNotEmpty && y.key[0] == lower[0] ? 0 : 1;
        if (firstX != firstY) return firstX.compareTo(firstY);
        return x.key.compareTo(y.key);
      });
    return [
      for (final e in ranked.take(max))
        isAllCaps
            ? e.key.toUpperCase()
            : isTitle
            ? _capitalize(e.key)
            : e.key,
    ];
  }

  String _alphabet() {
    if (affixes.tryChars.isNotEmpty) return affixes.tryChars.toLowerCase();
    return 'esianrtolcdugmphbyfvkwzxjq';
  }

  bool _keyNeighbors(String a, String b) {
    for (final row in affixes.keyRows) {
      final i = row.indexOf(a);
      if (i < 0) continue;
      if ((i > 0 && row[i - 1] == b) || (i + 1 < row.length && row[i + 1] == b)) return true;
    }
    return false;
  }

  /// Single edits with a cost (keyboard neighbors and swaps are cheaper).
  Iterable<(String, int)> _edits(String w, String alphabet) sync* {
    final chars = w.split('');
    // Swaps.
    for (var i = 0; i + 1 < chars.length; i++) {
      if (chars[i] == chars[i + 1]) continue;
      yield (w.substring(0, i) + chars[i + 1] + chars[i] + w.substring(i + 2), 1);
    }
    // Deletes.
    for (var i = 0; i < chars.length; i++) {
      yield (w.substring(0, i) + w.substring(i + 1), 1);
    }
    // Replacements.
    for (var i = 0; i < chars.length; i++) {
      for (final c in alphabet.split('')) {
        if (c == chars[i]) continue;
        yield (w.substring(0, i) + c + w.substring(i + 1), _keyNeighbors(chars[i], c) ? 1 : 2);
      }
    }
    // Inserts.
    for (var i = 0; i <= chars.length; i++) {
      for (final c in alphabet.split('')) {
        yield (w.substring(0, i) + c + w.substring(i), 2);
      }
    }
  }
}

/// A word found by [SpellTokenizer].
final class SpellToken {
  /// Creates a token.
  const SpellToken(this.start, this.word);

  /// Offset in the text.
  final int start;

  /// The word.
  final String word;

  /// End offset.
  int get end => start + word.length;
}

/// Splits text into checkable words, skipping URLs, emails, words with
/// digits, CamelCase, (optionally) ALL-CAPS and words under 2 chars.
final class SpellTokenizer {
  /// Creates a tokenizer.
  const SpellTokenizer({this.skipAllCaps = true, this.extraWordChars = ''});

  /// Skip ALL-CAPS words.
  final bool skipAllCaps;

  /// Additional word characters (`WORDCHARS`).
  final String extraWordChars;

  static final _url = RegExp(r'''(?:https?://|www\.|mailto:)\S+|[\w.+-]+@[\w-]+\.[\w.-]+''', unicode: true);
  static final _letter = RegExp(r"[\p{L}\p{M}'’]", unicode: true);

  /// Tokens of [text].
  List<SpellToken> tokens(String text) {
    final skip = <(int, int)>[for (final m in _url.allMatches(text)) (m.start, m.end)];
    final out = <SpellToken>[];
    var i = 0;
    while (i < text.length) {
      if (!_isWordChar(text[i])) {
        i++;
        continue;
      }
      final start = i;
      while (i < text.length && (_isWordChar(text[i]) || RegExp(r'\d').hasMatch(text[i]))) {
        i++;
      }
      var word = text.substring(start, i);
      // Trim apostrophes at the edges.
      var s = start;
      while (word.isNotEmpty && (word.startsWith("'") || word.startsWith('’'))) {
        word = word.substring(1);
        s++;
      }
      while (word.isNotEmpty && (word.endsWith("'") || word.endsWith('’'))) {
        word = word.substring(0, word.length - 1);
      }
      if (word.runes.length < 2) continue;
      if (skip.any((r) => s >= r.$1 && s < r.$2)) continue;
      if (RegExp(r'\d').hasMatch(word)) continue;
      if (skipAllCaps && word == word.toUpperCase() && word != word.toLowerCase()) continue;
      if (RegExp(r'\p{Ll}\p{Lu}', unicode: true).hasMatch(word)) continue;
      out.add(SpellToken(s, word));
    }
    return out;
  }

  bool _isWordChar(String c) => _letter.hasMatch(c) || extraWordChars.contains(c);
}
