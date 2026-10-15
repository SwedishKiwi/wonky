import 'package:test/test.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/testing.dart';

void main() {
  group('Given a slide with a build (M9 stub compiler)', () {
    test('when compiling then the timeline has zero clicks and every frame '
        'is the edit frame', () {
      final b = DeckBuilder();
      final slide = b.slide(layoutKey: 'blank');
      b.build_(slide, b.shape(slide));
      final model = b.build();

      final t = SlideTimelineCompiler.compile(
        SlideMotionInput(
          slide: model.slide(slide)!,
          builds: model.buildsOf(slide),
        ),
      );

      expect(t.slideId, slide);
      expect(t.stepCount, 0);
      expect(t.printFrame, same(SlideFrame.edit));
      expect(t.frameAt(const TimelinePosition(0, 120)), same(SlideFrame.edit));
      expect(t.finalFrame.stateOf('any').opacity, 1);
      expect(t.describe(), {'clicks': 0, 'durationMs': 0});
      expect(
        TransitionCompiler.compile(from: t.finalFrame, to: t.initial),
        same(TransitionPlan.cut),
      );
    });
  });
}
