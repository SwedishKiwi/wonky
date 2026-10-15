import 'package:flutter/painting.dart';
import 'package:wonky_code/wonky_code.dart';

/// Turns a [SyntaxPalette] and a mono font into `TextStyle`s and `TextSpan`s
/// (Slides 07 §2.3).
///
/// Tabs are expanded to the next multiple of [tabSize] columns, so the
/// rendered text is aligned like in a code editor.
class CodeTextStyler {
  /// Creates a styler for [palette] with [baseStyle] (font family, size and
  /// line height; its color is replaced by the palette's).
  CodeTextStyler(this.palette, {TextStyle? baseStyle, this.tabSize = 4})
    : baseStyle = defaultBaseStyle.merge(baseStyle);

  /// JetBrains Mono 13/1.45 with ligatures off (Slides 07 §3.3).
  static const TextStyle defaultBaseStyle = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
    fontSize: 13,
    height: 1.45,
    fontFeatures: [FontFeature.disable('calt'), FontFeature.disable('liga')],
  );

  /// The palette.
  final SyntaxPalette palette;

  /// Font family, size and height of all code text.
  final TextStyle baseStyle;

  /// Columns per tab stop.
  final int tabSize;

  final Map<SyntaxToken?, TextStyle> _styles = {};

  /// The style of plain text (palette text color).
  TextStyle get plainStyle => styleFor(null);

  /// The full style of [token] (`null` = plain text).
  TextStyle styleFor(SyntaxToken? token) => _styles.putIfAbsent(token, () {
    final style = palette.styleOf(token);
    return baseStyle.copyWith(
      color: Color(style.color),
      fontWeight: style.bold ? FontWeight.w700 : baseStyle.fontWeight,
      fontStyle: style.italic ? FontStyle.italic : baseStyle.fontStyle,
    );
  });

  /// One `TextSpan` per line of [code] (`\n` or `\r\n` separated, without
  /// the line break), colored by [tokens] (sorted, disjoint, as returned by
  /// a `CodeTokenizer`; a token may span lines). Each line span carries
  /// [plainStyle]; its children carry the token styles.
  List<TextSpan> lineSpans(String code, List<CodeToken> tokens) {
    final out = <TextSpan>[];
    var t = 0;
    var lineStart = 0;
    while (true) {
      var lineEnd = code.indexOf('\n', lineStart);
      final isLast = lineEnd < 0;
      if (isLast) lineEnd = code.length;
      var textEnd = lineEnd;
      if (textEnd > lineStart && code.codeUnitAt(textEnd - 1) == 0x0d) {
        textEnd--;
      }
      final children = <TextSpan>[];
      var column = 0;
      void add(int from, int to, SyntaxToken? token) {
        final (text, next) = _expandTabs(code.substring(from, to), column);
        column = next;
        children.add(
          token == null
              ? TextSpan(text: text)
              : TextSpan(text: text, style: styleFor(token)),
        );
      }

      while (t < tokens.length && tokens[t].end <= lineStart) {
        t++;
      }
      var pos = lineStart;
      while (t < tokens.length && tokens[t].start < textEnd) {
        final token = tokens[t];
        final start = token.start < lineStart ? lineStart : token.start;
        final end = token.end > textEnd ? textEnd : token.end;
        if (start > pos) add(pos, start, null);
        final from = start < pos ? pos : start;
        if (end > from) {
          add(from, end, token.token);
          pos = end;
        }
        if (token.end > textEnd) break; // continues on the next line
        t++;
      }
      if (pos < textEnd) add(pos, textEnd, null);
      out.add(TextSpan(style: plainStyle, children: children));
      if (isLast) break;
      lineStart = lineEnd + 1;
    }
    return out;
  }

  /// [code] as one `TextSpan` (lines joined with `\n`), colored by [tokens].
  TextSpan span(String code, List<CodeToken> tokens) {
    final lines = lineSpans(code, tokens);
    final children = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) children.add(const TextSpan(text: '\n'));
      children.addAll(lines[i].children ?? const []);
    }
    return TextSpan(style: plainStyle, children: children);
  }

  /// [text] with tabs expanded from [column]; returns the text and the
  /// column after it.
  (String, int) _expandTabs(String text, int column) {
    if (!text.contains('\t')) return (text, column + text.length);
    final buffer = StringBuffer();
    var col = column;
    for (final unit in text.codeUnits) {
      if (unit == 0x09) {
        final spaces = tabSize - col % tabSize;
        buffer.write(' ' * spaces);
        col += spaces;
      } else {
        buffer.writeCharCode(unit);
        col++;
      }
    }
    return (buffer.toString(), col);
  }

  /// Display columns of [line]: tabs expanded to [tabSize] stops, East
  /// Asian wide characters and emoji (roughly: code points ≥ U+1100 outside
  /// the combining ranges) counted as two.
  int columnsOf(String line) {
    var col = 0;
    for (final rune in line.runes) {
      if (rune == 0x09) {
        col += tabSize - col % tabSize;
      } else if (rune >= 0x1100 && !(rune >= 0x2000 && rune < 0x2e80)) {
        col += 2;
      } else {
        col++;
      }
    }
    return col;
  }
}
