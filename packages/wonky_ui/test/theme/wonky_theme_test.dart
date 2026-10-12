import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_ui/wonky_ui.dart';

void main() {
  group('Given WonkyTheme', () {
    test('when requesting the same config twice then the identical cached '
        'instance is returned', () {
      final a = WonkyTheme.light(const WonkyThemeConfig(accent: 'blue'));
      final b = WonkyTheme.light(const WonkyThemeConfig(accent: 'blue'));
      expect(identical(a, b), isTrue);
    });

    test('when the accent differs then the primary color differs', () {
      final neutral = WonkyTheme.light();
      final blue = WonkyTheme.light(const WonkyThemeConfig(accent: 'blue'));
      expect(blue.colorScheme.primary, isNot(neutral.colorScheme.primary));
    });

    test('when compact density is chosen then the spacing step shrinks', () {
      final c = WonkyTheme.dark(const WonkyThemeConfig(density: WonkyDensity.compact));
      expect(c.spacing.step, lessThan(WonkyTheme.dark().spacing.step));
    });

    for (final b in Brightness.values) {
      test('when reading custom tokens in ${b.name} then all are defined', () {
        final scheme = WonkyTheme.of(b, const WonkyThemeConfig()).colorScheme;
        expect(scheme.custom.length, greaterThanOrEqualTo(32));
        expect(scheme.presenceColors.toSet(), hasLength(12));
        expect(scheme.canvas, isNotNull);
        expect(scheme.page, b == Brightness.light ? const Color(0xffffffff) : const Color(0xff1e1e1e));
      });

      test('when checking contrast in ${b.name} then status tokens are readable '
          'on the background', () {
        final s = WonkyTheme.of(b, const WonkyThemeConfig()).colorScheme;
        for (final c in [s.success, s.warning, s.info, s.destructive, s.mutedForeground]) {
          expect(_contrast(c, s.background), greaterThanOrEqualTo(4.5), reason: '$c');
        }
        expect(_contrast(s.offlineForeground, s.offline), greaterThanOrEqualTo(4.5));
      });
    }
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

