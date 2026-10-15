import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';

import '../support/scene_fixture.dart';

void main() {
  group('Given a scene with overlapping elements', () {
    late SceneFixture f;
    late String back, front, ellipse, line;
    late SlideScene scene;
    setUp(() {
      f = SceneFixture();
      back = f.shape(x: 100, y: 100, w: 400, h: 300);
      front = f.shape(x: 300, y: 200, w: 400, h: 300);
      ellipse = f.shape(x: 1000, y: 100, w: 400, h: 400, geometry: 'ellipse');
      line = f.line(100, 900, 900, 900);
      scene = f.scene();
    });

    test('when hitting the overlap then the topmost element wins', () {
      expect(SceneHitTest.elementAt(scene, 350, 250), front);
      expect(SceneHitTest.elementAt(scene, 150, 150), back);
    });

    test('when hitting outside every element then nothing is hit', () {
      expect(SceneHitTest.elementAt(scene, 1800, 1000), isNull);
    });

    test('when hitting the corner of an ellipse frame then it misses (precise '
        'geometry)', () {
      expect(SceneHitTest.elementAt(scene, 1010, 110), isNull);
      expect(SceneHitTest.elementAt(scene, 1200, 300), ellipse);
    });

    test('when hitting near a line within the tolerance then it is hit', () {
      expect(SceneHitTest.elementAt(scene, 500, 905, tolerance: 4), line);
      expect(SceneHitTest.elementAt(scene, 500, 940, tolerance: 4), isNull);
    });

    test('when an element is skipped then the one below is hit', () {
      expect(
        SceneHitTest.elementAt(scene, 350, 250, skip: (id) => id == front),
        back,
      );
    });

    test('when an element is rotated then the hit follows its rotation', () {
      final g = SceneFixture();
      final r = g.element(
        ElementKind.shape,
        x: 0,
        y: 0,
        w: 400,
        h: 40,
        rotation: 90,
      );
      final s = g.scene();

      // Rotated about its center (200, 20): now a vertical bar at x 180–220.
      expect(SceneHitTest.elementAt(s, 200, 150), r);
      expect(SceneHitTest.elementAt(s, 350, 20), isNull);
    });
  });
}
