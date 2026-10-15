import 'package:test/test.dart';
import 'package:wonky_fonts/wonky_fonts.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given the bundled fonts', () {
    test('when listing Slides families then they are the bundled families', () {
      expect(SlidesFonts.families, BundledFonts.families);
      expect(
        SlidesFonts.families,
        containsAll([
          'Merriweather',
          'Montserrat',
          'Nunito',
          'Source Sans 3',
          'JetBrains Mono',
        ]),
      );
    });

    final cases = <(String, int, bool, String, int, bool)>[
      ('Montserrat', 700, false, 'Montserrat', 700, false),
      ('montserrat', 600, false, 'Montserrat', 700, false),
      ('Open Sans', 500, false, 'Open Sans', 600, false),
      ('Open Sans', 300, false, 'Open Sans', 400, false),
      ('Merriweather', 400, true, 'Merriweather', 400, true),
      ('Roboto Mono', 400, true, 'Roboto Mono', 400, false),
      ('Source Sans 3', 900, false, 'Source Sans 3', 700, false),
    ];
    for (final (family, weight, italic, outFamily, outWeight, outItalic)
        in cases) {
      test(
        'when resolving $family $weight${italic ? ' italic' : ''} then $outFamily $outWeight is drawn',
        () {
          final f = SlidesFonts.resolve(family, weight: weight, italic: italic);
          expect(f.family, outFamily);
          expect(f.weight, outWeight);
          expect(f.italic, outItalic);
          expect(f.isFallback, isFalse);
          expect(f.face.assetKey, startsWith('packages/wonky_fonts/fonts/'));
        },
      );
    }

    final fallbacks = <(String, String)>[
      ('Inter', 'Open Sans'),
      ('Source Serif 4', 'Merriweather'),
      ('IBM Plex Mono', 'JetBrains Mono'),
      ('Totally Unknown', 'Open Sans'),
    ];
    for (final (family, expected) in fallbacks) {
      test(
        'when resolving the unbundled $family then $expected is used as a fallback',
        () {
          final f = SlidesFonts.resolve(family);
          expect(f.family, expected);
          expect(f.isFallback, isTrue);
        },
      );
    }

    test(
      'when the role is mono and the family is unknown then the mono fallback is used',
      () {
        final f = SlidesFonts.resolve(
          'Nope',
          defaultCategory: FontCategory.mono,
        );
        expect(f.family, BundledFonts.jetBrainsMono);
      },
    );
  });

  group('Given every built-in theme', () {
    for (final def in BuiltInThemes.all) {
      test(
        'when checking ${def.name} fonts then all three roles are bundled',
        () {
          final fonts = def.themeData().fonts;
          for (final role in ThemeFontRole.values) {
            expect(
              SlidesFonts.isAvailable(fonts.of(role).family),
              isTrue,
              reason: '$role',
            );
          }
          expect(SlidesFonts.categoryOf(fonts.mono.family), FontCategory.mono);
        },
      );
    }
  });
}
