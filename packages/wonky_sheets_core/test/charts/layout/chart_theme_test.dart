import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given the built-in spreadsheet themes', () {
    for (final t in SpreadsheetTheme.presets) {
      for (final dark in [false, true]) {
        test(
          'when deriving the ${dark ? 'dark' : 'light'} palette of ${t.name} then every color has 3:1 contrast',
          () {
            final theme = ChartTheme.from(t, dark: dark);

            expect(theme.palette, hasLength(18));
            for (final c in theme.palette) {
              expect(
                ChartTheme.contrast(c, theme.background),
                greaterThanOrEqualTo(ChartTheme.minContrast),
                reason: argbHex(c),
              );
            }
          },
        );
      }
    }
  });

  group('Given the standard theme', () {
    test(
      'when exporting in light mode then the print colors of 08 §6.4 are used',
      () {
        final t = ChartTheme.from(SpreadsheetTheme.standard, export: true);

        expect(t.background, 0xFFFFFFFF);
        expect(t.text, 0xFF202124);
        expect(t.axisLine, 0xFF9AA0A6);
        expect(t.gridline, 0xFFE0E0E0);
        expect(t.isExport, isTrue);
      },
    );

    test(
      'when used in the dark editor then the dark card token is the background',
      () {
        final t = ChartTheme.from(SpreadsheetTheme.standard, dark: true);

        expect(t.background, ChartUiTokens.dark.card);
        expect(t.text, ChartUiTokens.dark.foreground);
        expect(t.isDark, isTrue);
      },
    );

    test(
      'when exporting with the dark theme then the dark colors are used',
      () {
        final t = ChartTheme.from(
          SpreadsheetTheme.standard,
          export: true,
          dark: true,
        );

        expect(t.background, ChartUiTokens.dark.card);
      },
    );

    test('when there are more series than colors then the palette cycles', () {
      final t = ChartTheme.from(SpreadsheetTheme.standard);

      expect(t.seriesColor(18), t.seriesColor(0));
    });

    for (final (input, expected) in [
      ('#FF0000', 0xFFFF0000),
      ('#f00', 0xFFFF0000),
      ('#80FF0000', 0x80FF0000),
      ('theme:accent1', null),
      ('nonsense', 0xFF123456),
      (null, 0xFF123456),
    ]) {
      test('when resolving the color "$input" then the ARGB is right', () {
        final t = ChartTheme.from(SpreadsheetTheme.standard);
        final want =
            expected ??
            SpreadsheetTheme.standard.resolveArgb(
              SpreadsheetTheme.standard.accents.first,
            );

        expect(t.color(input, 0xFF123456), want);
      });
    }

    test('when choosing text on a dark fill then it is white', () {
      final t = ChartTheme.from(SpreadsheetTheme.standard);

      expect(t.onColor(0xFF000080), 0xFFFFFFFF);
      expect(t.onColor(0xFFFFFF00), 0xFF202124);
    });
  });
}
