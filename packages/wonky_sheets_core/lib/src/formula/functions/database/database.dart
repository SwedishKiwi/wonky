import 'dart:math' as math;

import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../criteria.dart';
import '../helpers.dart';
import '../registry.dart';

/// Database functions (05 §15.12): `D…(database, field, criteria)` over a range whose first
/// row holds the field names. `criteria` is a range whose first row names fields and whose
/// following rows are OR-ed rows of AND-ed criteria (§15.14 syntax).
void registerDatabase(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.database;
  for (final agg in _DbAgg.values) {
    b.fn(
      agg.fnName,
      agg.summary,
      [
        P.range(
          'database',
          'The array or range containing the data to consider, structured in such a way that the first row contains the labels for each column\'s values.',
        ),
        P.scalar(
          'field',
          'Indicates which column in database contains the values to be extracted and operated on: the column label text, or its 1-based index.',
        ),
        P.range(
          'criteria',
          'An array or range containing zero or more criteria to filter the database values by before operating.',
        ),
      ],
      (a) => _evaluate(a, agg),
      cost: FunctionCost.heavy,
      examples: [
        '${agg.fnName}(A1:F20, "Price", G1:G2)',
        '${agg.fnName}(A1:F20, 2, {"Region"; "East"})',
      ],
      seeAlso: [
        for (final s in const ['DSUM', 'DCOUNT', 'DAVERAGE', 'DGET'])
          if (s != agg.fnName) s,
      ],
      notes: agg == _DbAgg.dcount || agg == _DbAgg.dcounta
          ? 'field may be left empty to count the matching records.'
          : null,
    );
  }
}

enum _DbAgg {
  daverage(
    'DAVERAGE',
    'Returns the average of a set of values selected from a database table-like array or range using a SQL-like query.',
  ),
  dcount(
    'DCOUNT',
    'Counts numeric values selected from a database table-like array or range using a SQL-like query.',
  ),
  dcounta(
    'DCOUNTA',
    'Counts values, including text, selected from a database table-like array or range using a SQL-like query.',
  ),
  dget(
    'DGET',
    'Returns a single value from a database table-like array or range using a SQL-like query.',
  ),
  dmax(
    'DMAX',
    'Returns the maximum value selected from a database table-like array or range using a SQL-like query.',
  ),
  dmin(
    'DMIN',
    'Returns the minimum value selected from a database table-like array or range using a SQL-like query.',
  ),
  dproduct(
    'DPRODUCT',
    'Returns the product of values selected from a database table-like array or range using a SQL-like query.',
  ),
  dstdev(
    'DSTDEV',
    'Returns the standard deviation of a population sample selected from a database table-like array or range using a SQL-like query.',
  ),
  dstdevp(
    'DSTDEVP',
    'Returns the standard deviation of an entire population selected from a database table-like array or range using a SQL-like query.',
  ),
  dsum(
    'DSUM',
    'Returns the sum of values selected from a database table-like array or range using a SQL-like query.',
  ),
  dvar(
    'DVAR',
    'Returns the variance of a population sample selected from a database table-like array or range using a SQL-like query.',
  ),
  dvarp(
    'DVARP',
    'Returns the variance of an entire population selected from a database table-like array or range using a SQL-like query.',
  );

  const _DbAgg(this.fnName, this.summary);

  final String fnName;
  final String summary;
}

String _label(FValue v) => switch (v) {
  FText(:final v) => v.trim().toLowerCase(),
  FNumber(:final v) => Numeric.toText(v),
  FBool(:final v) => v ? 'true' : 'false',
  FRich(:final scalar) => _label(scalar),
  _ => '',
};

FValue _evaluate(FunctionArgs a, _DbAgg agg) {
  final db = a.array(0);
  final crit = a.array(2);
  final labels = [for (var c = 0; c < db.cols; c++) _label(db.at(0, c))];
  final countOnly = agg == _DbAgg.dcount || agg == _DbAgg.dcounta;
  final field = _field(a, labels, allowEmpty: countOnly);
  final matches = _compileCriteria(a, crit, labels);
  final values = <FValue>[];
  for (var r = 1; r < db.rows; r++) {
    if (!matches(db, r)) continue;
    var v = field == null ? FBool.t : db.at(r, field);
    if (v is FRich) v = v.scalar;
    values.add(v);
  }

  if (agg == _DbAgg.dget) {
    if (values.isEmpty) {
      fail(ErrorKind.value, 'No match found in DGET evaluation.');
    }
    if (values.length > 1) {
      fail(ErrorKind.num, 'More than one match found in DGET evaluation.');
    }
    return values.single;
  }
  if (agg == _DbAgg.dcounta) {
    return FNumber(
      values
          .where((v) => v is! FEmpty && !(v is FText && v.v.isEmpty))
          .length
          .toDouble(),
    );
  }
  if (agg == _DbAgg.dcount && field == null) {
    return FNumber(values.length.toDouble());
  }
  final xs = <double>[];
  for (final v in values) {
    if (v is FError) {
      if (agg == _DbAgg.dcount) continue;
      throw FormulaError(v);
    }
    if (v is FNumber) xs.add(v.v);
  }
  switch (agg) {
    case _DbAgg.dcount:
      return FNumber(xs.length.toDouble());
    case _DbAgg.dsum:
      return numResult(sumOf(xs));
    case _DbAgg.daverage:
      if (xs.isEmpty) fail(ErrorKind.div0, ErrorMessages.divZeroEval(a.fn));
      return numResult(meanOf(xs));
    case _DbAgg.dmax:
      return numResult(xs.isEmpty ? 0 : xs.reduce(math.max));
    case _DbAgg.dmin:
      return numResult(xs.isEmpty ? 0 : xs.reduce(math.min));
    case _DbAgg.dproduct:
      if (xs.isEmpty) return FNumber.zero;
      return numResult(xs.fold(1.0, (p, x) => p * x));
    case _DbAgg.dstdev || _DbAgg.dvar:
      if (xs.length < 2) fail(ErrorKind.div0, ErrorMessages.divZeroEval(a.fn));
      final v = devSq(xs) / (xs.length - 1);
      return numResult(agg == _DbAgg.dvar ? v : math.sqrt(v));
    case _DbAgg.dstdevp || _DbAgg.dvarp:
      if (xs.isEmpty) fail(ErrorKind.div0, ErrorMessages.divZeroEval(a.fn));
      final v = devSq(xs) / xs.length;
      return numResult(agg == _DbAgg.dvarp ? v : math.sqrt(v));
    case _DbAgg.dget || _DbAgg.dcounta:
      throw StateError('handled above');
  }
}

/// Column index of the `field` argument, or null when it is empty and [allowEmpty].
int? _field(FunctionArgs a, List<String> labels, {required bool allowEmpty}) {
  final v = a.has(1) ? a.scalar(1) : FEmpty.instance;
  switch (v) {
    case FNumber(:final v):
      final i = v.truncate();
      if (i < 1 || i > labels.length) {
        fail(
          ErrorKind.value,
          'Function ${a.fn} parameter 2 value $i is out of range.',
        );
      }
      return i - 1;
    case FText(:final v):
      final i = labels.indexOf(v.trim().toLowerCase());
      if (i < 0 || v.trim().isEmpty) {
        fail(
          ErrorKind.value,
          "Function ${a.fn} parameter 2 value '$v' is not a field of the database.",
        );
      }
      return i;
    case FEmpty() || FOmitted() when allowEmpty:
      return null;
    default:
      fail(
        ErrorKind.value,
        'Function ${a.fn} parameter 2 expects a field label or a column index.',
      );
  }
}

typedef _RowTest = bool Function(FArray db, int row);

_RowTest _compileCriteria(FunctionArgs a, FArray crit, List<String> labels) {
  if (crit.rows < 2) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter 3 needs a header row and at least one criteria row.',
    );
  }
  final columns = [
    for (var c = 0; c < crit.cols; c++) labels.indexOf(_label(crit.at(0, c))),
  ];
  // Each criteria row: list of (database column, criterion); null = never matches.
  final rows = <List<(int, Criterion)>?>[];
  for (var r = 1; r < crit.rows; r++) {
    final conditions = <(int, Criterion)>[];
    var possible = true;
    for (var c = 0; c < crit.cols; c++) {
      var v = crit.at(r, c);
      if (v is FRich) v = v.scalar;
      if (v is FEmpty || (v is FText && v.v.isEmpty)) continue;
      if (columns[c] < 0) {
        possible = false;
        break;
      }
      conditions.add((columns[c], Criterion.of(v, a.locale)));
    }
    rows.add(possible ? conditions : null);
  }
  return (db, row) {
    for (final conditions in rows) {
      if (conditions == null) continue;
      var ok = true;
      for (final (col, criterion) in conditions) {
        if (!criterion.test(db.at(row, col))) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  };
}
