import 'package:test/test.dart';
import 'package:wonky_spellcheck/wonky_spellcheck.dart';

import 'support/spell_test_utils.dart';

void main() {
  group('Given FLAG long', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor('''
FLAG long
SFX Aa Y 1
SFX Aa 0 s .
PFX Bb Y 1
PFX Bb 0 un .
''', '1\ndo/AaBb'),
    );

    checkVectors(() => checker, [
      ('dos', true),
      ('undo', true),
      ('undos', true),
      ('dox', false),
    ]);
  });

  group('Given FLAG num', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor('''
FLAG num
SFX 101 Y 1
SFX 101 0 s .
SFX 7 Y 1
SFX 7 0 ed .
SFX 70 Y 1
SFX 70 0 ing .
''', '1\nwalk/101,7'),
    );

    checkVectors(() => checker, [
      ('walks', true),
      ('walked', true),
      ('walking', false),
    ]);
  });

  group('Given FLAG UTF-8', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor(
        'FLAG UTF-8\nSFX é Y 1\nSFX é 0 s .\nSFX ü Y 1\nSFX ü 0 te .',
        '1\nchat/é',
      ),
    );

    checkVectors(() => checker, [('chats', true), ('chatte', false)]);
  });

  group('Given AF flag aliases in the dictionary and in affixes', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor('''
AF 3
AF AB
AF B
AF C
SFX A Y 1
SFX A 0 s .
SFX B Y 1
SFX B 0 ed .
SFX C Y 1
SFX C 0 er/3 .
''', '2\njump/1\nhop/2'),
    );

    checkVectors(() => checker, [
      ('jumps', true),
      ('jumped', true),
      ('hoped', true),
      ('hops', false),
    ]);
  });

  group('Given ICONV and IGNORE', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor(
        'ICONV 1\nICONV ﬁ fi\nIGNORE ¬',
        '2\nfinish\nhello',
      ),
    );

    checkVectors(() => checker, [
      ('ﬁnish', true),
      ('hel¬lo', true),
      ('hel-lo', false),
    ]);
  });

  group('Given the default BREAK patterns', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor('', '2\nwell\nknown'));

    checkVectors(() => checker, [
      ('well-known', true),
      ('Well-known', true),
      ('well-known-well', true),
      ('-well', true),
      ('well-', true),
      ('well-knwon', false),
      ('well--known', true),
    ]);
  });

  group('Given BREAK 0', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor('BREAK 0', '2\nwell\nknown'));

    checkVectors(() => checker, [('well-known', false), ('well', true)]);
  });

  group('Given custom BREAK patterns', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor(
        'BREAK 2\nBREAK ·\nBREAK ^l\'',
        '2\nwell\nknown',
      ),
    );

    checkVectors(() => checker, [
      ('well·known', true),
      ("l'well", true),
      ('well-known', false),
    ]);
  });

  group('Given unusual .dic lines', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor(
        'FOOBAR unknown directive\nSFX S Y 1\nSFX S 0 s .',
        '﻿1\r\n'
            'and\\/or\r\n'
            'cat/S po:noun\r\n'
            'dog\tpo:noun\r\n'
            'ad hoc\r\n'
            'test/S\r\n'
            'test\r\n'
            'bird\r\n'
            '\r\n',
      ),
    );

    checkVectors(() => checker, [
      ('and/or', true),
      ('cats', true),
      ('dog', true),
      ('ad hoc', true),
      ('tests', true),
      ('test', true),
      ('bird', true),
      ('birds', false),
      ('po:noun', false),
    ]);
  });

  group('Given homonyms with different flags', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor(
        'SFX A Y 1\nSFX A 0 s .\nSFX B Y 1\nSFX B 0 ed .',
        '1\ntest/A\ntest/B',
      ),
    );

    checkVectors(() => checker, [
      ('tests', true),
      ('tested', true),
      ('testsed', false),
    ]);
  });

  group('Given an .aff with TRY, WORDCHARS, KEY, LANG and SET', () {
    late HunspellDictionary dictionary;
    setUp(
      () => dictionary = HunspellDictionary.parse(
        'SET UTF-8\nLANG en_US\nTRY abc\nWORDCHARS 0123\nKEY qw|as',
        '',
      ),
    );

    test('when reading the getters then they reflect the directives', () {
      expect(
        (
          dictionary.encoding,
          dictionary.language,
          dictionary.tryChars,
          dictionary.wordChars,
          dictionary.keyboard,
        ),
        ('UTF-8', 'en_US', 'abc', '0123', 'qw|as'),
      );
    });
  });
}
