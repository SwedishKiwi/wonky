import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../support/property.dart';

void main() {
  group('Given the built-in themes', () {
    for (final b in BuiltinThemes.all) {
      test('when parsing ${b.key} then it validates without errors', () {
        final r = const WriteThemeValidator().validate(b.json);

        expect(r.errors, isEmpty);
        expect(b.theme.name, isNotEmpty);
      });

      test(
        'when re-importing ${b.key} canonical JSON then it is byte-identical',
        () {
          final again = WriteThemeData.fromJsonString(b.theme.canonicalJson);

          expect(again.canonicalJson, b.theme.canonicalJson);
        },
      );

      for (final v in ThemeVariant.values) {
        test(
          'when checking ${b.key} ${v.name} then body and headings reach 4.5:1',
          () {
            final results = ContrastChecker().checkResolved(
              ThemeResolver.instance.resolve(b.theme, v),
            );
            final important = results.where(
              (r) =>
                  r.pairId == 'body' || RegExp(r'^h[1-6]$').hasMatch(r.pairId),
            );

            expect(
              important
                  .where((r) => r.ratio < 4.5)
                  .map((r) => '${r.pairId} ${r.ratio}'),
              isEmpty,
            );
          },
        );
      }
    }

    test('when looking up by key and UUID then the stable UUIDv5 matches', () {
      final d = BuiltinThemes.byKey('wonky-default')!;

      expect(BuiltinThemes.byUuid(d.uuid), same(d));
      expect(
        d.uuid,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-')),
      );
      expect(BuiltinThemes.all.map((t) => t.uuid).toSet().length, 8);
    });
  });

  group('Given the resolver', () {
    final theme = BuiltinThemes.wonkyDefault.theme;

    test('when resolving twice then the result is memoized', () {
      expect(
        identical(
          ThemeResolver.instance.resolve(theme, ThemeVariant.light),
          ThemeResolver.instance.resolve(theme, ThemeVariant.light),
        ),
        isTrue,
      );
    });

    test(
      'when resolving Wonky Default then body is 11pt Inter with 1.5 line height',
      () {
        final r = ThemeResolver.instance.resolve(theme, ThemeVariant.light);

        expect(
          (
            r.body.style.fontFamily,
            r.body.style.fontSize,
            r.body.style.lineHeight,
          ),
          ('Inter', 11, 1.5),
        );
        expect(r.headings.length, 6);
        expect(
          r.headings.first.style.fontSize,
          greaterThan(r.headings.last.style.fontSize),
        );
        expect(r.codeBlock.style.fontFamily, 'JetBrains Mono');
      },
    );

    test('when overriding an element then the cascade applies it', () {
      final json = jsonDecode(theme.canonicalJson) as Map<String, dynamic>;
      final patched = ThemeJsonPatch.merge(json, {
        'elements': {
          'h2': {'fontSize': '20pt', 'color': '@accent'},
          'body': {'fontSize': '12pt'},
        },
      });

      final r = ThemeResolver.instance.resolve(
        WriteThemeData.fromJson(patched),
        ThemeVariant.light,
      );

      expect(r.headings[1].style.fontSize, 20);
      expect(r.headings[1].style.color, r.palette[PaletteKey.accent]);
      expect(r.body.style.fontSize, 12);
    });

    test('when setting a property by path then get returns it', () {
      final json = jsonDecode(theme.canonicalJson) as Map<String, dynamic>;

      final set = ThemePropertyPath.set(json, 'elements.h2.fontSize', '18pt');

      expect(ThemePropertyPath.get(set, 'elements.h2.fontSize'), '18pt');
    });
  });

  group('Given theme JSON with problems', () {
    test('when a property is unknown then it is dropped with a warning', () {
      final json =
          jsonDecode(BuiltinThemes.wonkyDefault.theme.canonicalJson)
              as Map<String, dynamic>;
      json['elements'] = {
        'h1': {'fontSize': '20pt', 'sparkle': true},
      };

      final r = const WriteThemeValidator().validate(json);

      expect(r.errors, isEmpty);
      expect(r.warnings, isNotEmpty);
    });

    test('when a font size is out of bounds then validation fails', () {
      final json =
          jsonDecode(BuiltinThemes.wonkyDefault.theme.canonicalJson)
              as Map<String, dynamic>;
      json['elements'] = {
        'body': {'fontSize': '500pt'},
      };

      expect(const WriteThemeValidator().validate(json).errors, isNotEmpty);
    });
  });

  group('Given lengths and contrast references', () {
    final cases = <(String, double)>[
      ('11pt', 11),
      ('16px', 12),
      ('1in', 72),
      ('25.4mm', 72),
    ];
    for (final (text, pt) in cases) {
      test('when converting $text then it is $pt pt', () {
        expect(Length.parse(text).toPt(), closeTo(pt, 1e-9));
      });
    }

    test('when measuring #777777 on white then the WCAG ratio is 4.48', () {
      expect(
        ContrastChecker.ratio(0xff777777, 0xffffffff),
        closeTo(4.48, 0.01),
      );
    });
  });

  group('Given numbering', () {
    test('when numbering headings in outline style then labels nest', () {
      final labels = HeadingNumberer.labelsFor(
        const ResolvedHeadingNumbering(
          enabled: true,
          toLevel: 3,
          style: HeadingNumberingStyle.outline,
          suffix: ' ',
        ),
        [1, 2, 2, 3, 1, 2],
      );

      expect(labels, ['1 ', '1.1 ', '1.2 ', '1.2.1 ', '2 ', '2.1 ']);
    });

    final markers = <(int, ListNumberStyle, String)>[
      (1, ListNumberStyle.lowerAlpha, 'a'),
      (26, ListNumberStyle.lowerAlpha, 'z'),
      (27, ListNumberStyle.lowerAlpha, 'aa'),
      (4, ListNumberStyle.lowerRoman, 'iv'),
      (1999, ListNumberStyle.upperRoman, 'MCMXCIX'),
    ];
    for (final (n, style, expected) in markers) {
      test('when formatting $n as ${style.name} then it is $expected', () {
        expect(ListMarkers.ordinal(n, style), expected);
      });
    }
  });

  propertyTest(
    'Given random light palettes when deriving dark then body text keeps 4.5:1',
    (random, _) {
      String hex(int v) => '#${v.toRadixString(16).padLeft(6, '0')}';
      final json =
          jsonDecode(BuiltinThemes.wonkyDefault.theme.canonicalJson)
              as Map<String, dynamic>;
      final palette = Map<String, dynamic>.from(json['palette'] as Map);
      palette['text'] = hex(random.nextInt(0x555555));
      palette['heading'] = hex(random.nextInt(0x444444));
      palette['page'] = hex(0xd0d0d0 + random.nextInt(0x2f2f2f));
      palette['accent'] = hex(random.nextInt(0xffffff));
      json['palette'] = palette;
      json['dark'] = {'mode': 'derived'};

      final dark = ThemeResolver.instance.resolve(
        WriteThemeData.fromJson(json),
        ThemeVariant.dark,
      );

      expect(
        ContrastChecker.ratio(
          dark.body.style.color,
          dark.page.paperColor | 0xff000000,
        ),
        greaterThanOrEqualTo(4.5),
      );
    },
    runs: 50,
  );
}
