import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/spellcheck.dart' show SpellDictionaries;
import 'package:wonky_slides/features/spellcheck/slides_spelling.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../harness/deck_harness.dart';

/// The real glue (Slides 03 §14): the bundled en-US Hunspell dictionary of
/// `wonky_spellcheck`, loaded through `package:wonky_app/spellcheck.dart`.
void main() {
  tearDown(() {
    SlidesSpelling.debugDictionaries = null;
    SlidesSpelling.debugLocale = null;
  });

  testWidgets('Given a deck in English when the bundled dictionary has '
      'loaded then misspellings are flagged with Hunspell suggestions and '
      'skipped words are not', (tester) async {
    // One instance per test: futures don't survive a test's fake-async zone.
    SlidesSpelling.debugDictionaries = SpellDictionaries();
    SlidesSpelling.debugLocale = 'en-US';
    final b = DeckBuilder(title: 'Real');
    final s = b.slide(layoutKey: 'blank', notes: 'Teh notes');
    b.textBox(s, 'The quick borwn fox, NASA and iPhone abc123');
    final d = DeckHarness.open(fixture: b);
    addTearDown(d.dispose);
    final spelling = SlidesSpelling.of(d.editor);
    expect(spelling.state, SlidesSpellingState.loading);
    for (
      var i = 0;
      i < 400 && spelling.state == SlidesSpellingState.loading;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(spelling.state, SlidesSpellingState.ready);
    expect(spelling.dictionaryTag, 'en-US');
    expect([for (final i in spelling.deckIssues()) i.word], ['borwn', 'Teh']);
    expect(spelling.suggestionsFor('borwn'), contains('brown'));
  });
}
