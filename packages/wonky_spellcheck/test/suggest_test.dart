import 'package:test/test.dart';
import 'package:wonky_spellcheck/wonky_spellcheck.dart';

import 'support/spell_test_utils.dart';

const _aff = r'''
SET UTF-8
TRY esianrtolcdugmphbyfvkwzx'
NOSUGGEST !
FORBIDDENWORD *
REP 3
REP f ph
REP ^alot$ a_lot
REP shun$ tion
MAP 1
MAP eéè
SFX S Y 1
SFX S 0 s .
''';

const _dic = '''
24
a
lot
the
cat/S
phone/S
receive
separate
because
vacation
hello
help
house
café
Paris
nation
known
well
damn/*
shit/!
test
moon
noon
card
cart
''';

/// Only KEY can produce candidates: TRY has no useful letters.
const _keyAff = '''
TRY x
KEY qwertyuiop|asdfghjkl|zxcvbnm
''';

void main() {
  group('Given a dictionary with REP, MAP and TRY', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_aff, _dic));

    final firsts = <(String, String, String)>[
      ('REP', 'fone', 'phone'),
      ('REP with ^/\$ anchors and _', 'alot', 'a lot'),
      ('REP with \$ anchor', 'nashun', 'nation'),
      ('MAP', 'cafe', 'café'),
      ('swapped characters', 'teh', 'the'),
      ('swapped characters', 'becuase', 'because'),
      ('swapped characters', 'recieve', 'receive'),
      ('a forgotten doubled character', 'helo', 'hello'),
      ('an extra character', 'thhe', 'the'),
      ('a bad character (TRY)', 'seperate', 'separate'),
      ('a doubled syllable', 'vacacation', 'vacation'),
      ('a moved character', 'hlelo', 'hello'),
      ('a missing space', 'thecat', 'the cat'),
      ('a lowercase proper name', 'paris', 'Paris'),
      ('Titlecase input', 'Teh', 'The'),
      ('ALL-CAPS input', 'TEH', 'THE'),
      ('an affixed form', 'phonse', 'phones'),
      ('a misspelled part of a hyphenated word', 'well-knwon', 'well-known'),
    ];
    for (final (kind, word, expected) in firsts) {
      test('when suggesting for "$word" ($kind) then "$expected" is first', () {
        expect(checker.suggest(word, budget: unlimited).first, expected);
      });
    }

    test('when suggesting for a word two edits away then the n-gram pass '
        'finds it', () {
      expect(
        checker.suggest('seperete', budget: unlimited),
        contains('separate'),
      );
    });

    test('when suggesting then the input itself is never suggested', () {
      expect(checker.suggest('the', budget: unlimited), isNot(contains('the')));
    });

    test('when suggesting for a correct word then case variants of it are not '
        'suggested', () {
      expect(
        checker.suggest('hello', budget: unlimited),
        isNot(contains('Hello')),
      );
    });

    test('when suggesting near a FORBIDDENWORD then it is not suggested', () {
      expect(
        checker.suggest('damm', budget: unlimited),
        isNot(contains('damn')),
      );
    });

    test('when suggesting near a NOSUGGEST word then it is not suggested', () {
      expect(
        checker.suggest('shyt', budget: unlimited),
        isNot(contains('shit')),
      );
    });

    test('when asking for at most 1 then 1 comes back', () {
      expect(checker.suggest('xoon', max: 1, budget: unlimited), hasLength(1));
    });

    test('when asking for 0 then none come back', () {
      expect(checker.suggest('teh', max: 0), isEmpty);
    });

    test('when suggesting twice then the results are identical', () {
      expect(
        checker.suggest('moom', budget: unlimited),
        checker.suggest('moom', budget: unlimited),
      );
    });

    test('when equally good candidates tie then they are in lexicographic '
        'order', () {
      expect(checker.suggest('carx', max: 2, budget: unlimited), [
        'card',
        'cart',
      ]);
    });

    test('when the stopwatch is already past the budget then there are no '
        'suggestions', () {
      final suggestions = checker.suggest(
        'teh',
        budget: const Duration(milliseconds: 50),
        stopwatch: FakeStopwatch(50000),
      );
      expect(suggestions, isEmpty);
    });

    test('when the budget is not used up then the injected stopwatch is '
        'honoured', () {
      final suggestions = checker.suggest(
        'teh',
        budget: const Duration(milliseconds: 50),
        stopwatch: FakeStopwatch(10),
      );
      expect(suggestions.first, 'the');
    });
  });

  group('Given NOSPLITSUGS', () {
    test('when suggesting for two joined words then no split is offered', () {
      final checker = checkerFor('$_aff\nNOSPLITSUGS', _dic);
      expect(
        checker.suggest('thecat', budget: unlimited),
        isNot(contains('the cat')),
      );
    });
  });

  group('Given a KEY layout and no useful TRY characters', () {
    test('when a key was hit next to the right one then KEY fixes it', () {
      final checker = checkerFor(_keyAff, '1\nhello');
      expect(checker.suggest('hrllo', budget: unlimited), ['hello']);
    });
  });

  group('Given an .aff without TRY', () {
    test('when a letter is wrong then letters of the dictionary are tried', () {
      final checker = checkerFor('', '2\nmouse\nhouse');
      expect(checker.suggest('mousr', budget: unlimited), contains('mouse'));
    });
  });

  group('Given OCONV', () {
    test('when suggesting then output conversion is applied', () {
      final checker = checkerFor(
        "ICONV 1\nICONV ’ '\nOCONV 1\nOCONV ' ’\nTRY st",
        "1\ndon't",
      );
      expect(checker.suggest("dont't", budget: unlimited).first, 'don’t');
    });
  });

  group('Given personal words', () {
    test('when a personal word is close then it is suggested', () {
      final checker = SpellChecker(
        HunspellDictionary.parse(_aff, _dic),
        personalWords: ['serverpod'],
      );
      expect(checker.suggest('serverpd', budget: unlimited).first, 'serverpod');
    });
  });
}
