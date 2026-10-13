import 'package:test/test.dart';
import 'package:wonky_write_core/spellcheck.dart';

import 'support/spell_test_utils.dart';

const _flagDic = '''
5
foo/X
bar/X
baz
ab/X
Bar/X
''';

const _ordinalsAff = '''
COMPOUNDMIN 1
ONLYINCOMPOUND c
COMPOUNDRULE 2
COMPOUNDRULE n*1t
COMPOUNDRULE n*mp
''';

const _ordinalsDic = '''
14
0/nm
1/n1
2/nm
3/nm
4/nm
0th/pt
1st/p
1th/tc
2nd/p
2th/tc
3rd/p
3th/tc
4th/pt
''';

void main() {
  group('Given COMPOUNDFLAG with the default COMPOUNDMIN of 3', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor('COMPOUNDFLAG X', _flagDic));

    checkVectors(() => checker, [
      ('foobar', true),
      ('barfoo', true),
      ('foobarfoo', true),
      ('Foobar', true),
      ('FOOBAR', true),
      ('foobaz', false),
      ('fooab', false),
      ('foob', false),
    ]);
  });

  group('Given COMPOUNDWORDMAX 2', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor('COMPOUNDFLAG X\nCOMPOUNDWORDMAX 2', _flagDic),
    );

    checkVectors(() => checker, [('foobar', true), ('foobarfoo', false)]);
  });

  group('Given COMPOUNDBEGIN, COMPOUNDMIDDLE and COMPOUNDLAST', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor(
        'COMPOUNDBEGIN B\nCOMPOUNDMIDDLE M\nCOMPOUNDEND L',
        '3\nstart/B\nmid/M\nend/L',
      ),
    );

    checkVectors(() => checker, [
      ('startend', true),
      ('startmidend', true),
      ('startmidmidend', true),
      ('endstart', false),
      ('startmid', false),
      ('midend', false),
    ]);
  });

  group('Given COMPOUNDPERMITFLAG on one of two suffixes', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor('''
COMPOUNDFLAG X
COMPOUNDPERMITFLAG P
SFX S Y 1
SFX S 0 s .
SFX T Y 1
SFX T 0 s/P .
''', '2\ncar/XS\nkey/XT'),
    );

    checkVectors(() => checker, [
      ('cars', true),
      ('carkeys', true),
      ('keyscar', true),
      ('carskey', false),
    ]);
  });

  group('Given compound boundary checks', () {
    final cases = <(String, String, String, bool)>[
      ('CHECKCOMPOUNDDUP', 'foo/X', 'foofoo', false),
      ('', 'foo/X', 'foofoo', true),
      ('CHECKCOMPOUNDTRIPLE', 'fall/X\nlake/X', 'falllake', false),
      ('', 'fall/X\nlake/X', 'falllake', true),
      ('CHECKCOMPOUNDCASE', 'foo/X\nBar/X', 'fooBar', false),
      ('', 'foo/X\nBar/X', 'fooBar', true),
      (
        'CHECKCOMPOUNDPATTERN 1\nCHECKCOMPOUNDPATTERN oo b',
        'foo/X\nbar/X',
        'foobar',
        false,
      ),
      (
        'CHECKCOMPOUNDPATTERN 1\nCHECKCOMPOUNDPATTERN oo b',
        'foo/X\nbar/X',
        'barfoo',
        true,
      ),
      (
        'CHECKCOMPOUNDPATTERN 1\nCHECKCOMPOUNDPATTERN /Y /X',
        'foo/XY\nbar/X',
        'foobar',
        false,
      ),
      (
        'CHECKCOMPOUNDPATTERN 1\nCHECKCOMPOUNDPATTERN /Y /X',
        'foo/XY\nbar/X',
        'barfoo',
        true,
      ),
      ('FORCEUCASE U', 'foo/X\nbar/XU', 'foobar', false),
      ('FORCEUCASE U', 'foo/X\nbar/XU', 'Foobar', true),
      (
        'CHECKCOMPOUNDREP\nREP 1\nREP f ph',
        'phoo\nfoo/X\nbar/X',
        'foobar',
        true,
      ),
      (
        'CHECKCOMPOUNDREP\nREP 1\nREP oob oo',
        'foo/X\nbar/X\nfooar',
        'foobar',
        false,
      ),
    ];
    for (final (directives, dic, word, accepted) in cases) {
      final label = directives.isEmpty
          ? 'no check'
          : directives.split('\n').last;
      test('when checking "$word" with $label then it is '
          '${accepted ? 'accepted' : 'rejected'}', () {
        final checker = checkerFor('COMPOUNDFLAG X\n$directives', '1\n$dic');
        expect(checker.check(word), accepted);
      });
    }
  });

  group('Given COMPOUNDRULEs for English ordinals', () {
    late SpellChecker checker;
    setUp(() => checker = checkerFor(_ordinalsAff, _ordinalsDic));

    checkVectors(() => checker, [
      ('1st', true),
      ('21st', true),
      ('11th', true),
      ('111th', true),
      ('22nd', true),
      ('104th', true),
      ('21th', false),
      ('1th', false),
      ('23nd', false),
    ]);
  });

  group('Given a COMPOUNDRULE with long flags and quantifiers', () {
    late SpellChecker checker;
    setUp(
      () => checker = checkerFor(
        'FLAG long\nCOMPOUNDMIN 1\nCOMPOUNDRULE 1\nCOMPOUNDRULE (aa)(bb)*(cc)?',
        '3\nx/aa\ny/bb\nz/cc',
      ),
    );

    checkVectors(() => checker, [
      ('xz', true),
      ('xyyz', true),
      ('xy', true),
      ('zx', false),
      ('yz', false),
    ]);
  });

  group('Given a long misspelled word in a compounding dictionary', () {
    test('when checking it then the search terminates and rejects it', () {
      final checker = checkerFor(
        'COMPOUNDFLAG X\nCOMPOUNDMIN 1',
        '2\na/X\nb/X',
      );
      expect(checker.check('${'ab' * 40}c'), isFalse);
    });
  });

  group('Given a dictionary with compounding', () {
    test('when reading hasCompounding then it is true', () {
      final dictionary = HunspellDictionary.parse('COMPOUNDFLAG X', '');
      expect(dictionary.hasCompounding, isTrue);
    });
  });
}
