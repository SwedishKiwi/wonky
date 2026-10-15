import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/themes/theme_previews.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/themes.dart';

import '../../harness/deck_harness.dart';

/// Theme and layout previews (05 §9): in-memory preview decks that never
/// write to the open deck.
void main() {
  late DeckHarness d;

  setUp(() => d = DeckHarness.open());
  tearDown(() => d.dispose());

  String dump() => jsonEncode(d.model.dump(), toEncodable: (v) => '$v');

  test('Given a built-in theme when its preview is built then the card shows '
      'its name on the title layout at the deck size', () {
    final p = ThemePreviewDeck.builtIn(
      'midnight',
      const SlideSize(SlideSizeKind.standard4x3, 1440, 1080),
      subtitle: 'Sub',
    );
    final m = p.renderer.model;
    expect(m.deck!.width, 1440);
    final card = p.cardSlideId!;
    final texts = [
      for (final e in m.elementsOf(card)) SlidesText.plainText(e.text).trim(),
    ];
    expect(texts, containsAll(['Midnight', 'Sub']));
    p.dispose();
  });

  test('Given the open deck when its theme previews are built then every '
      'layout has a preview slide with the prompts and the deck is '
      'untouched', () {
    final before = dump();
    final previews = ThemePreviews.of(d.editor);
    final themeId = d.model.deck!.themeId!;
    final p = previews.deckTheme(themeId)!;
    final layouts = d.model.indexes.themes.layoutsOfTheme(themeId);

    expect(p.layoutSlides.keys, containsAll([for (final l in layouts) l.id]));
    final pm = p.renderer.model;
    final titleBody = layouts.firstWhere((l) => l.key == 'titleBody');
    final slide = p.layoutSlides[titleBody.id]!;
    final texts = [
      for (final e in pm.elementsOf(slide)) SlidesText.plainText(e.text).trim(),
    ];
    expect(texts, contains('Click to add title'));
    expect(identical(previews.deckOfLayout(titleBody.id), p), isTrue);
    expect(dump(), before);
    previews.dispose();
  });

  test('Given cached previews when the deck size changes then they are '
      'rebuilt', () async {
    final previews = ThemePreviews.of(d.editor);
    final themeId = d.model.deck!.themeId!;
    final first = previews.deckTheme(themeId)!;
    d.registerOp(
      'test.size',
      (a) => SetDeckProps(
        size: DeckSizeChange(SlideSize.preset(SlideSizeKind.square)),
      ),
    );
    await d.run('test.size');
    final second = previews.deckTheme(themeId)!;
    expect(identical(first, second), isFalse);
    expect(second.renderer.model.deck!.width, 1080);
    previews.dispose();
  });
}
