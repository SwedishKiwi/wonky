import '../eval/args.dart';
import '../values/fvalue.dart';

/// How an argument is evaluated before the implementation sees it (05 §7.3).
enum ArgKind {
  /// Single value; references/arrays use implicit intersection (or lifting in array mode).
  scalar,

  /// Scalar coerced to number.
  number,

  /// Scalar coerced to text.
  text,

  /// Scalar coerced to boolean.
  boolean,

  /// Must be a reference.
  reference,

  /// Reference or array, not lifted, not intersected.
  range,

  /// Evaluated in array mode; result as array (references stay references).
  array,

  /// A function value (LAMBDA).
  lambda,

  /// Unevaluated thunk.
  lazy,

  /// Passed as-is (references kept).
  any;

  bool get isScalarLike =>
      this == ArgKind.scalar || this == ArgKind.number || this == ArgKind.text || this == ArgKind.boolean;
}

/// Function categories in Insert › Function order (05 §14.1).
enum FunctionCategory {
  math('Math'),
  statistical('Statistical'),
  lookup('Lookup'),
  logical('Logical'),
  text('Text'),
  dateTime('Date'),
  financial('Financial'),
  info('Info'),
  array('Array'),
  filter('Filter'),
  database('Database'),
  engineering('Engineering'),
  parser('Parser'),
  operator('Operator'),
  web('Web'),
  google('Google'),
  lambdaHelper('Lambda helpers');

  const FunctionCategory(this.label);
  final String label;
}

enum ReturnKind { scalar, array, reference, lambda, rich }

enum FunctionCost { light, heavy }

enum Priority { p0, p1, p2 }

/// One declared parameter.
final class ArgSpec {
  final String name;
  final ArgKind kind;
  final bool optional;
  final Object? defaultValue;
  final bool repeatable;
  final String description;

  const ArgSpec(
    this.name,
    this.kind, {
    this.optional = false,
    this.defaultValue,
    this.repeatable = false,
    this.description = '',
  });
}

/// Help for one argument.
final class ArgHelp {
  final String name;
  final String description;
  final bool optional;
  final String? defaultText;
  final bool repeatable;
  const ArgHelp(this.name, this.description, {this.optional = false, this.defaultText, this.repeatable = false});

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'optional': optional,
    'default': ?defaultText,
    if (repeatable) 'repeatable': true,
  };
}

/// Help metadata for autocomplete, signature help, Insert › Function, AI and MCP (05 §14.1).
final class FunctionHelp {
  final String summary;
  final String syntax;
  final List<ArgHelp> args;
  final List<String> examples;
  final List<String> seeAlso;
  final String? notes;
  final String? learnMoreSlug;

  const FunctionHelp({
    required this.summary,
    required this.syntax,
    this.args = const [],
    this.examples = const [],
    this.seeAlso = const [],
    this.notes,
    this.learnMoreSlug,
  });

  Map<String, Object?> toJson() => {
    'summary': summary,
    'syntax': syntax,
    'args': [for (final a in args) a.toJson()],
    'examples': examples,
    'seeAlso': seeAlso,
    'notes': ?notes,
  };
}

/// Implementation of a built-in function.
typedef FunctionImpl = FValue Function(Args args);

/// A registered function (05 §14.1).
final class FunctionSpec {
  final String name;
  final List<String> aliases;
  final FunctionCategory category;
  final List<ArgSpec> params;
  final int minArgs;
  final int maxArgs;
  final int repeatGroupSize;
  final ReturnKind returns;
  final bool liftable;
  final bool volatile;
  final bool positionSensitive;
  final bool usesFilterVisibility;
  final bool async;
  final FunctionCost cost;
  final Priority priority;
  final FunctionImpl impl;
  final FunctionHelp help;

  /// Whether scalar error arguments are passed to [impl] instead of being propagated.
  final bool handlesErrors;

  /// False for stubs (`#NAME?` "isn't available"); hidden from autocomplete.
  final bool implemented;

  /// Whether the result is a reference (INDEX, OFFSET, INDIRECT, CHOOSE…).
  bool get returnsReference => returns == ReturnKind.reference;

  const FunctionSpec({
    required this.name,
    this.aliases = const [],
    required this.category,
    required this.params,
    required this.minArgs,
    required this.maxArgs,
    this.repeatGroupSize = 0,
    this.returns = ReturnKind.scalar,
    this.liftable = true,
    this.volatile = false,
    this.positionSensitive = false,
    this.usesFilterVisibility = false,
    this.async = false,
    this.cost = FunctionCost.light,
    this.priority = Priority.p1,
    required this.impl,
    required this.help,
    this.handlesErrors = false,
    this.implemented = true,
  });

  /// Index of the first repeatable parameter, or -1.
  int get repeatStart {
    for (var i = 0; i < params.length; i++) {
      if (params[i].repeatable) return i;
    }
    return -1;
  }

  /// Parameter spec for argument [i] (accounting for repeat groups).
  ArgSpec? paramAt(int i) {
    if (i < params.length) return params[i];
    final rs = repeatStart;
    if (rs < 0) return null;
    final size = params.length - rs;
    return params[rs + (i - rs) % size];
  }

  ArgKind kindAt(int i) => paramAt(i)?.kind ?? ArgKind.scalar;

  Map<String, Object?> toJson() => {
    'name': name,
    'category': category.name,
    'syntax': help.syntax,
    'summary': help.summary,
    'priority': priority.name,
    'implemented': implemented,
    if (aliases.isNotEmpty) 'aliases': aliases,
  };
}
