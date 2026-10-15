import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/snapping.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

Matcher _frame(
  double x,
  double y,
  double w,
  double h, {
  double rotation = 0,
  bool flipH = false,
  bool flipV = false,
}) => isA<ElementFrame>()
    .having((f) => f.x, 'x', closeTo(x, 1e-4))
    .having((f) => f.y, 'y', closeTo(y, 1e-4))
    .having((f) => f.width, 'width', closeTo(w, 1e-4))
    .having((f) => f.height, 'height', closeTo(h, 1e-4))
    .having((f) => f.rotation, 'rotation', closeTo(rotation, 1e-4))
    .having((f) => f.flipH, 'flipH', flipH)
    .having((f) => f.flipV, 'flipV', flipV);

void main() {
  const f = ElementFrame(100, 100, 400, 200);

  group('Given an unrotated frame', () {
    test('when dragging the bottom-right handle then the top-left stays', () {
      final r = FrameTransforms.resize(f, ResizeHandle.bottomRight, 600, 400);

      expect(r, _frame(100, 100, 500, 300));
    });

    test('when dragging the left edge then only x and width change', () {
      final r = FrameTransforms.resize(f, ResizeHandle.left, 50, 999);

      expect(r, _frame(50, 100, 450, 200));
    });

    test('when dragging a corner with keep-aspect then the ratio stays', () {
      final r = FrameTransforms.resize(
        f,
        ResizeHandle.bottomRight,
        900,
        350,
        keepAspect: true,
      );

      expect(r, _frame(100, 100, 800, 400));
    });

    test('when dragging an edge with keep-aspect then the other side scales '
        'about the middle', () {
      final r = FrameTransforms.resize(
        f,
        ResizeHandle.right,
        900,
        0,
        keepAspect: true,
      );

      expect(r, _frame(100, 0, 800, 400));
    });

    test('when resizing from the center (Alt) then the center stays', () {
      final r = FrameTransforms.resize(
        f,
        ResizeHandle.right,
        550,
        200,
        fromCenter: true,
      );

      expect(r, _frame(50, 100, 500, 200));
    });

    test('when dragging past the anchor then the frame flips', () {
      final r = FrameTransforms.resize(f, ResizeHandle.right, 0, 200);

      expect(r, _frame(0, 100, 100, 200, flipH: true));
    });

    test('when collapsing then the minimum size applies (0 for lines)', () {
      expect(
        FrameTransforms.resize(f, ResizeHandle.bottom, 0, 100.2),
        _frame(100, 100, 400, 1),
      );
      expect(
        FrameTransforms.resize(f, ResizeHandle.bottom, 0, 100, minSize: 0),
        _frame(100, 100, 400, 0),
      );
    });
  });

  group('Given a frame rotated by 90°', () {
    const r90 = ElementFrame(100, 100, 400, 200, rotation: 90);

    test('when dragging its (visual) right handle down then the width grows '
        'in the rotated axis and the opposite edge stays', () {
      // Center (300, 200); local +x points down after rotating 90°.
      final (hx, hy) = FrameTransforms.handlePoint(r90, ResizeHandle.right);
      expect(hx, closeTo(300, 1e-9));
      expect(hy, closeTo(400, 1e-9));

      final r = FrameTransforms.resize(r90, ResizeHandle.right, 300, 500);

      // Width 500; the left edge (at y = 0) stays → center y = 250.
      expect(r, _frame(50, 150, 500, 200, rotation: 90));
    });
  });

  group('Given multi-selection scaling', () {
    test('when the box doubles then positions and sizes double', () {
      const box = SuRect(0, 0, 100, 100);
      final r = FrameTransforms.scaleInBox(
        const ElementFrame(50, 50, 50, 50),
        box,
        const ElementFrame(0, 0, 200, 200),
      );

      expect(r, _frame(100, 100, 100, 100));
    });
  });

  group('Given rotation about a center', () {
    test('when rotating 90° about the slide origin then the frame orbits and '
        'turns', () {
      final r = FrameTransforms.rotateAbout(
        const ElementFrame(100, -50, 200, 100),
        0,
        0,
        90,
      );

      // Center (200, 0) → (0, 200).
      expect(r, _frame(-100, 150, 200, 100, rotation: 90));
    });

    test('when measuring the handle angle then up is 0° and right is 90°', () {
      expect(FrameTransforms.angleOf(0, 0, 0, -10), closeTo(0, 1e-9));
      expect(FrameTransforms.angleOf(0, 0, 10, 0), closeTo(90, 1e-9));
    });
  });

  group('Given Shift-constrained moves', () {
    final cases = [
      ((100.0, 10.0), (100.0, 0.0)),
      ((10.0, 100.0), (0.0, 100.0)),
      ((100.0, 90.0), (95.0, 95.0)),
      ((-100.0, 90.0), (-95.0, 95.0)),
    ];
    for (final (input, expected) in cases) {
      test('when moving by $input then the delta is $expected', () {
        expect(FrameTransforms.constrain(input.$1, input.$2), expected);
      });
    }
  });

  group('Given an element group', () {
    final groups = [
      const ElementFrame(100, 100, 400, 200),
      const ElementFrame(50, 80, 800, 300),
      const ElementFrame(50, 80, 800, 400, rotation: 30),
      const ElementFrame(50, 80, 400, 200, rotation: 120, flipH: true),
      const ElementFrame(10, 20, 600, 300, flipV: true),
    ];
    const cb = SuRect(0, 0, 400, 200);
    const child = ElementFrame(40, 20, 100, 60, rotation: 15);

    for (final (i, g) in groups.indexed) {
      test('when mapping a child to the parent and back (group $i) then the '
          'child frame is unchanged', () {
        final up = GroupSpace.toParent(child, g, cb);

        final back = FrameTransforms.toChild(up, g, cb);

        expect(
          back,
          _frame(
            child.x,
            child.y,
            child.width,
            child.height,
            rotation: child.rotation,
          ),
        );
      });
    }

    test('when converting a slide delta into a scaled, rotated group then '
        'the child delta undoes the transform', () {
      const g = ElementFrame(0, 0, 800, 400, rotation: 90);

      final (dx, dy) = FrameTransforms.deltaToChild(0, 20, g, cb);

      expect(dx, closeTo(10, 1e-6));
      expect(dy, closeTo(0, 1e-6));
    });
  });
}
