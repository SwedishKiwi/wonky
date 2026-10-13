import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_write/features/emoji/emoji_catalog.dart';

import 'support/emoji_fixture.dart';

List<String> _chars(List<Emoji> list) => [for (final e in list) e.char];

void main() {
  group('Given the fixture catalog', () {
    late EmojiCatalog catalog;
    setUp(() => catalog = emojiFixture());

    test('when listing categories then they keep the asset order', () {
      expect(
        [for (final c in catalog.categories) c.id],
        ['smileys', 'people', 'symbols'],
      );
      expect(_chars(catalog.inCategory(0)), ['😀', '😄', '🙂']);
      expect(catalog.inCategory(9), isEmpty);
    });

    test('when searching "smile" then the exact shortcode ranks first', () {
      final result = catalog.search('smile');

      expect(_chars(result), ['😄', '😀', '🙂']);
    });

    test('when searching ":wave:" then the colons are ignored', () {
      expect(_chars(catalog.search(':wave:')), ['👋']);
    });

    test('when searching "grin" then shortcode prefix beats name prefix', () {
      expect(_chars(catalog.search('grin')), ['😀', '😄']);
    });

    test('when searching "+1" then the shortcode matches', () {
      expect(_chars(catalog.search('+1')), ['👍']);
    });

    test('when searching two words then all must match', () {
      expect(_chars(catalog.search('smiling face')), ['😄', '🙂']);
    });

    test('when searching a keyword prefix then it matches', () {
      expect(_chars(catalog.search('frie')), ['🧑‍🤝‍🧑']);
    });

    test('when searching with a limit then at most that many come back', () {
      expect(catalog.search('face', limit: 2), hasLength(2));
    });

    test('when searching an empty query then nothing comes back', () {
      expect(catalog.search('  '), isEmpty);
    });

    test('when applying tone 3 to waving hand then the modifier follows', () {
      final hand = catalog.byChar('👋')!;

      expect(hand.hasSkinTones, isTrue);
      expect(hand.withSkinTone(3), '👋🏽');
      expect(hand.withSkinTone(0), '👋');
    });

    test('when applying a tone to an emoji with VS16 then VS16 is dropped', () {
      final lifter = catalog.byChar('\u{1F3CB}️')!;

      expect(lifter.withSkinTone(1), '\u{1F3CB}\u{1F3FB}');
    });

    test('when applying a tone to a ZWJ sequence then it goes after the '
        'first code point', () {
      final beard = catalog.byChar('\u{1F9D4}‍♂️')!;

      expect(beard.withSkinTone(5), '\u{1F9D4}\u{1F3FF}‍♂️');
    });

    test('when applying a tone to a multi-person ZWJ sequence then the '
        'stored variant is used', () {
      final people = catalog.byChar('🧑‍🤝‍🧑')!;

      expect(people.withSkinTone(2), '🧑🏼‍🤝‍🧑🏼');
    });

    test('when applying a tone to an emoji without tones then it is '
        'unchanged', () {
      final heart = catalog.byChar('❤️')!;

      expect(heart.hasSkinTones, isFalse);
      expect(heart.withSkinTone(4), '❤️');
    });

    test('when looking up a toned or VS16-less char then the base emoji '
        'is found', () {
      expect(catalog.byChar('👋🏿')?.name, 'waving hand');
      expect(catalog.byChar('❤')?.name, 'red heart');
      expect(catalog.byChar('x'), isNull);
    });
  });

  group('Given the bundled emoji asset', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('when loading it then it has the Unicode 15.1 emoji', () async {
      final catalog = await EmojiCatalog.load(rootBundle);

      expect(catalog.version, '15.1');
      expect(catalog.categories, hasLength(9));
      expect(catalog.all.length, greaterThan(1800));
      expect(catalog.search('thumbs up').first.char, '👍');
      expect(catalog.search(':joy:').first.char, '😂');
      expect(catalog.byChar('👋')!.withSkinTone(3), '👋🏽');
      expect(catalog.byChar('🧑‍🤝‍🧑')!.withSkinTone(1), '🧑🏻‍🤝‍🧑🏻');
      expect(identical(await EmojiCatalog.load(rootBundle), catalog), isTrue);
    });

    test('when loading it then no skin tone swatch or regional indicator '
        'is listed', () async {
      final catalog = await EmojiCatalog.load(rootBundle);

      expect(catalog.byChar('\u{1F3FB}'), isNull);
      expect(catalog.byChar('\u{1F1E6}'), isNull);
      expect(catalog.byChar('🇸🇪')?.name, 'flag: Sweden');
    });
  });
}
