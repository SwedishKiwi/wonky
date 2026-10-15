import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

void main() {
  const accents = [
    0xFF112233,
    0xFF445566,
    0xFF778899,
    0xFFAABBCC,
    0xFFDDEEFF,
    0xFF000000,
  ];
  const source = ChartThemeColors(
    accentArgbs: accents,
    textFont: 'Lato',
    colors: {'text': 0xFF101010},
  );

  group('Given a plain chart theme source (Slides 08 §2.6)', () {
    test('when resolving colors then hex, short hex and theme keys work', () {
      expect(source.resolveArgb('#AbCdEf'), 0xFFABCDEF);
      expect(source.resolveArgb('#abc'), 0xFFAABBCC);
      expect(source.resolveArgb('theme:accent2'), 0xFF445566);
      expect(source.resolveArgb('theme:text'), 0xFF101010);
      expect(source.resolveArgb('theme:nope'), isNull);
      expect(source.resolveArgb('auto'), isNull);
      expect(source.resolveArgb(null), isNull);
    });

    test('when deriving a chart theme then palette and font follow it', () {
      final theme = ChartTheme.from(source, export: true);
      expect(theme.fontFamily, 'Lato');
      expect(theme.palette, hasLength(18));
      expect(theme.source, same(source));
      expect(theme.color('theme:accent1', 0), 0xFF112233);
      expect(ChartTheme.paletteOf(source).take(6), accents);
    });
  });
}
