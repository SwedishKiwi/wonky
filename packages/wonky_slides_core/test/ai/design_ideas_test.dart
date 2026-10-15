import 'package:test/test.dart';
import 'package:wonky_slides_core/ai.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart' show SlidesPlanContext;
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/testing.dart';

/// *Design ideas* candidates (Slides 11 §6.6, §10 AC 8: ≥ 4 candidates for
/// title + bullets, title + image and big-number slides; deterministic).
void main() {
  group('DesignIdeasEngine', () {
    List<String?> keys(List<DesignIdea> ideas) => [
      for (final i in ideas) i.layoutKey,
    ];

    test('when a slide has a title and bullets then at least four layouts '
        'are offered, list layouts first, never its own layout', () {
      final b = DeckBuilder();
      final s = b.slide(
        title: 'Plan',
        body: 'Hire\nShip\nGrow\nRepeat\nRest\nCelebrate',
      );
      final ideas = DesignIdeasEngine.candidates(b.build(), s);
      expect(ideas.length, greaterThanOrEqualTo(4));
      expect(keys(ideas), isNot(contains('titleBody')));
      expect(keys(ideas).first, 'twoColumns');
      expect(keys(ideas), isNot(contains('blank')));
      expect(keys(ideas), isNot(contains('code')));
      // Deterministic: the same order every time.
      expect(
        keys(DesignIdeasEngine.candidates(b.build(), s)),
        keys(ideas),
      );
    });

    test('when a slide holds one number then the big-number layout comes '
        'first', () {
      final b = DeckBuilder();
      final s = b.slide(title: 'Users', body: '4,200');
      final ideas = DesignIdeasEngine.candidates(b.build(), s);
      expect(ideas.length, greaterThanOrEqualTo(4));
      expect(ideas.first.layoutKey, 'bigNumber');
    });

    test('when a slide has an image then image layouts lead', () {
      final b = DeckBuilder();
      final s = b.slide(title: 'Team', body: 'Our people');
      b.element(s, ElementKind.image);
      final ideas = DesignIdeasEngine.candidates(b.build(), s);
      expect(ideas.length, greaterThanOrEqualTo(4));
      expect(keys(ideas).take(2), containsAll(['imageLeft', 'imageRight']));
    });

    test('when an idea is applied then the slide gets its layout and keeps '
        'its title', () {
      final b = DeckBuilder();
      final s = b.slide(title: 'Users', body: '4,200');
      final m = b.build();
      final idea = DesignIdeasEngine.candidates(m, s).first;
      final plan = const SlidesPlanner().plan(
        idea.op,
        m,
        SlidesPlanContext(userId: testUserId, now: testNow),
      );
      m.applyPlan(plan);
      expect(m.slide(s)!.layoutId, idea.layoutId);
      expect(idea.rankLine, startsWith('${idea.id}: Big number'));
    });

    test('when the slide is empty then there are no ideas', () {
      final b = DeckBuilder();
      final s = b.slide(layoutKey: 'blank');
      expect(DesignIdeasEngine.candidates(b.build(), s), isEmpty);
    });
  });
}
