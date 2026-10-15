import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given every built-in theme (05 §11.1)', () {
    for (final def in BuiltInThemes.all) {
      for (final appearance in SlideAppearance.values) {
        group('${def.name} ${appearance.name}', () {
          final results = ThemeContrast.check(
            def.themeData().colors,
            appearance,
          );
          for (final r in results) {
            test(
              'when checking ${r.pair.id} then it is at least ${r.pair.required}:1',
              () {
                expect(
                  r.ratio,
                  greaterThanOrEqualTo(r.pair.required),
                  reason: '$r',
                );
              },
            );
          }
        });
      }
    }
  });

  group('Given the required pairs', () {
    test('when listing them then they match the thresholds of 05 §11.1', () {
      expect(
        {for (final p in ThemeContrast.requiredPairs) p.id: p.required},
        {
          'text1/bg1': 7.0,
          'text2/bg1': 4.5,
          'accent1/bg1': 3.0,
          'link/bg1': 4.5,
        },
      );
    });
  });

  group('Given a scheme with a low-contrast link', () {
    final colors = BuiltInThemes.defaultTheme.themeData().colors;
    final broken = ThemeColors(
      light: ThemeColorScheme({...colors.light.colors, 'link': 0xff0891b2}),
      dark: colors.dark,
    );

    test('when listing failures then only the light link fails', () {
      final f = ThemeContrast.failures(broken);
      expect(f, hasLength(1));
      expect(f.single.pair.id, 'link/bg1');
      expect(f.single.appearance, SlideAppearance.light);
      expect(f.single.toJson()['ratio'], lessThan(4.5));
    });
  });

  group('Given translucent colors', () {
    test(
      'when the foreground is half transparent then it is composited first',
      () {
        final opaque = ThemeContrast.ratio(0xff000000, 0xffffffff);
        final half = ThemeContrast.ratio(0x80000000, 0xffffffff);
        expect(opaque, closeTo(21, 0.01));
        expect(half, lessThan(opaque));
      },
    );
  });
}
