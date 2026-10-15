import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

void main() {
  group('Given a title placeholder moved and restyled on a slide', () {
    late MemoryDeck deck;
    late String title;
    late String box;

    setUp(() {
      final b = DeckBuilder();
      final s = b.slide(layoutKey: 'titleBody', title: 'Hi');
      box = b.textBox(s, 'Free');
      deck = MemoryDeck(
        model: b.build(),
        userId: b.userId,
        planner: const SlidesPlanner(),
      );
      title = SlideResolver(deck.model)
          .resolve(s)!
          .elements
          .firstWhere((e) => e.placeholderType == SlidePlaceholderType.title)
          .id;
      deck.execute(
        UpdateFrames([
          FrameUpdate(title, x: 10, y: 20, width: 300, height: 90),
        ]),
      );
      deck.execute(SetTextBoxStyle([title], {'anchor': 'bottom'}));
    });

    test('when it is reset to the layout then frame and style inherit again '
        'and the text stays', () {
      final plan = deck.execute(ResetPlaceholders([title]));
      final e = deck.model.element(title)!;

      expect(plan.label, 'Reset to layout');
      expect([
        e.x,
        e.y,
        e.width,
        e.height,
        e.textStyleJson,
      ], everyElement(isNull));
      expect(SlidesText.plainText(e.text), 'Hi\n');
    });

    test('when a regular text box is reset then the planner refuses', () {
      expect(
        () => deck.execute(ResetPlaceholders([box])),
        throwsA(isA<PlanException>()),
      );
    });
  });
}
