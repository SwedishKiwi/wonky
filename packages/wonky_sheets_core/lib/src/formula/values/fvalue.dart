import '../../addressing/grid_geometry.dart';
import 'errors.dart';
import 'format_hint.dart';

/// A formula value (05 §6.1). Immutable.
sealed class FValue {
  const FValue();

  /// Whether this value is an error (including pending).
  bool get isError => false;

  /// Short human-readable rendering for debugging and tests.
  String get debugText;

  @override
  String toString() => debugText;
}

/// Readability alias used by 08 (charts) and 09 (scripts).
typedef FormulaValue = FValue;

/// A number. Dates and times are serial numbers with a date/time [hint].
final class FNumber extends FValue {
  final double v;
  final FormatHint hint;
  const FNumber(this.v, [this.hint = FormatHint.none]);

  static const FNumber zero = FNumber(0);
  static const FNumber one = FNumber(1);

  FNumber withHint(FormatHint h) => identical(h, hint) ? this : FNumber(v, h);

  @override
  String get debugText => v == v.truncateToDouble() && v.abs() < 1e15
      ? v.toInt().toString()
      : v.toString();

  /// Equality ignores the format hint (see [FValues.sameValue] for change detection).
  @override
  bool operator ==(Object other) => other is FNumber && other.v == v;

  @override
  int get hashCode => v.hashCode;
}

/// Text.
final class FText extends FValue {
  final String v;
  const FText(this.v);

  static const FText empty = FText('');

  @override
  String get debugText => '"$v"';

  @override
  bool operator ==(Object other) => other is FText && other.v == v;

  @override
  int get hashCode => v.hashCode;
}

/// Boolean.
final class FBool extends FValue {
  final bool v;
  const FBool._(this.v);

  static const FBool t = FBool._(true);
  static const FBool f = FBool._(false);

  factory FBool(bool v) => v ? t : f;

  @override
  String get debugText => v ? 'TRUE' : 'FALSE';
}

/// An error value. [pending] marks the "Loading…" value of async functions (05 §13.1).
final class FError extends FValue {
  final ErrorKind kind;
  final String? message;
  final bool pending;

  const FError(this.kind, [this.message, this.pending = false]);

  /// The transient "Loading…" value (`#N/A`, pending).
  const FError.pending([String this.message = ErrorMessages.loading])
    : kind = ErrorKind.na,
      pending = true;

  static const FError na = FError(ErrorKind.na);
  static const FError value = FError(ErrorKind.value);
  static const FError ref = FError(ErrorKind.ref);
  static const FError div0 = FError(ErrorKind.div0);
  static const FError num = FError(ErrorKind.num);
  static const FError name = FError(ErrorKind.name);
  static const FError nullRef = FError(ErrorKind.nullRef);
  static const FError parse = FError(ErrorKind.parse);
  static const FError spill = FError(ErrorKind.spill);
  static const FError calc = FError(ErrorKind.calc);

  @override
  bool get isError => true;

  @override
  String get debugText => kind.literal;

  /// Equality compares kind and pending only (messages are informational).
  @override
  bool operator ==(Object other) =>
      other is FError && other.kind == kind && other.pending == pending;

  @override
  int get hashCode => Object.hash(kind, pending);
}

/// A blank cell / omitted value.
final class FEmpty extends FValue {
  const FEmpty._();
  static const FEmpty instance = FEmpty._();

  @override
  String get debugText => '<empty>';
}

/// Marker for a missing (omitted) function argument (`f(1,)`).
final class FOmitted extends FValue {
  const FOmitted._();
  static const FOmitted instance = FOmitted._();

  @override
  String get debugText => '<omitted>';
}

/// A dense, row-major, immutable 2-D array. Subclasses may compute elements lazily.
class FArray extends FValue {
  final int rows;
  final int cols;
  final List<FValue> _cells;

  FArray(this.rows, this.cols, List<FValue> cells) : _cells = cells {
    assert(cells.length == rows * cols, 'cells length must be rows*cols');
  }

  /// Subclass constructor without storage.
  FArray.lazy(this.rows, this.cols) : _cells = const [];

  factory FArray.generate(int rows, int cols, FValue Function(int r, int c) f) {
    final cells = List<FValue>.generate(
      rows * cols,
      (i) => f(i ~/ cols, i % cols),
    );
    return FArray(rows, cols, cells);
  }

  factory FArray.fromRows(List<List<FValue>> rows) {
    final r = rows.length;
    final c = r == 0 ? 0 : rows[0].length;
    return FArray(r, c, [for (final row in rows) ...row]);
  }

  /// A single row.
  factory FArray.row(List<FValue> values) => FArray(1, values.length, values);

  /// A single column.
  factory FArray.column(List<FValue> values) =>
      FArray(values.length, 1, values);

  int get length => rows * cols;

  FValue at(int r, int c) => _cells[r * cols + c];

  /// Element by row-major linear index.
  FValue atIndex(int i) => at(i ~/ cols, i % cols);

  /// Row-major elements.
  Iterable<FValue> get elements sync* {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        yield at(r, c);
      }
    }
  }

  /// Row [r] as a list.
  List<FValue> row(int r) => [for (var c = 0; c < cols; c++) at(r, c)];

  /// Column [c] as a list.
  List<FValue> column(int c) => [for (var r = 0; r < rows; r++) at(r, c)];

  /// Row lists.
  List<List<FValue>> toRows() => [for (var r = 0; r < rows; r++) row(r)];

  FValue get topLeft => rows == 0 || cols == 0 ? FEmpty.instance : at(0, 0);

  @override
  String get debugText {
    final b = StringBuffer('{');
    for (var r = 0; r < rows && r < 20; r++) {
      if (r > 0) b.write(';');
      for (var c = 0; c < cols && c < 20; c++) {
        if (c > 0) b.write(',');
        b.write(at(r, c).debugText);
      }
    }
    if (rows > 20 || cols > 20) b.write('…');
    b.write('}');
    return b.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! FArray || other.rows != rows || other.cols != cols) {
      return false;
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (at(r, c) != other.at(r, c)) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(rows, cols);
}

/// An array whose elements are computed on access (whole-column spills, 05 §8.4).
final class LazyArray extends FArray {
  final FValue Function(int r, int c) _element;
  LazyArray(super.rows, super.cols, this._element) : super.lazy();

  @override
  FValue at(int r, int c) => _element(r, c);
}

/// A rectangle on a sheet in current indices.
final class ResolvedArea {
  final String sheetId;
  final int top;
  final int left;
  final int bottom;
  final int right;

  const ResolvedArea(
    this.sheetId,
    this.top,
    this.left,
    this.bottom,
    this.right,
  );

  factory ResolvedArea.cell(String sheetId, int row, int col) =>
      ResolvedArea(sheetId, row, col, row, col);

  int get rows => bottom - top + 1;
  int get cols => right - left + 1;
  int get cellCount => rows * cols;
  bool get isSingleCell => top == bottom && left == right;
  GridRect get rect => GridRect(top, left, bottom, right);

  bool contains(int row, int col) =>
      row >= top && row <= bottom && col >= left && col <= right;

  ResolvedArea sub(int r1, int c1, int r2, int c2) =>
      ResolvedArea(sheetId, top + r1, left + c1, top + r2, left + c2);

  @override
  bool operator ==(Object other) =>
      other is ResolvedArea &&
      other.sheetId == sheetId &&
      other.top == top &&
      other.left == left &&
      other.bottom == bottom &&
      other.right == right;

  @override
  int get hashCode => Object.hash(sheetId, top, left, bottom, right);

  @override
  String toString() => '$sheetId!${rect.a1}';
}

/// A reference value (from a reference expression, INDEX, OFFSET, INDIRECT, CHOOSE, …).
final class FRef extends FValue {
  final ResolvedArea area;

  /// Whether the reference was produced at evaluation time (INDIRECT, OFFSET, INDEX, named
  /// ranges, unbound tokens); reads of dynamic references are recorded as dependencies.
  final bool dynamic;

  /// Whether the reference is open-ended or whole-row/column (`A:A`, `A2:B`); materialization
  /// clamps such references to the used extent (05 §8.4).
  final bool open;

  const FRef(this.area, {this.dynamic = false, this.open = false});

  FRef withArea(ResolvedArea a) => FRef(a, dynamic: true, open: open);

  @override
  String get debugText => 'Ref(${area.rect.a1})';

  @override
  bool operator ==(Object other) => other is FRef && other.area == area;

  @override
  int get hashCode => area.hashCode;
}

/// A callable function value (LAMBDA closure, named function used as a value).
abstract interface class FCallable {
  /// Parameter names.
  List<String> get params;

  /// Display name (`LAMBDA` or a named function name).
  String get name;
}

/// A LAMBDA value.
final class FLambda extends FValue {
  final FCallable closure;
  const FLambda(this.closure);

  @override
  String get debugText =>
      '<lambda ${closure.name}(${closure.params.join(', ')})>';
}

/// Kind of a renderable rich value.
enum RichKind { sparkline, image, hyperlink }

/// A renderable cell value (SPARKLINE, IMAGE, HYPERLINK). Other formulas see [scalar].
final class FRich extends FValue {
  final RichKind kind;
  final FValue scalar;
  final Object payload;
  const FRich(this.kind, this.scalar, this.payload);

  @override
  String get debugText => 'Rich(${kind.name}: ${scalar.debugText})';

  @override
  bool operator ==(Object other) =>
      other is FRich &&
      other.kind == kind &&
      other.scalar == scalar &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(kind, scalar);
}

/// Helpers over [FValue].
abstract final class FValues {
  static const FValue empty = FEmpty.instance;

  /// Change detection: same type, value and format hint.
  static bool sameValue(FValue a, FValue b) {
    if (identical(a, b)) return true;
    if (a is FNumber && b is FNumber) {
      return (a.v == b.v || (a.v.isNaN && b.v.isNaN)) && a.hint == b.hint;
    }
    if (a is FError && b is FError) {
      return a.kind == b.kind &&
          a.pending == b.pending &&
          a.message == b.message;
    }
    if (a is FArray && b is FArray) {
      if (a.rows != b.rows || a.cols != b.cols) return false;
      if (a.length > 100000) return false;
      for (var r = 0; r < a.rows; r++) {
        for (var c = 0; c < a.cols; c++) {
          if (!sameValue(a.at(r, c), b.at(r, c))) return false;
        }
      }
      return true;
    }
    return a == b;
  }
}
