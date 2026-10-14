import '../external/external_data.dart';
import '../functions/registry.dart';
import '../model/workbook_view.dart';
import '../parser/formula_locale.dart';
import '../parser/lexer.dart';
import 'call_context.dart';

/// Kinds of completion items (05 §18).
enum CompletionKind {
  builtin,
  namedFunction,
  customFunction,
  namedRange,
  letName,
  sheet,
}

/// One completion candidate.
final class CompletionItem {
  final CompletionKind kind;
  final String name;
  final String summary;

  /// Text inserted for the replaced prefix (`VLOOKUP(` for functions, the name otherwise).
  final String insertText;

  /// Matched character ranges inside [name] (for bold rendering).
  final List<(int, int)> matches;

  /// Category label for built-ins.
  final String? category;

  const CompletionItem({
    required this.kind,
    required this.name,
    required this.summary,
    required this.insertText,
    this.matches = const [],
    this.category,
  });

  @override
  String toString() => 'CompletionItem(${kind.name} $name)';
}

/// Completions at a caret; [replaceStart]..[replaceEnd] is the prefix being replaced.
final class CompletionList {
  final List<CompletionItem> items;
  final int replaceStart;
  final int replaceEnd;
  final String prefix;
  const CompletionList(
    this.items,
    this.replaceStart,
    this.replaceEnd,
    this.prefix,
  );

  static const CompletionList empty = CompletionList([], 0, 0, '');
  bool get isEmpty => items.isEmpty;
}

/// Inputs for [completionsAt].
final class CompletionContext {
  final FunctionRegistry registry;
  final Iterable<NamedRangeView> names;
  final Iterable<String> sheetNames;
  final CustomFunctionProvider? customFunctions;

  /// Names of custom functions (the provider has no listing API).
  final Iterable<String> customFunctionNames;
  final FormulaLocale locale;

  /// Per-user usage counts (03 §8.7); falls back to a shipped popularity table.
  final Map<String, int> usage;
  final int maxItems;

  CompletionContext({
    FunctionRegistry? registry,
    this.names = const [],
    this.sheetNames = const [],
    this.customFunctions,
    this.customFunctionNames = const [],
    this.locale = FormulaLocale.enUS,
    this.usage = const {},
    this.maxItems = 20,
  }) : registry = registry ?? FunctionRegistry.standard;
}

/// Popularity of common functions (ties in ranking, 05 §4.3).
const Map<String, int> functionPopularity = {
  'SUM': 100,
  'IF': 95,
  'VLOOKUP': 90,
  'COUNTIF': 85,
  'AVERAGE': 84,
  'SUMIF': 80,
  'COUNT': 78, //
  'INDEX': 76,
  'MATCH': 75,
  'XLOOKUP': 74,
  'IFERROR': 73,
  'FILTER': 72,
  'COUNTA': 70,
  'MAX': 69, //
  'MIN': 68,
  'ROUND': 67,
  'TODAY': 66,
  'NOW': 65,
  'CONCATENATE': 64,
  'SUMIFS': 63,
  'COUNTIFS': 62, //
  'UNIQUE': 61,
  'SORT': 60,
  'QUERY': 59,
  'ARRAYFORMULA': 58,
  'TEXT': 57,
  'LEFT': 56,
  'RIGHT': 55, //
  'MID': 54,
  'LEN': 53,
  'TRIM': 52,
  'SPLIT': 51,
  'DATE': 50,
  'AND': 49,
  'OR': 48,
  'NOT': 47, //
  'IMPORTRANGE': 46,
  'REGEXMATCH': 45,
  'SUBSTITUTE': 44,
  'IFS': 43,
  'AVERAGEIF': 42,
  'ABS': 41, //
  'VALUE': 40,
  'UPPER': 39,
  'LOWER': 38,
  'PROPER': 37,
  'TEXTJOIN': 36,
  'SEQUENCE': 35, //
};

bool _identChar(int c) => FormulaLexer.isIdentPart(c);

/// Ranked completions for the identifier prefix ending at [caret] (05 §4.3). Empty when the
/// caret is not at the end of an identifier in an expression position.
CompletionList completionsAt(String text, int caret, CompletionContext ctx) {
  if (caret > text.length || caret <= 0) return CompletionList.empty;
  if (!text.startsWith('=') && !text.startsWith('+') && !text.startsWith('-')) {
    return CompletionList.empty;
  }
  final tokens = FormulaLexer(
    locale: ctx.locale,
    storedForm: false,
  ).tokenize(text);
  // inside a string → no completions
  for (final t in tokens) {
    if ((t.kind == TokenKind.string ||
            t.kind == TokenKind.unterminatedString) &&
        t.start < caret &&
        caret < t.end + (t.kind == TokenKind.unterminatedString ? 1 : 0)) {
      return CompletionList.empty;
    }
  }
  // quoted sheet name completion: ='My s|
  final q = text.lastIndexOf("'", caret - 1);
  if (q >= 0) {
    final between = text.substring(q + 1, caret);
    final quotesBefore = "'".allMatches(text.substring(0, q)).length;
    if (quotesBefore.isEven &&
        !between.contains("'") &&
        !between.contains('!')) {
      final items = <CompletionItem>[];
      final low = between.toLowerCase();
      for (final s in ctx.sheetNames) {
        if (s.toLowerCase().startsWith(low)) {
          items.add(
            CompletionItem(
              kind: CompletionKind.sheet,
              name: s,
              summary: 'Sheet',
              insertText: "'${s.replaceAll("'", "''")}'!",
              matches: [(0, between.length)],
            ),
          );
        }
      }
      if (items.isNotEmpty) {
        return CompletionList(
          items.take(ctx.maxItems).toList(),
          q,
          caret,
          between,
        );
      }
    }
  }
  var start = caret;
  while (start > 0 && _identChar(text.codeUnitAt(start - 1))) {
    start--;
  }
  if (start == caret) return CompletionList.empty;
  if (!FormulaLexer.isIdentStart(text.codeUnitAt(start))) {
    return CompletionList.empty;
  }
  if (caret < text.length && _identChar(text.codeUnitAt(caret))) {
    return CompletionList.empty;
  }
  // expression position: previous significant char
  var p = start - 1;
  while (p >= 0 && ' \t\r\n'.contains(text[p])) {
    p--;
  }
  if (p >= 0) {
    final c = text[p];
    const allowed = '=+-*/^&<>(,;:{}%\\';
    if (!allowed.contains(c) && c != ctx.locale.argSeparator) {
      return CompletionList.empty;
    }
  }
  final prefix = text.substring(start, caret);
  final up = prefix.toUpperCase();
  final scored = <(int, CompletionItem)>[];

  int? score(String name) {
    final n = name.toUpperCase();
    if (n.startsWith(up)) return 3000 - n.length;
    // word start inside dotted / underscored names: DIST → NORM.DIST
    for (var i = 1; i < n.length; i++) {
      final prev = n[i - 1];
      if ((prev == '.' || prev == '_') && n.startsWith(up, i)) {
        return 2000 - n.length;
      }
    }
    // fuzzy subsequence
    var k = 0;
    for (var i = 0; i < n.length && k < up.length; i++) {
      if (n[i] == up[k]) k++;
    }
    if (k == up.length && up.length >= 2) return 1000 - n.length;
    return null;
  }

  List<(int, int)> matchesOf(String name) {
    final n = name.toUpperCase();
    final i = n.indexOf(up);
    return i >= 0 ? [(i, i + up.length)] : const [];
  }

  int popularity(String name) =>
      ctx.usage[name] ?? functionPopularity[name] ?? 0;

  for (final spec in ctx.registry.all) {
    if (!spec.implemented) continue;
    // Display language (P2): the localized name is listed and inserted;
    // the English name still matches.
    final shown = ctx.locale.displayFunction(spec.name);
    var s = score(shown);
    if (shown != spec.name) {
      final en = score(spec.name);
      if (en != null && (s == null || en > s)) s = en;
    }
    if (s == null) continue;
    scored.add((
      s * 1000 + popularity(spec.name),
      CompletionItem(
        kind: CompletionKind.builtin,
        name: shown,
        summary: spec.help.summary,
        insertText: '$shown(',
        matches: matchesOf(shown),
        category: spec.category.label,
      ),
    ));
  }
  for (final n in ctx.names) {
    final s = score(n.name);
    if (s == null) continue;
    final isFn = n.range == null && n.formula != null;
    scored.add((
      s * 1000 + 500,
      CompletionItem(
        kind: isFn ? CompletionKind.namedFunction : CompletionKind.namedRange,
        name: n.name,
        summary: n.comment ?? (isFn ? 'Named function' : 'Named range'),
        insertText: isFn ? '${n.name}(' : n.name,
        matches: matchesOf(n.name),
      ),
    ));
  }
  final cp = ctx.customFunctions;
  for (final name in ctx.customFunctionNames) {
    final s = score(name);
    if (s == null) continue;
    final summary = cp != null && cp.has(name.toUpperCase())
        ? cp.help(name.toUpperCase()).summary
        : 'Custom function';
    scored.add((
      s * 1000 + 400,
      CompletionItem(
        kind: CompletionKind.customFunction,
        name: name,
        summary: summary,
        insertText: '$name(',
        matches: matchesOf(name),
      ),
    ));
  }
  // LET / LAMBDA names in scope
  final frames = openFrames(tokens, start);
  final seen = <String>{};
  for (final f in frames) {
    final fn = f.name?.toUpperCase();
    if (fn != 'LET' && fn != 'LAMBDA') continue;
    f.nameArgs.forEach((idx, name) {
      final isName = fn == 'LAMBDA' || idx.isEven;
      if (!isName || !seen.add(name.toUpperCase())) return;
      final s = score(name);
      if (s == null) return;
      scored.add((
        s * 1000 + 900,
        CompletionItem(
          kind: CompletionKind.letName,
          name: name,
          summary: '$fn variable',
          insertText: name,
          matches: matchesOf(name),
        ),
      ));
    });
  }
  scored.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    return c != 0 ? c : a.$2.name.compareTo(b.$2.name);
  });
  return CompletionList(
    [for (final s in scored.take(ctx.maxItems)) s.$2],
    start,
    caret,
    prefix,
  );
}
