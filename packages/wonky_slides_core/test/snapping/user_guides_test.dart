import 'package:test/test.dart';
import 'package:wonky_slides_core/snapping.dart';

void main() {
  group('Given user guides', () {
    const guides = [
      UserGuide(GuideAxis.vertical, 960),
      UserGuide(GuideAxis.horizontal, 540.5),
    ];

    test('when encoding and decoding then they round-trip', () {
      final json = UserGuides.encode(guides);

      expect(
        json,
        '{"v":1,"guides":[{"axis":"v","at":960},'
        '{"axis":"h","at":540.5}]}',
      );
      expect(UserGuides.decode(json), guides);
    });

    test('when there are none then the column is cleared', () {
      expect(UserGuides.encode(const []), isNull);
      expect(UserGuides.decode(null), isEmpty);
    });

    test('when the value is a bare list with bad entries then the valid '
        'ones are read', () {
      expect(
        UserGuides.decode('[{"axis":"v","at":10},{"axis":"x","at":3},{}]'),
        [const UserGuide(GuideAxis.vertical, 10)],
      );
      expect(UserGuides.decode('not json'), isEmpty);
    });
  });
}
