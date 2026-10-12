import '../eval/args.dart';
import '../values/errors.dart';
import '../values/fvalue.dart';
import 'builtins.dart';
import 'function_spec.dart';

export 'function_spec.dart';

/// Parameter shorthands for registrations.
abstract final class P {
  static ArgSpec _a(
    String name,
    ArgKind k,
    String d,
    bool opt,
    Object? def,
    bool rep,
  ) => ArgSpec(name, k, optional: opt || rep, defaultValue: def, repeatable: rep, description: d);

  static ArgSpec num(String name, [String d = '', bool opt = false, Object? def]) =>
      _a(name, ArgKind.number, d, opt, def, false);
  static ArgSpec text(String name, [String d = '', bool opt = false, Object? def]) =>
      _a(name, ArgKind.text, d, opt, def, false);
  static ArgSpec bool_(String name, [String d = '', bool opt = false, Object? def]) =>
      _a(name, ArgKind.boolean, d, opt, def, false);
  static ArgSpec scalar(String name, [String d = '', bool opt = false, Object? def]) =>
      _a(name, ArgKind.scalar, d, opt, def, false);
  static ArgSpec range(String name, [String d = '', bool opt = false]) =>
      _a(name, ArgKind.range, d, opt, null, false);
  static ArgSpec array(String name, [String d = '', bool opt = false]) =>
      _a(name, ArgKind.array, d, opt, null, false);
  static ArgSpec ref(String name, [String d = '', bool opt = false]) =>
      _a(name, ArgKind.reference, d, opt, null, false);
  static ArgSpec lambda(String name, [String d = '', bool opt = false]) =>
      _a(name, ArgKind.lambda, d, opt, null, false);
  static ArgSpec lazy(String name, [String d = '', bool opt = false]) =>
      _a(name, ArgKind.lazy, d, opt, null, false);
  static ArgSpec any(String name, [String d = '', bool opt = false]) =>
      _a(name, ArgKind.any, d, opt, null, false);

  /// Repeatable parameter (part of the trailing repeat group).
  static ArgSpec rep(String name, ArgKind kind, [String d = '']) =>
      _a(name, kind, d, true, null, true);
}

/// Collects registrations; see [FunctionRegistry.standard].
final class FunctionRegistryBuilder {
  final Map<String, FunctionSpec> _specs = {};
  final Map<String, String> _aliases = {};
  FunctionCategory category = FunctionCategory.math;

  /// Registers a function. Syntax and argument help are derived from [params].
  void fn(
    String name,
    String summary,
    List<ArgSpec> params,
    FunctionImpl impl, {
    List<String> aliases = const [],
    List<String> examples = const [],
    List<String> seeAlso = const [],
    String? notes,
    Priority priority = Priority.p1,
    ReturnKind returns = ReturnKind.scalar,
    bool? liftable,
    bool volatile = false,
    bool positionSensitive = false,
    bool usesFilterVisibility = false,
    bool async = false,
    FunctionCost cost = FunctionCost.light,
    bool handlesErrors = false,
    int? minArgs,
    int? maxArgs,
    FunctionCategory? category,
    bool implemented = true,
  }) {
    final rs = params.indexWhere((p) => p.repeatable);
    final computedMin = params.where((p) => !p.optional).length;
    final computedMax = rs >= 0 ? 255 : params.length;
    final lift =
        liftable ?? (params.isNotEmpty && params.every((p) => p.kind.isScalarLike) && returns == ReturnKind.scalar);
    final spec = FunctionSpec(
      name: name,
      aliases: aliases,
      category: category ?? this.category,
      params: params,
      minArgs: minArgs ?? computedMin,
      maxArgs: maxArgs ?? computedMax,
      repeatGroupSize: rs >= 0 ? params.length - rs : 0,
      returns: returns,
      liftable: lift,
      volatile: volatile,
      positionSensitive: positionSensitive,
      usesFilterVisibility: usesFilterVisibility,
      async: async,
      cost: cost,
      priority: priority,
      impl: impl,
      handlesErrors: handlesErrors,
      implemented: implemented,
      help: FunctionHelp(
        summary: summary,
        syntax: syntaxOf(name, params),
        args: [
          for (final p in params)
            ArgHelp(
              p.name,
              p.description,
              optional: p.optional,
              repeatable: p.repeatable,
              defaultText: p.defaultValue == null ? null : _defaultText(p.defaultValue),
            ),
        ],
        examples: examples,
        seeAlso: seeAlso,
        notes: notes,
      ),
    );
    _specs[name] = spec;
    for (final a in aliases) {
      _aliases[a] = name;
    }
  }

  /// Registers an alias of an existing function.
  void alias(String alias, String target) => _aliases[alias] = target;

  /// Known-unsupported or not-yet-implemented function (`#NAME?` with explanation).
  void stub(
    String name,
    String summary, {
    String? message,
    FunctionCategory? category,
    Priority priority = Priority.p2,
    String syntax = '',
  }) {
    final msg = message ?? ErrorMessages.notAvailable(name);
    _specs[name] = FunctionSpec(
      name: name,
      category: category ?? this.category,
      params: const [],
      minArgs: 0,
      maxArgs: 255,
      liftable: false,
      priority: priority,
      implemented: false,
      handlesErrors: true,
      impl: (_) => FError(ErrorKind.name, msg),
      help: FunctionHelp(summary: summary, syntax: syntax.isEmpty ? '$name(…)' : syntax),
    );
  }

  static String _defaultText(Object? v) => switch (v) {
    true => 'TRUE',
    false => 'FALSE',
    final String s => '"$s"',
    _ => '$v',
  };

  /// `NAME(a, b, [c], [d, …])`.
  static String syntaxOf(String name, List<ArgSpec> params) {
    final parts = <String>[];
    final rs = params.indexWhere((p) => p.repeatable);
    for (var i = 0; i < params.length; i++) {
      final p = params[i];
      if (p.repeatable) continue;
      parts.add(p.optional ? '[${p.name}]' : p.name);
    }
    if (rs >= 0) {
      final group = params.sublist(rs).map((p) => p.name).join(', ');
      parts.add('[$group, …]');
    }
    return '$name(${parts.join(', ')})';
  }

  FunctionRegistry build() => FunctionRegistry._(Map.of(_specs), Map.of(_aliases));
}

/// Immutable function registry: canonical name and alias lookup (05 §14.2).
final class FunctionRegistry {
  final Map<String, FunctionSpec> _specs;
  final Map<String, String> _aliases;

  FunctionRegistry._(this._specs, this._aliases);

  static FunctionRegistry? _standard;

  /// The registry of all built-in functions.
  static FunctionRegistry get standard => _standard ??= _buildStandard();

  static FunctionRegistry _buildStandard() {
    final b = FunctionRegistryBuilder();
    registerBuiltins(b);
    return b.build();
  }

  /// Looks up by canonical name or alias (upper case).
  FunctionSpec? lookup(String upperName) {
    final s = _specs[upperName];
    if (s != null) return s;
    final a = _aliases[upperName];
    return a == null ? null : _specs[a];
  }

  bool has(String upperName) => _specs.containsKey(upperName) || _aliases.containsKey(upperName);

  /// All canonical specs (sorted by name).
  List<FunctionSpec> get all => _specs.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  /// Alias → canonical name.
  Map<String, String> get aliases => Map.unmodifiable(_aliases);

  int get length => _specs.length;
}

/// Convenience: the value used to mark an omitted optional argument.
const FValue omitted = FOmitted.instance;

/// Re-export for implementations.
typedef FunctionArgs = Args;
