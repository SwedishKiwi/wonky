import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/motion/motion_stage.dart';
import 'package:wonky_slides/features/motion/player/slide_player.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/stage/slide_stage.dart';
import 'package:wonky_slides_core/motion.dart';

import '../stage/stage_fixture.dart';
import 'motion_fixture.dart';

void main() {
  testWidgets('Given a preview playback when a step plays then the stage '
      'ticks until it settles and shows the timeline frames', (tester) async {
    final d = MotionDeck();
    final m = d.model();
    final timelines = <String, SlideTimeline>{};
    var now = 0;
    final playback = SlidePlayback(
      now: () => now,
      player: SlidePlayer(
        timelineOf: (id) => timelines[id] ??= SlideTimelineCompiler.compile(
          SlideMotionInput.fromDeck(m, id),
        ),
        planOf: (r) => TransitionCompiler.between(
          m,
          fromSlideId: r.fromSlideId,
          toSlideId: r.toSlideId,
          fromFrame: r.fromFrame,
          toFrame: r.toFrame,
        ),
      ),
    );
    addTearDown(playback.dispose);
    final r = SlideRenderer(model: m, fonts: RecordingFontRegistry());
    addTearDown(r.dispose);
    playback.player.show(d.a, 0, now: now);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 640,
          height: 360,
          child: SlidePlaybackStage(playback: playback, renderer: r),
        ),
      ),
    );

    playback.player.playStep(1, now: now);
    playback.changed();
    now += 250;
    await tester.pump(const Duration(milliseconds: 16));

    expect(playback.animating, isTrue);
    final stage = tester.widget<SlideStage>(find.byType(SlideStage));
    expect(stage.frame.stateOf(d.aShape).opacity, closeTo(0.5, 1e-9));
    now += 1000;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(playback.animating, isFalse);
    expect(
      tester
          .widget<SlideStage>(find.byType(SlideStage))
          .frame
          .stateOf(d.aShape)
          .opacity,
      1,
    );
  });
}
