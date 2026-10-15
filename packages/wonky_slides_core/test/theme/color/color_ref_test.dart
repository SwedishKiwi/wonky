import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given ColorRef strings', () {
    final cases = <(String, String)>[
      ('#FFFFFF', '#FFFFFF'),
      ('#ff5a1f', '#FF5A1F'),
      ('#00000033', '#00000033'),
      ('transparent', 'transparent'),
      ('theme:accent1', 'theme:accent1'),
      ('theme:accent1/alpha:0.5', 'theme:accent1/alpha:0.5'),
      ('theme:text2/lum:+0.2', 'theme:text2/lum:+0.2'),
      ('theme:bg1/lum:-0.3/alpha:0.7', 'theme:bg1/lum:-0.3/alpha:0.7'),
      ('theme:custom12', 'theme:custom12'),
    ];
    for (final (input, expected) in cases) {
      test('when parsing "$input" then it formats as "$expected"', () {
        expect(ColorRef.parse(input).json, expected);
      });
    }

    final bad = [
      '#FFF',
      'red',
      'theme:accent7',
      'theme:custom13',
      'theme:accent1/alpha:2',
      'theme:accent1/lum:+3',
      'theme:accent1/foo:1',
    ];
    for (final input in bad) {
      test('when parsing "$input" then it is rejected', () {
        expect(() => ColorRef.parse(input), throwsA(isA<FormatException>()));
        expect(ColorRef.tryParse(input), isNull);
      });
    }
  });

  group('Given a theme color lookup', () {
    int? lookup(String key) => switch (key) {
      'accent1' => 0xff6366f1,
      'bg1' => 0xffffffff,
      _ => null,
    };

    test('when resolving a hex color then the theme is not consulted', () {
      expect(ColorRef.parse('#11223380').resolve((_) => null), 0x80112233);
    });

    test('when resolving theme:accent1/alpha:0.5 then alpha is halved', () {
      expect(
        ColorRef.parse('theme:accent1/alpha:0.5').resolve(lookup),
        0x806366f1,
      );
    });

    test('when lightening by 1 then the color becomes white', () {
      expect(
        ColorRef.parse('theme:accent1/lum:+1').resolve(lookup),
        0xffffffff,
      );
    });

    test('when darkening by 1 then the color becomes black', () {
      expect(
        ColorRef.parse('theme:accent1/lum:-1').resolve(lookup),
        0xff000000,
      );
    });

    test('when lightening by 0.3 then the OKLCH lightness rises', () {
      final base = Oklch.fromArgb(0xff6366f1);
      final light = Oklch.fromArgb(
        ColorRef.parse('theme:accent1/lum:+0.3').resolve(lookup)!,
      );
      expect(light.l, greaterThan(base.l));
      expect(light.h, closeTo(base.h, 2));
    });

    test('when the key is missing then resolve returns null', () {
      expect(ColorRef.parse('theme:custom1').resolve(lookup), isNull);
    });
  });
}
