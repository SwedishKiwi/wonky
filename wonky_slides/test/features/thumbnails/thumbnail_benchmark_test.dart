@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/stage/slide_stage.dart';

import '../stage/stage_fixture.dart';

/// 03 §18: a navigator thumbnail (240 px wide) records in ≤ 8 ms. Measured
/// on recording only (rasterizing happens on the raster thread). Run with
/// `flutter test -t slow`.
void main() {
  testWidgets('when recording thumbnails of a busy slide then each takes at '
      'most 8 ms on average', (tester) async {
    final f = StageFixture();
    for (var i = 0; i < 12; i++) {
      f.shape(x: 40.0 * i, y: 30.0 * i, text: 'Shape $i with some text');
    }
    f.text(
      'A text box with a longer paragraph that wraps over a few lines '
      'to exercise the text layout engine.',
    );
    f.table();
    f.line();
    f.code();
    final r = f.renderer();
    addTearDown(r.dispose);
    final scene = r.scene(f.slideId)!;
    // Warm up (text layout caches, shaders).
    recordScene(scene, scale: 240 / 1920).dispose();

    const runs = 20;
    final sw = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      recordScene(scene, scale: 240 / 1920).dispose();
    }
    sw.stop();

    expect(sw.elapsedMicroseconds / runs, lessThan(8000));
  });
}
