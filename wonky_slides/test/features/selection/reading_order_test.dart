import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/selection/reading_order.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';

void main() {
  group('Given elements in two visual rows', () {
    late ResolvedSlide slide;
    late Map<String, String> ids;

    setUp(() {
      final b = DeckBuilder();
      final s = b.slide(layoutKey: 'blank');
      ids = {
        // Row 1 (centers within 10 % of 1080): right, then left.
        'r1b': b.shape(s, x: 900, y: 100, width: 200, height: 100),
        'r1a': b.shape(s, x: 100, y: 120, width: 200, height: 100),
        // Row 2.
        'r2': b.shape(s, x: 500, y: 600, width: 200, height: 100),
      };
      final model = b.build();
      slide = SlideResolver(model).resolve(s)!;
    });

    test('when ordering automatically then rows go top to bottom, left to '
        'right', () {
      final order = ReadingOrder.of(slide.elements, slideHeight: 1080);

      expect(order.map((e) => e.id), [ids['r1a'], ids['r1b'], ids['r2']]);
    });

    test('when the deck is right-to-left then rows read right to left', () {
      final order = ReadingOrder.of(
        slide.elements,
        slideHeight: 1080,
        rtl: true,
      );

      expect(order.map((e) => e.id), [ids['r1b'], ids['r1a'], ids['r2']]);
    });
  });
}
