import '../../addressing/sheet_names.dart';
import 'formula_tokens.dart';
import 'function_map.dart';

/// Result of a formula translation.
final class FormulaTranslation {
  /// Creates a result.
  const FormulaTranslation(
    this.formula, {
    this.unsupported = const {},
    this.notes = const [],
    this.changedSemantics = false,
  });

  /// The translated formula (without leading `=`).
  final String formula;

  /// Unsupported function names (upper case) or constructs
  /// (`external reference`, `structured reference`, `3D reference`).
  final Set<String> unsupported;

  /// Informational notes (e.g. Google-only functions on export).
  final List<String> notes;

  /// Whether a construct with possibly different semantics was removed
  /// (implicit intersection `@`).
  final bool changedSemantics;

  /// Whether the formula can be used as is.
  bool get isSupported => unsupported.isEmpty;
}

/// Wonky A1 ⇄ Excel A1 formula translation (11 §5.3), at the token level so
/// spacing and literal spelling survive.
final class ExcelFormulaTranslator {
  /// Creates a translator.
  ///
  /// - [isSupportedFunction]: whether Wonky implements a function (upper
  ///   case, no prefixes); when null only [FunctionMap.excelOnly] functions are
  ///   unsupported.
  /// - [knownNames]: workbook names (named ranges/functions) that may be
  ///   called like functions.
  /// - [nameRenames]: renamed names (sheet-scoped XLSX names), applied to
  ///   name tokens on import.
  /// - [sheetRenames]: renamed sheets, applied to reference prefixes.
  ExcelFormulaTranslator({
    this.isSupportedFunction,
    Set<String> knownNames = const {},
    this.nameRenames = const {},
    this.sheetRenames = const {},
  }) : knownNames = {for (final n in knownNames) n.toUpperCase()};

  final bool Function(String upperName)? isSupportedFunction;
  final Set<String> knownNames;
  final Map<String, String> nameRenames;
  final Map<String, String> sheetRenames;

  /// Excel (OOXML storage form, without `=`) → Wonky A1.
  FormulaTranslation importFormula(String excel) {
    final tokens = FormulaTokenizer.tokenize(excel);
    final unsupported = <String>{};
    var changed = false;
    final lambdaNames = _boundNames(tokens);
    final renames = {
      for (final e in nameRenames.entries) e.key.toLowerCase(): e.value,
    };
    final sheetMap = {
      for (final e in sheetRenames.entries) e.key.toLowerCase(): e.value,
    };
    final out = <FToken>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      switch (t.kind) {
        case FTok.func:
          var stripped = FunctionMap.stripPrefixes(t.text);
          if (stripped.length > 6 &&
              stripped.substring(0, 6).toLowerCase() == '_xlpm.') {
            stripped = stripped.substring(6);
          }
          final upper = stripped.toUpperCase();
          if (upper == 'SINGLE') {
            // `_xlfn.SINGLE(x)` is the stored form of `@x`.
            changed = true;
            continue;
          }
          if ((upper == 'TRUE' || upper == 'FALSE') &&
              i + 2 < tokens.length &&
              tokens[i + 1].kind == FTok.open &&
              tokens[i + 2].kind == FTok.close) {
            out.add(FToken(FTok.boolean, upper));
            i += 2;
            continue;
          }
          final isLocal =
              lambdaNames.contains(upper) || knownNames.contains(upper);
          if (!isLocal) {
            if (FunctionMap.excelOnly.contains(upper) &&
                !(isSupportedFunction?.call(upper) ?? false)) {
              unsupported.add(upper);
            } else if (isSupportedFunction != null &&
                !isSupportedFunction!(upper)) {
              unsupported.add(upper);
            }
          }
          out.add(FToken(FTok.func, isLocal ? stripped : upper));
        case FTok.name:
          var text = t.text;
          if (text.length > 6 &&
              text.substring(0, 6).toLowerCase() == '_xlpm.') {
            text = text.substring(6);
          }
          final bang = text.lastIndexOf('!');
          if (bang > 0) {
            final sheet = SheetNames.unquote(text.substring(0, bang));
            final nn = sheetMap[sheet.toLowerCase()] ?? sheet;
            final local = text.substring(bang + 1);
            text =
                '${SheetNames.quoteIfNeeded(nn)}!${renames[local.toLowerCase()] ?? local}';
          } else {
            text = renames[text.toLowerCase()] ?? text;
          }
          // `Sheet1:Sheet3!A1` (3D reference).
          if (i + 2 < tokens.length &&
              tokens[i + 1].kind == FTok.op &&
              tokens[i + 1].text == ':' &&
              tokens[i + 2].kind == FTok.ref &&
              tokens[i + 2].area?.sheet != null) {
            unsupported.add('3D reference');
          }
          out.add(FToken(FTok.name, text));
        case FTok.ref:
          var a = t.area!;
          final s = a.sheet;
          if (s != null) {
            final nn = sheetMap[s.toLowerCase()];
            if (nn != null) a = a.withSheet(nn);
          }
          out.add(FToken(FTok.ref, a.format(), a));
        case FTok.external:
          unsupported.add('external reference');
          out.add(t);
        case FTok.structured:
          unsupported.add('structured reference');
          out.add(t);
        case FTok.at:
          changed = true;
        case FTok.spill:
          // `A1#` → ANCHORARRAY(A1): wrap the previous reference.
          final prev = out.isNotEmpty
              ? out.removeLast()
              : FToken(FTok.unknown, '');
          out
            ..add(FToken(FTok.func, 'ANCHORARRAY'))
            ..add(FToken(FTok.open, '('))
            ..add(prev)
            ..add(FToken(FTok.close, ')'));
          if (!(isSupportedFunction?.call('ANCHORARRAY') ?? false)) {
            unsupported.add('ANCHORARRAY');
          }
        case FTok.boolean:
          out.add(FToken(FTok.boolean, t.text.toUpperCase()));
        case FTok.error:
          out.add(FToken(FTok.error, t.text.toUpperCase()));
        default:
          out.add(t);
      }
    }
    return FormulaTranslation(
      FormulaTokenizer.render(out),
      unsupported: unsupported,
      changedSemantics: changed,
    );
  }

  /// Wonky A1 (without `=`) → Excel OOXML storage form.
  FormulaTranslation exportFormula(String wonky) {
    final tokens = FormulaTokenizer.tokenize(wonky);
    final bound = _boundNames(tokens);
    final notes = <String>[];
    final googleOnly = <String>{};
    final sheetMap = {
      for (final e in sheetRenames.entries) e.key.toLowerCase(): e.value,
    };
    for (final t in tokens) {
      switch (t.kind) {
        case FTok.func:
          final upper = t.text.toUpperCase();
          if (bound.contains(upper) || knownNames.contains(upper)) {
            if (bound.contains(upper)) t.text = '_xlpm.${t.text}';
            continue;
          }
          if (FunctionMap.googleOnly.contains(upper)) googleOnly.add(upper);
          t.text = '${FunctionMap.excelPrefix(upper)}$upper';
        case FTok.name:
          if (bound.contains(t.text.toUpperCase())) t.text = '_xlpm.${t.text}';
        case FTok.ref:
          final s = t.area!.sheet;
          if (s != null && sheetMap.containsKey(s.toLowerCase())) {
            t.area = t.area!.withSheet(sheetMap[s.toLowerCase()]);
          }
          t.text = t.area!.format();
        default:
          break;
      }
    }
    for (final g in googleOnly) {
      notes.add('Function $g is not available in Excel');
    }
    return FormulaTranslation(
      FormulaTokenizer.render(tokens),
      unsupported: googleOnly,
      notes: notes,
    );
  }

  /// Names bound by LET/LAMBDA anywhere in the formula (upper case).
  static Set<String> _boundNames(List<FToken> tokens) {
    final names = <String>{};
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.kind != FTok.func) continue;
      final upper = FunctionMap.stripPrefixes(t.text).toUpperCase();
      if (upper != 'LET' && upper != 'LAMBDA') continue;
      // Collect top-level arguments of this call.
      final args = <List<FToken>>[[]];
      var depth = 0;
      var j = i + 1;
      for (; j < tokens.length; j++) {
        final u = tokens[j];
        if (u.kind == FTok.open || u.kind == FTok.openBrace) {
          depth++;
          if (depth == 1) continue;
        } else if (u.kind == FTok.close || u.kind == FTok.closeBrace) {
          depth--;
          if (depth == 0) break;
        } else if (u.kind == FTok.sep && depth == 1) {
          args.add([]);
          continue;
        }
        if (depth >= 1) args.last.add(u);
      }
      String? single(List<FToken> a) {
        final sig = a.where((x) => x.kind != FTok.ws).toList();
        if (sig.length != 1 || sig.single.kind != FTok.name) return null;
        var n = sig.single.text;
        if (n.toLowerCase().startsWith('_xlpm.')) n = n.substring(6);
        return n.toUpperCase();
      }

      if (upper == 'LET') {
        for (var k = 0; k + 1 < args.length; k += 2) {
          final n = single(args[k]);
          if (n != null) names.add(n);
        }
      } else {
        for (var k = 0; k + 1 < args.length; k++) {
          final n = single(args[k]);
          if (n != null) names.add(n);
        }
      }
    }
    return names;
  }
}

/// Expands XLSX shared formulas (`<f t="shared" si>`): the master formula
/// is tokenized once and shifted per dependent cell.
final class SharedFormula {
  /// Creates a shared formula anchored at ([row], [col]).
  SharedFormula(this.formula, this.row, this.col)
    : _tokens = FormulaTokenizer.tokenize(formula);

  /// The master formula (any dialect using A1 references).
  final String formula;
  final int row;
  final int col;
  final List<FToken> _tokens;

  /// The formula as seen from ([r], [c]).
  String at(int r, int c) => r == row && c == col
      ? formula
      : FormulaRewriter.shiftTokens(
          _tokens,
          r - row,
          c - col,
          maxRows: 1048576,
          maxCols: 16384,
        );
}
