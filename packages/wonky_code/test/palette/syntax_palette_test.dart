import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  group('Given palette JSON', () {
    test('when parsing and serializing then it round-trips', () {
      final palette = BuiltInPalettes.githubDark;

      final copy = SyntaxPalette.fromJson(palette.toJson());

      expect(copy.toJson(), palette.toJson());
    });

    test('when only background, text and tokens are given then chrome colors '
        'fall back', () {
      final palette = SyntaxPalette.fromJson({
        'id': 'mini',
        'background': '#ffffff',
        'text': '#000000',
        'tokens': {
          'keyword': {'color': '#ff0000', 'fontWeight': 700},
          'comment': {'color': '#00ff00', 'fontStyle': 'italic'},
          'nonsense': {'color': '#0000ff'},
        },
      });

      expect(palette.brightness, PaletteBrightness.light);
      expect(palette.lineNumber, 0xff000000);
      expect(palette.selection, 0x40000000);
      expect(palette.tokens.keys, {SyntaxToken.keyword, SyntaxToken.comment});
      expect(
        palette.styleOf(SyntaxToken.keyword),
        const TokenStyle(0xffff0000, bold: true),
      );
      expect(
        palette.styleOf(SyntaxToken.comment),
        const TokenStyle(0xff00ff00, italic: true),
      );
    });

    test('when a token has no style then it is plain text', () {
      final palette = SyntaxPalette.fromJson({
        'background': '#ffffff',
        'text': '#123456',
      });

      expect(palette.styleOf(SyntaxToken.string), const TokenStyle(0xff123456));
      expect(palette.styleOf(null), const TokenStyle(0xff123456));
    });

    test('when the background is missing then parsing fails', () {
      expect(
        () => SyntaxPalette.fromJson({'text': '#000000'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Given colors', () {
    const cases = <(String, int)>[
      ('#fff', 0xffffffff),
      ('#0a3069', 0xff0a3069),
      ('#8250df40', 0x408250df),
    ];
    for (final (text, argb) in cases) {
      test('when parsing "$text" then it is ${argb.toRadixString(16)}', () {
        expect(SyntaxPalette.parseColor(text), argb);
      });
    }

    test('when formatting a translucent color then alpha comes last', () {
      expect(SyntaxPalette.formatColor(0x408250df), '#8250df40');
    });

    test('when comparing black and white then the contrast is 21', () {
      expect(
        SyntaxPalette.contrastRatio(0xff000000, 0xffffffff),
        closeTo(21, 0.001),
      );
    });
  });
}
