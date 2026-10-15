import 'package:test/test.dart';
import 'package:wonky_fonts/wonky_fonts.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given the Wonky theme', () {
    final theme = BuiltInThemes.defaultTheme.themeData();
    final resolver = DeckThemeResolver();

    test('when resolving light then theme refs use the light scheme', () {
      final r = resolver.resolve(theme, SlideAppearance.light);
      expect(r.colorOf('bg1'), 0xffffffff);
      expect(r.color(const ThemeColor('accent1')), 0xff6366f1);
      expect(r.textStyle('title').color, 0xff0f172a);
      expect(r.warnings, isEmpty);
    });

    test('when switching to dark then the same refs use the dark scheme', () {
      final r = resolver.resolve(theme, SlideAppearance.dark);
      expect(r.colorOf('bg1'), 0xff0b1020);
      expect(r.textStyle('title').color, 0xfff8fafc);
      expect(
        r.color(const HexColor(0xff123456)),
        0xff123456,
        reason: 'explicit colors stay',
      );
    });

    test('when resolving twice then the cached instance is returned', () {
      final a = resolver.resolve(theme, SlideAppearance.light);
      final b = resolver.resolve(
        theme.copyWith(name: 'Renamed'),
        SlideAppearance.light,
      );
      expect(
        identical(a, b),
        isTrue,
        reason: 'the name is not part of the content hash',
      );
    });

    test('when the content changes then the hash and the result change', () {
      final changed = theme.copyWith(
        textStyles: theme.textStyles.withStyle(
          'title',
          const ThemeTextStyle(size: 50),
        ),
      );
      expect(changed.contentHash, isNot(theme.contentHash));
      expect(
        resolver
            .resolve(changed, SlideAppearance.light)
            .textStyle('title')
            .size,
        50,
      );
    });

    test(
      'when resolving text styles then fonts come from the roles and weights snap',
      () {
        final r = resolver.resolve(theme, SlideAppearance.light);
        final title = r.textStyle('title');
        expect(title.font.family, BundledFonts.openSans);
        expect(title.font.weight, 700);
        final quote = r.textStyle('quote');
        expect(quote.font.requestedWeight, 500);
        expect(quote.font.weight, 600, reason: 'ties snap heavier (05 §3.3)');
        final big = r.textStyle('bigNumber');
        expect(
          big.font.weight,
          700,
          reason: '800 snaps to the heaviest shipped face',
        );
        expect(big.color, 0xff6366f1);
      },
    );

    test('when resolving the code palettes then the Wonky pair is used', () {
      final light = resolver.resolve(theme, SlideAppearance.light);
      final dark = resolver.resolve(theme, SlideAppearance.dark);
      expect(light.codePalette.id, 'wonky-light');
      expect(dark.codePalette.id, 'wonky-dark');
    });

    test(
      'when an auto code block sits on a dark background then it uses the dark palette',
      () {
        final r = resolver.resolve(theme, SlideAppearance.light);
        expect(r.codePaletteForBackground(0xff0b1020).id, 'wonky-dark');
        expect(r.codePaletteForBackground(0xfff1f5f9).id, 'wonky-light');
      },
    );

    test('when resolving the chart palette then it lists the six accents', () {
      final r = resolver.resolve(theme, SlideAppearance.light);
      expect(r.chartPalette.first, 0xff6366f1);
      expect(r.chartPalette, hasLength(6));
    });

    test('when resolving the background then it is a solid bg1', () {
      final r = resolver.resolve(theme, SlideAppearance.dark);
      final fill = r.themeBackground.fill;
      expect(
        fill,
        isA<ResolvedSolidFill>().having((f) => f.color, 'color', 0xff0b1020),
      );
    });
  });

  group('Given the Aurora theme with explicit dark background fills', () {
    final theme = BuiltInThemes.byKey('aurora')!.themeData();

    test('when resolving dark then fillDark is used', () {
      final r = DeckThemeResolver.resolveUncached(theme, SlideAppearance.dark);
      final fill = r.themeBackground.fill as ResolvedGradientFill;
      expect(fill.stops.first.$2, 0xff120f33);
      expect(isDarkColor(r.themeBackground.effectiveColor(0xff000000)), isTrue);
    });

    test('when resolving light then the light gradient is used', () {
      final r = DeckThemeResolver.resolveUncached(theme, SlideAppearance.light);
      final fill = r.themeBackground.fill as ResolvedGradientFill;
      expect(fill.stops.first.$2, 0xfff5f3ff);
      expect(
        r
            .codePaletteForBackground(
              r.themeBackground.effectiveColor(0xffffffff),
            )
            .id,
        'wonky-light',
      );
    });
  });

  group('Given a theme with an unknown font and a missing custom color', () {
    final base = BuiltInThemes.defaultTheme.themeData();
    final theme = base.copyWith(
      fonts: base.fonts.withRole(
        ThemeFontRole.heading,
        const ThemeFont('Inter', 700),
      ),
      textStyles: base.textStyles.withStyle(
        'caption',
        const ThemeTextStyle(
          font: FontRef('Playfair Display'),
          color: ThemeColor('custom3'),
        ),
      ),
    );

    test(
      'when resolving then the fonts fall back by category with warnings',
      () {
        final r = DeckThemeResolver.resolveUncached(
          theme,
          SlideAppearance.light,
        );
        expect(r.fonts[ThemeFontRole.heading]!.family, BundledFonts.openSans);
        expect(r.fonts[ThemeFontRole.heading]!.isFallback, isTrue);
        expect(
          r.textStyle('caption').font.family,
          BundledFonts.merriweather,
          reason: 'serif fallback',
        );
        expect(
          r.warnings.map((w) => w.code),
          containsAll(['unknown_font', 'unknown_color']),
        );
        expect(r.textStyle('caption').color, r.colorOf('text1'));
      },
    );
  });

  group('Given modifiers on theme colors', () {
    final r = DeckThemeResolver.resolveUncached(
      BuiltInThemes.defaultTheme.themeData(),
      SlideAppearance.light,
    );

    test('when resolving alpha then the alpha channel is scaled', () {
      expect(r.colorString('theme:accent1/alpha:0.15') >>> 24, 38);
    });

    test('when resolving a fill then gradient stops resolve', () {
      final f =
          r.fill(
                const GradientFill(
                  stops: [
                    GradientStop(0, ThemeColor('accent1')),
                    GradientStop(1, ThemeColor('accent6')),
                  ],
                ),
              )
              as ResolvedGradientFill;
      expect(f.stops.map((s) => s.$2), [0xff6366f1, 0xffa855f7]);
    });
  });
}
