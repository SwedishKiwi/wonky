import '../../addressing/grid_geometry.dart';
import '../model/workbook_view.dart';
import '../values/errors.dart';
import '../values/format_hint.dart';
import '../values/fvalue.dart';
import 'eval_context.dart';

/// Maximum number of cells in an array result (05 §3.8).
const int maxArrayCells = 2000000;

/// Reference resolution, dereferencing, materialization and iteration (05 §7.4, §8.4).
abstract final class RangeAccess {
  static SheetView? sheetOf(EvalContext ctx, ResolvedArea a) =>
      a.sheetId == ctx.sheet.id ? ctx.sheet : ctx.workbook.sheetById(a.sheetId);

  static void _record(EvalContext ctx, FRef ref) {
    if (ref.dynamic) ctx.deps.areas.add(ref.area);
  }

  /// Value of a single-cell area.
  static FValue cell(EvalContext ctx, FRef ref) {
    _record(ctx, ref);
    final s = sheetOf(ctx, ref.area);
    if (s == null) return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
    return ctx.host.cellValue(s, ref.area.top, ref.area.left);
  }

  /// Single-cell value with its format hint attached to numbers (bare references, lookups).
  static FValue cellWithHint(EvalContext ctx, SheetView s, int row, int col) {
    final v = ctx.host.cellValue(s, row, col);
    if (v is FNumber && v.hint.isNone) {
      final h = ctx.host.cellHint(s, row, col);
      if (!h.isNone) return v.withHint(h);
    }
    return v;
  }

  /// Implicit intersection (05 §7.4.1).
  static FValue intersect(EvalContext ctx, FRef ref) {
    final a = ref.area;
    if (a.isSingleCell) return cell(ctx, ref);
    _record(ctx, ref);
    final s = sheetOf(ctx, a);
    if (s == null) return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
    if (a.left == a.right && ctx.row >= a.top && ctx.row <= a.bottom) {
      return ctx.host.cellValue(s, ctx.row, a.left);
    }
    if (a.top == a.bottom && ctx.col >= a.left && ctx.col <= a.right) {
      return ctx.host.cellValue(s, a.top, ctx.col);
    }
    return const FError(ErrorKind.value, ErrorMessages.arrayValueNotFound);
  }

  /// Logical rectangle clamped to the used extent for open references (≥ 1 row/column).
  static ResolvedArea clamp(EvalContext ctx, FRef ref) {
    final a = ref.area;
    if (!ref.open) return a;
    final s = sheetOf(ctx, a);
    if (s == null) return a;
    final ur = ctx.host.usedRows(s);
    final uc = ctx.host.usedColumns(s);
    var bottom = a.bottom;
    var right = a.right;
    if (bottom > ur - 1) bottom = ur - 1 < a.top ? a.top : ur - 1;
    if (right > uc - 1) right = uc - 1 < a.left ? a.left : uc - 1;
    return ResolvedArea(a.sheetId, a.top, a.left, bottom, right);
  }

  /// Materializes a reference into a dense array (open references clamped).
  static FValue materialize(EvalContext ctx, FRef ref, {bool withHints = true}) {
    _record(ctx, ref);
    final s = sheetOf(ctx, ref.area);
    if (s == null) return const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist);
    final a = clamp(ctx, ref);
    final rows = a.rows, cols = a.cols;
    if (rows * cols > maxArrayCells) {
      return const FError(ErrorKind.num, ErrorMessages.resultTooLarge);
    }
    final cells = List<FValue>.filled(rows * cols, FEmpty.instance);
    ctx.host.forEachValue(s, a.rect, (r, c, v) {
      final i = (r - a.top) * cols + (c - a.left);
      if (withHints && v is FNumber && v.hint.isNone) {
        final f = s.numberFormatAt(r, c);
        if (f != null) v = v.withHint(FormatHint.fromCell(f));
      }
      cells[i] = v;
    });
    return FArray(rows, cols, cells);
  }

  /// Dereferences: single cells → value; multi-cell refs → array.
  static FValue deref(EvalContext ctx, FValue v) {
    if (v is FRef) {
      if (v.area.isSingleCell) return cell(ctx, v);
      return materialize(ctx, v);
    }
    return v;
  }

  /// Converts any value to an array (scalars → 1×1).
  static FArray toArray(EvalContext ctx, FValue v) {
    switch (v) {
      case FArray():
        return v;
      case FRef():
        final m = materialize(ctx, v);
        if (m is FArray) return m;
        throw FormulaError(m as FError);
      case FRich(:final scalar):
        return FArray(1, 1, [scalar]);
      default:
        return FArray(1, 1, [v]);
    }
  }

  /// Visits the non-empty values of a reference, array or scalar. Arrays include empties
  /// (they are dense); references skip blank cells.
  static void forEach(EvalContext ctx, FValue v, void Function(FValue v) visit) {
    switch (v) {
      case FRef():
        _record(ctx, v);
        final s = sheetOf(ctx, v.area);
        if (s == null) {
          visit(const FError(ErrorKind.ref, ErrorMessages.referenceDoesNotExist));
          return;
        }
        ctx.host.forEachValue(s, v.area.rect, (_, _, x) => visit(x));
      case FArray():
        for (var r = 0; r < v.rows; r++) {
          for (var c = 0; c < v.cols; c++) {
            visit(v.at(r, c));
          }
        }
      default:
        visit(v);
    }
  }

  /// Visits values with positions relative to the top-left (non-empty for references).
  static void forEachIndexed(
    EvalContext ctx,
    FValue v,
    void Function(int r, int c, FValue v) visit,
  ) {
    switch (v) {
      case FRef():
        _record(ctx, v);
        final s = sheetOf(ctx, v.area);
        if (s == null) return;
        final a = v.area;
        ctx.host.forEachValue(s, a.rect, (r, c, x) => visit(r - a.top, c - a.left, x));
      case FArray():
        for (var r = 0; r < v.rows; r++) {
          for (var c = 0; c < v.cols; c++) {
            visit(r, c, v.at(r, c));
          }
        }
      default:
        visit(0, 0, v);
    }
  }

  /// (rows, cols) of a reference (logical), array or scalar.
  static (int, int) shape(FValue v) => switch (v) {
    FRef(:final area) => (area.rows, area.cols),
    FArray(:final rows, :final cols) => (rows, cols),
    _ => (1, 1),
  };

  /// Element (r, c) of a range/array/scalar without materializing references.
  static FValue elementAt(EvalContext ctx, FValue v, int r, int c) {
    switch (v) {
      case FRef(:final area):
        if (r >= area.rows || c >= area.cols) return FEmpty.instance;
        _record(ctx, v);
        final s = sheetOf(ctx, area);
        if (s == null) return const FError(ErrorKind.ref);
        return ctx.host.cellValue(s, area.top + r, area.left + c);
      case FArray():
        if (r >= v.rows || c >= v.cols) return FEmpty.instance;
        return v.at(r, c);
      default:
        return v;
    }
  }

  /// Rect helper.
  static GridRect rectOf(ResolvedArea a) => a.rect;
}
