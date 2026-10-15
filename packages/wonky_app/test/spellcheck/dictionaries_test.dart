import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/spellcheck.dart';

void main() {
  group('Given document languages', () {
    const all = [
      DictionaryInfo(tag: 'en-US', name: 'US', aff: 'a', dic: 'd'),
      DictionaryInfo(tag: 'en-GB', name: 'GB', aff: 'a', dic: 'd'),
      DictionaryInfo(tag: 'fr-FR', name: 'FR', aff: 'a', dic: 'd'),
    ];
    for (final (language, expected) in [
      (null, 'en-US'),
      ('en', 'en-US'),
      ('en-AU', 'en-GB'),
      ('en_GB', 'en-GB'),
      ('en-CA', 'en-US'),
      ('fr', 'fr-FR'),
      ('fr-CA', 'fr-FR'),
      ('de-DE', null),
    ]) {
      test('when resolving "$language" then the dictionary is $expected', () {
        expect(SpellDictionaries.resolve(all, language)?.tag, expected);
      });
    }
  });
}
