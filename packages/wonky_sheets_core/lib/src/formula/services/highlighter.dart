import '../../addressing/a1.dart';
import '../parser/formula_locale.dart';
import '../parser/lexer.dart';

/// Token classes mapped to theme colours by the editor (03 §8.7).
enum HighlightClass {
  function,
  reference,
  namedRange,
  number,
  string,
  boolean,
  error,
  operator,
  punctuation,
  name,
  whitespace,
  unmatchedParen,
  matchedParen,
  unknown,
}

/// A highlighted span of the formula text.
final class HighlightSpan {
  final int start;
  final int end;
  final HighlightClass cls;

  /// Reference colour index 0..9 for references (cycles after 10), else null.
  final int? colorIndex;
  const HighlightSpan(this.start, this.end, this.cls, [this.colorIndex]);

  @override
  String toString() =>
      '${cls.name}[$start,$end)${colorIndex == null ? '' : '#$colorIndex'}';
}

/// A reference in edited A1 text with its colour (drives the coloured range boxes, 03 §8.7).
final class FormulaReferenceSpan {
  final int start;
  final int end;

  /// Parsed reference; [A1Area.sheet] is null for the edited cell's sheet.
  final A1Area area;
  final int colorIndex;
  const FormulaReferenceSpan(this.start, this.end, this.area, this.colorIndex);

  @override
  String toString() =>
      'FormulaReferenceSpan(${area.format()} [$start,$end) #$colorIndex)';
}

/// Syntax highlighting and reference colouring for the cell editor (05 §4.3).
abstract final class FormulaHighlighter {
  static const int referenceColorCount = 10;

  static String _refKey(A1Area a) =>
      '${a.sheet?.toLowerCase() ?? ''}!${a.withSheet(null).formatArea().replaceAll(r'$', '')}';

  /// Highlight spans for [text] (A1 form). [caret] highlights the matching paren pair.
  /// [isNamedRange] marks names that are defined named ranges.
  static List<HighlightSpan> highlight(
    String text, {
    FormulaLocale locale = FormulaLocale.enUS,
    int? caret,
    bool Function(String name)? isNamedRange,
  }) {
    final tokens = FormulaLexer(
      locale: locale,
      storedForm: false,
    ).tokenize(text);
    final colors = <String, int>{};
    final out = <HighlightSpan>[];
    // paren matching
    final match = <int, int>{};
    final stack = <int>[];
    for (var i = 0; i < tokens.length; i++) {
      final k = tokens[i].kind;
      if (k == TokenKind.openParen) stack.add(i);
      if (k == TokenKind.closeParen && stack.isNotEmpty) {
        final o = stack.removeLast();
        match[o] = i;
        match[i] = o;
      }
    }
    final caretPair = <int>{};
    if (caret != null) {
      for (var i = 0; i < tokens.length; i++) {
        final t = tokens[i];
        final isParen =
            t.kind == TokenKind.openParen || t.kind == TokenKind.closeParen;
        if (isParen &&
            (t.start == caret || t.end == caret) &&
            match.containsKey(i)) {
          caretPair
            ..add(i)
            ..add(match[i]!);
          break;
        }
      }
    }
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      switch (t.kind) {
        case TokenKind.cellRef ||
            TokenKind.rangeRef ||
            TokenKind.columnRange ||
            TokenKind.rowRange:
          final key = _refKey(t.ref!.a1!);
          final idx =
              colors.putIfAbsent(key, () => colors.length) %
              referenceColorCount;
          out.add(HighlightSpan(t.start, t.end, HighlightClass.reference, idx));
        case TokenKind.storedRef:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.reference));
        case TokenKind.sheetPrefix:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.reference));
        case TokenKind.functionName:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.function));
        case TokenKind.name:
          final named = isNamedRange?.call(t.text) ?? false;
          if (named) {
            final key = 'name:${t.text.toUpperCase()}';
            final idx =
                colors.putIfAbsent(key, () => colors.length) %
                referenceColorCount;
            out.add(
              HighlightSpan(t.start, t.end, HighlightClass.namedRange, idx),
            );
          } else {
            out.add(HighlightSpan(t.start, t.end, HighlightClass.name));
          }
        case TokenKind.number:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.number));
        case TokenKind.string || TokenKind.unterminatedString:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.string));
        case TokenKind.boolean:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.boolean));
        case TokenKind.error:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.error));
        case TokenKind.operator:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.operator));
        case TokenKind.openParen || TokenKind.closeParen:
          final cls = !match.containsKey(i)
              ? HighlightClass.unmatchedParen
              : (caretPair.contains(i)
                    ? HighlightClass.matchedParen
                    : HighlightClass.punctuation);
          out.add(HighlightSpan(t.start, t.end, cls));
        case TokenKind.openBrace ||
            TokenKind.closeBrace ||
            TokenKind.argSeparator ||
            TokenKind.arrayColSep ||
            TokenKind.arrayRowSep:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.punctuation));
        case TokenKind.whitespace:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.whitespace));
        case TokenKind.unknown:
          out.add(HighlightSpan(t.start, t.end, HighlightClass.unknown));
      }
    }
    return out;
  }

  /// References of [text] with colour indices in order of first appearance (identical
  /// references share a colour).
  static List<FormulaReferenceSpan> references(
    String text, {
    FormulaLocale locale = FormulaLocale.enUS,
  }) {
    final tokens = FormulaLexer(
      locale: locale,
      storedForm: false,
    ).tokenize(text);
    final colors = <String, int>{};
    final out = <FormulaReferenceSpan>[];
    for (final t in tokens) {
      final a = t.ref?.a1;
      if (a == null) continue;
      final idx =
          colors.putIfAbsent(_refKey(a), () => colors.length) %
          referenceColorCount;
      out.add(FormulaReferenceSpan(t.start, t.end, a, idx));
    }
    return out;
  }
}
