import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

/// *Derive dark colors* (Slides 05 §2.2, §8.4; SL-28).
void main() {
  group('Given the light scheme of every built-in theme', () {
    for (final def in BuiltInThemes.all) {
      test('when deriving the dark scheme of ${def.key} then it is dark and '
          'passes the 05 §11 contrast pairs', () {
        final light = BuiltInThemes.package(def.key)!.theme.colors;

        final colors = const ThemeDarkDeriver().deriveColors(light);

        expect(colors.light, light.light);
        expect(
          relativeLuminance(colors.dark.bg1),
          lessThan(relativeLuminance(light.light.bg1)),
        );
        expect(
          ThemeContrast.check(
            colors,
            SlideAppearance.dark,
          ).where((r) => !r.passes).map((r) => r.toString()),
          isEmpty,
        );
      });
    }
  });

  group('Given a white background and a translucent accent', () {
    test('when transformed then alpha is kept', () {
      final out = const ThemeDarkDeriver().transform(
        0x806366F1,
        ThemeColorRole.accent,
      );

      expect(out >>> 24, 0x80);
    });

    test('when a custom color is derived then it reaches 3:1 on the dark '
        'background', () {
      const d = ThemeDarkDeriver();
      final c = d.deriveCustom(0xff1e3a8a, 0xff0b1020);

      expect(contrastRatio(c, 0xff0b1020), greaterThanOrEqualTo(3));
    });
  });
}
