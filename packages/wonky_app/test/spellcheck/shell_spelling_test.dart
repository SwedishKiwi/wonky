import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/spellcheck.dart';
import 'package:wonky_app/testing.dart';

import '../support/fake_spelling.dart';

void main() {
  late CommandTestHarness h;
  late FakeSpellEngine engine;
  late ShellSpelling spelling;

  setUp(() async {
    h = CommandTestHarness();
    engine = installFakeShellSpelling();
    spelling = ShellSpelling(h.services.prefs);
    await spelling.whenSettled();
  });

  tearDown(() {
    spelling.dispose();
    resetShellSpelling();
    h.dispose();
  });

  group('Given the shell spell checker', () {
    test('when text is checked then unknown words are flagged with their '
        'offsets, skipped ranges and ALL-CAPS words are not', () {
      expect(spelling.isReady, isTrue);
      expect(spelling.check('say helo NASA wrold', skip: [(14, 19)]), [
        const SpellRange(4, 8, 'helo'),
      ]);
      expect(spelling.suggestionsFor('helo'), ['hello', 'help']);
    });

    test('when "Ignore words in UPPERCASE" is off then ALL-CAPS words are '
        'checked', () async {
      var heard = 0;
      spelling.addListener(() => heard++);
      await h.services.prefs.setWriteDefault(
        'spellcheckIgnoreUppercase',
        false,
      );
      expect(heard, 1);
      expect(spelling.check('NASA'), [const SpellRange(0, 4, 'NASA')]);
    });

    test('when "Check spelling" is off then nothing is flagged and '
        'listeners hear it', () async {
      var heard = 0;
      spelling.addListener(() => heard++);
      await h.services.prefs.setWriteDefault('spellcheck', false);
      expect(heard, 1);
      expect(spelling.underline, isFalse);
      expect(spelling.check('helo'), isEmpty);
    });

    test('when a word is ignored then no composer of the session flags it; '
        'added words go to the shared personal dictionary', () async {
      spelling.ignore('helo');
      final other = ShellSpelling(h.services.prefs);
      addTearDown(other.dispose);
      await other.whenSettled();
      expect(other.check('helo'), isEmpty);
      expect(await spelling.addToDictionary('wrold'), isTrue);
      expect(PersonalDictionary.wordsOf(h.services.prefs), ['wrold']);
      expect(engine.personal, {'wrold'});
      expect(spelling.check('wrold'), isEmpty);
    });
  });
}
