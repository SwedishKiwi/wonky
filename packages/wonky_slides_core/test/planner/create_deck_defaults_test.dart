import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart';

MemoryDeck _empty() => MemoryDeck(
  model: DeckModel(deckId: testDeckId),
  userId: testUserId,
  planner: const SlidesPlanner(),
  ids: SequentialIdGenerator(1),
);

void main() {
  group('Given the user\'s default transition (SL-30, 06 A-06-7)', () {
    test('when a deck is created with it then its slides inherit it', () {
      final d = _empty();
      d.execute(
        CreateDeck(
          deckId: testDeckId,
          title: 'Pitch',
          defaultsJson: DeckMotionDefaults.withTransition(
            null,
            TransitionSpec.of('push'),
          ),
        ),
      );
      final m = d.model;
      final slide = m.slides.single;
      expect(slide.transitionJson, isNull);
      expect(
        TransitionSpec.effective(
          slide.transitionJson,
          m.deck!.defaultsJson,
        ).type,
        'push',
      );
    });

    test('when the default transition is invalid then creating is refused', () {
      expect(
        () => _empty().execute(
          const CreateDeck(
            deckId: testDeckId,
            title: 'Pitch',
            defaultsJson: '{"transition": {"durationMs": "slow"}}',
          ),
        ),
        throwsA(isA<PlanException>()),
      );
    });
  });
}
