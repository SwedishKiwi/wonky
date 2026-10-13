import '../values/errors.dart';
import '../values/fvalue.dart';
import 'eval_context.dart';

/// LET/LAMBDA binding frame (names upper-cased).
final class LambdaEnv {
  final LambdaEnv? parent;
  final Map<String, FValue> _values = {};
  LambdaEnv(this.parent);

  void bind(String name, FValue v) => _values[name.toUpperCase()] = v;

  /// Value bound to [upperName], or null when unbound.
  FValue? lookup(String upperName) {
    LambdaEnv? e = this;
    while (e != null) {
      final v = e._values[upperName];
      if (v != null) return v;
      e = e.parent;
    }
    return null;
  }
}

/// Maximum LAMBDA recursion depth (05 §3.8).
const int maxLambdaDepth = 512;

/// A LAMBDA closure.
final class LambdaClosure implements FCallable {
  @override
  final List<String> params;
  final CompiledExpr body;
  final LambdaEnv? captured;
  @override
  final String name;

  LambdaClosure(this.params, this.body, this.captured, {this.name = 'LAMBDA'});

  /// Invokes the closure with already-evaluated [args] (missing → omitted).
  FValue invoke(EvalContext ctx, List<FValue> args) {
    if (args.length > params.length) {
      return FError(
        ErrorKind.na,
        ErrorMessages.wrongArgCount(
          name,
          params.length,
          params.length,
          args.length,
        ),
      );
    }
    if (ctx.callDepth >= maxLambdaDepth) {
      return const FError(ErrorKind.calc, ErrorMessages.recursionLimit);
    }
    final env = LambdaEnv(captured);
    for (var i = 0; i < params.length; i++) {
      env.bind(params[i], i < args.length ? args[i] : FOmitted.instance);
    }
    final prevEnv = ctx.env;
    ctx.env = env;
    ctx.callDepth++;
    try {
      return body(ctx);
    } finally {
      ctx.callDepth--;
      ctx.env = prevEnv;
    }
  }
}

/// Invokes any callable value.
FValue invokeCallable(EvalContext ctx, FCallable f, List<FValue> args) {
  if (f is LambdaClosure) return f.invoke(ctx, args);
  return const FError(ErrorKind.value);
}
