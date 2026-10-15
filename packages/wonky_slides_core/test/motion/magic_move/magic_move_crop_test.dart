import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';

import '../../support/magic_move_fixture.dart';

void main() {
  group('Given the same image cropped differently on two slides', () {
    test('when halfway then the crop interpolates from the image insets '
        '(`dataJson.crop` {l, t, r, b}, 02 §6.4)', () {
      final f = MagicMoveFixture();
      f.element(
        f.a,
        ElementKind.image,
        key: 'img',
        data: {
          'src': 'wonky-file://photo',
          'crop': {'l': 0.2, 't': 0, 'r': 0, 'b': 0.4},
        },
      );
      final b = f.element(
        f.bSlide,
        ElementKind.image,
        key: 'img',
        data: {'src': 'wonky-file://photo'},
      );

      final crop = f.plan().frameAt(500).pairs[b]!.crop!;

      expect(crop['x'], closeTo(0.1, 1e-9));
      expect(crop['y'], closeTo(0, 1e-9));
      expect(crop['w'], closeTo(0.9, 1e-9));
      expect(crop['h'], closeTo(0.8, 1e-9));
    });
  });
}
