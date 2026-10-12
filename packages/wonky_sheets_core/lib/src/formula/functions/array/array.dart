import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';

/// Array & matrix functions (05 §15.9). FREQUENCY and the regression family live with the
/// statistical functions.
void registerArray(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.array;

  b.fn(
    'ARRAYFORMULA',
    'Enables the display of values returned from an array formula into multiple rows and/or columns and the use of non-array functions with arrays.',
    [P.array('array_formula', 'A range, mathematical expression using one cell range or multiple ranges of the same size, or a function that returns a result greater than one cell.')],
    (a) => a[0],
    returns: ReturnKind.array,
    handlesErrors: true,
    priority: Priority.p0,
    examples: ['ARRAYFORMULA(A1:C1 * A2:C2)', 'ARRAYFORMULA(SUM(A1:A10 * B1:B10))'],
  );

  b.fn(
    'SUMPRODUCT',
    'Calculates the sum of the products of corresponding entries in two equal-sized arrays or ranges.',
    [P.array('array1', 'The first array or range whose entries will be multiplied with corresponding entries in the second such array or range.'), P.rep('array2', ArgKind.array, 'Additional arrays of the same size.')],
    (a) {
      final arrays = [for (var i = 0; i < a.length; i++) a.array(i)];
      final r = arrays.first.rows, c = arrays.first.cols;
      for (final x in arrays) {
        if (x.rows != r || x.cols != c) fail(ErrorKind.value, 'SUMPRODUCT has mismatched range sizes. Expected row count: $r. column count: $c. Actual row count: ${x.rows}, column count: ${x.cols}.');
      }
      var sum = 0.0;
      for (var i = 0; i < r * c; i++) {
        var p = 1.0;
        for (final x in arrays) {
          final v = x.atIndex(i);
          if (v is FError) throw FormulaError(v);
          p *= v is FNumber ? v.v : 0;
        }
        sum += p;
      }
      return numResult(sum);
    },
    priority: Priority.p0,
    examples: ['SUMPRODUCT(A2:C5, D2:F5)', 'SUMPRODUCT((A1:A10 > 5) * B1:B10)'],
  );

  void pairSum(String name, String summary, double Function(double x, double y) f) {
    b.fn(
      name,
      summary,
      [P.array('array_x', 'The array or range of values whose entries are the first operand.'), P.array('array_y', 'The array or range of values whose entries are the second operand.')],
      (a) {
        final x = a.array(0), y = a.array(1);
        if (x.length != y.length) fail(ErrorKind.na, ErrorMessages.arraySizeMismatch(name));
        var s = 0.0;
        var any = false;
        for (var i = 0; i < x.length; i++) {
          final p = x.atIndex(i), q = y.atIndex(i);
          if (p is FError) throw FormulaError(p);
          if (q is FError) throw FormulaError(q);
          if (p is FNumber && q is FNumber) {
            any = true;
            s += f(p.v, q.v);
          }
        }
        if (!any) fail(ErrorKind.div0);
        return numResult(s);
      },
      priority: Priority.p2,
      examples: ['$name({1,2,3}, {4,5,6})'],
    );
  }

  pairSum('SUMX2MY2', 'Calculates the sum of the differences of the squares of values in two arrays.', (x, y) => x * x - y * y);
  pairSum('SUMX2PY2', 'Calculates the sum of the sums of the squares of values in two arrays.', (x, y) => x * x + y * y);
  pairSum('SUMXMY2', 'Calculates the sum of the squares of differences of values in two arrays.', (x, y) => (x - y) * (x - y));

  b.fn(
    'TRANSPOSE',
    'Transposes the rows and columns of an array or range of cells.',
    [P.array('array_or_range', 'The array or range whose rows and columns will be swapped.')],
    (a) {
      final x = a.array(0);
      return FArray.generate(x.cols, x.rows, (r, c) => x.at(c, r));
    },
    returns: ReturnKind.array,
    priority: Priority.p0,
    examples: ['TRANSPOSE(A1:C2)'],
  );

  b.fn(
    'MMULT',
    'Calculates the matrix product of two matrices specified as arrays or ranges.',
    [P.array('matrix1', 'The first matrix in the matrix multiplication operation.'), P.array('matrix2', 'The second matrix in the matrix multiplication operation.')],
    (a) {
      final m1 = _matrix(a, 0), m2 = _matrix(a, 1);
      final n = m1.length, k = m1.first.length, p = m2.first.length;
      if (k != m2.length) fail(ErrorKind.value, 'MMULT has mismatched dimensions.');
      return FArray.generate(n, p, (r, c) {
        var s = 0.0;
        for (var i = 0; i < k; i++) {
          s += m1[r][i] * m2[i][c];
        }
        return FNumber(s);
      });
    },
    returns: ReturnKind.array,
    examples: ['MMULT(A1:B2, C1:D2)'],
  );
  b.fn(
    'MDETERM',
    'Returns the matrix determinant of a square matrix specified as an array or range.',
    [P.array('square_matrix', 'An array or range with an equal number of rows and columns representing a matrix.')],
    (a) {
      final m = _matrix(a, 0);
      if (m.length != m.first.length) fail(ErrorKind.value, 'MDETERM requires a square matrix.');
      return numResult(_lu(m).det);
    },
    examples: ['MDETERM({1,2;3,4})'],
  );
  b.fn(
    'MINVERSE',
    'Returns the multiplicative inverse of a square matrix specified as an array or range.',
    [P.array('square_matrix', 'An array or range with an equal number of rows and columns representing a matrix.')],
    (a) {
      final m = _matrix(a, 0);
      final n = m.length;
      if (n != m.first.length) fail(ErrorKind.value, 'MINVERSE requires a square matrix.');
      final inv = invert(m);
      if (inv == null) fail(ErrorKind.num, 'MINVERSE: the matrix is singular.');
      return FArray.generate(n, n, (r, c) => FNumber(inv[r][c]));
    },
    returns: ReturnKind.array,
    examples: ['MINVERSE({1,2;3,4})'],
  );

  b.fn(
    'ARRAY_CONSTRAIN',
    'Constrains an array result to a specified size.',
    [P.array('input_range', 'The range to constrain.'), P.num('num_rows', 'The number of rows the result should contain.'), P.num('num_cols', 'The number of columns the result should contain.')],
    (a) {
      final x = a.array(0);
      final r = a.integer(1), c = a.integer(2);
      if (r < 1 || c < 1) fail(ErrorKind.value);
      final rr = r < x.rows ? r : x.rows, cc = c < x.cols ? c : x.cols;
      return FArray.generate(rr, cc, x.at);
    },
    returns: ReturnKind.array,
    examples: ['ARRAY_CONSTRAIN(A1:C10, 2, 2)'],
  );

  FValue takeDrop(Args a, {required bool take}) {
    final x = a.array(0);
    final hasRows = a.has(1), hasCols = a.has(2);
    if (!hasRows && !hasCols) fail(ErrorKind.value);
    var r = hasRows ? a.integer(1) : (take ? x.rows : 0);
    var c = hasCols ? a.integer(2) : (take ? x.cols : 0);
    int r0, r1, c0, c1;
    if (take) {
      if (r == 0 || c == 0) fail(ErrorKind.calc, 'Empty array result.');
      r = r.abs() > x.rows ? x.rows * r.sign : r;
      c = c.abs() > x.cols ? x.cols * c.sign : c;
      (r0, r1) = r > 0 ? (0, r) : (x.rows + r, x.rows);
      (c0, c1) = c > 0 ? (0, c) : (x.cols + c, x.cols);
    } else {
      (r0, r1) = r >= 0 ? (r, x.rows) : (0, x.rows + r);
      (c0, c1) = c >= 0 ? (c, x.cols) : (0, x.cols + c);
      if (r0 >= r1 || c0 >= c1) fail(ErrorKind.calc, 'Empty array result.');
    }
    return FArray.generate(r1 - r0, c1 - c0, (i, j) => x.at(r0 + i, c0 + j));
  }

  b.fn(
    'TAKE',
    'Returns rows or columns from the start or end of an array.',
    [P.array('array', 'The array to take from.'), P.num('rows', 'Rows to take; negative takes from the end.', true), P.num('columns', 'Columns to take; negative takes from the end.', true)],
    (a) => takeDrop(a, take: true),
    returns: ReturnKind.array,
    examples: ['TAKE(A1:C10, 3)', 'TAKE(A1:C10, -2, 1)'],
  );
  b.fn(
    'DROP',
    'Removes rows or columns from the start or end of an array.',
    [P.array('array', 'The array to drop from.'), P.num('rows', 'Rows to drop; negative drops from the end.', true), P.num('columns', 'Columns to drop; negative drops from the end.', true)],
    (a) => takeDrop(a, take: false),
    returns: ReturnKind.array,
    examples: ['DROP(A1:C10, 1)'],
  );
  b.fn(
    'EXPAND',
    'Expands an array to the specified dimensions.',
    [
      P.array('array', 'The array to expand.'),
      P.num('rows', 'The number of rows of the result.'),
      P.num('columns', 'The number of columns of the result.', true),
      P.scalar('pad_with', 'The value with which to pad. Default is #N/A.', true),
    ],
    (a) {
      final x = a.array(0);
      final r = a.has(1) ? a.integer(1) : x.rows;
      final c = a.has(2) ? a.integer(2) : x.cols;
      if (r < x.rows || c < x.cols) fail(ErrorKind.value, 'EXPAND cannot shrink an array.');
      final pad = a.has(3) ? a.scalarOrError(3) : FError.na;
      return FArray.generate(r, c, (i, j) => i < x.rows && j < x.cols ? x.at(i, j) : pad);
    },
    returns: ReturnKind.array,
    examples: ['EXPAND(A1:B2, 3, 3, 0)'],
  );

  FValue stack(Args a, {required bool vertical}) {
    final parts = [for (var i = 0; i < a.length; i++) a.array(i)];
    if (vertical) {
      final w = parts.map((p) => p.cols).reduce((x, y) => x > y ? x : y);
      final rows = <List<FValue>>[];
      for (final p in parts) {
        for (var r = 0; r < p.rows; r++) {
          rows.add([for (var c = 0; c < w; c++) c < p.cols ? p.at(r, c) : FError.na]);
        }
      }
      return FArray.fromRows(rows);
    }
    final h = parts.map((p) => p.rows).reduce((x, y) => x > y ? x : y);
    final rows = <List<FValue>>[for (var r = 0; r < h; r++) []];
    for (final p in parts) {
      for (var r = 0; r < h; r++) {
        for (var c = 0; c < p.cols; c++) {
          rows[r].add(r < p.rows ? p.at(r, c) : FError.na);
        }
      }
    }
    return FArray.fromRows(rows);
  }

  b.fn(
    'HSTACK',
    'Appends ranges horizontally and in sequence to return a larger array.',
    [P.array('range1', 'The first range to append.'), P.rep('range2', ArgKind.array, 'Additional ranges to add.')],
    (a) => stack(a, vertical: false),
    returns: ReturnKind.array,
    priority: Priority.p0,
    examples: ['HSTACK(A1:B2, C1:D2)'],
  );
  b.fn(
    'VSTACK',
    'Appends ranges vertically and in sequence to return a larger array.',
    [P.array('range1', 'The first range to append.'), P.rep('range2', ArgKind.array, 'Additional ranges to add.')],
    (a) => stack(a, vertical: true),
    returns: ReturnKind.array,
    priority: Priority.p0,
    examples: ['VSTACK(A1:B2, A10:B12)'],
  );

  b.fn(
    'FLATTEN',
    'Flattens all the values from one or more ranges into a single column.',
    [P.array('range1', 'The first range to flatten.'), P.rep('range2', ArgKind.array, 'Additional ranges to flatten.')],
    (a) {
      final out = <FValue>[];
      for (var i = 0; i < a.length; i++) {
        out.addAll(a.array(i).elements);
      }
      return FArray.column(out);
    },
    returns: ReturnKind.array,
    examples: ['FLATTEN(A1:B2)'],
  );

  FValue toVector(Args a, {required bool column}) {
    final x = a.array(0);
    final ignore = a.intOr(1, 0);
    final byCol = a.boolOr(2, false);
    if (ignore < 0 || ignore > 3) fail(ErrorKind.value);
    final out = <FValue>[];
    void push(FValue v) {
      if ((ignore == 1 || ignore == 3) && v is FEmpty) return;
      if ((ignore == 2 || ignore == 3) && v is FError) return;
      out.add(v);
    }

    if (byCol) {
      for (var c = 0; c < x.cols; c++) {
        for (var r = 0; r < x.rows; r++) {
          push(x.at(r, c));
        }
      }
    } else {
      x.elements.forEach(push);
    }
    if (out.isEmpty) fail(ErrorKind.calc, 'Empty array result.');
    return column ? FArray.column(out) : FArray.row(out);
  }

  b.fn(
    'TOCOL',
    'Transforms an array or range of cells into a single column.',
    [
      P.array('array_or_range', 'The array or range to transform.'),
      P.num('ignore', '0 keep all (default), 1 ignore blanks, 2 ignore errors, 3 ignore blanks and errors.', true, 0),
      P.bool_('scan_by_column', 'Scan column by column (TRUE) or row by row (FALSE, default).', true, false),
    ],
    (a) => toVector(a, column: true),
    returns: ReturnKind.array,
    examples: ['TOCOL(A1:C3, 1)'],
  );
  b.fn(
    'TOROW',
    'Transforms an array or range of cells into a single row.',
    [
      P.array('array_or_range', 'The array or range to transform.'),
      P.num('ignore', '0 keep all (default), 1 ignore blanks, 2 ignore errors, 3 ignore blanks and errors.', true, 0),
      P.bool_('scan_by_column', 'Scan column by column (TRUE) or row by row (FALSE, default).', true, false),
    ],
    (a) => toVector(a, column: false),
    returns: ReturnKind.array,
    examples: ['TOROW(A1:C3)'],
  );

  FValue wrap(Args a, {required bool rows}) {
    final x = a.array(0);
    if (x.rows != 1 && x.cols != 1) fail(ErrorKind.value, '${a.fn} expects a single row or column.');
    final n = a.integer(1);
    if (n < 1) fail(ErrorKind.num);
    final pad = a.has(2) ? a.scalarOrError(2) : FError.na;
    final items = x.elements.toList();
    final groups = (items.length + n - 1) ~/ n;
    if (rows) {
      return FArray.generate(groups, n, (r, c) {
        final i = r * n + c;
        return i < items.length ? items[i] : pad;
      });
    }
    return FArray.generate(n, groups, (r, c) {
      final i = c * n + r;
      return i < items.length ? items[i] : pad;
    });
  }

  b.fn(
    'WRAPROWS',
    'Wraps the provided row or column of cells by rows after a specified number of elements to form a new array.',
    [P.array('range', 'The range to wrap.'), P.num('wrap_count', 'The maximum number of cells for each row.'), P.scalar('pad_with', 'The value with which to fill the extra cells.', true)],
    (a) => wrap(a, rows: true),
    returns: ReturnKind.array,
    examples: ['WRAPROWS(A1:A10, 3)'],
  );
  b.fn(
    'WRAPCOLS',
    'Wraps the provided row or column of cells by columns after a specified number of elements to form a new array.',
    [P.array('range', 'The range to wrap.'), P.num('wrap_count', 'The maximum number of cells for each column.'), P.scalar('pad_with', 'The value with which to fill the extra cells.', true)],
    (a) => wrap(a, rows: false),
    returns: ReturnKind.array,
    examples: ['WRAPCOLS(A1:A10, 3)'],
  );
}

List<List<double>> _matrix(Args a, int i) {
  final x = a.array(i);
  return [
    for (var r = 0; r < x.rows; r++)
      [
        for (var c = 0; c < x.cols; c++)
          switch (x.at(r, c)) {
            FNumber(:final v) => v,
            final FError e => throw FormulaError(e),
            _ => fail(ErrorKind.value, 'Function ${a.fn} parameter ${i + 1} expects number values.'),
          },
      ],
  ];
}

final class _Lu {
  final List<List<double>> lu;
  final List<int> perm;
  final double det;
  _Lu(this.lu, this.perm, this.det);
}

_Lu _lu(List<List<double>> m) {
  final n = m.length;
  final a = [for (final r in m) List<double>.of(r)];
  final perm = List<int>.generate(n, (i) => i);
  var det = 1.0;
  for (var k = 0; k < n; k++) {
    var p = k;
    for (var i = k + 1; i < n; i++) {
      if (a[i][k].abs() > a[p][k].abs()) p = i;
    }
    if (a[p][k] == 0) return _Lu(a, perm, 0);
    if (p != k) {
      final t = a[p];
      a[p] = a[k];
      a[k] = t;
      final tp = perm[p];
      perm[p] = perm[k];
      perm[k] = tp;
      det = -det;
    }
    det *= a[k][k];
    for (var i = k + 1; i < n; i++) {
      a[i][k] /= a[k][k];
      for (var j = k + 1; j < n; j++) {
        a[i][j] -= a[i][k] * a[k][j];
      }
    }
  }
  return _Lu(a, perm, det);
}

/// Matrix inverse by Gauss–Jordan with partial pivoting; null when singular.
List<List<double>>? invert(List<List<double>> m) {
  final n = m.length;
  final a = [
    for (var i = 0; i < n; i++) [...m[i], for (var j = 0; j < n; j++) i == j ? 1.0 : 0.0],
  ];
  for (var k = 0; k < n; k++) {
    var p = k;
    for (var i = k + 1; i < n; i++) {
      if (a[i][k].abs() > a[p][k].abs()) p = i;
    }
    if (a[p][k].abs() < 1e-300) return null;
    final t = a[p];
    a[p] = a[k];
    a[k] = t;
    final pivot = a[k][k];
    for (var j = 0; j < 2 * n; j++) {
      a[k][j] /= pivot;
    }
    for (var i = 0; i < n; i++) {
      if (i == k) continue;
      final f = a[i][k];
      if (f == 0) continue;
      for (var j = 0; j < 2 * n; j++) {
        a[i][j] -= f * a[k][j];
      }
    }
  }
  return [for (final r in a) r.sublist(n)];
}
