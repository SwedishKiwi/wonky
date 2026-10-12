import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../eval/range_access.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';

/// LAMBDA helper functions (05 §15.11).
void registerLambdaHelpers(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.lambdaHelper;
  b.fn(
    'MAP',
    'Maps each value in the given arrays to a new value by application of a LAMBDA function to each value.',
    [
      P.array('array1', 'An array or range to be mapped.'),
      P.rep('array2', ArgKind.array, 'Additional arrays or ranges, then the LAMBDA (last argument), which takes as many parameters as there are arrays.'),
    ],
    _map,
    returns: ReturnKind.array,
    minArgs: 2,
    examples: ['MAP(A1:A3, LAMBDA(x, x * 2))', 'MAP(A1:A3, B1:B3, LAMBDA(a, b, a + b))'],
    seeAlso: ['LAMBDA', 'REDUCE', 'BYROW'],
  );
  b.fn(
    'REDUCE',
    'Reduces an array to an accumulated result by application of a LAMBDA function to each value.',
    [
      P.any('initial_value', 'The starting value of the accumulator.'),
      P.array('array_or_range', 'An array or range to be reduced.'),
      P.lambda('LAMBDA', 'A LAMBDA called with (accumulator, current_value) that returns the new accumulator.'),
    ],
    (a) => _scan(a, keepAll: false),
    examples: ['REDUCE(0, A1:A10, LAMBDA(acc, v, acc + v))'],
  );
  b.fn(
    'SCAN',
    'Scans an array and produces intermediate values by application of a LAMBDA function to each value. Returns an array of the intermediate values obtained at each step.',
    [
      P.any('initial_value', 'The starting value of the accumulator.'),
      P.array('array_or_range', 'An array or range to be scanned.'),
      P.lambda('LAMBDA', 'A LAMBDA called with (accumulator, current_value) that returns the new accumulator.'),
    ],
    (a) => _scan(a, keepAll: true),
    returns: ReturnKind.array,
    examples: ['SCAN(0, A1:A10, LAMBDA(acc, v, acc + v))'],
  );
  b.fn(
    'BYROW',
    'Groups an array by rows by application of a LAMBDA function to each row.',
    [P.array('array_or_range', 'An array or range to be grouped by rows.'), P.lambda('LAMBDA', 'A LAMBDA that takes a row and returns a single value.')],
    (a) => _byLine(a, rows: true),
    returns: ReturnKind.array,
    examples: ['BYROW(A1:C3, LAMBDA(row, SUM(row)))'],
  );
  b.fn(
    'BYCOL',
    'Groups an array by columns by application of a LAMBDA function to each column.',
    [P.array('array_or_range', 'An array or range to be grouped by columns.'), P.lambda('LAMBDA', 'A LAMBDA that takes a column and returns a single value.')],
    (a) => _byLine(a, rows: false),
    returns: ReturnKind.array,
    examples: ['BYCOL(A1:C3, LAMBDA(col, MAX(col)))'],
  );
  b.fn(
    'MAKEARRAY',
    'Returns an array of specified dimensions with values calculated by application of a LAMBDA function.',
    [
      P.num('rows', 'The number of rows to return.'),
      P.num('columns', 'The number of columns to return.'),
      P.lambda('LAMBDA', 'A LAMBDA called with (row_index, column_index), 1-based.'),
    ],
    (a) {
      final rows = a.integer(0), cols = a.integer(1);
      if (rows < 1 || cols < 1) fail(ErrorKind.value, 'MAKEARRAY dimensions must be positive.');
      if (rows * cols > maxArrayCells) fail(ErrorKind.num, ErrorMessages.resultTooLarge);
      final f = a.lambda(2);
      _checkArity(f, 2, 'MAKEARRAY');
      return FArray.generate(rows, cols, (r, c) => _scalar(a.ctx, a.call(f, [FNumber(r + 1.0), FNumber(c + 1.0)])));
    },
    returns: ReturnKind.array,
    examples: ['MAKEARRAY(3, 3, LAMBDA(r, c, r * c))'],
  );
}

void _checkArity(FCallable f, int n, String fn) {
  if (f.params.length != n) {
    fail(ErrorKind.value, 'Wrong number of arguments to LAMBDA in $fn. Expected $n arguments, but got ${f.params.length} arguments.');
  }
}

FValue _scalar(EvalContext ctx, FValue v) {
  if (v is FRef) v = RangeAccess.deref(ctx, v);
  if (v is FArray) {
    if (v.length == 1) return v.at(0, 0);
    return const FError(ErrorKind.value, 'Single value expected. Nested array results are not supported.');
  }
  if (v is FLambda) return const FError(ErrorKind.calc, ErrorMessages.lambdaResult);
  if (v is FOmitted) return FEmpty.instance;
  return v;
}

FValue _map(Args a) {
  final f = a.lambda(a.length - 1);
  final arrays = [for (var i = 0; i < a.length - 1; i++) a.array(i)];
  _checkArity(f, arrays.length, 'MAP');
  final r = arrays.first.rows, c = arrays.first.cols;
  for (final x in arrays) {
    if (x.rows != r || x.cols != c) fail(ErrorKind.value, 'Array arguments to MAP are of different size.');
  }
  return FArray.generate(r, c, (i, j) => _scalar(a.ctx, a.call(f, [for (final x in arrays) x.at(i, j)])));
}

FValue _scan(Args a, {required bool keepAll}) {
  var acc = a[0];
  if (acc is FRef) acc = RangeAccess.deref(a.ctx, acc);
  if (acc is FOmitted) acc = FEmpty.instance;
  final arr = a.array(1);
  final f = a.lambda(2);
  _checkArity(f, 2, keepAll ? 'SCAN' : 'REDUCE');
  final out = <FValue>[];
  for (final v in arr.elements) {
    acc = a.call(f, [acc, v]);
    if (keepAll) acc = _scalar(a.ctx, acc);
    if (keepAll) out.add(acc);
  }
  if (keepAll) return FArray(arr.rows, arr.cols, out);
  if (acc is FRef) return RangeAccess.deref(a.ctx, acc);
  return acc;
}

FValue _byLine(Args a, {required bool rows}) {
  final arr = a.array(0);
  final f = a.lambda(1);
  _checkArity(f, 1, rows ? 'BYROW' : 'BYCOL');
  if (rows) {
    return FArray.column([
      for (var r = 0; r < arr.rows; r++) _scalar(a.ctx, a.call(f, [FArray.row(arr.row(r))])),
    ]);
  }
  return FArray.row([
    for (var c = 0; c < arr.cols; c++) _scalar(a.ctx, a.call(f, [FArray.column(arr.column(c))])),
  ]);
}
