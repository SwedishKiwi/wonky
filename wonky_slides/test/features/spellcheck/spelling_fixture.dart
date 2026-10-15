import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wonky_app/spellcheck.dart';
import 'package:wonky_slides/features/spellcheck/slides_spelling.dart';

/// A small spell engine for tests: a fixed word list (case-insensitive),
/// suggestions per word, the personal words; tokenizes letters like the
/// Hunspell tokenizer's main rules (skip ranges, ALL-CAPS, under two
/// letters).
class FakeSpellEngine implements SpellEngine {
  FakeSpellEngine({
    Iterable<String> words = defaultWords,
    this.suggestions = defaultSuggestions,
    this.tag = 'en-US',
  }) : _known = {for (final w in words) w.toLowerCase()};

  static const defaultWords = [
    'hello',
    'world',
    'the',
    'quick',
    'brown',
    'fox',
    'plan',
    'notes',
    'shape',
    'text',
    'cell',
    'say',
    'first',
    'a',
    'is',
    'our',
    'team',
    'big',
    'day',
    'link',
    'here',
    'title',
    'good',
  ];

  static const defaultSuggestions = <String, List<String>>{
    'helo': ['hello', 'help', 'hole'],
    'wrold': ['world'],
    'teh': ['the', 'tea'],
    'borwn': ['brown'],
    'plna': ['plan'],
    'celll': ['cell'],
  };

  @override
  final String tag;
  final Set<String> _known;
  final Map<String, List<String>> suggestions;
  Set<String> personal = {};

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
    for (final m in RegExp(r'[\p{L}]+', unicode: true).allMatches(text))
      if (m.end - m.start >= 2 &&
          !(skipAllCaps && m.group(0)!.toUpperCase() == m.group(0)) &&
          !skipRanges.any((r) => m.start < r.$2 && m.end > r.$1))
        SpellWord(m.start, m.end, m.group(0)!),
  ];

  @override
  void setPersonalWords(Iterable<String> words) => personal = words.toSet();
}

/// An asset bundle with only the dictionary index (en-US, en-GB).
class _IndexBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('/index.json')) {
      final json = jsonEncode({
        'dictionaries': [
          {'tag': 'en-US', 'name': 'English (US)', 'aff': 'a', 'dic': 'd'},
          {'tag': 'en-GB', 'name': 'English (UK)', 'aff': 'a', 'dic': 'd'},
        ],
      });
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
    }
    throw StateError('No asset $key');
  }
}

/// Installs [engine] (default a [FakeSpellEngine]) as the en-US
/// dictionary (and a second fake as en-GB) of every `SlidesSpelling` and
/// the device locale `en-US`; returns the en-US engine. Call [resetSpelling] in `tearDown`.
FakeSpellEngine installFakeSpelling([FakeSpellEngine? engine]) {
  final e = engine ?? FakeSpellEngine();
  final d = SpellDictionaries(bundle: _IndexBundle())
    ..debugSetEngine('en-US', e)
    ..debugSetEngine('en-GB', FakeSpellEngine(tag: 'en-GB'));
  SlidesSpelling.debugDictionaries = d;
  SlidesSpelling.debugLocale = 'en-US';
  return e;
}

/// Restores the real dictionaries.
void resetSpelling() {
  SlidesSpelling.debugDictionaries = null;
  SlidesSpelling.debugLocale = null;
}
