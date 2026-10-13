import 'dart:math' as math;

import '../../../addressing/a1.dart';
import '../../../addressing/column_letters.dart';
import '../../../addressing/r1c1.dart';
import '../../../addressing/sheet_names.dart';
import '../../codec/formula_codec.dart';
import '../../eval/args.dart';
import '../../eval/compiler.dart';
import '../../eval/eval_context.dart';
import '../../eval/range_access.dart';
import '../../values/compare.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../criteria.dart';
import '../registry.dart';

/// Lookup & reference functions (05 §15.3).
void registerLookup(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.lookup;

  b.fn(
    'VLOOKUP',
    'Vertical lookup. Searches down the first column of a range for a key and returns the value of a specified cell in the row found.',
    [
      P.scalar(
        'search_key',
        'The value to search for. For example, 42, "Cats", or I24.',
      ),
      P.range(
        'range',
        'The range to consider for the search. The first column in the range is searched for the key specified in search_key.',
      ),
      P.num(
        'index',
        'The column index of the value to be returned, where the first column in range is numbered 1.',
      ),
      P.bool_(
        'is_sorted',
        'Indicates whether the column to be searched (the first column of the specified range) is sorted. FALSE is recommended: exact match.',
        true,
        true,
      ),
    ],
    (a) => _vhlookup(a, vertical: true),
    priority: Priority.p0,
    examples: ['VLOOKUP(10003, A2:B26, 2, FALSE)'],
    seeAlso: ['XLOOKUP', 'HLOOKUP', 'INDEX', 'MATCH'],
  );
  b.fn(
    'HLOOKUP',
    'Horizontal lookup. Searches across the first row of a range for a key and returns the value of a specified cell in the column found.',
    [
      P.scalar('search_key', 'The value to search for.'),
      P.range(
        'range',
        'The range to consider for the search. The first row in the range is searched for the key.',
      ),
      P.num(
        'index',
        'The row index of the value to be returned, where the first row in range is numbered 1.',
      ),
      P.bool_(
        'is_sorted',
        'Indicates whether the row to be searched is sorted.',
        true,
        true,
      ),
    ],
    (a) => _vhlookup(a, vertical: false),
    priority: Priority.p0,
    examples: ['HLOOKUP(10003, A1:Z2, 2, FALSE)'],
    seeAlso: ['VLOOKUP', 'XLOOKUP'],
  );
  b.fn(
    'LOOKUP',
    'Looks through a sorted row or column for a key and returns the value of the cell in a result range located in the same position as the search row or column.',
    [
      P.scalar('search_key', 'The value to search for in the row or column.'),
      P.range(
        'search_range_or_search_result_array',
        'The sorted range to search, or an array whose first row/column is searched and last row/column returned.',
      ),
      P.range('result_range', 'The range from which to return a result.', true),
    ],
    _lookup,
    examples: [
      'LOOKUP(10003, A1:A100, B1:B100)',
      'LOOKUP(3, {1,2,3;"a","b","c"})',
    ],
  );
  b.fn(
    'MATCH',
    'Returns the relative position of an item in a range that matches a specified value.',
    [
      P.scalar('search_key', 'The value to search for.'),
      P.range('range', 'The one-dimensional array to be searched.'),
      P.num(
        'search_type',
        '1 (default): sorted ascending, largest value ≤ key; 0: exact match; -1: sorted descending, smallest value ≥ key.',
        true,
        1,
      ),
    ],
    _match,
    priority: Priority.p0,
    examples: ['MATCH("Sunday", A2:A9, 0)', 'MATCH(DATE(2012, 1, 1), A2:F2)'],
    seeAlso: ['INDEX', 'XMATCH'],
  );
  b.fn(
    'XMATCH',
    'Returns the relative position of an item in an array or range that matches a specified value based on different match and search modes.',
    [
      P.scalar('search_key', 'The value to search for.'),
      P.range(
        'lookup_range',
        'The range to search. Must be a single row or column.',
      ),
      P.num(
        'match_mode',
        '0 (default) exact; -1 exact or next smaller; 1 exact or next larger; 2 wildcard match.',
        true,
        0,
      ),
      P.num(
        'search_mode',
        '1 (default) first to last; -1 last to first; 2 binary search ascending; -2 binary search descending.',
        true,
        1,
      ),
    ],
    (a) {
      final (vec, _) = _vector(a, a[1], 'XMATCH');
      final i = _xsearch(a, vec, a.scalar(0), a.intOr(2, 0), a.intOr(3, 1));
      if (i < 0) {
        return FError(
          ErrorKind.na,
          ErrorMessages.didNotFind(_keyText(a.scalar(0)), 'XMATCH'),
        );
      }
      return FNumber(i + 1.0);
    },
    examples: ['XMATCH("Apple", A2:A10)'],
    seeAlso: ['XLOOKUP', 'MATCH'],
  );
  b.fn(
    'XLOOKUP',
    'Returns the values in the result range based on the position where a match was found in the lookup range. If no match is found, it returns the closest match.',
    [
      P.scalar('search_key', 'The value to search for.'),
      P.range(
        'lookup_range',
        'The range to consider for the search. Must be a single row or column.',
      ),
      P.range(
        'result_range',
        'The range to consider for the result. Its row or column size must match lookup_range.',
      ),
      P.lazy(
        'missing_value',
        'The value to return if no match is found.',
        true,
      ),
      P.num(
        'match_mode',
        '0 (default) exact; -1 exact or next smaller; 1 exact or next larger; 2 wildcard match.',
        true,
        0,
      ),
      P.num(
        'search_mode',
        '1 (default) first to last; -1 last to first; 2 binary search ascending; -2 binary search descending.',
        true,
        1,
      ),
    ],
    _xlookup,
    priority: Priority.p0,
    examples: [
      'XLOOKUP("Apple", A2:A10, B2:B10)',
      'XLOOKUP(E2, A:A, C:D, "Not found")',
    ],
    seeAlso: ['VLOOKUP', 'XMATCH', 'INDEX'],
  );
  b.fn(
    'INDEX',
    'Returns the content of a cell, specified by row and column offset.',
    [
      P.array(
        'reference',
        'The range of cells from which the values are returned.',
      ),
      P.num(
        'row',
        'The index of the row to be returned from within the reference range of cells. 0 returns the whole column.',
        true,
        0,
      ),
      P.num(
        'column',
        'The index of the column to be returned from within the reference range of cells. 0 returns the whole row.',
        true,
        0,
      ),
      P.num('area', 'Area number (only 1 is supported).', true, 1),
    ],
    _index,
    returns: ReturnKind.reference,
    liftable: false,
    priority: Priority.p0,
    examples: ['INDEX(A1:C20, 5, 1)', 'SUM(A1:INDEX(A:A, 10))'],
    seeAlso: ['MATCH', 'OFFSET'],
  );
  b.fn(
    'OFFSET',
    'Returns a range reference shifted a specified number of rows and columns from a starting cell reference.',
    [
      P.ref(
        'cell_reference',
        'The starting point from which to count the offset rows and columns.',
      ),
      P.num('offset_rows', 'The number of rows to shift by.'),
      P.num('offset_columns', 'The number of columns to shift by.'),
      P.num(
        'height',
        'The height of the range to return starting at the offset target.',
        true,
      ),
      P.num(
        'width',
        'The width of the range to return starting at the offset target.',
        true,
      ),
    ],
    _offset,
    returns: ReturnKind.reference,
    liftable: false,
    positionSensitive: true,
    priority: Priority.p0,
    examples: ['OFFSET(A2, 3, 4)', 'SUM(OFFSET(A1, 0, 0, 5, 1))'],
  );
  b.fn(
    'INDIRECT',
    'Returns a cell reference specified by a string.',
    [
      P.text(
        'cell_reference_as_string',
        'A cell reference, written as a string with surrounding quotation marks.',
      ),
      P.bool_(
        'is_A1_notation',
        'Indicates if the cell reference is in A1 notation (TRUE) or R1C1 notation (FALSE).',
        true,
        true,
      ),
    ],
    _indirect,
    returns: ReturnKind.reference,
    liftable: false,
    positionSensitive: true,
    priority: Priority.p0,
    examples: ['INDIRECT("Sheet2!" & B10)', 'INDIRECT("R2C3", FALSE)'],
  );
  b.fn(
    'ROW',
    'Returns the row number of a specified cell.',
    [
      P.ref(
        'cell_reference',
        'The cell whose row number will be returned.',
        true,
      ),
    ],
    (a) => _rowCol(a, row: true),
    positionSensitive: true,
    liftable: false,
    priority: Priority.p0,
    examples: ['ROW(A9)', 'ROW()'],
  );
  b.fn(
    'COLUMN',
    'Returns the column number of a specified cell, with A = 1.',
    [
      P.ref(
        'cell_reference',
        'The cell whose column number will be returned.',
        true,
      ),
    ],
    (a) => _rowCol(a, row: false),
    positionSensitive: true,
    liftable: false,
    priority: Priority.p0,
    examples: ['COLUMN(C9)', 'COLUMN()'],
  );
  b.fn(
    'ROWS',
    'Returns the number of rows in a specified array or range.',
    [P.array('range', 'The range whose row count will be returned.')],
    (a) => FNumber(a.shape(0).$1.toDouble()),
    liftable: false,
    priority: Priority.p0,
    examples: ['ROWS(A9:A62)'],
  );
  b.fn(
    'COLUMNS',
    'Returns the number of columns in a specified array or range.',
    [P.array('range', 'The range whose column count will be returned.')],
    (a) => FNumber(a.shape(0).$2.toDouble()),
    liftable: false,
    priority: Priority.p0,
    examples: ['COLUMNS(A1:F1)'],
  );
  b.fn(
    'ADDRESS',
    'Returns a cell reference as a string.',
    [
      P.num('row', 'The row number of the cell reference.'),
      P.num(
        'column',
        'The column number (not name) of the cell reference. A is column number 1.',
      ),
      P.num(
        'absolute_relative_mode',
        '1 (default) row and column absolute; 2 row absolute, column relative; 3 row relative, column absolute; 4 both relative.',
        true,
        1,
      ),
      P.bool_(
        'use_a1_notation',
        'Whether to use A1 notation (TRUE) or R1C1 notation (FALSE).',
        true,
        true,
      ),
      P.text(
        'sheet',
        'Text indicating the name of the sheet into which the address points.',
        true,
      ),
    ],
    _address,
    examples: ['ADDRESS(1, 2)', 'ADDRESS(1, 2, 4, FALSE, "Sheet2")'],
  );
  b.fn(
    'CHOOSE',
    'Returns an element from a list of choices based on index.',
    [
      P.num('index', 'Which choice (of the up to 30 provided) to return.'),
      P.lazy(
        'choice1',
        'A potential value to return. Required. May be a reference to a cell or an individual value.',
      ),
      P.rep(
        'choice2',
        ArgKind.lazy,
        'Additional values among which to choose.',
      ),
    ],
    (a) {
      final i = a.integer(0);
      if (i < 1 || i > a.length - 1) {
        fail(ErrorKind.num, 'CHOOSE index $i is out of range.');
      }
      final v = a.lazy(i);
      return v is FOmitted ? FEmpty.instance : v;
    },
    returns: ReturnKind.reference,
    priority: Priority.p0,
    examples: ['CHOOSE(2, "A", "B", "C")'],
  );
  b.fn(
    'CHOOSECOLS',
    'Creates a new array from the selected columns in the existing range.',
    [
      P.array('array', 'The array that contains the columns to be returned.'),
      P.num(
        'col_num1',
        'The first column number to return; negative numbers count from the end.',
      ),
      P.rep('col_num2', ArgKind.number, 'Additional column numbers.'),
    ],
    (a) => _choose(a, cols: true),
    returns: ReturnKind.array,
    liftable: false,
    examples: ['CHOOSECOLS(A1:D5, 1, -1)'],
  );
  b.fn(
    'CHOOSEROWS',
    'Creates a new array from the selected rows in the existing range.',
    [
      P.array('array', 'The array that contains the rows to be returned.'),
      P.num(
        'row_num1',
        'The first row number to return; negative numbers count from the end.',
      ),
      P.rep('row_num2', ArgKind.number, 'Additional row numbers.'),
    ],
    (a) => _choose(a, cols: false),
    returns: ReturnKind.array,
    liftable: false,
    examples: ['CHOOSEROWS(A1:D5, 1, 3)'],
  );
  b.fn(
    'FORMULATEXT',
    'Returns the formula as a string.',
    [P.ref('cell', 'A reference to a cell.')],
    (a) {
      final r = a.ref(0);
      final s = a.sheetOfRef(r);
      final f = a.ctx.host.formulaAt(s, r.area.top, r.area.left);
      if (f == null) {
        fail(ErrorKind.na, 'FORMULATEXT parameter 1 is not a formula.');
      }
      return FText(
        FormulaCodec.toA1(
          f,
          CodecContext(
            workbook: a.ctx.workbook,
            hostSheetId: s.id,
            hostRow: r.area.top,
            hostCol: r.area.left,
            locale: a.locale,
          ),
        ),
      );
    },
    liftable: false,
    examples: ['FORMULATEXT(A1)'],
  );
  b.fn(
    'GETPIVOTDATA',
    'Extracts an aggregated value from a pivot table that corresponds to the specified row and column headings.',
    [
      P.text(
        'value_name',
        'The name of the value in the pivot table for which you want to get data.',
      ),
      P.ref(
        'any_pivot_table_cell',
        'Any reference to a cell in the desired pivot table.',
      ),
      P.rep(
        'original_column',
        ArgKind.text,
        'The name of the column in the original data set.',
      ),
      P.rep(
        'pivot_item',
        ArgKind.scalar,
        'The name of the row or column shown in the pivot table corresponding to original_column.',
      ),
    ],
    (a) {
      final provider = a.ctx.host.pivots;
      final r = a.ref(1);
      if (provider == null) {
        fail(ErrorKind.ref, 'The reference is not inside a pivot table.');
      }
      final filters = <(String, FValue)>[];
      for (var i = 2; i + 1 < a.length; i += 2) {
        filters.add((a.text(i), a.scalar(i + 1)));
      }
      return provider.getPivotData(
        r.area.sheetId,
        r.area.top,
        r.area.left,
        a.text(0),
        filters,
      );
    },
    liftable: false,
    examples: [
      'GETPIVOTDATA("SUM of number of units", A1, "division", "east")',
    ],
  );
}

String _keyText(FValue v) => switch (v) {
  FNumber(:final v) => Numeric.toText(v),
  FText(:final v) => v,
  FBool(:final v) => v ? 'TRUE' : 'FALSE',
  _ => '',
};

/// 1-D vector of a range/array argument (+ orientation: true = vertical).
(List<FValue>, bool) _vector(Args a, FValue v, String fn) {
  if (v is FError) throw FormulaError(v);
  final (rows, cols) = RangeAccess.shape(v);
  if (rows != 1 && cols != 1) {
    fail(ErrorKind.na, '$fn range must be a single row or a single column.');
  }
  final vertical = cols == 1 && rows != 1 || (rows == 1 && cols == 1);
  return (_cells(a, v, 0, vertical, vertical ? rows : cols), vertical);
}

/// Values of row/column [index] of a range/array (cached for references).
List<FValue> _cells(Args a, FValue v, int index, bool vertical, int length) {
  if (v is FArray) {
    return vertical ? v.column(index) : v.row(index);
  }
  if (v is! FRef) return [v is FRich ? v.scalar : v];
  final ctx = a.ctx;
  final area = v.area;
  final s = a.sheetOfRef(v);
  if (v.dynamic) ctx.deps.areas.add(area);
  final used = vertical
      ? ctx.host.usedRows(s) - area.top
      : ctx.host.usedColumns(s) - area.left;
  final n = math.max(0, math.min(length, used));
  final sub = vertical
      ? ResolvedArea(
          area.sheetId,
          area.top,
          area.left + index,
          area.top + math.max<int>(n, 1) - 1,
          area.left + index,
        )
      : ResolvedArea(
          area.sheetId,
          area.top + index,
          area.left,
          area.top + index,
          area.left + math.max<int>(n, 1) - 1,
        );
  final key =
      'V|${sub.sheetId}|${sub.top}|${sub.left}|${sub.bottom}|${sub.right}';
  final stamp = ctx.host.lookupCache.stampOf(sub);
  final cached = ctx.host.lookupCache.get<List<FValue>>(key, stamp);
  if (cached != null) return cached;
  final out = List<FValue>.filled(n, FEmpty.instance);
  if (n > 0) {
    ctx.host.forEachValue(s, sub.rect, (r, c, x) {
      out[vertical ? r - sub.top : c - sub.left] = x is FRich ? x.scalar : x;
    });
  }
  if (n >= 32) ctx.host.lookupCache.put(key, stamp, out);
  return out;
}

final Expando<Map<Object, int>> _firstMaps = Expando();
final Expando<Map<Object, int>> _lastMaps = Expando();

/// Exact-match position via cached hash index (05 §11.2 ExactMatchIndex); -1 when absent.
int _exactIndex(Args a, List<FValue> vec, FValue key, {bool last = false}) {
  final k = Compare.matchKey(key);
  if (k == null) {
    for (var i = 0; i < vec.length; i++) {
      final j = last ? vec.length - 1 - i : i;
      if (Compare.compare(vec[j], key) == 0 &&
          vec[j] is! FError &&
          vec[j] is! FEmpty) {
        return j;
      }
    }
    return -1;
  }
  if (vec.length < 64) {
    for (var i = 0; i < vec.length; i++) {
      final j = last ? vec.length - 1 - i : i;
      final x = vec[j];
      if (x is FNumber && key is FNumber) {
        if (Numeric.approxEqual(x.v, key.v)) return j;
      } else if (Compare.matchKey(x) == k) {
        return j;
      }
    }
    return -1;
  }
  final exp = last ? _lastMaps : _firstMaps;
  var map = exp[vec];
  if (map == null) {
    map = <Object, int>{};
    for (var i = 0; i < vec.length; i++) {
      final j = last ? vec.length - 1 - i : i;
      final mk = Compare.matchKey(vec[j]);
      if (mk != null) map.putIfAbsent(mk, () => j);
    }
    exp[vec] = map;
  }
  return map[k] ?? -1;
}

bool _isWildcardKey(FValue key) =>
    key is FText &&
    (key.v.contains('*') || key.v.contains('?') || key.v.contains('~'));

int _wildcardIndex(List<FValue> vec, String pattern, {bool last = false}) {
  final re = Criterion.wildcardRegExp(pattern);
  for (var i = 0; i < vec.length; i++) {
    final j = last ? vec.length - 1 - i : i;
    final x = vec[j];
    if (x is FText && re.hasMatch(x.v)) return j;
  }
  return -1;
}

int _rank(FValue v) => switch (v) {
  FNumber() => 0,
  FText() => 1,
  FBool() => 2,
  _ => -1,
};

/// Binary search for the last position whose value (same type as key) is ≤ key (ascending)
/// or ≥ key ([descending]).
int _approx(List<FValue> vec, FValue key, {bool descending = false}) {
  final kr = _rank(key);
  final pos = <int>[
    for (var i = 0; i < vec.length; i++)
      if (_rank(vec[i]) == kr) i,
  ];
  var lo = 0, hi = pos.length - 1, found = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final c = Compare.compare(vec[pos[mid]], key);
    final ok = descending ? c >= 0 : c <= 0;
    if (ok) {
      found = pos[mid];
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return found;
}

FValue _vhlookup(Args a, {required bool vertical}) {
  final key = a.scalar(0);
  final range = a[1];
  if (range is FError) return range;
  final (rows, cols) = RangeAccess.shape(range);
  final index = a.integer(2);
  if (index < 1) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter 3 value is $index. It should be greater than or equal to 1.',
    );
  }
  if (index > (vertical ? cols : rows)) {
    fail(ErrorKind.ref, '${a.fn} evaluates to an out of bounds range.');
  }
  final sorted = a.boolOr(3, true);
  final vec = _cells(a, range, 0, vertical, vertical ? rows : cols);
  int i;
  if (!sorted) {
    i = _isWildcardKey(key)
        ? _wildcardIndex(vec, (key as FText).v)
        : _exactIndex(a, vec, key);
  } else {
    i = _approx(vec, key);
  }
  if (i < 0) {
    return FError(ErrorKind.na, ErrorMessages.didNotFind(_keyText(key), a.fn));
  }
  return _resultAt(
    a,
    range,
    vertical ? i : index - 1,
    vertical ? index - 1 : i,
  );
}

FValue _resultAt(Args a, FValue range, int r, int c) {
  if (range is FRef) {
    final s = a.sheetOfRef(range);
    return RangeAccess.cellWithHint(
      a.ctx,
      s,
      range.area.top + r,
      range.area.left + c,
    );
  }
  return RangeAccess.elementAt(a.ctx, range, r, c);
}

FValue _lookup(Args a) {
  final key = a.scalar(0);
  final src = a[1];
  if (src is FError) return src;
  final (rows, cols) = RangeAccess.shape(src);
  if (a.has(2)) {
    final (vec, _) = _vector(a, src, 'LOOKUP');
    final i = _approx(vec, key);
    if (i < 0) {
      return FError(
        ErrorKind.na,
        ErrorMessages.didNotFind(_keyText(key), 'LOOKUP'),
      );
    }
    final res = a[2];
    final (rr, _) = RangeAccess.shape(res);
    return rr == 1 ? _resultAt(a, res, 0, i) : _resultAt(a, res, i, 0);
  }
  final horizontal = cols > rows;
  final vec = _cells(a, src, 0, !horizontal, horizontal ? cols : rows);
  final i = _approx(vec, key);
  if (i < 0) {
    return FError(
      ErrorKind.na,
      ErrorMessages.didNotFind(_keyText(key), 'LOOKUP'),
    );
  }
  return horizontal
      ? _resultAt(a, src, rows - 1, i)
      : _resultAt(a, src, i, cols - 1);
}

FValue _match(Args a) {
  final key = a.scalar(0);
  final type = a.intOr(2, 1);
  final (vec, _) = _vector(a, a[1], 'MATCH');
  int i;
  if (type == 0) {
    i = _isWildcardKey(key)
        ? _wildcardIndex(vec, (key as FText).v)
        : _exactIndex(a, vec, key);
  } else {
    i = _approx(vec, key, descending: type < 0);
  }
  if (i < 0) {
    return FError(
      ErrorKind.na,
      ErrorMessages.didNotFind(_keyText(key), 'MATCH'),
    );
  }
  return FNumber(i + 1.0);
}

/// XLOOKUP/XMATCH search (05 §15.3).
int _xsearch(
  Args a,
  List<FValue> vec,
  FValue key,
  int matchMode,
  int searchMode,
) {
  if (![0, -1, 1, 2].contains(matchMode)) {
    fail(ErrorKind.value, 'Invalid match_mode $matchMode.');
  }
  if (![1, -1, 2, -2].contains(searchMode)) {
    fail(ErrorKind.value, 'Invalid search_mode $searchMode.');
  }
  final last = searchMode == -1;
  if (matchMode == 2) {
    return key is FText
        ? _wildcardIndex(vec, key.v, last: last)
        : _exactIndex(a, vec, key, last: last);
  }
  if (searchMode.abs() == 2) {
    // binary search
    final desc = searchMode == -2;
    var lo = 0, hi = vec.length - 1;
    var exact = -1, below = -1, above = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final x = vec[mid];
      final c = Compare.compare(x, key);
      if (c == 0 && x is! FEmpty) {
        exact = mid;
        break;
      }
      final less = desc ? c > 0 : c < 0;
      if (less) {
        if (desc) {
          above = mid;
        } else {
          below = mid;
        }
        lo = mid + 1;
      } else {
        if (desc) {
          below = mid;
        } else {
          above = mid;
        }
        hi = mid - 1;
      }
    }
    if (exact >= 0) return exact;
    if (matchMode == -1) return below;
    if (matchMode == 1) return above;
    return -1;
  }
  final ex = _exactIndex(a, vec, key, last: last);
  if (ex >= 0 || matchMode == 0) return ex;
  // next smaller / larger (same type), linear
  var best = -1;
  FValue? bestV;
  final kr = _rank(key);
  for (var i = 0; i < vec.length; i++) {
    final j = last ? vec.length - 1 - i : i;
    final x = vec[j];
    if (_rank(x) != kr) continue;
    final c = Compare.compare(x, key);
    if (matchMode == -1 &&
        c < 0 &&
        (bestV == null || Compare.compare(x, bestV) > 0)) {
      best = j;
      bestV = x;
    }
    if (matchMode == 1 &&
        c > 0 &&
        (bestV == null || Compare.compare(x, bestV) < 0)) {
      best = j;
      bestV = x;
    }
  }
  return best;
}

FValue _xlookup(Args a) {
  final key = a.scalar(0);
  final look = a[1];
  final res = a[2];
  if (look is FError) return look;
  if (res is FError) return res;
  final (vec, vertical) = _vector(a, look, 'XLOOKUP');
  final (rr, rc) = RangeAccess.shape(res);
  final (lr, lc) = RangeAccess.shape(look);
  final n = vertical ? lr : lc;
  if ((vertical ? rr : rc) != n) {
    fail(ErrorKind.value, 'Array arguments to XLOOKUP are of different size.');
  }
  final i = _xsearch(a, vec, key, a.intOr(4, 0), a.intOr(5, 1));
  if (i < 0) {
    if (a.hasLazy(3)) {
      final m = a.lazy(3);
      return m is FOmitted ? FEmpty.instance : m;
    }
    return FError(
      ErrorKind.na,
      ErrorMessages.didNotFind(_keyText(key), 'XLOOKUP'),
    );
  }
  if (res is FRef) {
    final ar = res.area;
    if (vertical) {
      if (rc == 1) return _resultAt(a, res, i, 0);
      return FRef(
        ResolvedArea(ar.sheetId, ar.top + i, ar.left, ar.top + i, ar.right),
        dynamic: true,
      );
    }
    if (rr == 1) return _resultAt(a, res, 0, i);
    return FRef(
      ResolvedArea(ar.sheetId, ar.top, ar.left + i, ar.bottom, ar.left + i),
      dynamic: true,
    );
  }
  final arr = RangeAccess.toArray(a.ctx, res);
  if (vertical) return arr.cols == 1 ? arr.at(i, 0) : FArray.row(arr.row(i));
  return arr.rows == 1 ? arr.at(0, i) : FArray.column(arr.column(i));
}

FValue _index(Args a) {
  final ref = a[0];
  if (ref is FError) return ref;
  var row = a.intOr(1, 0);
  var col = a.intOr(2, 0);
  final area = a.intOr(3, 1);
  if (area != 1) fail(ErrorKind.ref, 'INDEX area must be 1.');
  if (row < 0 || col < 0) {
    fail(ErrorKind.value, 'INDEX parameters must be non-negative.');
  }
  final (rows, cols) = RangeAccess.shape(ref);
  // one-dimensional shortcut: INDEX(row_vector, n)
  if (a.has(1) && !a.has(2) && rows == 1 && cols > 1) {
    col = row;
    row = 1;
  }
  if (row > rows || col > cols) {
    fail(ErrorKind.ref, 'INDEX parameter out of range.');
  }
  if (ref is FRef) {
    final ar = ref.area;
    final r1 = row == 0 ? ar.top : ar.top + row - 1;
    final r2 = row == 0 ? ar.bottom : r1;
    final c1 = col == 0 ? ar.left : ar.left + col - 1;
    final c2 = col == 0 ? ar.right : c1;
    return FRef(
      ResolvedArea(ar.sheetId, r1, c1, r2, c2),
      dynamic: true,
      open: ref.open && (row == 0 || col == 0),
    );
  }
  final arr = ref is FArray ? ref : FArray(1, 1, [ref]);
  if (row == 0 && col == 0) return arr;
  if (row == 0) return FArray.column(arr.column(col - 1));
  if (col == 0) {
    return arr.cols == 1 ? arr.at(row - 1, 0) : FArray.row(arr.row(row - 1));
  }
  return arr.at(row - 1, col - 1);
}

FValue _offset(Args a) {
  final ref = a.ref(0);
  final ar = ref.area;
  final dr = a.integer(1), dc = a.integer(2);
  final h = a.has(3) ? a.integer(3) : ar.rows;
  final w = a.has(4) ? a.integer(4) : ar.cols;
  if (h == 0 || w == 0) {
    fail(ErrorKind.ref, 'OFFSET height and width must be non-zero.');
  }
  final s = a.sheetOfRef(ref);
  var r1 = ar.top + dr, c1 = ar.left + dc;
  var r2 = r1 + h - (h > 0 ? 1 : -1), c2 = c1 + w - (w > 0 ? 1 : -1);
  if (r2 < r1) (r1, r2) = (r2, r1);
  if (c2 < c1) (c1, c2) = (c2, c1);
  if (r1 < 0 || c1 < 0 || r2 >= s.rows.length || c2 >= s.columns.length) {
    fail(ErrorKind.ref, 'Result of OFFSET is out of the grid.');
  }
  a.ctx.deps.axisSheets.add(s.id);
  return FRef(ResolvedArea(ar.sheetId, r1, c1, r2, c2), dynamic: true);
}

FValue _indirect(Args a) {
  final text = a.text(0).trim();
  final a1 = a.boolOr(1, true);
  final ctx = a.ctx;
  ctx.deps.sheetNames = true;
  if (text.isEmpty) {
    fail(
      ErrorKind.ref,
      'Function INDIRECT parameter 1 value is empty. It should be a valid cell reference.',
    );
  }
  A1Area? area;
  if (a1) {
    area = A1Area.tryParse(text);
    if (area == null) {
      // named range?
      final nr = ctx.host.namedRange(text);
      if (nr?.range != null) {
        ctx.deps.names.add(text.toUpperCase());
        return FormulaCompiler.resolveIdRange(ctx, nr!.range!);
      }
      // range of two parts each with sheet, e.g. "Sheet1!A1:Sheet1!B2"
      fail(
        ErrorKind.ref,
        "Function INDIRECT parameter 1 value is '$text'. It is not a valid cell/range reference.",
      );
    }
  } else {
    area = R1C1.tryParse(text, ctx.row, ctx.col);
    if (area == null) {
      fail(
        ErrorKind.ref,
        "Function INDIRECT parameter 1 value is '$text'. It is not a valid cell/range reference.",
      );
    }
  }
  final v = FormulaCompiler.resolveA1(ctx, area);
  return v;
}

FValue _rowCol(Args a, {required bool row}) {
  if (!a.has(0)) return FNumber((row ? a.ctx.row : a.ctx.col) + 1.0);
  final r = a.ref(0);
  final ar = r.area;
  final first = row ? ar.top : ar.left;
  final n = row ? ar.rows : ar.cols;
  if (n == 1 || !a.ctx.arrayMode) return FNumber(first + 1.0);
  final values = [for (var i = 0; i < n; i++) FNumber(first + i + 1.0)];
  return row ? FArray.column(values) : FArray.row(values);
}

FValue _address(Args a) {
  final row = a.integer(0), col = a.integer(1);
  final mode = a.intOr(2, 1);
  final useA1 = a.boolOr(3, true);
  if (row < 1 ||
      col < 1 ||
      col > ColumnLetters.maxColumns ||
      mode < 1 ||
      mode > 4) {
    fail(ErrorKind.value, 'Invalid ADDRESS arguments.');
  }
  final absRow = mode == 1 || mode == 2;
  final absCol = mode == 1 || mode == 3;
  String s;
  if (useA1) {
    s = '${absCol ? r'$' : ''}${ColumnLetters.fromIndex(col - 1)}${absRow ? r'$' : ''}$row';
  } else {
    s = '${absRow ? 'R$row' : 'R[$row]'}${absCol ? 'C$col' : 'C[$col]'}';
  }
  if (a.has(4)) {
    final sheet = a.text(4);
    s = '${SheetNames.quoteIfNeeded(sheet)}!$s';
  }
  return FText(s);
}

FValue _choose(Args a, {required bool cols}) {
  final arr = a.array(0);
  final n = cols ? arr.cols : arr.rows;
  final picks = <int>[];
  for (var i = 1; i < a.length; i++) {
    for (final v in a.flat(i)) {
      if (v is FError) throw FormulaError(v);
      final k = (v is FNumber ? v.v : a.number(i)).truncate();
      final idx = k > 0 ? k - 1 : n + k;
      if (k == 0 || idx < 0 || idx >= n) {
        fail(ErrorKind.value, '${a.fn} index $k is out of range.');
      }
      picks.add(idx);
    }
  }
  if (cols) {
    return FArray.generate(
      arr.rows,
      picks.length,
      (r, c) => arr.at(r, picks[c]),
    );
  }
  return FArray.generate(picks.length, arr.cols, (r, c) => arr.at(picks[r], c));
}
