import 'package:wonky_write_core/spellcheck.dart';

import 'spell_engine.dart';

/// Parses a dictionary in time slices of at most [slice]; [yieldSlice] waits
/// for the next slot (an idle task on the UI thread).
Future<SpellEngine> createHunspellEngine({
  required String tag,
  required String aff,
  required String dic,
  required Future<void> Function() yieldSlice,
  Duration slice = const Duration(milliseconds: 8),
}) async {
  final loader = HunspellDictionaryLoader(aff, dic);
  while (!loader.step(slice)) {
    await yieldSlice();
  }
  return _HunspellEngine(tag, loader.result);
}

class _HunspellEngine implements SpellEngine {
  _HunspellEngine(this.tag, HunspellDictionary dictionary)
    : _checker = SpellChecker(dictionary),
      _wordChars = dictionary.wordChars;

  @override
  final String tag;
  final SpellChecker _checker;
  final String _wordChars;
  SpellTokenizer? _tokenizer;
  bool? _tokenizerAllCaps;

  @override
  bool check(String word, {bool followedByPeriod = false}) =>
      _checker.check(word) || (followedByPeriod && _checker.check('$word.'));

  @override
  List<String> suggest(String word, {int max = 5}) =>
      _checker.suggest(word, max: max);

  @override
  List<SpellWord> words(
    String text, {
    List<(int, int)> skipRanges = const [],
    bool skipAllCaps = true,
  }) {
    if (_tokenizer == null || _tokenizerAllCaps != skipAllCaps) {
      _tokenizer = SpellTokenizer(
        wordChars: _wordChars,
        skipAllCaps: skipAllCaps,
      );
      _tokenizerAllCaps = skipAllCaps;
    }
    return [
      for (final t in _tokenizer!.tokenize(text, skipRanges: skipRanges))
        SpellWord(t.start, t.end, t.word, followedByPeriod: t.followedByPeriod),
    ];
  }

  @override
  void setPersonalWords(Iterable<String> words) {
    for (final w in _checker.personalWords.toList()) {
      _checker.removePersonalWord(w);
    }
    for (final w in words) {
      _checker.addPersonalWord(w);
    }
  }
}
