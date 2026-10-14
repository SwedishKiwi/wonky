import '../../addressing/a1.dart';
import '../../addressing/column_letters.dart';
import '../../addressing/sheet_names.dart';
import 'function_map.dart';

/// Token kinds of the IO formula tokenizer.
enum FTok {
  ws,
  string,
  number,
  boolean,
  error,

  /// An A1 reference (cell, range, whole rows/columns), optionally sheet-prefixed.
  ref,

  /// A function name (identifier directly followed by `(`).
  func,

  /// A name (named range, LET/LAMBDA variable, …).
  name,
  op,

  /// Argument / array column separator.
  sep,

  /// Array row separator.
  rowSep,
  open,
  close,
  openBrace,
  closeBrace,

  /// External workbook reference (`[1]Sheet1!A1`, `'[Book.xlsx]S'!A1`).
  external,

  /// Structured table reference (`Table1[Col]`).
  structured,

  /// Excel implicit intersection operator `@`.
  at,

  /// Excel spill operator `#` after a reference.
  spill,

  /// Stored reference token `⟦…⟧`.
  stored,
  unknown,
}

/// One token. For [FTok.ref], [area] holds the parsed reference.
final class FToken {
  /// Creates a token.
  FToken(this.kind, this.text, [this.area]);

  final FTok kind;
  String text;
  A1Area? area;

  @override
  String toString() => '${kind.name}($text)';
}

/// Lexical conventions of a formula dialect.
final class FormulaDialect {
  /// Creates a dialect.
  const FormulaDialect({
    this.argSeparator = ',',
    this.decimal = '.',
    this.arrayColSeparator = ',',
    this.arrayRowSeparator = ';',
  });

  /// Canonical (en_US / Excel file / Wonky stored) conventions.
  static const canonical = FormulaDialect();

  /// Decimal-comma conventions (de_DE, fr_FR, …).
  static const decimalComma = FormulaDialect(
    argSeparator: ';',
    decimal: ',',
    arrayColSeparator: r'\',
  );

  final String argSeparator;
  final String decimal;
  final String arrayColSeparator;
  final String arrayRowSeparator;

  /// Conventions of a spreadsheet locale.
  static FormulaDialect forLocale(String? locale) =>
      usesDecimalComma(locale) ? decimalComma : canonical;

  static const Set<String> _commaLanguages = {
    'de',
    'fr',
    'es',
    'it',
    'pt',
    'nl',
    'ru',
    'pl',
    'sv',
    'da',
    'nb',
    'no',
    'nn',
    'fi',
    'cs', //
    'sk',
    'sl',
    'hr',
    'sr',
    'bs',
    'hu',
    'ro',
    'bg',
    'el',
    'tr',
    'uk',
    'be',
    'lt',
    'lv',
    'et', //
    'id', 'vi', 'ca', 'gl', 'eu', 'is', 'az', 'kk', 'ka', 'mk', 'sq',
  };

  /// Whether [locale] uses `,` as decimal separator.
  static bool usesDecimalComma(String? locale) {
    if (locale == null || locale.isEmpty) return false;
    final parts = locale.split(RegExp('[_-]'));
    final lang = parts.first.toLowerCase();
    const dotLocales = {'de_CH', 'es_MX', 'es_US', 'fr_CH', 'it_CH'};
    if (dotLocales.contains(locale)) return false;
    return _commaLanguages.contains(lang);
  }
}

/// Error literals recognized in formulas, longest first.
const List<String> kFormulaErrorLiterals = [
  '#GETTING_DATA',
  '#BLOCKED!',
  '#DIV/0!',
  '#VALUE!',
  '#ERROR!',
  '#SPILL!',
  '#NAME?',
  '#NULL!',
  '#CALC!',
  '#NUM!',
  '#REF!',
  '#N/A',
];

/// An error-tolerant tokenizer for Excel, Wonky A1 and stored formulas
/// (strings, quoted sheet names, `⟦…⟧` tokens and Excel-only constructs are
/// respected). Never throws. Concatenating the token texts reproduces the
/// input.
abstract final class FormulaTokenizer {
  static bool _identStart(int c) =>
      ColumnLetters.isLetter(c) ||
      c == 0x5f ||
      c == 0x5c ||
      (c >= 0xc0 && c != 0x27e6 && c != 0x27e7);

  static bool _identPart(int c) =>
      ColumnLetters.isLetter(c) ||
      ColumnLetters.isDigit(c) ||
      c == 0x5f ||
      c == 0x2e ||
      c == 0x3f ||
      (c >= 0xc0 && c != 0x27e6 && c != 0x27e7);

  /// Tokenizes [text] (without leading `=`).
  static List<FToken> tokenize(
    String text, {
    FormulaDialect dialect = FormulaDialect.canonical,
  }) {
    final out = <FToken>[];
    final stack = <int>[];
    final n = text.length;
    var i = 0;
    bool endsValue() {
      for (var k = out.length - 1; k >= 0; k--) {
        final t = out[k];
        if (t.kind == FTok.ws) continue;
        return t.kind == FTok.ref ||
            t.kind == FTok.close ||
            t.kind == FTok.name ||
            t.kind == FTok.number ||
            t.kind == FTok.stored ||
            t.kind == FTok.closeBrace;
      }
      return false;
    }

    while (i < n) {
      final c = text.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d || c == 0xa0) {
        var j = i + 1;
        while (j < n) {
          final d = text.codeUnitAt(j);
          if (d == 0x20 || d == 0x09 || d == 0x0a || d == 0x0d || d == 0xa0) {
            j++;
          } else {
            break;
          }
        }
        out.add(FToken(FTok.ws, text.substring(i, j)));
        i = j;
        continue;
      }
      // Array separators first: `\` (decimal-comma column separator) would
      // otherwise start an identifier.
      if (stack.isNotEmpty && stack.last == 0x7b) {
        if (text.startsWith(dialect.arrayRowSeparator, i)) {
          out.add(FToken(FTok.rowSep, dialect.arrayRowSeparator));
          i += dialect.arrayRowSeparator.length;
          continue;
        }
        if (text.startsWith(dialect.arrayColSeparator, i)) {
          out.add(FToken(FTok.sep, dialect.arrayColSeparator));
          i += dialect.arrayColSeparator.length;
          continue;
        }
      }
      if (c == 0x22) {
        var j = i + 1;
        while (j < n) {
          if (text.codeUnitAt(j) == 0x22) {
            if (j + 1 < n && text.codeUnitAt(j + 1) == 0x22) {
              j += 2;
              continue;
            }
            j++;
            break;
          }
          j++;
        }
        out.add(FToken(FTok.string, text.substring(i, j)));
        i = j;
        continue;
      }
      if (c == 0x27e6) {
        final close = text.indexOf('⟧', i);
        final e = close < 0 ? n : close + 1;
        out.add(FToken(FTok.stored, text.substring(i, e)));
        i = e;
        continue;
      }
      if (c == 0x23) {
        if (endsValue() && out.isNotEmpty && out.last.kind != FTok.ws) {
          out.add(FToken(FTok.spill, '#'));
          i++;
          continue;
        }
        String? lit;
        for (final l in kFormulaErrorLiterals) {
          if (n - i >= l.length &&
              text.substring(i, i + l.length).toUpperCase() == l) {
            lit = l;
            break;
          }
        }
        if (lit != null) {
          out.add(FToken(FTok.error, text.substring(i, i + lit.length)));
          i += lit.length;
        } else {
          out.add(FToken(FTok.unknown, '#'));
          i++;
        }
        continue;
      }
      if (c == 0x5b) {
        // External reference `[1]Sheet!A1` / `[1]!Name`, or a bare structured ref.
        final close = text.indexOf(']', i);
        if (close > 0) {
          var j = close + 1;
          while (j < n &&
              (_identPart(text.codeUnitAt(j)) || text.codeUnitAt(j) == 0x20)) {
            j++;
          }
          if (j < n && text.codeUnitAt(j) == 0x21) {
            j++;
            final m = A1Scanner.scan(text, j, allowSheet: false);
            if (m != null) {
              j = m.end;
            } else {
              while (j < n && _identPart(text.codeUnitAt(j))) {
                j++;
              }
            }
            out.add(FToken(FTok.external, text.substring(i, j)));
            i = j;
            continue;
          }
        }
        final e = _scanBrackets(text, i);
        out.add(FToken(FTok.structured, text.substring(i, e)));
        i = e;
        continue;
      }
      if (c == 0x24 ||
          c == 0x27 ||
          _identStart(c) ||
          ColumnLetters.isDigit(c)) {
        final prevNumber = out.isNotEmpty && out.last.kind == FTok.number;
        if (!prevNumber) {
          final m = A1Scanner.scan(text, i);
          if (m != null && !(m.end < n && text.codeUnitAt(m.end) == 0x28)) {
            final s = m.area.sheet;
            final kind = s != null && (s.startsWith('[') || s.contains('['))
                ? FTok.external
                : FTok.ref;
            out.add(FToken(kind, text.substring(i, m.end), m.area));
            i = m.end;
            continue;
          }
          if (c == 0x27) {
            final p = A1Scanner.scanSheetPrefix(text, i);
            if (p != null) {
              // Quoted sheet followed by a name (`'S'!Name`) or an external book.
              var j = p.$2;
              while (j < n && _identPart(text.codeUnitAt(j))) {
                j++;
              }
              final kind = p.$1.contains('[') ? FTok.external : FTok.name;
              out.add(FToken(kind, text.substring(i, j)));
              i = j;
              continue;
            }
            var j = i + 1;
            while (j < n && text.codeUnitAt(j) != 0x27) {
              j++;
            }
            final e = j < n ? j + 1 : n;
            out.add(FToken(FTok.unknown, text.substring(i, e)));
            i = e;
            continue;
          }
        }
      }
      if (ColumnLetters.isDigit(c) ||
          (text.startsWith(dialect.decimal, i) &&
              i + 1 < n &&
              ColumnLetters.isDigit(text.codeUnitAt(i + 1)))) {
        final e = _scanNumber(text, i, dialect.decimal);
        out.add(FToken(FTok.number, text.substring(i, e)));
        i = e;
        continue;
      }
      if (_identStart(c)) {
        var j = i + 1;
        while (j < n && _identPart(text.codeUnitAt(j))) {
          j++;
        }
        // `Sheet1!Name` (sheet-qualified name).
        if (j < n && text.codeUnitAt(j) == 0x21) {
          var k = j + 1;
          while (k < n && _identPart(text.codeUnitAt(k))) {
            k++;
          }
          if (k > j + 1) {
            out.add(FToken(FTok.name, text.substring(i, k)));
            i = k;
            continue;
          }
        }
        final word = text.substring(i, j);
        if (j < n && text.codeUnitAt(j) == 0x5b) {
          final e = _scanBrackets(text, j);
          out.add(FToken(FTok.structured, text.substring(i, e)));
          i = e;
          continue;
        }
        final upper = word.toUpperCase();
        if (j < n && text.codeUnitAt(j) == 0x28) {
          out.add(FToken(FTok.func, word));
        } else if (upper == 'TRUE' || upper == 'FALSE') {
          out.add(FToken(FTok.boolean, word));
        } else {
          out.add(FToken(FTok.name, word));
        }
        i = j;
        continue;
      }
      if (c == 0x28) {
        stack.add(c);
        out.add(FToken(FTok.open, '('));
        i++;
        continue;
      }
      if (c == 0x29) {
        if (stack.isNotEmpty && stack.last == 0x28) stack.removeLast();
        out.add(FToken(FTok.close, ')'));
        i++;
        continue;
      }
      if (c == 0x7b) {
        stack.add(c);
        out.add(FToken(FTok.openBrace, '{'));
        i++;
        continue;
      }
      if (c == 0x7d) {
        if (stack.isNotEmpty && stack.last == 0x7b) stack.removeLast();
        out.add(FToken(FTok.closeBrace, '}'));
        i++;
        continue;
      }
      final inBrace = stack.isNotEmpty && stack.last == 0x7b;
      if (inBrace) {
        if (text.startsWith(dialect.arrayRowSeparator, i)) {
          out.add(FToken(FTok.rowSep, dialect.arrayRowSeparator));
          i += dialect.arrayRowSeparator.length;
          continue;
        }
        if (text.startsWith(dialect.arrayColSeparator, i)) {
          out.add(FToken(FTok.sep, dialect.arrayColSeparator));
          i += dialect.arrayColSeparator.length;
          continue;
        }
      } else if (text.startsWith(dialect.argSeparator, i)) {
        out.add(FToken(FTok.sep, dialect.argSeparator));
        i += dialect.argSeparator.length;
        continue;
      }
      if (c == 0x40) {
        out.add(FToken(FTok.at, '@'));
        i++;
        continue;
      }
      if (c == 0x3c || c == 0x3e) {
        if (i + 1 < n) {
          final d = text.codeUnitAt(i + 1);
          if (d == 0x3d || (c == 0x3c && d == 0x3e)) {
            out.add(FToken(FTok.op, text.substring(i, i + 2)));
            i += 2;
            continue;
          }
        }
        out.add(FToken(FTok.op, text[i]));
        i++;
        continue;
      }
      if ('+-*/^&=%:'.contains(text[i])) {
        out.add(FToken(FTok.op, text[i]));
        i++;
        continue;
      }
      out.add(FToken(FTok.unknown, text[i]));
      i++;
    }
    return out;
  }

  static int _scanBrackets(String text, int i) {
    var depth = 0;
    var j = i;
    while (j < text.length) {
      final d = text.codeUnitAt(j);
      if (d == 0x27 && j + 1 < text.length) {
        j += 2; // escaped char in structured refs
        continue;
      }
      if (d == 0x5b) depth++;
      if (d == 0x5d) {
        depth--;
        if (depth == 0) return j + 1;
      }
      j++;
    }
    return text.length;
  }

  static int _scanNumber(String text, int i, String decimal) {
    final n = text.length;
    var j = i;
    while (j < n && ColumnLetters.isDigit(text.codeUnitAt(j))) {
      j++;
    }
    if (text.startsWith(decimal, j)) {
      j += decimal.length;
      while (j < n && ColumnLetters.isDigit(text.codeUnitAt(j))) {
        j++;
      }
    }
    if (j < n && (text.codeUnitAt(j) == 0x45 || text.codeUnitAt(j) == 0x65)) {
      var k = j + 1;
      if (k < n && (text.codeUnitAt(k) == 0x2b || text.codeUnitAt(k) == 0x2d)) {
        k++;
      }
      if (k < n && ColumnLetters.isDigit(text.codeUnitAt(k))) {
        while (k < n && ColumnLetters.isDigit(text.codeUnitAt(k))) {
          k++;
        }
        j = k;
      }
    }
    return j;
  }

  /// Joins token texts.
  static String render(Iterable<FToken> tokens) {
    final b = StringBuffer();
    for (final t in tokens) {
      b.write(t.text);
    }
    return b.toString();
  }

  /// Renders a reference token's area (sheet quoting normalized).
  static String formatArea(A1Area a) => a.format();
}

/// Token-level formula rewrites shared by the importers, exporters and the
/// planner.
abstract final class FormulaRewriter {
  /// Shifts relative references by ([dRow], [dCol]) (shared formulas,
  /// copy semantics). References moved outside the grid become `#REF!`.
  static String shift(
    String formula,
    int dRow,
    int dCol, {
    int maxRows = 10000000,
    int maxCols = 18278,
  }) {
    if (dRow == 0 && dCol == 0) return formula;
    final tokens = FormulaTokenizer.tokenize(formula);
    return shiftTokens(tokens, dRow, dCol, maxRows: maxRows, maxCols: maxCols);
  }

  /// [shift] on pre-tokenized input (tokens are not modified).
  static String shiftTokens(
    List<FToken> tokens,
    int dRow,
    int dCol, {
    int maxRows = 10000000,
    int maxCols = 18278,
  }) {
    final b = StringBuffer();
    for (final t in tokens) {
      if (t.kind != FTok.ref || t.area == null) {
        b.write(t.text);
        continue;
      }
      final shifted = shiftArea(
        t.area!,
        dRow,
        dCol,
        maxRows: maxRows,
        maxCols: maxCols,
      );
      b.write(shifted == null ? '#REF!' : shifted.format());
    }
    return b.toString();
  }

  /// Shifts the relative parts of [a]; null when out of the grid.
  static A1Area? shiftArea(
    A1Area a,
    int dRow,
    int dCol, {
    int maxRows = 10000000,
    int maxCols = 18278,
  }) {
    int? r(int? v, bool abs) => v == null ? null : (abs ? v : v + dRow);
    int? c(int? v, bool abs) => v == null ? null : (abs ? v : v + dCol);
    final r1 = r(a.row1, a.absRow1);
    final r2 = r(a.row2, a.absRow2);
    final c1 = c(a.col1, a.absCol1);
    final c2 = c(a.col2, a.absCol2);
    bool badR(int? v) => v != null && (v < 0 || v >= maxRows);
    bool badC(int? v) => v != null && (v < 0 || v >= maxCols);
    if (badR(r1) || badR(r2) || badC(c1) || badC(c2)) return null;
    return A1Area.raw(
      a.kind,
      sheet: a.sheet,
      row1: r1,
      col1: c1,
      row2: r2,
      col2: c2,
      absRow1: a.absRow1,
      absCol1: a.absCol1,
      absRow2: a.absRow2,
      absCol2: a.absCol2,
    );
  }

  /// Renames sheet prefixes of references (old name, case-insensitive →
  /// new name).
  static String renameSheets(String formula, Map<String, String> renames) {
    if (renames.isEmpty) return formula;
    final lower = {
      for (final e in renames.entries) e.key.toLowerCase(): e.value,
    };
    final tokens = FormulaTokenizer.tokenize(formula);
    var changed = false;
    for (final t in tokens) {
      if (t.kind == FTok.ref && t.area?.sheet != null) {
        final nn = lower[t.area!.sheet!.toLowerCase()];
        if (nn != null) {
          t.area = t.area!.withSheet(nn);
          t.text = t.area!.format();
          changed = true;
        }
      } else if (t.kind == FTok.name && t.text.contains('!')) {
        final bang = t.text.lastIndexOf('!');
        final sheet = SheetNames.unquote(t.text.substring(0, bang));
        final nn = lower[sheet.toLowerCase()];
        if (nn != null) {
          t.text = '${SheetNames.quoteIfNeeded(nn)}${t.text.substring(bang)}';
          changed = true;
        }
      }
    }
    return changed ? FormulaTokenizer.render(tokens) : formula;
  }

  /// Renames name tokens (case-insensitive).
  static String renameNames(String formula, Map<String, String> renames) {
    if (renames.isEmpty) return formula;
    final lower = {
      for (final e in renames.entries) e.key.toLowerCase(): e.value,
    };
    final tokens = FormulaTokenizer.tokenize(formula);
    var changed = false;
    for (final t in tokens) {
      if (t.kind == FTok.name) {
        final nn = lower[t.text.toLowerCase()];
        if (nn != null) {
          t.text = nn;
          changed = true;
        }
      }
    }
    return changed ? FormulaTokenizer.render(tokens) : formula;
  }

  /// Converts a formula typed in [dialect] (e.g. de_DE `SUM(1,5;A1)`) to
  /// canonical separators (`SUM(1.5,A1)`).
  static String toCanonical(String formula, FormulaDialect dialect) {
    if (identical(dialect, FormulaDialect.canonical) ||
        (dialect.argSeparator == ',' &&
            dialect.decimal == '.' &&
            dialect.arrayColSeparator == ',')) {
      return formula;
    }
    final tokens = FormulaTokenizer.tokenize(formula, dialect: dialect);
    for (final t in tokens) {
      switch (t.kind) {
        case FTok.sep:
          t.text = ',';
        case FTok.rowSep:
          t.text = ';';
        case FTok.number:
          t.text = t.text.replaceAll(dialect.decimal, '.');
        default:
          break;
      }
    }
    return FormulaTokenizer.render(tokens);
  }

  /// Whether an Excel dynamic-array formula needs Wonky's array mode
  /// (`ARRAYFORMULA(...)`) to evaluate the same: false when the whole
  /// formula is one reference, an array literal, or one call of a function
  /// that returns arrays by itself ([FunctionMap.arrayResult]).
  static bool needsArrayMode(String formula) {
    final tokens = [
      for (final t in FormulaTokenizer.tokenize(formula))
        if (t.kind != FTok.ws) t,
    ];
    if (tokens.isEmpty) return false;
    if (tokens.length == 1) {
      return tokens.single.kind != FTok.ref &&
          tokens.single.kind != FTok.name &&
          tokens.single.kind != FTok.stored;
    }
    final first = tokens.first;
    if (first.kind == FTok.openBrace) {
      return _closing(tokens, 0) != tokens.length - 1;
    }
    if (first.kind == FTok.func &&
        tokens[1].kind == FTok.open &&
        FunctionMap.arrayResult.contains(
          FunctionMap.stripPrefixes(first.text).toUpperCase(),
        )) {
      return _closing(tokens, 1) != tokens.length - 1;
    }
    return true;
  }

  /// Index of the bracket closing the one at [start], or -1.
  static int _closing(List<FToken> tokens, int start) {
    var depth = 0;
    for (var i = start; i < tokens.length; i++) {
      final k = tokens[i].kind;
      if (k == FTok.open || k == FTok.openBrace) depth++;
      if (k == FTok.close || k == FTok.closeBrace) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Function names used in [formula] (upper case).
  static Set<String> functionNames(String formula) => {
    for (final t in FormulaTokenizer.tokenize(formula))
      if (t.kind == FTok.func) t.text.toUpperCase(),
  };
}
