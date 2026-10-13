import '../../addressing/a1.dart';
import '../parser/formula_grammar.dart';
import '../parser/formula_locale.dart';
import '../parser/lexer.dart';
import '../parser/parse_error.dart';

/// A text edit produced by an editor service.
final class FormulaEdit {
  final String text;

  /// Selection after the edit.
  final int selectionStart;
  final int selectionEnd;
  const FormulaEdit(this.text, this.selectionStart, this.selectionEnd);

  @override
  String toString() => 'FormulaEdit("$text", $selectionStart..$selectionEnd)';
}

/// Result of [autoFix].
final class AutoFixResult {
  final String text;
  final bool changed;

  /// Remaining parse error (the formula is still stored; it evaluates to `#ERROR!`).
  final FormulaParseError? error;
  const AutoFixResult(this.text, {required this.changed, this.error});
}

/// Whether a reference may be inserted at [caret] (point mode, 03 §8.7): after `=`, `(`, a
/// separator, an operator, `:` or `!`.
bool refInsertionPoint(
  String text,
  int caret, {
  FormulaLocale locale = FormulaLocale.enUS,
}) {
  if (!text.startsWith('=') || caret < 1 || caret > text.length) return false;
  final tokens = FormulaLexer(locale: locale, storedForm: false).tokenize(text);
  FormulaToken? prev;
  for (final t in tokens) {
    if (t.end > caret) {
      // caret inside a token: only allowed at a token boundary
      if (t.start < caret && t.kind != TokenKind.whitespace) return false;
      break;
    }
    if (t.kind != TokenKind.whitespace) prev = t;
  }
  if (prev == null) return false;
  if (prev.kind == TokenKind.unterminatedString ||
      prev.kind == TokenKind.string) {
    return false;
  }
  return switch (prev.kind) {
    TokenKind.operator ||
    TokenKind.openParen ||
    TokenKind.openBrace ||
    TokenKind.argSeparator ||
    TokenKind.arrayColSep ||
    TokenKind.arrayRowSep ||
    TokenKind.sheetPrefix => true,
    _ => false,
  };
}

/// F4 (05 §4.3): cycles the reference at/before the caret `A1 → $A$1 → A$1 → $A1 → A1`; ranges
/// apply the state to both ends; whole columns/rows toggle `$`. [selectionEnd] > [caret] cycles
/// every reference in the selection.
FormulaEdit? cycleAbsolute(
  String text,
  int caret, {
  int? selectionEnd,
  FormulaLocale locale = FormulaLocale.enUS,
}) {
  final tokens = FormulaLexer(locale: locale, storedForm: false).tokenize(text);
  final refs = [
    for (final t in tokens)
      if (t.ref?.a1 != null) t,
  ];
  if (refs.isEmpty) return null;
  final selEnd = selectionEnd ?? caret;
  List<FormulaToken> targets;
  if (selEnd > caret) {
    targets = [
      for (final t in refs)
        if (t.end > caret && t.start < selEnd) t,
    ];
  } else {
    FormulaToken? hit;
    for (final t in refs) {
      if (t.start <= caret && caret <= t.end) hit = t;
    }
    if (hit == null) {
      for (final t in refs) {
        if (t.end <= caret) hit = t;
      }
    }
    targets = hit == null ? const [] : [hit];
  }
  if (targets.isEmpty) return null;
  final b = StringBuffer();
  var last = 0;
  var newEnd = caret;
  var newStart = caret;
  for (final t in targets) {
    b.write(text.substring(last, t.start));
    final cycled = _cycle(t.ref!.a1!);
    final s = b.length;
    // keep the user's sheet prefix spelling
    final prefix = text.substring(t.start, t.end);
    final bang = prefix.lastIndexOf('!');
    if (bang >= 0) {
      b
        ..write(prefix.substring(0, bang + 1))
        ..write(cycled.formatArea());
    } else {
      b.write(cycled.formatArea());
    }
    if (t == targets.first) newStart = selEnd > caret ? s : b.length;
    newEnd = b.length;
    last = t.end;
  }
  b.write(text.substring(last));
  return FormulaEdit(b.toString(), selEnd > caret ? newStart : newEnd, newEnd);
}

A1Area _cycle(A1Area a) {
  // state of the first endpoint
  (bool, bool) next(bool absCol, bool absRow) {
    if (!absCol && !absRow) return (true, true);
    if (absCol && absRow) return (false, true);
    if (!absCol && absRow) return (true, false);
    return (false, false);
  }

  switch (a.kind) {
    case A1Kind.columns:
      final abs = !a.absCol1;
      return A1Area.raw(
        a.kind,
        sheet: a.sheet,
        col1: a.col1,
        col2: a.col2,
        absCol1: abs,
        absCol2: abs,
      );
    case A1Kind.rows:
      final abs = !a.absRow1;
      return A1Area.raw(
        a.kind,
        sheet: a.sheet,
        row1: a.row1,
        row2: a.row2,
        absRow1: abs,
        absRow2: abs,
      );
    default:
      final (c, r) = next(a.absCol1, a.absRow1);
      return A1Area.raw(
        a.kind,
        sheet: a.sheet,
        row1: a.row1,
        col1: a.col1,
        row2: a.row2,
        col2: a.col2,
        absCol1: c,
        absRow1: r,
        absCol2: c,
        absRow2: r,
      );
  }
}

/// Commit auto-fix (05 §4.3, 03 §8.4): appends missing `)` and closing `"`, converts `+A1` to
/// `=+A1`, trims trailing argument separators.
AutoFixResult autoFix(
  String text, {
  FormulaLocale locale = FormulaLocale.enUS,
}) {
  var t = text;
  var changed = false;
  if (!t.startsWith('=') && (t.startsWith('+') || t.startsWith('-'))) {
    t = '=$t';
    changed = true;
  }
  if (!t.startsWith('=')) return AutoFixResult(text, changed: false);
  var tokens = FormulaLexer(locale: locale, storedForm: true).tokenize(t);
  if (tokens.isNotEmpty && tokens.last.kind == TokenKind.unterminatedString) {
    t = '$t"';
    changed = true;
    tokens = FormulaLexer(locale: locale, storedForm: true).tokenize(t);
  }
  // trailing separators before the end or before the auto-closed parens
  var trimmed = t.trimRight();
  while (trimmed.isNotEmpty &&
      (trimmed.endsWith(locale.argSeparator) || trimmed.endsWith(','))) {
    final sig = FormulaLexer.significant(
      FormulaLexer(locale: locale, storedForm: true).tokenize(trimmed),
    );
    if (sig.isEmpty || sig.last.kind != TokenKind.argSeparator) break;
    trimmed = trimmed.substring(0, sig.last.start).trimRight();
    changed = true;
  }
  t = trimmed.length == t.trimRight().length ? t : trimmed;
  tokens = FormulaLexer(locale: locale, storedForm: true).tokenize(t);
  final stack = <TokenKind>[];
  for (final tok in tokens) {
    if (tok.kind == TokenKind.openParen || tok.kind == TokenKind.openBrace) {
      stack.add(tok.kind);
    }
    if ((tok.kind == TokenKind.closeParen ||
            tok.kind == TokenKind.closeBrace) &&
        stack.isNotEmpty) {
      stack.removeLast();
    }
  }
  if (stack.isNotEmpty) {
    final b = StringBuffer(t);
    for (final k in stack.reversed) {
      b.write(k == TokenKind.openParen ? ')' : '}');
    }
    t = b.toString();
    changed = true;
  }
  final (_, err) = FormulaParser.tryParse(t, locale: locale, storedForm: true);
  return AutoFixResult(t, changed: changed, error: err);
}

/// `Mod+Shift+Enter` (05 §19): wraps the formula in ARRAYFORMULA(…) or unwraps it.
String toggleArrayFormula(String text) {
  if (!text.startsWith('=')) return text;
  final body = text.substring(1).trim();
  final m = RegExp(
    r'^ARRAYFORMULA\((.*)\)$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(body);
  if (m != null) {
    final inner = m.group(1)!;
    // only unwrap when the outer parens match each other
    var depth = 0;
    var ok = true;
    for (var i = 0; i < inner.length; i++) {
      if (inner[i] == '(') depth++;
      if (inner[i] == ')') depth--;
      if (depth < 0) {
        ok = false;
        break;
      }
    }
    if (ok && depth == 0) return '=$inner';
  }
  return '=ARRAYFORMULA($body)';
}
