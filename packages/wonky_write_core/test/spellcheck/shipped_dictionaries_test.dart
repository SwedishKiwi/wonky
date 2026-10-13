@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:wonky_write_core/spellcheck.dart';

import 'support/dictionaries.dart';

/// (tag, correct words, misspelled words) per shipped dictionary.
const _smoke = <(String, List<String>, List<String>)>[
  (
    'en-US',
    ['color', 'organize', 'houses', 'unhappiness', "it's", 'don’t', 'mother-in-law', 'The', 'NASA', '21st'],
    ['colour', 'teh', 'recieve', 'definately', 'nasa', '21th'],
  ),
  (
    'en-GB',
    ['colour', 'organise', 'theatre', 'realised', 'Paris'],
    ['color', 'teh', 'recieve', 'paris'],
  ),
  (
    'fr-FR',
    ["l'école", 'd’accord', 'peut-être', "aujourd'hui", 'chevaux', 'écrivîmes', 'Français'],
    ['bocoup', 'chevals', 'ecole'],
  ),
  (
    'es-ES',
    ['también', 'está', 'niños', 'rápidamente', 'dígamelo'],
    ['tambien', 'ninios', 'rapidamente'],
  ),
  (
    'nl-NL',
    ['gemeenteraad', 'ziekenhuis', 'mogelijkheden', 'Amsterdam', 'fietsenmaker', 'eenentwintigste'],
    ['mogelijkhijd', 'fietsenstaling', 'amsterdam'],
  ),
  (
    'sv-SE',
    ['flickorna', 'hjärtat', 'Stockholm', 'regeringen', 'kärnkraftverk', 'mjölkpaket'],
    ['regerningen', 'kärlken', 'stockholm'],
  ),
];

/// (misspelling, expected suggestion, within the first n) for en-US.
const _enSuggestions = <(String, String, int)>[
  ('teh', 'the', 1),
  ('recieve', 'receive', 1),
  ('seperate', 'separate', 1),
  ('becuase', 'because', 1),
  ('occured', 'occurred', 1),
  ('definately', 'definitely', 3),
  ('Teh', 'The', 1),
  ('TEH', 'THE', 1),
  ('alot', 'a lot', 1),
  ('accomodate', 'accommodate', 1),
];

void main() {
  final skip = shippedDictionariesSkipReason;

  group('Given the shipped dictionaries index', () {
    test('when reading it then every entry has existing files and a '
        'license', () {
      final dir = shippedDictionariesDir()!;
      final entries = shippedDictionaryIndex();
      expect(
        [for (final e in entries) e['tag']],
        [for (final (tag, _, _) in _smoke) tag],
      );
      for (final e in entries) {
        final tag = e['tag']! as String;
        expect(
          [
            File('${dir.path}/${e['aff']}').existsSync(),
            File('${dir.path}/${e['dic']}').existsSync(),
            File('${dir.path}/LICENSE-$tag.txt').existsSync(),
            (e['name'] as String?)?.isNotEmpty,
            (e['license'] as String?)?.isNotEmpty,
          ],
          everyElement(isTrue),
          reason: tag,
        );
      }
    });

    test('when reading the .aff files then they declare UTF-8', () {
      final dir = shippedDictionariesDir()!;
      final sets = [
        for (final e in shippedDictionaryIndex())
          HunspellDictionary.parse(
            File('${dir.path}/${e['aff']}').readAsStringSync(),
            '',
          ).encoding,
      ];
      expect(sets, everyElement('UTF-8'));
    });
  }, skip: skip);

  for (final (tag, good, bad) in _smoke) {
    group('Given the shipped $tag dictionary', () {
      late SpellChecker checker;
      setUp(() => checker = SpellChecker(loadShippedDictionary(tag)));

      for (final word in good) {
        test('when checking "$word" then it is accepted', () {
          expect(checker.check(word), isTrue);
        });
      }
      for (final word in bad) {
        test('when checking "$word" then it is rejected', () {
          expect(checker.check(word), isFalse);
        });
      }
    }, skip: skip);
  }

  group('Given the shipped en-US dictionary', () {
    late SpellChecker checker;
    setUp(() => checker = SpellChecker(loadShippedDictionary('en-US')));

    for (final (word, expected, within) in _enSuggestions) {
      test('when suggesting for "$word" then "$expected" is in the top '
          '$within', () {
        final suggestions = checker.suggest(
          word,
          budget: const Duration(minutes: 1),
        );
        expect(suggestions.take(within), contains(expected));
      });
    }

    test('when tokenizing and checking a sentence then only the misspelled '
        'words are flagged', () {
      const text =
          'Teh quick brown fox jumps over the lazy dog, recieve it at '
          'https://example.com or mail me@example.com. NASA uses iPhone apps.';
      final tokenizer = SpellTokenizer(
        wordChars: checker.dictionary.wordChars,
      );
      final flagged = [
        for (final t in tokenizer.tokenize(text))
          if (!checker.checkToken(t)) t.word,
      ];
      expect(flagged, ['Teh', 'recieve']);
    });
  }, skip: skip);
}
