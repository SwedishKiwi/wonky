import 'package:test/test.dart';
import 'package:wonky_write_core/spellcheck.dart';

import 'support/spell_test_utils.dart';

const _affixAff = '''
SET UTF-8

PFX A Y 1
PFX A 0 re .

PFX I N 1
PFX I 0 in .

SFX S Y 3
SFX S y ies [^aeiou]y
SFX S 0 s [aeiou]y
SFX S 0 s [^y]

SFX D Y 4
SFX D 0 d e
SFX D y ied [^aeiou]y
SFX D 0 ed [^ey]
SFX D 0 ed [aeiou]y

SFX N N 1
SFX N 0 ness .
''';

const _affixDic = '''
5
work/ADS
cry/DS
toy/S
bake/D
able/IN
''';

const _twofoldAff = '''
SFX X Y 1
SFX X 0 able/Y .

SFX Y Y 1
SFX Y 0 ness .
''';

const _twofoldDic = '''
1
read/X
''';

const _circumfixAff = '''
CIRCUMFIX X

PFX G Y 1
PFX G 0 ge/X .

SFX T Y 1
SFX T 0 t/X .

SFX E Y 1
SFX E 0 en .
''';

const _circumfixDic = '''
1
spiel/GTE
''';

const _needAffixAff = '''
NEEDAFFIX X

SFX S Y 1
SFX S 0 s .

SFX N Y 1
SFX N 0 ing/XP .

SFX P Y 1
SFX P 0 s .
''';

const _needAffixDic = '''
3
foo/XS
bar/N
baz/X
baz/S
''';

const _forbiddenAff = '''
FORBIDDENWORD !

SFX S Y 1
SFX S 0 s .
''';

const _forbiddenDic = '''
3
foot/S
foots/!
bar/S
''';

const _keepCaseAff = '''
KEEPCASE K
''';

const _keepCaseDic = '''
4
ok/K
iPod/K
hello
Paris
''';

const _onlyInCompoundAff = '''
COMPOUNDFLAG Y
COMPOUNDMIN 1
ONLYINCOMPOUND X
''';

const _onlyInCompoundDic = '''
3
foo/Y
bar/Y
s/XY
''';

void main() {
  group('Given prefixes and suffixes with strip, conditions and cross '
      'products', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_affixAff, _affixDic));

    checkVectors(() => checker, [
      ('work', true),
      ('works', true),
      ('rework', true),
      ('reworks', true),
      ('reworked', true),
      ('rereworks', false),
      ('cries', true),
      ('crys', false),
      ('cried', true),
      ('cryed', false),
      ('toys', true),
      ('toies', false),
      ('baked', true),
      ('bakeed', false),
      ('inable', true),
      ('ableness', true),
      ('inableness', false),
      ('worker', false),
      ('bakes', false),
    ]);
  });

  group('Given a suffix whose continuation class allows a second suffix', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_twofoldAff, _twofoldDic));

    checkVectors(() => checker, [
      ('readable', true),
      ('readableness', true),
      ('readness', false),
    ]);
  });

  group('Given CIRCUMFIX affixes', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_circumfixAff, _circumfixDic));

    checkVectors(() => checker, [
      ('spiel', true),
      ('spielen', true),
      ('gespielt', true),
      ('gespiel', false),
      ('spielt', false),
      ('gespielen', false),
    ]);
  });

  group('Given NEEDAFFIX on roots and on affixes', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_needAffixAff, _needAffixDic));

    checkVectors(() => checker, [
      ('foo', false),
      ('foos', true),
      ('bar', true),
      ('baring', false),
      ('barings', true),
      // A homonym without NEEDAFFIX makes the bare root valid.
      ('baz', true),
      ('bazs', true),
    ]);
  });

  group('Given a FORBIDDENWORD form of an affixed word', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_forbiddenAff, _forbiddenDic));

    checkVectors(() => checker, [
      ('foot', true),
      ('foots', false),
      ('Foots', false),
      ('bars', true),
    ]);
  });

  group('Given KEEPCASE words', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_keepCaseAff, _keepCaseDic));

    checkVectors(() => checker, [
      ('ok', true),
      ('OK', false),
      ('Ok', false),
      ('iPod', true),
      ('IPOD', false),
      ('Hello', true),
      ('HELLO', true),
    ]);
  });

  group('Given an ONLYINCOMPOUND linking element', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_onlyInCompoundAff, _onlyInCompoundDic));

    checkVectors(() => checker, [
      ('s', false),
      ('foo', true),
      ('foosbar', true),
      ('foobar', true),
    ]);
  });

  group('Given an empty dictionary', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor('', ''));

    test('when checking a word then it is rejected', () {
      expect(checker.check('word'), isFalse);
    });

    test('when checking the empty string then it is accepted', () {
      expect(checker.check(''), isTrue);
    });
  });

  group('Given a dictionary built with HunspellDictionary.parse', () {
    late HunspellDictionary dictionary;
    setUp(() => dictionary = HunspellDictionary.parse(_affixAff, _affixDic));

    test('when reading wordCount then it counts the roots', () {
      expect(dictionary.wordCount, 5);
    });

    test('when asking for a root then containsRoot finds only roots', () {
      expect(
        [dictionary.containsRoot('work'), dictionary.containsRoot('works')],
        [true, false],
      );
    });
  });
}
