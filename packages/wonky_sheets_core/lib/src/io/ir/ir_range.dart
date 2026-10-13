import '../../addressing/a1.dart';
import '../../addressing/column_letters.dart';
import '../../addressing/grid_geometry.dart';
import '../../addressing/sheet_names.dart';

/// A sheet-local index range of the IR. `null` bounds are open: `r1 == r2 ==
/// null` spans all rows (whole columns `A:C`), `c1 == c2 == null` spans all
/// columns (whole rows `1:3`).
final class IrRange {
  /// Creates a range (bounds are normalized so that `r1 <= r2`, `c1 <= c2`).
  factory IrRange(int? r1, int? c1, int? r2, int? c2) {
    if (r1 != null && r2 != null && r1 > r2) (r1, r2) = (r2, r1);
    if (c1 != null && c2 != null && c1 > c2) (c1, c2) = (c2, c1);
    return IrRange._(r1, c1, r2, c2);
  }

  const IrRange._(this.r1, this.c1, this.r2, this.c2);

  /// A single cell.
  factory IrRange.cell(int row, int col) => IrRange._(row, col, row, col);

  /// From an index rectangle.
  factory IrRange.rect(GridRect r) =>
      IrRange._(r.top, r.left, r.bottom, r.right);

  /// Whole columns.
  factory IrRange.columns(int c1, int c2) => IrRange(null, c1, null, c2);

  /// Whole rows.
  factory IrRange.rows(int r1, int r2) => IrRange(r1, null, r2, null);

  final int? r1;
  final int? c1;
  final int? r2;
  final int? c2;

  /// Whether all bounds are set.
  bool get isBounded => r1 != null && r2 != null && c1 != null && c2 != null;

  /// Whether the rows are unbounded (whole columns).
  bool get wholeColumns => r1 == null && r2 == null;

  /// Whether the columns are unbounded (whole rows).
  bool get wholeRows => c1 == null && c2 == null;

  /// First row (0 when open).
  int get top => r1 ?? 0;

  /// First column (0 when open).
  int get left => c1 ?? 0;

  /// Bounded rectangle within a grid of [rowCount] × [colCount].
  GridRect toRect(int rowCount, int colCount) => GridRect(
    r1 ?? 0,
    c1 ?? 0,
    r2 ?? (rowCount - 1 < (r1 ?? 0) ? (r1 ?? 0) : rowCount - 1),
    c2 ?? (colCount - 1 < (c1 ?? 0) ? (c1 ?? 0) : colCount - 1),
  );

  /// The range as a bounded rectangle (requires [isBounded]).
  GridRect get rect => GridRect(r1!, c1!, r2!, c2!);

  /// Shifts by rows/columns (open bounds stay open).
  IrRange shift(int dRow, int dCol) => IrRange._(
    r1 == null ? null : r1! + dRow,
    c1 == null ? null : c1! + dCol,
    r2 == null ? null : r2! + dRow,
    c2 == null ? null : c2! + dCol,
  );

  /// Largest row index touched (or -1 for whole columns).
  int get maxRow => r2 ?? r1 ?? -1;

  /// Largest column index touched (or -1 for whole rows).
  int get maxCol => c2 ?? c1 ?? -1;

  /// A1 text (`A1`, `A1:B2`, `A:C`, `1:3`), optionally absolute and with a
  /// sheet prefix.
  String toA1({String? sheet, bool absolute = false}) {
    final d = absolute ? r'$' : '';
    String col(int c) => '$d${ColumnLetters.fromIndex(c)}';
    String row(int r) => '$d${r + 1}';
    final prefix = sheet == null ? '' : '${SheetNames.quoteIfNeeded(sheet)}!';
    if (wholeColumns) return '$prefix${col(c1 ?? 0)}:${col(c2 ?? c1 ?? 0)}';
    if (wholeRows) return '$prefix${row(r1 ?? 0)}:${row(r2 ?? r1 ?? 0)}';
    final a = '${col(c1 ?? 0)}${row(r1 ?? 0)}';
    if (r2 == null) return '$prefix$a:${col(c2 ?? c1 ?? 0)}';
    if (c2 == null) return '$prefix$a:${row(r2!)}';
    if (r1 == r2 && c1 == c2) return '$prefix$a';
    return '$prefix$a:${col(c2!)}${row(r2!)}';
  }

  /// Parses an A1 reference (with optional sheet prefix, `$` allowed).
  /// Returns `(sheet, range)` or null.
  static (String?, IrRange)? parseA1(String text) {
    final a = A1Area.tryParse(text.trim());
    if (a == null) return null;
    return (a.sheet, fromArea(a));
  }

  /// From a parsed [A1Area].
  static IrRange fromArea(A1Area a) => switch (a.kind) {
    A1Kind.cell => IrRange.cell(a.row1!, a.col1!),
    A1Kind.rect => IrRange(a.row1, a.col1, a.row2, a.col2),
    A1Kind.columns => IrRange.columns(a.col1!, a.col2!),
    A1Kind.rows => IrRange.rows(a.row1!, a.row2!),
    A1Kind.openRows => IrRange(a.row1, a.col1, null, a.col2),
    A1Kind.openColumns => IrRange(a.row1, a.col1, a.row2, null),
  };

  /// Opens bounds that reach the format's grid limit (`A1:A1048576` → `A:A`).
  IrRange openAt({required int maxRows, required int maxCols}) {
    var a = r1;
    var b = r2;
    var c = c1;
    var d = c2;
    if (a == 0 && b != null && b >= maxRows - 1) {
      a = null;
      b = null;
    }
    if (c == 0 && d != null && d >= maxCols - 1) {
      c = null;
      d = null;
    }
    return IrRange._(a, c, b, d);
  }

  /// Normalized JSON (A1 text).
  String toJson() => toA1();

  @override
  bool operator ==(Object other) =>
      other is IrRange &&
      other.r1 == r1 &&
      other.r2 == r2 &&
      other.c1 == c1 &&
      other.c2 == c2;

  @override
  int get hashCode => Object.hash(r1, c1, r2, c2);

  @override
  String toString() => 'IrRange(${toA1()})';
}
