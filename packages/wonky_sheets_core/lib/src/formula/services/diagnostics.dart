import '../ast/ast.dart';
import '../functions/registry.dart';
import '../parser/formula_grammar.dart';
import '../parser/formula_locale.dart';
import '../parser/lexer.dart';
import '../parser/parse_error.dart';
import '../values/errors.dart';
import '../values/fvalue.dart';

/// Error tooltip content (05 §18): title, message and command ids of one-click fixes.
final class ErrorTooltip {
  final String title;
  final String message;

  /// Command ids (05 §19), e.g. `sheets.formula.selectSpillBlockers`.
  final List<String> actions;
  const ErrorTooltip(this.title, this.message, [this.actions = const []]);

  @override
  String toString() => 'ErrorTooltip($title: $message $actions)';
}

/// Describes an error value for the red-triangle tooltip (05 §4.3). Null for non-errors.
ErrorTooltip? describeError(FValue value) {
  if (value is! FError) return null;
  final msg = value.message ?? _defaultMessage(value.kind);
  if (value.pending) return ErrorTooltip('Loading…', msg);
  switch (value.kind) {
    case ErrorKind.parse:
      return ErrorTooltip('Formula parse error', msg);
    case ErrorKind.spill:
      return ErrorTooltip('Error', msg, const [
        'sheets.formula.selectSpillBlockers',
      ]);
    case ErrorKind.ref:
      if (msg == ErrorMessages.circular) {
        return ErrorTooltip('Circular dependency', msg, const [
          'sheets.formula.showCircularPath',
        ]);
      }
      if (msg.startsWith('Result was not automatically expanded')) {
        return ErrorTooltip('Array result too large', msg, const [
          'sheets.formula.insertRowsForSpill',
        ]);
      }
      if (msg.contains('connect these sheets')) {
        return ErrorTooltip('Connect sheets', msg, const [
          'sheets.formula.allowImportRange',
        ]);
      }
      return ErrorTooltip('Error', msg);
    case ErrorKind.na:
      if (msg == ErrorMessages.offline) {
        return ErrorTooltip('Error', msg, const [
          'sheets.formula.refreshExternalData',
        ]);
      }
      return ErrorTooltip('Error', msg);
    case ErrorKind.num:
      if (msg == ErrorMessages.resultTooLarge) {
        return ErrorTooltip('Array result too large', msg);
      }
      return ErrorTooltip('Error', msg);
    default:
      return ErrorTooltip('Error', msg);
  }
}

String _defaultMessage(ErrorKind k) => switch (k) {
  ErrorKind.div0 => 'Division by zero.',
  ErrorKind.value => 'Wrong type of argument.',
  ErrorKind.ref => ErrorMessages.referenceDoesNotExist,
  ErrorKind.name => 'Unknown name.',
  ErrorKind.num => 'Invalid numeric value.',
  ErrorKind.na => 'Value not available.',
  ErrorKind.parse => ErrorMessages.parseError,
  ErrorKind.spill => 'Array result could not be expanded.',
  ErrorKind.calc => 'Calculation error.',
  ErrorKind.nullRef => 'Intersection of ranges is empty.',
};

/// Result of [validateFormula] (MCP `sheets.validate_formula`, 05 §20).
final class FormulaValidation {
  final bool ok;
  final FormulaParseError? error;
  final List<String> functionsUsed;

  /// A1 reference texts in order of appearance.
  final List<String> references;

  /// Names of unknown functions (would evaluate `#NAME?` unless defined).
  final List<String> unknownFunctions;

  const FormulaValidation({
    required this.ok,
    this.error,
    this.functionsUsed = const [],
    this.references = const [],
    this.unknownFunctions = const [],
  });

  Map<String, Object?> toJson() => {
    'ok': ok,
    if (error != null)
      'error': {
        'offset': error!.offset,
        'length': error!.length,
        'message': error!.message,
      },
    'functions_used': functionsUsed,
    'references': references,
    if (unknownFunctions.isNotEmpty) 'unknown_functions': unknownFunctions,
  };
}

/// Validates an A1 formula without a spreadsheet.
FormulaValidation validateFormula(
  String formula, {
  FormulaLocale locale = FormulaLocale.enUS,
  FunctionRegistry? registry,
}) {
  final reg = registry ?? FunctionRegistry.standard;
  final text = formula.startsWith('=') ? formula : '=$formula';
  final (ast, err) = FormulaParser.tryParse(
    text,
    locale: locale,
    storedForm: false,
  );
  final tokens = FormulaLexer(locale: locale, storedForm: false).tokenize(text);
  final refs = [
    for (final t in tokens)
      if (t.ref?.a1 != null) t.text,
  ];
  if (ast == null) {
    return FormulaValidation(ok: false, error: err, references: refs);
  }
  final used = <String>{};
  final unknown = <String>{};
  void walk(Expr e) {
    if (e is CallExpr) {
      final u = e.name.toUpperCase();
      final spec = reg.lookup(u);
      if (spec != null) {
        used.add(spec.name);
      } else if (u != 'LET' && u != 'LAMBDA') {
        unknown.add(e.name);
      } else {
        used.add(u);
      }
    }
    for (final c in e.children) {
      walk(c);
    }
  }

  walk(ast);
  return FormulaValidation(
    ok: true,
    functionsUsed: used.toList()..sort(),
    references: refs,
    unknownFunctions: unknown.toList()..sort(),
  );
}

/// Pretty-prints an AST in canonical A1/en_US form (stored references are rendered with
/// [renderRef]; without it they print as stored tokens).
String printFormula(Expr e, {String Function(RefNode ref)? renderRef}) {
  String p(Expr e) => printFormula(e, renderRef: renderRef);
  String args(List<Expr?> a) => a.map((x) => x == null ? '' : p(x)).join(', ');
  return switch (e) {
    NumberLit(:final value, :final text) => text ?? _num(value),
    StringLit(:final value) => '"${value.replaceAll('"', '""')}"',
    BoolLit(:final value) => value ? 'TRUE' : 'FALSE',
    ErrorLit(:final kind) => kind.literal,
    ArrayLit(:final rows) =>
      '{${rows.map((r) => r.map(p).join(', ')).join('; ')}}',
    RefExpr(:final ref) => renderRef?.call(ref) ?? ref.toString(),
    NameExpr(:final name) => name,
    CallExpr(:final name, args: final a) => '${name.toUpperCase()}(${args(a)})',
    InvokeExpr(:final callee, args: final a) => '${p(callee)}(${args(a)})',
    UnaryExpr(:final op, :final operand) => '${op.symbol}${p(operand)}',
    PercentExpr(:final operand) => '${p(operand)}%',
    BinaryExpr(:final op, :final left, :final right) =>
      '${p(left)} ${op.symbol} ${p(right)}',
    RangeOpExpr(:final left, :final right) => '${p(left)}:${p(right)}',
    ParenExpr(:final inner) => '(${p(inner)})',
  };
}

String _num(double v) => v == v.truncateToDouble() && v.abs() < 1e15
    ? v.toInt().toString()
    : v.toString();
