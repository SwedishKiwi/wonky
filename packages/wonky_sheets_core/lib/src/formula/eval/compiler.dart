import 'dart:collection';

import '../../addressing/a1.dart';
import '../ast/ast.dart';
import '../codec/ref_resolver.dart';
import '../codec/ref_token.dart';
import '../functions/function_spec.dart';
import '../functions/registry.dart';
import '../model/workbook_view.dart';
import '../parser/formula_grammar.dart';
import '../parser/parse_error.dart';
import '../values/errors.dart';
import '../values/fvalue.dart';
import 'args.dart';
import 'eval_context.dart';
import 'lambda.dart';
import 'operators.dart';
import 'range_access.dart';

/// Result of compiling a formula (shared by all cells with the same template key).
final class CompiledFormula {
  final CompiledExpr root;
  final Expr? ast;
  final FormulaParseError? parseError;
  final bool volatile;
  final bool positionSensitive;
  final bool usesFilter;
  final bool usesExternal;

  /// Upper-case names referenced as names or unknown functions (NameDep, 05 §7.2).
  final Set<String> names;

  /// Whether the formula is a bare reference (`=A1`, `=B2:C5`): result format from the cell.
  final bool bareReference;

  /// Built-in function names used (upper case).
  final Set<String> functions;

  const CompiledFormula({
    required this.root,
    this.ast,
    this.parseError,
    this.volatile = false,
    this.positionSensitive = false,
    this.usesFilter = false,
    this.usesExternal = false,
    this.names = const {},
    this.bareReference = false,
    this.functions = const {},
  });
}

/// A stored formula split into its template key and reference slots.
final class TemplateKey {
  final String key;
  final List<StoredRef> slots;
  const TemplateKey(this.key, this.slots);

  /// Replaces each stored reference with `⟦#i⟧` (strings are skipped).
  static TemplateKey extract(String stored) {
    final n = stored.length;
    final b = StringBuffer();
    final slots = <StoredRef>[];
    var i = 0;
    var last = 0;
    while (i < n) {
      final c = stored.codeUnitAt(i);
      if (c == 0x22) {
        i++;
        while (i < n) {
          if (stored.codeUnitAt(i) == 0x22) {
            if (i + 1 < n && stored.codeUnitAt(i + 1) == 0x22) {
              i += 2;
              continue;
            }
            break;
          }
          i++;
        }
        i++;
        continue;
      }
      if (c == RefToken.openCode) {
        final close = stored.indexOf(RefToken.close, i);
        if (close < 0) break;
        final a = RefToken.decode(stored.substring(i, close + 1));
        if (a == null) {
          i = close + 1;
          continue;
        }
        var end = close + 1;
        RefToken? e;
        if (end + 1 < n &&
            stored.codeUnitAt(end) == 0x3a &&
            stored.codeUnitAt(end + 1) == RefToken.openCode) {
          final close2 = stored.indexOf(RefToken.close, end + 1);
          if (close2 > 0) {
            e = RefToken.decode(stored.substring(end + 1, close2 + 1));
            if (e != null) end = close2 + 1;
          }
        }
        b
          ..write(stored.substring(last, i))
          ..write('⟦#${slots.length}⟧');
        slots.add(StoredRef(a, e));
        i = end;
        last = end;
        continue;
      }
      i++;
    }
    if (slots.isEmpty) return TemplateKey(stored, const []);
    b.write(stored.substring(last));
    return TemplateKey(b.toString(), slots);
  }
}

final class _Scope {
  final _Scope? parent;
  final Set<String> names;
  _Scope(this.parent, this.names);

  bool contains(String upper) {
    _Scope? s = this;
    while (s != null) {
      if (s.names.contains(upper)) return true;
      s = s.parent;
    }
    return false;
  }
}

final class _Meta {
  bool volatile = false;
  bool positionSensitive = false;
  bool usesFilter = false;
  bool usesExternal = false;
  final Set<String> names = {};
  final Set<String> functions = {};
}

/// AST → closure compiler with a template cache (05 §7.2).
final class FormulaCompiler {
  final FunctionRegistry registry;
  final int templateCapacity;
  final LinkedHashMap<String, CompiledFormula> _cache = LinkedHashMap();

  FormulaCompiler(this.registry, {this.templateCapacity = 50000});

  int get cachedTemplates => _cache.length;

  void clearCache() => _cache.clear();

  /// Compiles stored formula text (without `=`), sharing templates.
  (CompiledFormula, List<StoredRef>) compileStored(String stored) {
    final t = TemplateKey.extract(stored);
    var c = _cache.remove(t.key);
    if (c == null) {
      c = compileText(t.key, storedForm: true);
      if (_cache.length >= templateCapacity) _cache.remove(_cache.keys.first);
    }
    _cache[t.key] = c;
    return (c, t.slots);
  }

  /// Parses and compiles formula text (no template substitution).
  CompiledFormula compileText(String text, {bool storedForm = true}) {
    final (ast, err) = FormulaParser.tryParse(text, storedForm: storedForm);
    if (ast == null) {
      final e = FError(ErrorKind.parse, err!.message);
      return CompiledFormula(root: (_) => e, parseError: err);
    }
    return compileAst(ast);
  }

  /// Compiles an AST.
  CompiledFormula compileAst(Expr ast) {
    final m = _Meta();
    final root = _c(ast, null, m);
    var inner = ast;
    while (inner is ParenExpr) {
      inner = inner.inner;
    }
    return CompiledFormula(
      root: root,
      ast: ast,
      volatile: m.volatile,
      positionSensitive: m.positionSensitive,
      usesFilter: m.usesFilter,
      usesExternal: m.usesExternal,
      names: m.names,
      bareReference: inner is RefExpr,
      functions: m.functions,
    );
  }

  /// Compiles a sub-expression (Explain); local names are treated as unknown.
  CompiledExpr compileExpr(Expr e) => _c(e, null, _Meta());

  // ------------------------------------------------------------------ compile

  CompiledExpr _c(Expr e, _Scope? scope, _Meta m) {
    switch (e) {
      case NumberLit(:final value):
        final v = FNumber(value);
        return (_) => v;
      case StringLit(:final value):
        final v = FText(value);
        return (_) => v;
      case BoolLit(:final value):
        final v = FBool(value);
        return (_) => v;
      case ErrorLit(:final kind):
        final v = FError(kind);
        return (_) => v;
      case ParenExpr(:final inner):
        return _c(inner, scope, m);
      case RefExpr(:final ref):
        switch (ref) {
          case SlotRefNode(:final index):
            return (ctx) => index < ctx.slots.length
                ? resolveStored(ctx, ctx.slots[index])
                : const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
          case StoredRefNode(:final ref):
            return (ctx) => resolveStored(ctx, ref);
          case A1RefNode(:final area):
            m.positionSensitive = true;
            return (ctx) => resolveA1(ctx, area);
        }
      case NameExpr(:final name):
        final upper = name.toUpperCase();
        if (scope != null && scope.contains(upper)) {
          return (ctx) =>
              ctx.env?.lookup(upper) ?? FError(ErrorKind.name, ErrorMessages.unknownRange(name));
        }
        m.names.add(upper);
        return (ctx) => resolveName(ctx, upper, name);
      case ArrayLit(:final rows):
        final compiled = [
          for (final r in rows) [for (final x in r) _c(x, scope, m)],
        ];
        return (ctx) => _arrayLiteral(ctx, compiled);
      case UnaryExpr(:final op, :final operand):
        final o = _c(operand, scope, m);
        return (ctx) {
          final v = _operand(ctx, o(ctx));
          final loc = ctx.locale;
          return Operators.lift1(v, (x) => Operators.unary(op, x, loc));
        };
      case PercentExpr(:final operand):
        final o = _c(operand, scope, m);
        return (ctx) {
          final v = _operand(ctx, o(ctx));
          final loc = ctx.locale;
          return Operators.lift1(v, (x) => Operators.percent(x, loc));
        };
      case BinaryExpr(:final op, :final left, :final right):
        final l = _c(left, scope, m);
        final r = _c(right, scope, m);
        return (ctx) {
          final a = _operand(ctx, l(ctx));
          final b = _operand(ctx, r(ctx));
          final loc = ctx.locale;
          if (a is! FArray && b is! FArray) return Operators.binary(op, a, b, loc);
          return Operators.lift2(a, b, op.functionName, (x, y) => Operators.binary(op, x, y, loc));
        };
      case RangeOpExpr(:final left, :final right):
        final l = _c(left, scope, m);
        final r = _c(right, scope, m);
        return (ctx) => _rangeOp(l(ctx), r(ctx));
      case InvokeExpr(:final callee, :final args):
        final f = _c(callee, scope, m);
        final a = [for (final x in args) x == null ? null : _c(x, scope, m)];
        return (ctx) {
          final fv = f(ctx);
          if (fv is FError) return fv;
          if (fv is! FLambda) {
            return const FError(ErrorKind.value, 'The expression is not a function.');
          }
          return invokeCallable(ctx, fv.closure, [
            for (final x in a) x == null ? FOmitted.instance : x(ctx),
          ]);
        };
      case CallExpr():
        return _call(e, scope, m);
    }
  }

  CompiledExpr _call(CallExpr e, _Scope? scope, _Meta m) {
    final upper = e.name.toUpperCase();
    if (scope != null && scope.contains(upper)) {
      final a = [for (final x in e.args) x == null ? null : _c(x, scope, m)];
      return (ctx) {
        final fv = ctx.env?.lookup(upper);
        if (fv is FLambda) {
          return invokeCallable(ctx, fv.closure, [
            for (final x in a) x == null ? FOmitted.instance : x(ctx),
          ]);
        }
        if (fv is FError) return fv;
        return FError(ErrorKind.value, "'${e.name}' is not a function.");
      };
    }
    if (upper == 'LET') return _let(e, scope, m);
    if (upper == 'LAMBDA') return _lambda(e, scope, m);
    final spec = registry.lookup(upper);
    if (spec == null) {
      m.names.add(upper);
      m.usesExternal = true;
      final a = [for (final x in e.args) x == null ? null : _c(x, scope, m)];
      return (ctx) => _callDynamic(ctx, upper, e.name, a);
    }
    m.functions.add(spec.name);
    if (!spec.implemented) {
      return (ctx) => spec.impl(Args(ctx, spec, const [], const []));
    }
    final n = e.args.length;
    if (n < spec.minArgs || n > spec.maxArgs) {
      final err = FError(
        ErrorKind.na,
        ErrorMessages.wrongArgCount(spec.name, spec.minArgs, spec.maxArgs, n),
      );
      return (_) => err;
    }
    if (spec.volatile) m.volatile = true;
    if (spec.positionSensitive) m.positionSensitive = true;
    if (spec.usesFilterVisibility) m.usesFilter = true;
    if (spec.async) m.usesExternal = true;
    final a = [for (final x in e.args) x == null ? null : _c(x, scope, m)];
    return (ctx) => dispatch(ctx, spec, a);
  }

  CompiledExpr _let(CallExpr e, _Scope? scope, _Meta m) {
    final args = e.args;
    if (args.length < 3 || args.length.isEven) {
      final err = FError(ErrorKind.na, ErrorMessages.wrongArgCount('LET', 3, 255, args.length));
      return (_) => err;
    }
    final names = <String>[];
    final values = <CompiledExpr>[];
    final s = _Scope(scope, {});
    for (var i = 0; i + 1 < args.length; i += 2) {
      final ne = args[i];
      if (ne is! NameExpr || A1Area.tryParse(ne.name) != null) {
        final err = FError(
          ErrorKind.value,
          'Argument ${i + 1} of function LET must be a valid name.',
        );
        return (_) => err;
      }
      final ve = args[i + 1];
      values.add(ve == null ? (_) => FEmpty.instance : _c(ve, s, m));
      final up = ne.name.toUpperCase();
      names.add(up);
      s.names.add(up);
    }
    final bodyExpr = args.last;
    final body = bodyExpr == null ? (EvalContext _) => FEmpty.instance : _c(bodyExpr, s, m);
    return (ctx) {
      final prev = ctx.env;
      final env = LambdaEnv(prev);
      ctx.env = env;
      try {
        for (var i = 0; i < names.length; i++) {
          env.bind(names[i], values[i](ctx));
        }
        return body(ctx);
      } finally {
        ctx.env = prev;
      }
    };
  }

  CompiledExpr _lambda(CallExpr e, _Scope? scope, _Meta m) {
    final args = e.args;
    if (args.isEmpty || args.last == null) {
      final err = FError(ErrorKind.na, ErrorMessages.wrongArgCount('LAMBDA', 1, 255, args.length));
      return (_) => err;
    }
    final params = <String>[];
    for (var i = 0; i < args.length - 1; i++) {
      final p = args[i];
      if (p is! NameExpr || A1Area.tryParse(p.name) != null) {
        final err = FError(ErrorKind.value, 'Argument ${i + 1} of function LAMBDA must be a valid name.');
        return (_) => err;
      }
      params.add(p.name.toUpperCase());
    }
    final body = _c(args.last!, _Scope(scope, params.toSet()), m);
    return (ctx) => FLambda(LambdaClosure(params, body, ctx.env));
  }

  // ------------------------------------------------------------------ runtime helpers

  static FValue _operand(EvalContext ctx, FValue v) {
    switch (v) {
      case FRef():
        if (v.area.isSingleCell) {
          final s = RangeAccess.sheetOf(ctx, v.area);
          if (s == null) return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
          if (v.dynamic) ctx.deps.areas.add(v.area);
          final x = RangeAccess.cellWithHint(ctx, s, v.area.top, v.area.left);
          return x is FRich ? x.scalar : x;
        }
        return ctx.arrayMode ? RangeAccess.materialize(ctx, v) : RangeAccess.intersect(ctx, v);
      case FRich(:final scalar):
        return scalar;
      case FOmitted():
        return FEmpty.instance;
      case FLambda():
        return const FError(ErrorKind.value, ErrorMessages.lambdaResult);
      default:
        return v;
    }
  }

  static FValue _rangeOp(FValue a, FValue b) {
    if (a is FError) return a;
    if (b is FError) return b;
    if (a is! FRef || b is! FRef) {
      return const FError(ErrorKind.value, ErrorMessages.rangeOperatorRequiresRefs);
    }
    if (a.area.sheetId != b.area.sheetId) {
      return const FError(ErrorKind.value, ErrorMessages.rangeOperatorRequiresRefs);
    }
    final x = a.area, y = b.area;
    return FRef(
      ResolvedArea(
        x.sheetId,
        x.top < y.top ? x.top : y.top,
        x.left < y.left ? x.left : y.left,
        x.bottom > y.bottom ? x.bottom : y.bottom,
        x.right > y.right ? x.right : y.right,
      ),
      dynamic: true,
      open: a.open || b.open,
    );
  }

  static FValue _arrayLiteral(EvalContext ctx, List<List<CompiledExpr>> rows) {
    final rowBlocks = <FArray>[];
    for (final row in rows) {
      final parts = <FArray>[];
      for (final x in row) {
        var v = x(ctx);
        if (v is FRef) {
          v = RangeAccess.deref(ctx, v);
        }
        if (v is FRich) v = v.scalar;
        if (v is FLambda) v = const FError(ErrorKind.value, ErrorMessages.lambdaResult);
        if (v is FOmitted) v = FEmpty.instance;
        parts.add(v is FArray ? v : FArray(1, 1, [v]));
      }
      final h = parts.first.rows;
      for (final p in parts) {
        if (p.rows != h) {
          return const FError(
            ErrorKind.value,
            'In ARRAY_LITERAL, an Array Literal was missing values for one or more rows.',
          );
        }
      }
      final w = parts.fold<int>(0, (s, p) => s + p.cols);
      final cells = List<FValue>.filled(h * w, FEmpty.instance);
      var off = 0;
      for (final p in parts) {
        for (var r = 0; r < h; r++) {
          for (var c = 0; c < p.cols; c++) {
            cells[r * w + off + c] = p.at(r, c);
          }
        }
        off += p.cols;
      }
      rowBlocks.add(FArray(h, w, cells));
    }
    final w = rowBlocks.first.cols;
    for (final b in rowBlocks) {
      if (b.cols != w) {
        return const FError(
          ErrorKind.value,
          'In ARRAY_LITERAL, an Array Literal was missing values for one or more columns.',
        );
      }
    }
    if (rowBlocks.length == 1) {
      final b = rowBlocks.first;
      return b.length == 1 ? b.at(0, 0) : b;
    }
    final total = rowBlocks.fold<int>(0, (s, b) => s + b.rows);
    if (total * w > maxArrayCells) return const FError(ErrorKind.num, ErrorMessages.resultTooLarge);
    final cells = <FValue>[];
    for (final b in rowBlocks) {
      for (var r = 0; r < b.rows; r++) {
        for (var c = 0; c < w; c++) {
          cells.add(b.at(r, c));
        }
      }
    }
    return FArray(total, w, cells);
  }

  /// Resolves an id-based reference at evaluation time (with [EvalContext.rowOffset]).
  static FValue resolveStored(EvalContext ctx, StoredRef ref) {
    final r = RefResolver.resolve(ref, ctx.workbook, ctx.sheet);
    if (r is RefFailure) return _refFailure(r, ref);
    final rr = r as ResolvedRef;
    final unbound = ref.start.isUnbound;
    if (unbound) {
      ctx.deps.sheetNames = true;
      ctx.deps.axisSheets.add(rr.sheet.id);
    }
    final rows = rr.sheet.rows.length;
    final cols = rr.sheet.columns.length;
    var r1 = rr.row1 ?? 0;
    var c1 = rr.col1 ?? 0;
    var r2 = rr.row2 ?? rows - 1;
    var c2 = rr.col2 ?? cols - 1;
    if (ctx.rowOffset != 0 || ctx.colOffset != 0) {
      final s = ref.start;
      final e = ref.end ?? s;
      if (rr.row1 != null && !s.absRow) r1 += ctx.rowOffset;
      if (rr.row2 != null && !e.absRow) r2 += ctx.rowOffset;
      if (rr.col1 != null && !s.absCol) c1 += ctx.colOffset;
      if (rr.col2 != null && !e.absCol) c2 += ctx.colOffset;
      if (r1 < 0 || c1 < 0 || r2 >= rows || c2 >= cols || r1 > r2 || c1 > c2) {
        return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
      }
    }
    final open = !(rr.kind == A1Kind.cell || rr.kind == A1Kind.rect);
    return FRef(
      ResolvedArea(rr.sheet.id, r1, c1, r2, c2),
      dynamic: unbound || ctx.rowOffset != 0 || ctx.colOffset != 0,
      open: open,
    );
  }

  static FValue _refFailure(RefFailure f, StoredRef ref) => switch (f) {
    RefFailure.unresolvedSheetName => FError(
      ErrorKind.ref,
      ErrorMessages.unresolvedSheet(A1Area.tryParse(ref.start.unbound ?? '')?.sheet ?? ''),
    ),
    RefFailure.outOfBounds => FError(
      ErrorKind.ref,
      ErrorMessages.outOfBounds(ref.start.unbound ?? ''),
    ),
    _ => const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist),
  };

  /// Positional A1 reference (stored text that was never converted, INDIRECT).
  static FValue resolveA1(EvalContext ctx, A1Area area) {
    SheetView? sheet = ctx.sheet;
    if (area.sheet != null) {
      sheet = ctx.workbook.sheetByName(area.sheet!);
      ctx.deps.sheetNames = true;
      if (sheet == null) {
        return FError(ErrorKind.ref, ErrorMessages.unresolvedSheet(area.sheet!));
      }
    }
    ctx.deps.axisSheets.add(sheet.id);
    final rows = sheet.rows.length, cols = sheet.columns.length;
    final rect = area.toRect(rows, cols);
    final r1 = rect.top + (area.absRow1 ? 0 : ctx.rowOffset);
    final r2 = rect.bottom + (area.absRow2 ? 0 : ctx.rowOffset);
    final c1 = rect.left + (area.absCol1 ? 0 : ctx.colOffset);
    final c2 = rect.right + (area.absCol2 ? 0 : ctx.colOffset);
    if (r1 < 0 || c1 < 0 || r2 >= rows || c2 >= cols) {
      return FError(ErrorKind.ref, ErrorMessages.outOfBounds(area.format()));
    }
    return FRef(
      ResolvedArea(sheet.id, r1, c1, r2, c2),
      dynamic: true,
      open: !(area.kind == A1Kind.cell || area.kind == A1Kind.rect),
    );
  }

  /// Resolves an [IdRange] (named ranges).
  static FValue resolveIdRange(EvalContext ctx, IdRange r) {
    final sheet = ctx.workbook.sheetById(r.sheetId);
    if (sheet == null) return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
    int idx(AxisView axis, String? id, String? key, bool start, int dflt) {
      if (id == null) return dflt;
      return RefResolver.endpointIndex(axis, id, key, isStart: start);
    }

    final r1 = idx(sheet.rows, r.rowStart, r.rowStartKey, true, 0);
    final r2 = idx(sheet.rows, r.rowEnd, r.rowEndKey, false, sheet.rows.length - 1);
    final c1 = idx(sheet.columns, r.colStart, r.colStartKey, true, 0);
    final c2 = idx(sheet.columns, r.colEnd, r.colEndKey, false, sheet.columns.length - 1);
    if (r1 < 0 || c1 < 0 || r2 < r1 || c2 < c1 || r1 >= sheet.rows.length || c1 >= sheet.columns.length) {
      return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
    }
    return FRef(
      ResolvedArea(sheet.id, r1, c1, r2, c2),
      dynamic: true,
      open: r.rowEnd == null || r.colEnd == null || r.rowStart == null || r.colStart == null,
    );
  }

  /// Named range / named function value resolution (05 §7.6).
  static FValue resolveName(EvalContext ctx, String upper, String display) {
    ctx.deps.names.add(upper);
    final nr = ctx.host.namedRange(upper);
    if (nr != null) {
      final range = nr.range;
      if (range != null) return resolveIdRange(ctx, range);
      final f = ctx.host.namedFunction(upper);
      if (f != null) return FLambda(f);
    }
    if (upper == 'TRUE' || upper == 'FALSE') return FBool(upper == 'TRUE');
    return FError(ErrorKind.name, ErrorMessages.unknownRange(display));
  }

  static FValue _callDynamic(
    EvalContext ctx,
    String upper,
    String display,
    List<CompiledExpr?> args,
  ) {
    ctx.deps.names.add(upper);
    final nf = ctx.host.namedFunction(upper);
    if (nf != null) {
      if (args.length != nf.params.length) {
        return FError(
          ErrorKind.na,
          ErrorMessages.wrongArgCount(nf.name, nf.params.length, nf.params.length, args.length),
        );
      }
      final values = [for (final a in args) a == null ? FOmitted.instance : a(ctx)];
      final r = invokeCallable(ctx, nf, values);
      return r;
    }
    final cp = ctx.host.customFunctions;
    if (cp != null && cp.has(upper)) {
      ctx.deps.customFunctions.add(upper);
      final values = <FValue>[];
      for (final a in args) {
        var v = a == null ? FOmitted.instance : a(ctx);
        if (v is FRef) v = RangeAccess.deref(ctx, v);
        if (v is FRich) v = v.scalar;
        values.add(v);
      }
      final r = cp.lookup(upper, values, ctx.cellId);
      if (r == null) return const FError.pending();
      return r.value;
    }
    return FError(ErrorKind.name, ErrorMessages.unknownFunction(display));
  }

  /// Calls a built-in with argument evaluation per [ArgKind], error propagation and lifting.
  static FValue dispatch(EvalContext ctx, FunctionSpec spec, List<CompiledExpr?> exprs) {
    final n = exprs.length;
    final values = List<FValue>.filled(n, FOmitted.instance);
    List<CompiledExpr?> thunks = const [];
    List<int>? lift;
    for (var i = 0; i < n; i++) {
      final e = exprs[i];
      final kind = spec.kindAt(i);
      if (e == null) continue;
      switch (kind) {
        case ArgKind.lazy:
          if (thunks.isEmpty) thunks = List<CompiledExpr?>.filled(n, null);
          thunks[i] = e;
          continue;
        case ArgKind.array:
          values[i] = ctx.withMode(true, e);
          continue;
        case ArgKind.range:
        case ArgKind.reference:
        case ArgKind.any:
        case ArgKind.lambda:
          values[i] = e(ctx);
          continue;
        case ArgKind.scalar:
        case ArgKind.number:
        case ArgKind.text:
        case ArgKind.boolean:
          var v = e(ctx);
          if (v is FRef) {
            v = (ctx.arrayMode && !v.area.isSingleCell)
                ? RangeAccess.materialize(ctx, v)
                : RangeAccess.intersect(ctx, v);
          }
          if (v is FRich) v = v.scalar;
          if (v is FArray) {
            if (v.length == 1) {
              v = v.at(0, 0);
            } else if (spec.liftable) {
              (lift ??= []).add(i);
            } else {
              v = v.topLeft;
            }
          }
          if (v is FError && !spec.handlesErrors && lift == null) return v;
          values[i] = v;
      }
    }
    if (lift != null) return _broadcast(ctx, spec, values, thunks, lift);
    return invoke(ctx, spec, values, thunks);
  }

  static FValue _broadcast(
    EvalContext ctx,
    FunctionSpec spec,
    List<FValue> values,
    List<CompiledExpr?> thunks,
    List<int> lift,
  ) {
    var rows = 1, cols = 1;
    for (final i in lift) {
      final a = values[i] as FArray;
      if (a.rows > rows) rows = a.rows;
      if (a.cols > cols) cols = a.cols;
    }
    if (rows * cols > maxArrayCells) return const FError(ErrorKind.num, ErrorMessages.resultTooLarge);
    final out = List<FValue>.filled(rows * cols, FEmpty.instance);
    final elementValues = List<FValue>.of(values);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        FError? err;
        for (final i in lift) {
          final a = values[i] as FArray;
          final rr = a.rows == 1 ? 0 : r;
          final cc = a.cols == 1 ? 0 : c;
          var x = (rr < a.rows && cc < a.cols) ? a.at(rr, cc) : FError.na;
          if (x is FRich) x = x.scalar;
          elementValues[i] = x;
          if (err == null && x is FError && !spec.handlesErrors) err = x;
        }
        if (err == null && !spec.handlesErrors) {
          for (var i = 0; i < values.length; i++) {
            final v = elementValues[i];
            if (v is FError && spec.kindAt(i).isScalarLike) {
              err = v;
              break;
            }
          }
        }
        var res = err ?? invoke(ctx, spec, List.of(elementValues), thunks);
        if (res is FArray) res = res.topLeft;
        out[r * cols + c] = res;
      }
    }
    return FArray(rows, cols, out);
  }

  /// Runs the implementation and validates the result.
  static FValue invoke(
    EvalContext ctx,
    FunctionSpec spec,
    List<FValue> values,
    List<CompiledExpr?> thunks,
  ) {
    FValue r;
    try {
      r = spec.impl(Args(ctx, spec, values, thunks));
    } on FormulaError catch (e) {
      return e.error;
    } on EvaluationInterrupt {
      rethrow;
    } on StackOverflowError {
      return const FError(ErrorKind.calc, ErrorMessages.recursionLimit);
    }
    switch (r) {
      case FNumber(:final v):
        if (!v.isFinite) return FError.num;
      case FText(:final v):
        if (v.length > Operators.maxText) {
          return FError(ErrorKind.value, ErrorMessages.textTooLong(spec.name));
        }
      case FArray():
        if (r.rows == 0 || r.cols == 0) return FError.na;
      default:
        break;
    }
    return r;
  }
}
