import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/selection/transform_session.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/snapping.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

void main() {
  const slide = SuRect(0, 0, 1920, 1080);
  final targets = SnapTargets(
    slide: slide,
    boxes: const [SnapBox('o', SuRect(700, 100, 400, 200))],
  );
  const a = ElementFrame(100, 100, 400, 200);

  group('Given a move session', () {
    test('when the pointer moves then every frame moves by the delta', () {
      final t = TransformSession.move(
        {'a': a, 'b': const ElementFrame(100, 400, 100, 100)},
        const Offset(300, 200),
        targets: targets,
        threshold: 6,
      );

      t.update(const Offset(350, 230), const TransformModifiers(mod: true));

      expect(t.delta, const Offset(50, 30));
      expect(t.liveFrames['b']!.y, 430);
      expect(t.changed, isTrue);
    });

    test('when moving near another element then the delta snaps', () {
      final t = TransformSession.move(
        {'a': a},
        const Offset(300, 200),
        targets: targets,
        threshold: 6,
      );

      // a.right 500 + 197 = 697 → b.left 700.
      t.update(const Offset(497, 250));

      expect(t.delta.dx, 200);
      expect(t.guides, isNotEmpty);
    });

    test('when Shift is held then the move is constrained to an axis', () {
      final t = TransformSession.move(
        {'a': a},
        const Offset(300, 200),
        targets: targets,
        threshold: 6,
        snapping: false,
      );

      t.update(const Offset(400, 215), const TransformModifiers(shift: true));

      expect(t.delta, const Offset(100, 0));
    });

    test('when Alt is held then the drop duplicates', () {
      final t = TransformSession.move(
        {'a': a},
        Offset.zero,
        targets: targets,
        threshold: 6,
      );

      t.update(const Offset(40, 40), const TransformModifiers(alt: true));

      expect(t.duplicate, isTrue);
    });

    test('when computing the preview matrix then it maps the start frame '
        'onto the live frame', () {
      const to = ElementFrame(200, 300, 800, 200, rotation: 90);

      final m = TransformSession.frameMatrix(a, to);

      final c = MatrixUtils.transformPoint(m, const Offset(300, 200));
      expect(c.dx, closeTo(600, 1e-9));
      expect(c.dy, closeTo(400, 1e-9));
      // The start's top-left corner lands on the rotated live corner.
      final tl = MatrixUtils.transformPoint(m, const Offset(100, 100));
      expect(tl.dx, closeTo(700, 1e-9));
      expect(tl.dy, closeTo(0, 1e-9));
    });
  });

  group('Given a resize session over two elements', () {
    test('when the box doubles then both frames scale inside it', () {
      final t = TransformSession.resize(
        {
          'a': const ElementFrame(0, 0, 100, 100),
          'b': const ElementFrame(100, 100, 100, 100),
        },
        const Offset(200, 200),
        ResizeHandle.bottomRight,
        targets: SnapTargets(slide: slide, objects: false),
        threshold: 6,
      );

      t.update(const Offset(400, 400));

      expect(t.liveFrames['b'], const ElementFrame(200, 200, 200, 200));
      expect(t.liveBox, const SuRect(0, 0, 400, 400));
    });

    test('when an image keeps its aspect by default then Shift frees it', () {
      final t = TransformSession.resize(
        {'i': a},
        const Offset(500, 300),
        ResizeHandle.bottomRight,
        targets: SnapTargets(slide: slide, objects: false),
        threshold: 6,
        keepAspect: true,
      );

      t.update(const Offset(900, 320));
      expect(t.liveFrames['i']!.width / t.liveFrames['i']!.height, 2);

      t.update(const Offset(900, 320), const TransformModifiers(shift: true));
      expect(t.liveFrames['i']!.height, 220);
    });
  });

  group('Given a rotate session', () {
    test('when two elements rotate then they orbit the selection center', () {
      final t = TransformSession.rotate({
        'a': const ElementFrame(0, 0, 100, 100),
        'b': const ElementFrame(200, 0, 100, 100),
      }, const Offset(150, -100));

      // From straight up to straight right: 90°.
      t.update(const Offset(400, 50));

      expect(t.angle, 90);
      final b = t.liveFrames['b']!;
      expect(b.cx, closeTo(150, 1e-6));
      expect(b.cy, closeTo(150, 1e-6));
      expect(b.rotation, 90);
    });

    test('when one element rotates near 0° then it snaps to 0°', () {
      final t = TransformSession.rotate({'a': a}, const Offset(300, 0));

      t.update(const Offset(310, 0));

      expect(t.liveFrames['a']!.rotation, 0);
      expect(t.changed, isFalse);
    });
  });
}
