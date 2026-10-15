import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  test('every built-in palette is listed with its own id', () {
    expect(BuiltInPalettes.all.map((p) => p.id), BuiltInPalettes.json.keys);
  });

  for (final palette in BuiltInPalettes.all) {
    group('Given the ${palette.id} palette', () {
      final minimum = palette.id.startsWith('high-contrast') ? 7.0 : 4.5;

      test('when checking its tokens then every token has a style', () {
        expect(palette.tokens.keys.toSet(), SyntaxToken.values.toSet());
      });

      test('when checking contrast then text and every token reach '
          '$minimum:1', () {
        final failing = {
          for (final MapEntry(:key, :value) in palette.tokens.entries)
            if (SyntaxPalette.contrastRatio(value.color, palette.background) <
                minimum)
              key.name: SyntaxPalette.contrastRatio(
                value.color,
                palette.background,
              ),
          if (SyntaxPalette.contrastRatio(palette.text, palette.background) <
              minimum)
            'text': SyntaxPalette.contrastRatio(
              palette.text,
              palette.background,
            ),
        };

        expect(failing, isEmpty);
      });

      test('when checking line numbers then they reach 3:1', () {
        expect(
          SyntaxPalette.contrastRatio(palette.lineNumber, palette.background),
          greaterThanOrEqualTo(3),
        );
      });

      test('when checking brightness then it matches the background', () {
        final dark = SyntaxPalette.relativeLuminance(palette.background) < 0.2;

        expect(
          palette.brightness,
          dark ? PaletteBrightness.dark : PaletteBrightness.light,
        );
      });
    });
  }

  test('when picking the default palettes then they are Wonky Light/Dark', () {
    expect(
      BuiltInPalettes.forBrightness(PaletteBrightness.light).id,
      'wonky-light',
    );
    expect(
      BuiltInPalettes.forBrightness(PaletteBrightness.dark).id,
      'wonky-dark',
    );
  });
}
