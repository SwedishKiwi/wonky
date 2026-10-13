import '../../addressing/a1.dart';
import '../../addressing/sheet_names.dart';
import 'excel_formula_translator.dart';
import 'formula_tokens.dart';

/// ODF OpenFormula (`of:=SUM([.A1:.A3])`) ⇄ Wonky A1 (11 §5.5, §6.4).
final class OpenFormulaTranslator {
  /// Creates a translator; [excel] handles `msoxl:` formulas.
  OpenFormulaTranslator({ExcelFormulaTranslator? excel})
    : excel = excel ?? ExcelFormulaTranslator();

  final ExcelFormulaTranslator excel;

  static const _namespacePrefixes = [
    'COM.MICROSOFT.',
    'ORG.OPENOFFICE.',
    'ORG.LIBREOFFICE.',
    '_XLFN.',
  ];

  /// `table:formula` value → Wonky A1 (without `=`).
  FormulaTranslation importFormula(String odf) {
    var s = odf.trim();
    if (s.toLowerCase().startsWith('msoxl:')) {
      s = s.substring(6);
      if (s.startsWith('=')) s = s.substring(1);
      return excel.importFormula(s);
    }
    final colon = s.indexOf(':');
    if (colon > 0 &&
        colon < 8 &&
        RegExp(r'^[a-z]+$').hasMatch(s.substring(0, colon))) {
      s = s.substring(colon + 1);
    }
    if (s.startsWith('=')) s = s.substring(1);
    final unsupported = <String>{};
    final b = StringBuffer();
    var braces = 0;
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"') {
        final j = _skipString(s, i);
        b.write(s.substring(i, j));
        i = j;
        continue;
      }
      if (ch == '[') {
        final j = _findClose(s, i);
        final inner = s.substring(i + 1, j);
        final ref = _importRef(inner);
        if (ref == null) {
          unsupported.add('reference [$inner]');
          b.write('#REF!');
        } else {
          b.write(ref);
        }
        i = j + 1;
        continue;
      }
      if (ch == '{') braces++;
      if (ch == '}') braces--;
      if (ch == ';') {
        b.write(',');
      } else if (ch == '|' && braces > 0) {
        b.write(';');
      } else if (ch == '!' || ch == '~') {
        unsupported.add(ch == '!' ? 'intersection operator' : 'union operator');
        b.write(ch);
      } else {
        b.write(ch);
      }
      i++;
    }
    final tokens = FormulaTokenizer.tokenize(b.toString());
    final out = <FToken>[];
    for (var k = 0; k < tokens.length; k++) {
      final t = tokens[k];
      if (t.kind == FTok.func) {
        var name = t.text.toUpperCase();
        for (final p in _namespacePrefixes) {
          if (name.startsWith(p)) name = name.substring(p.length);
        }
        if ((name == 'TRUE' || name == 'FALSE') &&
            k + 2 < tokens.length &&
            tokens[k + 1].kind == FTok.open &&
            tokens[k + 2].kind == FTok.close) {
          out.add(FToken(FTok.boolean, name));
          k += 2;
          continue;
        }
        out.add(FToken(FTok.func, name));
      } else {
        out.add(t);
      }
    }
    final res = excel.importFormula(FormulaTokenizer.render(out));
    return FormulaTranslation(
      res.formula,
      unsupported: {...unsupported, ...res.unsupported},
    );
  }

  /// Wonky A1 (without `=`) → `of:=…`.
  String exportFormula(String wonky) {
    final tokens = FormulaTokenizer.tokenize(wonky);
    final b = StringBuffer('of:=');
    var braces = 0;
    for (final t in tokens) {
      switch (t.kind) {
        case FTok.ref:
          b.write(_exportRef(t.area!));
        case FTok.sep:
          b.write(';');
        case FTok.rowSep:
          b.write('|');
        case FTok.openBrace:
          braces++;
          b.write('{');
        case FTok.closeBrace:
          braces--;
          b.write('}');
        case FTok.boolean:
          b.write('${t.text.toUpperCase()}()');
        default:
          b.write(t.text);
      }
    }
    assert(braces >= 0);
    return b.toString();
  }

  static int _skipString(String s, int i) {
    var j = i + 1;
    while (j < s.length) {
      if (s[j] == '"') {
        if (j + 1 < s.length && s[j + 1] == '"') {
          j += 2;
          continue;
        }
        return j + 1;
      }
      j++;
    }
    return s.length;
  }

  static int _findClose(String s, int i) {
    var j = i + 1;
    var inQuote = false;
    while (j < s.length) {
      final ch = s[j];
      if (ch == "'") {
        if (inQuote && j + 1 < s.length && s[j + 1] == "'") {
          j += 2;
          continue;
        }
        inQuote = !inQuote;
      } else if (ch == ']' && !inQuote) {
        return j;
      }
      j++;
    }
    return s.length - 1;
  }

  /// `$Sheet1.$A$1:.B2` → `Sheet1!$A$1:B2`.
  static String? _importRef(String inner) {
    final parts = _splitColon(inner);
    if (parts.isEmpty || parts.length > 2) return null;
    String? sheet;
    final cells = <String>[];
    for (final p in parts) {
      final (sh, cell) = _splitSheet(p);
      if (sh != null) sheet ??= sh;
      if (cell.isEmpty || cell.toUpperCase().contains('#REF!')) return '#REF!';
      cells.add(cell);
    }
    final text = cells.join(':');
    final area = A1Area.tryParse(text);
    if (area == null) return null;
    return area.withSheet(sheet).format();
  }

  static List<String> _splitColon(String s) {
    final out = <String>[];
    var inQuote = false;
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == "'") inQuote = !inQuote;
      if (ch == ':' && !inQuote) {
        out.add(s.substring(start, i));
        start = i + 1;
      }
    }
    out.add(s.substring(start));
    return out;
  }

  static (String?, String) _splitSheet(String p) {
    var s = p.trim();
    if (s.startsWith(r'$')) s = s.substring(1);
    if (s.startsWith('.')) return (null, s.substring(1));
    if (s.startsWith("'")) {
      var j = 1;
      while (j < s.length) {
        if (s[j] == "'") {
          if (j + 1 < s.length && s[j + 1] == "'") {
            j += 2;
            continue;
          }
          break;
        }
        j++;
      }
      final name = s.substring(1, j).replaceAll("''", "'");
      final rest = j + 1 < s.length && s[j + 1] == '.'
          ? s.substring(j + 2)
          : s.substring(j + 1);
      return (name, rest);
    }
    final dot = s.lastIndexOf('.');
    if (dot < 0) return (null, s);
    return (s.substring(0, dot), s.substring(dot + 1));
  }

  static String _exportRef(A1Area a) {
    final sheet = a.sheet == null ? '' : '\$${_odfSheet(a.sheet!)}';
    final noSheet = a.withSheet(null);
    final area = noSheet.formatArea();
    final colon = area.indexOf(':');
    if (colon < 0) return '[$sheet.$area]';
    var second = area.substring(colon + 1);
    if (a.kind == A1Kind.openRows) second = '${second}1048576';
    if (a.kind == A1Kind.openColumns) second = 'XFD$second';
    return '[$sheet.${area.substring(0, colon)}:.$second]';
  }

  static String _odfSheet(String name) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)
      ? name
      : SheetNames.quote(name);
}
