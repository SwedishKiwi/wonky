import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_write/features/special_chars/special_chars_catalog.dart';

import 'support/special_chars_fixture.dart';

List<int> _codes(List<SpecialChar> list) => [for (final c in list) c.codePoint];

void main() {
  group('Given the fixture table', () {
    late SpecialCharsCatalog catalog;
    setUp(() => catalog = specialCharsFixture());

    test('when listing a category then its characters come in order', () {
      expect(catalog.categories, ['Punctuation', 'Arrows', 'Latin']);
      expect(_codes(catalog.inCategory(1)), [0x2190, 0x2192, 0x21D2, 0x2933]);
    });

    test('when reading a character then char and code label match', () {
      final arrow = catalog.byCodePoint(0x2192)!;

      expect(arrow.char, '→');
      expect(arrow.codeLabel, 'U+2192');
      expect(catalog.byCodePoint(0xE9)!.codeLabel, 'U+00E9');
      expect(arrow.displayName, 'Rightwards arrow');
    });

    test('when searching "arrow" then all arrows match, whole words first', () {
      expect(_codes(catalog.search('arrow')), [0x2190, 0x2192, 0x21D2, 0x2933]);
    });

    test('when searching an exact name then it ranks first', () {
      expect(_codes(catalog.search('rightwards arrow')).first, 0x2192);
      expect(_codes(catalog.search('rightwards arrow')), contains(0x21D2));
    });

    test('when searching a word prefix then it matches', () {
      expect(_codes(catalog.search('ellip')), [0x2026]);
    });

    for (final (query, expected) in [
      ('U+00E9', 0xE9),
      ('u+e9', 0xE9),
      ('00E9', 0xE9),
      ('2192', 0x2192),
      ('0x2192', 0x2192),
      ('→', 0x2192),
      ('é', 0xE9),
    ]) {
      test('when searching "$query" then U+${expected.toRadixString(16)} '
          'comes first', () {
        expect(catalog.search(query).first.codePoint, expected);
      });
    }

    test('when searching several words then all must match', () {
      expect(_codes(catalog.search('small e acute')), [0xE9]);
      expect(_codes(catalog.search('e with acute')), [0xC9, 0xE9]);
    });

    test('when searching an unknown word then nothing matches', () {
      expect(catalog.search('xylophone'), isEmpty);
      expect(catalog.search('cafe'), isEmpty);
    });

    test('when reading a zero width space then it is invisible', () {
      expect(catalog.byCodePoint(0x200B)!.isInvisible, isTrue);
      expect(catalog.byCodePoint(0x2014)!.isInvisible, isFalse);
    });
  });

  group('Given the bundled special characters asset', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('when loading it then all ten categories have characters', () async {
      final catalog = await SpecialCharsCatalog.load(rootBundle);

      expect(catalog.categories, [
        'Punctuation',
        'Arrows',
        'Math',
        'Currency',
        'Latin',
        'Greek',
        'Cyrillic',
        'Symbols',
        'Technical',
        'Box drawing',
      ]);
      expect(catalog.all.length, greaterThan(5000));
      expect([
        for (var i = 0; i < catalog.categories.length; i++)
          catalog.inCategory(i).length,
      ], everyElement(greaterThan(0)));
      expect(catalog.search('rightwards arrow').first.char, '→');
      expect(catalog.search('U+20AC').first.name, 'EURO SIGN');
      expect(catalog.byCodePoint(0x20AC)!.category, 3);
      expect(catalog.byCodePoint(0x0301), isNull); // combining acute
    });
  });
}
