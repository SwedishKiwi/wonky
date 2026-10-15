import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';

/// The text of each line span.
List<String> _texts(List<TextSpan> lines) =>
    lines.map((l) => l.toPlainText()).toList();

/// `(text, color)` of the children of [line].
List<(String, Color?)> _runs(TextSpan line) => [
  for (final child in line.children ?? const <InlineSpan>[])
    ((child as TextSpan).text ?? '', child.style?.color),
];

void main() {
  final palette = BuiltInPalettes.wonkyLight;
  final styler = CodeTextStyler(palette);
  final keyword = Color(palette.styleOf(SyntaxToken.keyword).color);
  final comment = Color(palette.styleOf(SyntaxToken.comment).color);

  group('Given code with tokens', () {
    test('when splitting into lines then each line keeps its tokens', () {
      const code = 'final a = 1;\n// end';
      final tokens = [
        const CodeToken(0, 5, SyntaxToken.keyword),
        CodeToken(13, code.length, SyntaxToken.comment),
      ];

      final lines = styler.lineSpans(code, tokens);

      expect(_texts(lines), ['final a = 1;', '// end']);
      expect(_runs(lines[0]), [('final', keyword), (' a = 1;', null)]);
      expect(_runs(lines[1]), [('// end', comment)]);
    });

    test('when a token spans two lines then both lines carry its color', () {
      const code = '/* a\nb */ x';
      final lines = styler.lineSpans(code, [
        const CodeToken(0, 9, SyntaxToken.comment),
      ]);

      expect(_runs(lines[0]), [('/* a', comment)]);
      expect(_runs(lines[1]), [('b */', comment), (' x', null)]);
    });

    test('when lines end with CRLF then the CR is dropped', () {
      expect(_texts(styler.lineSpans('a\r\nb', const [])), ['a', 'b']);
    });

    test(
      'when code ends with a line break then there is an empty last line',
      () {
        expect(_texts(styler.lineSpans('a\n', const [])), ['a', '']);
      },
    );

    test('when a line has tabs then they expand to the next tab stop', () {
      expect(_texts(styler.lineSpans('ab\tc\n\td', const [])), [
        'ab  c',
        '    d',
      ]);
    });

    test('when joining into one span then the text equals the code', () {
      const code = 'if (x) {\n  y();\n}';

      expect(
        styler.span(code, const [
          CodeToken(0, 2, SyntaxToken.keyword),
        ]).toPlainText(),
        code,
      );
    });
  });

  group('Given a palette', () {
    test('when styling plain text then it uses the palette text color', () {
      expect(styler.plainStyle.color, Color(palette.text));
      expect(styler.plainStyle.fontFamily, 'JetBrains Mono');
    });

    test('when styling a comment then it is italic', () {
      expect(styler.styleFor(SyntaxToken.comment).fontStyle, FontStyle.italic);
    });

    test('when styling a bold token then it is bold', () {
      final mono = CodeTextStyler(BuiltInPalettes.monochromeLight);

      expect(mono.styleFor(SyntaxToken.keyword).fontWeight, FontWeight.w700);
    });

    test('when a base style is given then its size wins and colors do not', () {
      final big = CodeTextStyler(
        palette,
        baseStyle: const TextStyle(fontSize: 20, color: Color(0xff00ff00)),
      );

      expect(big.plainStyle.fontSize, 20);
      expect(big.plainStyle.color, Color(palette.text));
    });
  });

  group('Given lines with special characters', () {
    for (final (line, columns) in const [
      ('abc', 3),
      ('\tx', 5),
      ('日本', 4),
      ('a\tb\t', 8),
    ]) {
      test('when counting columns of "$line" then there are $columns', () {
        expect(styler.columnsOf(line), columns);
      });
    }
  });
}
