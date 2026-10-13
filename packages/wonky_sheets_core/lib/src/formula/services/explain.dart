import '../ast/ast.dart';
import '../codec/formula_codec.dart';
import '../codec/ref_token.dart';
import '../eval/eval_context.dart';
import '../eval/range_access.dart';
import '../recalc/formula_engine.dart';
import '../values/fvalue.dart';
import 'diagnostics.dart';

/// A node of the evaluation trace (Explain formula panel, MCP `sheets.explain_formula`).
final class ExplainNode {
  /// Source text of the sub-expression (A1 form).
  final String label;

  /// Value of the sub-expression; null when it depends on LET/LAMBDA locals.
  final FValue? value;
  final SourceSpan span;

  /// Referenced area for reference nodes (outlined on the grid on hover).
  final ResolvedArea? area;
  final List<ExplainNode> children;

  const ExplainNode(
    this.label,
    this.value,
    this.span,
    this.children, {
    this.area,
  });

  /// JSON with arrays truncated to 10×10 and text to 100 chars (05 §18).
  Map<String, Object?> toJson() => {
    'expression': label,
    'value': value == null ? null : _valueJson(value!),
    if (area != null)
      'range': {
        'sheet': area!.sheetId,
        'top': area!.top,
        'left': area!.left,
        'bottom': area!.bottom,
        'right': area!.right,
      },
    if (children.isNotEmpty) 'children': [for (final c in children) c.toJson()],
  };

  static Object? _valueJson(FValue v) => switch (v) {
    FNumber(:final v) => v,
    FText(:final v) => v.length > 100 ? '${v.substring(0, 100)}…' : v,
    FBool(:final v) => v,
    FError(:final kind, :final message) => {
      'error': kind.literal,
      'message': ?message,
    },
    FEmpty() || FOmitted() => null,
    FArray() => {
      'rows': v.rows,
      'cols': v.cols,
      'values': [
        for (var r = 0; r < v.rows && r < 10; r++)
          [for (var c = 0; c < v.cols && c < 10; c++) _valueJson(v.at(r, c))],
      ],
    },
    FRef(:final area) => {'ref': area.toString()},
    FLambda() => 'LAMBDA',
    FRich(:final scalar) => _valueJson(scalar),
  };
}

/// Builds the evaluation trace of the formula at a cell (null for non-formula cells).
ExplainNode? explainCell(
  FormulaEngine engine,
  String sheetId,
  int row,
  int col,
) {
  final sheet = engine.workbook.sheetById(sheetId);
  if (sheet == null) return null;
  final stored = sheet.inputAt(row, col)?.formula;
  if (stored == null) return null;
  final (compiled, slots) = engine.compiler.compileStored(stored);
  final ast = compiled.ast;
  final codec = CodecContext(
    workbook: engine.workbook,
    hostSheetId: sheetId,
    hostRow: row,
    hostCol: col,
    locale: engine.locale,
  );
  if (ast == null) {
    return ExplainNode(
      FormulaCodec.toA1(stored, codec),
      compiled.root(_ctx(engine, sheet.id, row, col, slots)),
      SourceSpan.none,
      const [],
    );
  }
  String render(RefNode r) => switch (r) {
    SlotRefNode(:final index) =>
      index < slots.length
          ? FormulaCodec.renderStoredRef(
              slots[index],
              engine.workbook,
              sheet,
              sheetId,
            )
          : '#REF!',
    StoredRefNode(:final ref) => FormulaCodec.renderStoredRef(
      ref,
      engine.workbook,
      sheet,
      sheetId,
    ),
    A1RefNode(:final area) => area.format(),
  };

  ExplainNode build(Expr e, Set<String> locals) {
    final inner = e;
    final nextLocals = {...locals};
    if (e is CallExpr &&
        (e.name.toUpperCase() == 'LET' || e.name.toUpperCase() == 'LAMBDA')) {
      for (var i = 0; i < e.args.length - 1; i++) {
        final a = e.args[i];
        if (a is NameExpr && (e.name.toUpperCase() == 'LAMBDA' || i.isEven)) {
          nextLocals.add(a.name.toUpperCase());
        }
      }
    }
    final usesLocal = _usesNames(inner, locals);
    FValue? value;
    ResolvedArea? area;
    if (!usesLocal) {
      final ctx = _ctx(engine, sheet.id, row, col, slots);
      final raw = engine.compiler.compileExpr(inner)(ctx);
      if (raw is FRef) {
        area = raw.area;
        value = RangeAccess.deref(ctx, raw);
      } else {
        value = raw;
      }
    }
    final kids = <ExplainNode>[];
    if (inner is! RefExpr) {
      for (final c in inner.children) {
        kids.add(build(c, nextLocals));
      }
    }
    return ExplainNode(
      printFormula(inner, renderRef: render),
      value,
      inner.span,
      kids,
      area: area,
    );
  }

  return build(ast, const {});
}

bool _usesNames(Expr e, Set<String> names) {
  if (names.isEmpty) return false;
  if (e is NameExpr && names.contains(e.name.toUpperCase())) return true;
  if (e is CallExpr && names.contains(e.name.toUpperCase())) return true;
  for (final c in e.children) {
    if (_usesNames(c, names)) return true;
  }
  return false;
}

EvalContext _ctx(
  FormulaEngine engine,
  String sheetId,
  int row,
  int col,
  List<StoredRef> slots,
) {
  final sheet = engine.workbook.sheetById(sheetId)!;
  return EvalContext(
    host: engine,
    sheet: sheet,
    row: row,
    col: col,
    rowId: sheet.rows.idAt(row),
    colId: sheet.columns.idAt(col),
    slots: slots,
  );
}
