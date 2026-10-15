import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/selection/transform_session.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../harness/deck_harness.dart';
import '../stage/stage_fixture.dart' show RecordingFontRegistry;
import 'canvas_rig.dart' show solid;

/// Drag budgets of 03 §18: dragging 50 selected elements must leave the
/// frame to painting (the live preview is transforms only, no relayout,
/// no writes), and snapping against 500 elements stays under 2 ms.
void main() {
  test('Given 50 selected shapes among 500 when dragging then a pointer '
      'move (snap + preview frame) takes well under a frame', () {
    final b = DeckBuilder();
    final s = b.slide(layoutKey: 'blank');
    final ids = [
      for (var i = 0; i < 500; i++)
        b.shape(
          s,
          x: (i * 37) % 1800,
          y: (i * 53) % 1000,
          width: 40 + i % 60,
          height: 30 + i % 40,
          fillJson: solid('#3366FF'),
        ),
    ];
    final d = DeckHarness.open(fixture: b);
    addTearDown(d.dispose);
    d.editor.setCurrentSlide(s);
    final renderer = SlideRenderer(
      model: d.model,
      fonts: RecordingFontRegistry(),
    );
    final c = SlideCanvasController.attach(d.editor, renderer: renderer);
    addTearDown(() {
      c.dispose();
      renderer.dispose();
    });
    c.viewport.layout(const Size(1400, 900), const Size(1920, 1080));
    c.selection.select(ids.take(50));
    final frames = c.selectionFrames();
    expect(frames, hasLength(50));
    final t = TransformSession.move(
      frames,
      const Offset(500, 500),
      targets: c.snapTargets(frames.keys.toSet(), objects: true, guides: true),
      threshold: 6,
    );
    c.transform = t;

    final sw = Stopwatch()..start();
    const moves = 120;
    for (var i = 0; i < moves; i++) {
      t.update(Offset(500.0 + i * 3, 500.0 + i * 2));
      c.previewFrame();
    }
    sw.stop();

    expect(c.previewFrame().elements, hasLength(50));
    expect(sw.elapsedMicroseconds / moves, lessThan(4000));
  });
}
