import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/canvas/canvas_controller.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../../harness/deck_harness.dart';

void main() {
  late DeckHarness d;
  late CanvasController v;

  setUp(() {
    d = DeckHarness.open();
    v = CanvasController(d.editor)
      ..layout(const Size(1000, 600), const Size(1920, 1080));
  });
  tearDown(() async {
    v.dispose();
    await d.dispose();
  });

  group('Given a 1000 × 600 viewport at Fit', () {
    test('when mapping points then the slide is centered with a 48 px '
        'margin', () {
      expect(v.scale, closeTo(504 / 1080, 1e-9));
      expect(
        v.toSlide(v.toViewport(const Offset(960, 540))),
        const Offset(960, 540),
      );
      expect(v.toViewport(const Offset(960, 540)), const Offset(500, 300));
    });

    test('when panning then nothing moves (Fit disables panning)', () {
      expect(v.panBy(const Offset(50, 0)), isFalse);
      expect(v.scrollable, isFalse);
    });
  });

  group('Given a zoom around a focal point', () {
    test('when zooming to 200 % then the slide point under the pointer '
        'stays put', () {
      const focal = Offset(300, 200);
      final before = v.toSlide(focal);

      v.zoomAt(2, focal);

      expect(d.editor.zoomFit, isFalse);
      expect(v.scale, 2);
      final after = v.toSlide(focal);
      expect(after.dx, closeTo(before.dx, 1e-6));
      expect(after.dy, closeTo(before.dy, 1e-6));
      expect(v.scrollable, isTrue);
      expect(v.thumb(Axis.horizontal), isNotNull);
    });

    test('when panning far beyond the pasteboard then the pan is clamped', () {
      v.zoomAt(2, const Offset(500, 300));

      v.panBy(const Offset(1e6, 0));

      // The pasteboard's left edge (one slide width left of the slide)
      // reaches at most the margin.
      expect(v.toViewport(const Offset(-1920, 0)).dx, closeTo(48, 1e-6));
    });
  });

  group('Given zoom to a rectangle', () {
    test(
      'when zooming to a rectangle then it fills the viewport, centered',
      () {
        v.zoomToRect(const SuRect(100, 100, 904, 504));

        expect(v.scale, closeTo(1, 1e-9));
        expect(v.toViewport(const Offset(552, 352)), const Offset(500, 300));
      },
    );
  });
}
