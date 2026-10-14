import '../../addressing/a1.dart';
import '../../addressing/column_letters.dart';
import '../codec/ref_token.dart';
import '../values/errors.dart';
import 'formula_locale.dart';

/// Token classes of [FormulaLexer] (05 §4.1).
enum TokenKind {
  number,
  string,
  boolean,
  error,
  cellRef,
  rangeRef,
  columnRange,
  rowRange,
  storedRef,
  sheetPrefix,
  functionName,
  name,
  operator,
  argSeparator,
  arrayColSep,
  arrayRowSep,
  openParen,
  closeParen,
  openBrace,
  closeBrace,
  whitespace,
  unterminatedString,
  unknown,
}

/// Parsed reference of a reference token.
final class RefInfo {
  /// For A1 tokens.
  final A1Area? a1;

  /// For stored `⟦…⟧` tokens.
  final StoredRef? stored;

  const RefInfo.a1(A1Area this.a1) : stored = null;
  const RefInfo.stored(StoredRef this.stored) : a1 = null;
}

/// A lexical token with UTF-16 offsets into the formula text.
final class FormulaToken {
  final TokenKind kind;
  final int start;
  final int end;
  final String text;

  /// Bracket depth (parens and braces) at this token; open/close tokens carry the depth of the
  /// enclosed content's parent (i.e. matching pairs share a depth).
  final int depth;
  final RefInfo? ref;

  const FormulaToken(
    this.kind,
    this.start,
    this.end,
    this.text,
    this.depth, [
    this.ref,
  ]);

  bool get isReference =>
      kind == TokenKind.cellRef ||
      kind == TokenKind.rangeRef ||
      kind == TokenKind.columnRange ||
      kind == TokenKind.rowRange ||
      kind == TokenKind.storedRef;

  bool get isTrivia => kind == TokenKind.whitespace;

  @override
  String toString() => '${kind.name}($text)@$start';
}

/// Error-tolerant tokenizer used by highlighting, signature help, autocomplete, the codec and
/// auto-fix. Never throws; unknown characters become [TokenKind.unknown] tokens.
///
/// The text may start with `=`; it is emitted as an operator token.
final class FormulaLexer {
  final FormulaLocale locale;

  /// Whether `⟦…⟧` tokens are recognized (stored form).
  final bool storedForm;

  const FormulaLexer({
    this.locale = FormulaLocale.enUS,
    this.storedForm = true,
  });

  static bool isIdentStart(int c) =>
      ColumnLetters.isLetter(c) || c == 0x5f || (c >= 0xc0 && c < 0x2000);
  static bool isIdentPart(int c) =>
      ColumnLetters.isLetter(c) ||
      ColumnLetters.isDigit(c) ||
      c == 0x5f ||
      c == 0x2e ||
      (c >= 0xc0 && c < 0x2000);

  /// Tokenizes [text].
  List<FormulaToken> tokenize(String text) {
    final out = <FormulaToken>[];
    final stack = <int>[]; // 0x28 '(' or 0x7b '{'
    final n = text.length;
    var i = 0;
    void add(TokenKind k, int s, int e, [RefInfo? ref]) =>
        out.add(FormulaToken(k, s, e, text.substring(s, e), stack.length, ref));

    while (i < n) {
      final c = text.codeUnitAt(i);
      // whitespace
      if (c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d) {
        var j = i + 1;
        while (j < n) {
          final d = text.codeUnitAt(j);
          if (d == 0x20 || d == 0x09 || d == 0x0a || d == 0x0d) {
            j++;
          } else {
            break;
          }
        }
        add(TokenKind.whitespace, i, j);
        i = j;
        continue;
      }
      // strings
      if (c == 0x22) {
        var j = i + 1;
        var closed = false;
        while (j < n) {
          if (text.codeUnitAt(j) == 0x22) {
            if (j + 1 < n && text.codeUnitAt(j + 1) == 0x22) {
              j += 2;
              continue;
            }
            closed = true;
            j++;
            break;
          }
          j++;
        }
        add(closed ? TokenKind.string : TokenKind.unterminatedString, i, j);
        i = j;
        continue;
      }
      // stored refs
      if (c == RefToken.openCode) {
        final end = _scanStored(text, i);
        if (end > 0) {
          final ref = StoredRef.parse(text.substring(i, end));
          if (ref != null) {
            add(TokenKind.storedRef, i, end, RefInfo.stored(ref));
            i = end;
            continue;
          }
        }
        final close = text.indexOf(RefToken.close, i);
        final e = close < 0 ? n : close + 1;
        add(TokenKind.unknown, i, e);
        i = e;
        continue;
      }
      // errors
      if (c == 0x23) {
        String? lit;
        for (final l in ErrorKind.literalsLongestFirst) {
          if (text.length - i >= l.length &&
              text.substring(i, i + l.length).toUpperCase() == l) {
            lit = l;
            break;
          }
        }
        if (lit != null) {
          add(TokenKind.error, i, i + lit.length);
          i += lit.length;
          continue;
        }
        add(TokenKind.unknown, i, i + 1);
        i++;
        continue;
      }
      // A1 references (incl. sheet prefixes, row ranges, $-refs)
      if (c == 0x24 ||
          c == 0x27 ||
          isIdentStart(c) ||
          ColumnLetters.isDigit(c)) {
        final prev = _prevSignificant(out);
        final afterDot =
            prev != null && prev.end == i && prev.kind == TokenKind.number;
        if (!afterDot) {
          final m = A1Scanner.scan(text, i);
          if (m != null) {
            final kind = switch (m.area.kind) {
              A1Kind.cell => TokenKind.cellRef,
              A1Kind.columns => TokenKind.columnRange,
              A1Kind.rows => TokenKind.rowRange,
              _ => TokenKind.rangeRef,
            };
            add(kind, i, m.end, RefInfo.a1(m.area));
            i = m.end;
            continue;
          }
          final p = A1Scanner.scanSheetPrefix(text, i);
          if (p != null) {
            add(TokenKind.sheetPrefix, i, p.$2);
            i = p.$2;
            continue;
          }
        }
        if (c == 0x27) {
          // unterminated quoted sheet name or stray quote
          var j = i + 1;
          while (j < n && text.codeUnitAt(j) != 0x27) {
            j++;
          }
          final e = j < n ? j + 1 : n;
          add(TokenKind.unknown, i, e);
          i = e;
          continue;
        }
      }
      // numbers
      if (ColumnLetters.isDigit(c) ||
          (_isDecimalAt(text, i) &&
              i + 1 < n &&
              ColumnLetters.isDigit(text.codeUnitAt(i + 1)) &&
              !_endsValue(_prevSignificant(out)))) {
        final e = _scanNumber(text, i);
        add(TokenKind.number, i, e);
        i = e;
        continue;
      }
      // identifiers
      if (isIdentStart(c)) {
        var j = i + 1;
        while (j < n && isIdentPart(text.codeUnitAt(j))) {
          j++;
        }
        final word = text.substring(i, j);
        final upper = word.toUpperCase();
        final nextIsParen = j < n && text.codeUnitAt(j) == 0x28;
        if (nextIsParen) {
          add(TokenKind.functionName, i, j);
        } else if (upper == 'TRUE' ||
            upper == 'FALSE' ||
            locale.language?.booleanOf(upper) != null) {
          add(TokenKind.boolean, i, j);
        } else {
          add(TokenKind.name, i, j);
        }
        i = j;
        continue;
      }
      // brackets
      if (c == 0x28) {
        add(TokenKind.openParen, i, i + 1);
        stack.add(0x28);
        i++;
        continue;
      }
      if (c == 0x29) {
        if (stack.isNotEmpty && stack.last == 0x28) stack.removeLast();
        add(TokenKind.closeParen, i, i + 1);
        i++;
        continue;
      }
      if (c == 0x7b) {
        add(TokenKind.openBrace, i, i + 1);
        stack.add(0x7b);
        i++;
        continue;
      }
      if (c == 0x7d) {
        if (stack.isNotEmpty && stack.last == 0x7b) stack.removeLast();
        add(TokenKind.closeBrace, i, i + 1);
        i++;
        continue;
      }
      // separators
      final inBrace = stack.isNotEmpty && stack.last == 0x7b;
      final ch = String.fromCharCode(c);
      if (inBrace) {
        if (ch == locale.arrayRowSeparator) {
          add(TokenKind.arrayRowSep, i, i + 1);
          i++;
          continue;
        }
        if (ch == locale.arrayColSeparator || ch == ',') {
          add(TokenKind.arrayColSep, i, i + 1);
          i++;
          continue;
        }
      } else {
        if (ch == locale.argSeparator || (ch == ',' && stack.isNotEmpty)) {
          add(TokenKind.argSeparator, i, i + 1);
          i++;
          continue;
        }
      }
      // operators
      if (c == 0x3c || c == 0x3e) {
        // < > <= >= <>
        if (i + 1 < n) {
          final d = text.codeUnitAt(i + 1);
          if (d == 0x3d || (c == 0x3c && d == 0x3e)) {
            add(TokenKind.operator, i, i + 2);
            i += 2;
            continue;
          }
        }
        add(TokenKind.operator, i, i + 1);
        i++;
        continue;
      }
      if ('+-*/^&=%:'.contains(ch)) {
        add(TokenKind.operator, i, i + 1);
        i++;
        continue;
      }
      add(TokenKind.unknown, i, i + 1);
      i++;
    }
    return out;
  }

  static FormulaToken? _prevSignificant(List<FormulaToken> out) {
    for (var k = out.length - 1; k >= 0; k--) {
      if (!out[k].isTrivia) return out[k];
    }
    return null;
  }

  static bool _endsValue(FormulaToken? t) =>
      t != null &&
      (t.isReference ||
          t.kind == TokenKind.number ||
          t.kind == TokenKind.string ||
          t.kind == TokenKind.boolean ||
          t.kind == TokenKind.error ||
          t.kind == TokenKind.name ||
          t.kind == TokenKind.closeParen ||
          t.kind == TokenKind.closeBrace);

  bool _isDecimalAt(String text, int i) =>
      text.codeUnitAt(i) == locale.decimal.codeUnitAt(0);

  int _scanNumber(String text, int i) {
    final n = text.length;
    final dec = locale.decimal.codeUnitAt(0);
    var j = i;
    while (j < n && ColumnLetters.isDigit(text.codeUnitAt(j))) {
      j++;
    }
    if (j < n && text.codeUnitAt(j) == dec) {
      // In comma-decimal locales a ',' directly followed by a non-digit is a separator.
      final nextIsDigit =
          j + 1 < n && ColumnLetters.isDigit(text.codeUnitAt(j + 1));
      if (nextIsDigit || dec == 0x2e) {
        j++;
        while (j < n && ColumnLetters.isDigit(text.codeUnitAt(j))) {
          j++;
        }
      }
    }
    if (j < n && (text.codeUnitAt(j) == 0x65 || text.codeUnitAt(j) == 0x45)) {
      var k = j + 1;
      if (k < n && (text.codeUnitAt(k) == 0x2b || text.codeUnitAt(k) == 0x2d)) {
        k++;
      }
      final ds = k;
      while (k < n && ColumnLetters.isDigit(text.codeUnitAt(k))) {
        k++;
      }
      if (k > ds) j = k;
    }
    return j;
  }

  /// End offset of `⟦…⟧` or `⟦…⟧:⟦…⟧` at [i], or -1.
  static int _scanStored(String text, int i) {
    final close = text.indexOf(RefToken.close, i);
    if (close < 0) return -1;
    var end = close + 1;
    if (end + 1 < text.length &&
        text.codeUnitAt(end) == 0x3a &&
        text.codeUnitAt(end + 1) == RefToken.openCode) {
      final close2 = text.indexOf(RefToken.close, end + 1);
      if (close2 > 0) end = close2 + 1;
    }
    return end;
  }

  /// Significant (non-whitespace) tokens.
  static List<FormulaToken> significant(List<FormulaToken> tokens) => [
    for (final t in tokens)
      if (!t.isTrivia) t,
  ];
}
