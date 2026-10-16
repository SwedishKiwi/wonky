import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wonky_app/spellcheck.dart';

/// A small spell engine for tests: a fixed word list (case-insensitive),
/// suggestions per word and the personal words; letters make words (two
/// or more, not ALL-CAPS), skip ranges are honoured.
class FakeSpellEngine implements SpellEngine {
  FakeSpellEngine({
    Iterable<String> words = const ['say', 'hello', 'world', 'the', 'plan'],
    this.suggestions = const {
      'helo': ['hello', 'help'],
      'wrold': ['world'],
    },
  }) : _known = {for (final w in words) w.toLowerCase()};

  final Set<String> _known;
  final Map<String, List<String>> suggestions;
  Set<String> personal = {};

  @override
  String get tag => 'en-US';

  @override
  bool check(String word, {bool followedByPeriod = false}) =>
      _known.contains(word.toLowerCase()) || personal.contains(word);

  @override
  List<String> suggest(String word, {int max = 5}) =>
      (suggestions[word.toLowerCase()] ?? const []).take(max).toList();

  @override
  List<SpellWord> words(
    String text, {
    List<(int, int)> skipRanges = const [],
    bool skipAllCaps = true,
  }) => [
    for (final m in RegExp(r'\p{L}+', unicode: true).allMatches(text))
      if (m.end - m.start >= 2 &&
          !(skipAllCaps && m[0]!.toUpperCase() == m[0]) &&
          !skipRanges.any((r) => m.start < r.$2 && m.end > r.$1))
        SpellWord(m.start, m.end, m[0]!),
  ];

  @override
  void setPersonalWords(Iterable<String> words) => personal = words.toSet();
}

/// Installs [engine] as the en-US dictionary of every [ShellSpelling] and
/// the device locale `en-US`; undone at the end of the test by [reset].
FakeSpellEngine installFakeShellSpelling([FakeSpellEngine? engine]) {
  final e = engine ?? FakeSpellEngine();
  ShellSpelling.debugDictionaries = SpellDictionaries(bundle: _IndexBundle())
    ..debugSetEngine('en-US', e);
  ShellSpelling.debugLocale = 'en-US';
  return e;
}

/// Back to no dictionaries (the harness installs an empty set).
void resetShellSpelling() {
  ShellSpelling.debugDictionaries = null;
  ShellSpelling.debugLocale = null;
}

/// An asset bundle with only the dictionary index (en-US).
class _IndexBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('/index.json')) {
      final json = jsonEncode({
        'dictionaries': [
          {'tag': 'en-US', 'name': 'English (US)', 'aff': 'a', 'dic': 'd'},
        ],
      });
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
    }
    throw StateError('No asset $key');
  }
}
