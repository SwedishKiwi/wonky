import 'dart:convert';

import '../external/external_data.dart';
import '../functions/registry.dart';
import '../model/workbook_view.dart';
import '../parser/formula_locale.dart';
import '../parser/lexer.dart';
import 'call_context.dart';

/// Where a signature comes from.
enum SignatureSource { builtin, namedFunction, customFunction, lambda }

/// Signature-help data for the card under the editor (05 §18).
final class SignatureInfo {
  final String functionName;
  final SignatureSource source;

  /// Zero-based index of the argument at the caret.
  final int argIndex;

  /// Index into [params] of the active parameter (repeat groups mapped back).
  final int activeParam;

  /// Index of the active repeat group (0 for the first occurrence), or null.
  final int? activeRepeatGroup;

  /// Parameter names (with `[…]` for optional ones as in the syntax).
  final List<String> params;
  final FunctionHelp? help;
  final FunctionSpec? spec;

  /// Offset of the function name.
  final int callStart;

  const SignatureInfo({
    required this.functionName,
    required this.source,
    required this.argIndex,
    required this.activeParam,
    required this.params,
    required this.callStart,
    this.activeRepeatGroup,
    this.help,
    this.spec,
  });

  @override
  String toString() =>
      'SignatureInfo($functionName, arg $argIndex → param $activeParam)';
}

/// Signature help (05 §4.3): innermost unclosed call at [caret].
SignatureInfo? signatureAt(
  String text,
  int caret, {
  FormulaLocale locale = FormulaLocale.enUS,
  FunctionRegistry? registry,
  Iterable<NamedRangeView> namedFunctions = const [],
  CustomFunctionProvider? customFunctions,
}) {
  final reg = registry ?? FunctionRegistry.standard;
  final tokens = FormulaLexer(locale: locale, storedForm: false).tokenize(text);
  final frames = openFrames(tokens, caret);
  for (var i = frames.length - 1; i >= 0; i--) {
    final f = frames[i];
    if (f.name == null) continue;
    final upper = f.name!.toUpperCase();
    final spec = reg.lookup(upper);
    if (spec != null && upper != 'LET' && upper != 'LAMBDA') {
      final rs = spec.repeatStart;
      var active = f.argIndex;
      int? group;
      if (active >= spec.params.length && rs >= 0) {
        final size = spec.params.length - rs;
        active = rs + (f.argIndex - rs) % size;
      }
      if (rs >= 0 && f.argIndex >= rs) {
        group = (f.argIndex - rs) ~/ (spec.params.length - rs);
      }
      if (active >= spec.params.length) active = spec.params.length - 1;
      return SignatureInfo(
        functionName: spec.name,
        source: SignatureSource.builtin,
        argIndex: f.argIndex,
        activeParam: active,
        activeRepeatGroup: group,
        params: [
          for (final p in spec.params) p.optional ? '[${p.name}]' : p.name,
        ],
        help: spec.help,
        spec: spec,
        callStart: f.start,
      );
    }
    if (upper == 'LET' || upper == 'LAMBDA') {
      final spec2 = reg.lookup(upper);
      final params = upper == 'LET'
          ? [
              'name1',
              'value_expression1',
              '[name2, value_expression2, …]',
              'formula_expression',
            ]
          : ['[name, …]', 'formula_expression'];
      return SignatureInfo(
        functionName: upper,
        source: SignatureSource.builtin,
        argIndex: f.argIndex,
        activeParam: upper == 'LET' ? (f.argIndex < 2 ? f.argIndex : 2) : 0,
        params: params,
        help: spec2?.help,
        spec: spec2,
        callStart: f.start,
      );
    }
    for (final n in namedFunctions) {
      if (n.name.toUpperCase() != upper || n.formula == null) continue;
      final params = _lambdaParams(n.formula!, locale);
      final meta = _metaParams(n.metaJson);
      return SignatureInfo(
        functionName: n.name,
        source: SignatureSource.namedFunction,
        argIndex: f.argIndex,
        activeParam: params.isEmpty
            ? 0
            : (f.argIndex < params.length ? f.argIndex : params.length - 1),
        params: params,
        help: FunctionHelp(
          summary: n.comment ?? '',
          syntax: '${n.name}(${params.join(', ')})',
          args: [
            for (final p in params) ArgHelp(p, meta[p.toLowerCase()] ?? ''),
          ],
          examples: _metaExamples(n.metaJson),
        ),
        callStart: f.start,
      );
    }
    if (customFunctions != null && customFunctions.has(upper)) {
      final h = customFunctions.help(upper);
      final params = [
        for (final a in h.args) a.optional ? '[${a.name}]' : a.name,
      ];
      return SignatureInfo(
        functionName: upper,
        source: SignatureSource.customFunction,
        argIndex: f.argIndex,
        activeParam: params.isEmpty
            ? 0
            : (f.argIndex < params.length ? f.argIndex : params.length - 1),
        params: params,
        help: h,
        callStart: f.start,
      );
    }
    // a LET-bound lambda called by name: show parameter names when we can find them
    return SignatureInfo(
      functionName: f.name!,
      source: SignatureSource.lambda,
      argIndex: f.argIndex,
      activeParam: f.argIndex,
      params: const [],
      callStart: f.start,
    );
  }
  return null;
}

List<String> _lambdaParams(String formula, FormulaLocale locale) {
  final tokens = FormulaLexer.significant(
    const FormulaLexer().tokenize(
      formula.startsWith('=') ? formula : '=$formula',
    ),
  );
  final out = <String>[];
  for (var i = 0; i + 1 < tokens.length; i++) {
    if (tokens[i].kind == TokenKind.functionName &&
        tokens[i].text.toUpperCase() == 'LAMBDA') {
      var k = i + 2;
      final names = <String>[];
      while (k < tokens.length) {
        final t = tokens[k];
        if (t.kind == TokenKind.name &&
            k + 1 < tokens.length &&
            tokens[k + 1].kind == TokenKind.argSeparator) {
          names.add(t.text);
          k += 2;
          continue;
        }
        break;
      }
      out.addAll(names);
      break;
    }
  }
  return out;
}

Map<String, String> _metaParams(String? metaJson) {
  if (metaJson == null) return const {};
  try {
    final m = jsonDecode(metaJson);
    if (m is! Map) return const {};
    final params = m['params'];
    if (params is! List) return const {};
    return {
      for (final p in params)
        if (p is Map && p['name'] is String)
          (p['name'] as String).toLowerCase():
              (p['description'] as String?) ?? '',
    };
  } on FormatException {
    return const {};
  }
}

List<String> _metaExamples(String? metaJson) {
  if (metaJson == null) return const [];
  try {
    final m = jsonDecode(metaJson);
    if (m is Map && m['examples'] is List) {
      return [
        for (final e in m['examples'] as List)
          if (e is String) e,
      ];
    }
  } on FormatException {
    return const [];
  }
  return const [];
}
