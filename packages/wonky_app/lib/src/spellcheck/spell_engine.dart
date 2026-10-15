import 'package:flutter/foundation.dart';

/// A word of a block's text to check, with UTF-16 offsets `[start, end)`.
@immutable
class SpellWord {
  const SpellWord(
    this.start,
    this.end,
    this.word, {
    this.followedByPeriod = false,
  });

  final int start;
  final int end;
  final String word;

  /// A period follows the word (abbreviations like "etc.").
  final bool followedByPeriod;
}

/// The spell checker as an editor sees it (implemented with
/// `package:wonky_spellcheck` in `hunspell_engine.dart`; tests can inject
/// fakes). Shared by the apps (Write 04 §28.2, Slides 03 §14).
abstract class SpellEngine {
  /// The dictionary's BCP-47 tag ("en-US").
  String get tag;

  /// Whether [word] is spelled correctly (personal words included); with
  /// [followedByPeriod] the dotted form counts too ("etc.").
  bool check(String word, {bool followedByPeriod = false});

  /// Up to [max] suggestions, best first.
  List<String> suggest(String word, {int max = 5});

  /// The checkable words of [text], skipping [skipRanges] (code, links,
  /// mentions), URLs, emails, words with digits, CamelCase, words under two
  /// characters and — with [skipAllCaps] — ALL-CAPS words.
  List<SpellWord> words(
    String text, {
    List<(int, int)> skipRanges = const [],
    bool skipAllCaps = true,
  });

  /// Replaces the personal dictionary words.
  void setPersonalWords(Iterable<String> words);
}
