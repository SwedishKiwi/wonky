import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given every built-in theme', () {
    for (final def in BuiltInThemes.all) {
      group(def.name, () {
        final theme = def.themeData();

        test(
          'when encoding and decoding its columns then the theme is equal',
          () {
            final columns = theme.toColumns();
            final decoded = deckThemeFromColumns(columns);
            expect(decoded, theme);
            expect(decoded.toColumns(), columns);
          },
        );

        test(
          'when validating its columns then there are no errors or warnings',
          () {
            final r = const DeckThemeValidator().validateTheme(
              theme.toColumns(),
            );
            expect(r.errors, isEmpty);
            expect(r.warnings, isEmpty);
          },
        );

        test(
          'when round-tripping through toJson then every column is canonical',
          () {
            for (final c in DeckThemeColumn.values) {
              final json = theme.columnJson(c);
              final r = const DeckThemeValidator().validateColumn(c, json);
              expect(r.errors, isEmpty, reason: c.name);
              expect(jsonEquals(r.cleanedJson, json), isTrue, reason: c.name);
            }
          },
        );
      });
    }
  });

  group('Given the colorsJson example of 05 §2.2', () {
    final json = {
      'v': 1,
      'light': {
        'bg1': '#FFFFFF',
        'text1': '#0F172A',
        'bg2': '#F1F5F9',
        'text2': '#475569',
        'accent1': '#6366F1',
        'accent2': '#06B6D4',
        'accent3': '#10B981',
        'accent4': '#F59E0B',
        'accent5': '#EF4444',
        'accent6': '#A855F7',
        'link': '#4F46E5',
      },
      'dark': {
        'bg1': '#0B1020',
        'text1': '#F8FAFC',
        'bg2': '#161C2E',
        'text2': '#94A3B8',
        'accent1': '#818CF8',
        'accent2': '#22D3EE',
        'accent3': '#34D399',
        'accent4': '#FBBF24',
        'accent5': '#F87171',
        'accent6': '#C084FC',
        'link': '#A5B4FC',
      },
      'custom': [
        {'name': 'Brand orange', 'light': '#FF5A1F', 'dark': '#FF7A45'},
      ],
    };

    test('when parsing then custom1 resolves per appearance', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.colorsJson,
        json,
      );
      expect(r.errors, isEmpty);
      final colors = r.value as ThemeColors;
      expect(colors.colorOf('custom1', SlideAppearance.light), 0xffff5a1f);
      expect(colors.colorOf('custom1', SlideAppearance.dark), 0xffff7a45);
      expect(colors.colorOf('custom2', SlideAppearance.light), isNull);
    });

    test('when the dark scheme lacks a key then it is an error', () {
      final broken = jsonDecode(jsonEncode(json)) as Map<String, Object?>;
      (broken['dark'] as Map).remove('link');
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.colorsJson,
        broken,
      );
      expect(r.isValid, isFalse);
      expect(r.errors.single.path, 'colorsJson.dark.link');
      expect(r.errors.single.code, 'missing');
    });

    test('when a scheme uses a theme reference then it is an error', () {
      final broken = jsonDecode(jsonEncode(json)) as Map<String, Object?>;
      (broken['light'] as Map)['link'] = 'theme:accent1';
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.colorsJson,
        broken,
      );
      expect(r.errors.single.code, 'invalid_color');
    });

    test(
      'when an unknown key is present then it is dropped with a warning',
      () {
        final extra = {...json, 'gradients': <Object?>[]};
        final r = const DeckThemeValidator().validateColumn(
          DeckThemeColumn.colorsJson,
          extra,
        );
        expect(r.errors, isEmpty);
        expect(r.warnings.single.code, 'unknown_key');
        expect(r.cleanedJson!.containsKey('gradients'), isFalse);
      },
    );
  });

  group('Given a textStylesJson with only the body style', () {
    final json = {
      'v': 1,
      'styles': {
        'body': {'font': '@body', 'size': 36, 'color': 'theme:text1'},
      },
    };

    test(
      'when validating then the missing styles are filled with warnings',
      () {
        final r = const DeckThemeValidator().validateColumn(
          DeckThemeColumn.textStylesJson,
          json,
        );
        expect(r.errors, isEmpty);
        expect(r.warnings, hasLength(themeTextStyleKeys.length - 1));
        final styles = r.value as ThemeTextStyles;
        expect(styles.styles.keys, containsAll(themeTextStyleKeys));
        expect(styles['body'].size, 36);
        expect(styles['title'].size, 96);
        expect(styles.lists.bullets, hasLength(9));
      },
    );

    test('when a size is out of range then it is an error', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.textStylesJson,
        {
          'v': 1,
          'styles': {
            'body': {'size': 900},
          },
        },
      );
      expect(r.errors.single.path, 'textStylesJson.styles.body.size');
      expect(r.errors.single.code, 'out_of_range');
    });
  });

  group('Given a fontsJson with a family that is not bundled', () {
    final json = {
      'v': 1,
      'heading': {'family': 'Inter', 'weight': 700},
      'body': {'family': 'open sans', 'weight': 400},
      'mono': {'family': 'JetBrains Mono', 'weight': 400},
    };

    test('when validating then it warns and keeps the family', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.fontsJson,
        json,
      );
      expect(r.errors, isEmpty);
      expect(r.warnings.single.code, 'unknown_font');
      final fonts = r.value as ThemeFonts;
      expect(fonts.heading.family, 'Inter');
      expect(fonts.body.family, 'Open Sans', reason: 'canonical spelling');
    });
  });

  group('Given theme JSON with versions', () {
    test('when "v" is missing then it migrates to version 1', () {
      final out = DeckThemeMigrations.migrate(DeckThemeColumn.backgroundJson, {
        'fill': {'type': 'none'},
      });
      expect(out['v'], 1);
    });

    test('when "v" is newer than supported then validation fails', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.backgroundJson,
        {
          'v': 2,
          'fill': {'type': 'none'},
        },
      );
      expect(r.errors.single.code, 'unsupported_version');
    });

    test('when the column is not an object then it is a wrong type', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.fontsJson,
        <Object?>[],
      );
      expect(r.errors.single.code, 'wrong_type');
    });

    test('when the stored string is not JSON then it is invalid_json', () {
      final r = const DeckThemeValidator().validateColumnString(
        DeckThemeColumn.colorsJson,
        '{',
      );
      expect(r.errors.single.code, 'invalid_json');
    });

    test('when an optional column is null then it is valid and absent', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.chartStyleJson,
        null,
      );
      expect(r.isValid, isTrue);
      expect(r.value, isNull);
    });

    test('when a required column is null then it is an error', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.colorsJson,
        null,
      );
      expect(r.errors.single.code, 'missing');
    });
  });

  group('Given the 05 §2 example JSON of the object styles', () {
    test('when parsing the table style then the border strings parse', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.tableStyleJson,
        {
          'v': 1,
          'header': {
            'fill': 'theme:accent1',
            'text': {'color': 'theme:bg1', 'weight': 700},
          },
          'body': {
            'fill': 'theme:bg1',
            'text': {'style': 'body2'},
          },
          'bandFill': 'theme:bg2',
          'firstColumn': {
            'text': {'weight': 700},
          },
          'totalRow': {
            'fill': 'theme:bg2',
            'text': {'weight': 700},
            'borderTop': '3|solid|theme:text1',
          },
          'borders': {
            'outer': '0|none|theme:text2',
            'horizontal': '1|solid|theme:text2/alpha:0.3',
            'vertical': '0|none|theme:text2',
          },
          'cellPadding': [12, 16, 12, 16],
          'radius': 12,
        },
      );
      expect(r.errors, isEmpty);
      expect(r.warnings, isEmpty);
      final t = r.value as ThemeTableStyle;
      expect(t.horizontalBorder.isVisible, isTrue);
      expect(t.outerBorder.isVisible, isFalse);
      expect(t, defaultTableStyle);
    });

    test(
      'when parsing the code style then unknown palettes fall back with a warning',
      () {
        final r = const DeckThemeValidator().validateColumn(
          DeckThemeColumn.codeStyleJson,
          {
            'v': 1,
            'palettes': {'light': 'wonky-light', 'dark': 'no-such-palette'},
            'font': '@mono',
            'box': {'cornerRadius': 16, 'shadow': 'soft'},
            'chrome': 'window',
          },
        );
        expect(r.errors, isEmpty);
        expect(r.warnings.single.code, 'unknown_palette');
        expect((r.value as ThemeCodeStyle).darkPalette, 'wonky-dark');
      },
    );

    test(
      'when parsing the shape style with partial strokes then it is valid',
      () {
        final r = const DeckThemeValidator().validateColumn(
          DeckThemeColumn.shapeStyleJson,
          {
            'v': 1,
            'text': {
              'fill': {'type': 'none'},
              'stroke': {'type': 'none'},
              'textStyle': {
                'defaults': {'style': 'body'},
                'autofit': 'resize',
              },
            },
            'line': {
              'stroke': {
                'color': 'theme:text2',
                'width': 4,
                'endArrow': 'none',
              },
            },
            'quickStyles': [
              {
                'fill': {'type': 'solid', 'color': 'theme:accent1/alpha:0.15'},
                'textColor': 'theme:accent1',
              },
            ],
            'shadow': {'color': '#00000033', 'blur': 32, 'dx': 0, 'dy': 16},
          },
        );
        expect(r.errors, isEmpty);
        expect(r.warnings, isEmpty);
      },
    );

    test('when a gradient has one stop then it is an error', () {
      final r = const DeckThemeValidator().validateColumn(
        DeckThemeColumn.backgroundJson,
        {
          'v': 1,
          'fill': {
            'type': 'gradient',
            'stops': [
              {'at': 0, 'color': '#000000'},
            ],
          },
        },
      );
      expect(r.errors.single.code, 'too_few');
    });
  });

  group('Given the JSON schemas', () {
    test('when listing them then every column has an object schema', () {
      final all = DeckThemeSchemas.all;
      expect(all.keys, [for (final c in DeckThemeColumn.values) c.name]);
      for (final s in all.values) {
        expect(s['type'], 'object');
        expect(() => jsonEncode(s), returnsNormally);
      }
    });
  });
}
