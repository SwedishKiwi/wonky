import '../../query/query_ast.dart';
import '../../query/query_error.dart';
import '../../query/query_table.dart';
import '../../values/dates.dart';
import '../../values/format_hint.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../text/regex_shim.dart';

/// Executes a parsed [Query] over a [QueryTable] (05 §16.2).
///
/// Values inside the executor are `double` (numbers and date/time serials), `String`, `bool`
/// or `null`; each expression has a static [QType]. Failures throw [QueryException].
final class QueryExecutor {
  final QueryTable table;
  final Query query;

  /// Serial of the current local date-time (`now()`); called only when the query uses it.
  final double Function() now;

  /// Formats a number with a pattern for `options no_values`; null when invalid.
  final String? Function(double value, String pattern) formatNumber;

  double? _now;

  QueryExecutor(
    this.table,
    this.query, {
    required this.now,
    required this.formatNumber,
  });

  /// Runs the query: an optional header row followed by the result rows. Returns null when
  /// the output is empty (no header and no rows).
  FArray? run() {
    final select = query.select ?? [for (final id in table.ids) QColumn(id)];
    for (final e in [
      ...select,
      ...query.groupBy,
      ...query.pivot,
      for (final o in query.orderBy) o.expr,
      for (final l in query.labels) l.$1,
      for (final f in query.formats) f.$1,
    ]) {
      _checkColumns(e);
    }
    final where = query.where;
    if (where != null) _checkCondition(where);
    for (final g in [...query.groupBy, ...query.pivot]) {
      if (g.hasAggregate || g is QAggregate) {
        throw const QueryException(
          'INVALID_QUERY: Aggregations are not allowed in GROUP BY or PIVOT.',
        );
      }
    }
    for (final e in select) {
      _checkAggregateTypes(e);
    }

    final rows = <int>[
      for (var r = 0; r < table.rowCount; r++)
        if (where == null || _test(where, r)) r,
    ];

    final aggregating =
        query.groupBy.isNotEmpty ||
        query.pivot.isNotEmpty ||
        select.any(_isAggregate);
    if (!aggregating) return _plain(select, rows);
    if (query.select == null) {
      throw const QueryException(
        'INVALID_QUERY: SELECT * cannot be used with GROUP BY or PIVOT.',
      );
    }
    for (final e in select) {
      if (!_isAggregate(e) && !_groupedExpression(e)) {
        throw QueryException.addColToGroupBy(_firstColumn(e) ?? e.key);
      }
    }
    if (query.pivot.isNotEmpty) return _pivoted(select, rows);
    return _grouped(select, rows);
  }

  // ------------------------------------------------------------------ validation

  bool _isAggregate(QExpr e) => e is QAggregate || e.hasAggregate;

  final Map<QColumn, int> _columnIndex = Map.identity();

  int _column(QColumn c) => _columnIndex[c] ??= () {
    final i = table.indexOf(c.id);
    if (i < 0) throw QueryException.noColumn(c.id);
    return i;
  }();

  void _checkColumns(QExpr e) {
    if (e is QColumn) _column(e);
    for (final c in e.children) {
      _checkColumns(c);
    }
  }

  void _checkCondition(QCond c) {
    void expr(QExpr e) {
      _checkColumns(e);
      if (_isAggregate(e)) {
        throw const QueryException(
          'INVALID_QUERY: Aggregations are not allowed in WHERE.',
        );
      }
    }

    switch (c) {
      case QOr(:final operands) || QAnd(:final operands):
        operands.forEach(_checkCondition);
      case QNot(:final operand):
        _checkCondition(operand);
      case QCompare(:final left, :final right) ||
          QStringMatch(:final left, :final right):
        expr(left);
        expr(right);
      case QIsNull(:final operand) || QBoolValue(:final operand):
        expr(operand);
    }
  }

  void _checkAggregateTypes(QExpr e) {
    if (e is QAggregate &&
        (e.fn == QAggFn.sum || e.fn == QAggFn.avg) &&
        !_typeOf(e.argument).isNumeric) {
      throw QueryException('AVG_SUM_ONLY_NUMERIC: ${_label(e.argument)}');
    }
    for (final c in e.children) {
      _checkAggregateTypes(c);
    }
  }

  /// Whether a non-aggregated select item is constant within a group.
  bool _groupedExpression(QExpr e) {
    if (query.groupBy.contains(e)) return true;
    if (e is QColumn) return false;
    return e.children.every(_groupedExpression);
  }

  String? _firstColumn(QExpr e) {
    if (e is QColumn) return e.id;
    for (final c in e.children) {
      final id = _firstColumn(c);
      if (id != null) return id;
    }
    return null;
  }

  // ------------------------------------------------------------------ types and labels

  QType _typeOf(QExpr e) => switch (e) {
    QColumn() => table.types[_column(e)],
    QNumber() => QType.number,
    QString() => QType.string,
    QBool() => QType.boolean,
    QDateLiteral(:final kind) => switch (kind) {
      QDateKind.date => QType.date,
      QDateKind.datetime => QType.datetime,
      QDateKind.timeofday => QType.timeofday,
    },
    QNegate() || QArith() => QType.number,
    QAggregate(:final fn, :final argument) =>
      fn == QAggFn.max || fn == QAggFn.min ? _typeOf(argument) : QType.number,
    QCall(:final fn) => switch (fn) {
      QScalarFn.now => QType.datetime,
      QScalarFn.todate => QType.date,
      QScalarFn.upper || QScalarFn.lower => QType.string,
      _ => QType.number,
    },
  };

  String _label(QExpr e) {
    switch (e) {
      case QColumn():
        final l = table.labels.isEmpty ? '' : table.labels[_column(e)];
        return l.isEmpty ? e.id : l;
      case QNumber(:final value):
        return Numeric.toText(value);
      case QString(:final value):
        return "'$value'";
      case QBool(:final value):
        return '$value';
      case QDateLiteral(:final kind, :final text):
        return "${kind.name} '$text'";
      case QNegate(:final operand):
        return '-${_label(operand)}';
      case QArith(:final op, :final left, :final right):
        return '${op.functionName}(${_label(left)}, ${_label(right)})';
      case QAggregate(:final fn, :final argument):
        final inner = argument is QColumn
            ? (table.labels.isEmpty ? '' : table.labels[_column(argument)])
            : _label(argument);
        return inner.isEmpty ? fn.name : '${fn.name} $inner';
      case QCall(:final fn, :final args):
        return '${_callName(fn)}(${args.map(_label).join(', ')})';
    }
  }

  static String _callName(QScalarFn fn) => switch (fn) {
    QScalarFn.dayofweek => 'dayOfWeek',
    QScalarFn.datediff => 'dateDiff',
    QScalarFn.todate => 'toDate',
    _ => fn.name,
  };

  /// Default header text of an output column: the original header for bare columns.
  String _header(QExpr e) {
    for (final (x, text) in query.labels) {
      if (x == e) return text;
    }
    if (e is QColumn) {
      return table.labels.isEmpty ? '' : table.labels[_column(e)];
    }
    return _label(e);
  }

  FormatHint _hint(QExpr e) {
    if (query.options.contains(QOption.noFormat)) return FormatHint.none;
    for (final (x, pattern) in query.formats) {
      if (x == e) return FormatHint.fromCell(pattern);
    }
    switch (_typeOf(e)) {
      case QType.date:
        return FormatHint.date;
      case QType.datetime:
        return FormatHint.dateTime;
      case QType.timeofday:
        return FormatHint.time;
      default:
        break;
    }
    if (e is QColumn) return table.hints[_column(e)];
    if (e is QAggregate && e.fn != QAggFn.count && e.argument is QColumn) {
      return table.hints[_column(e.argument as QColumn)];
    }
    return FormatHint.none;
  }

  // ------------------------------------------------------------------ evaluation

  /// Value of [e] for [row]; aggregates use the rows of [group].
  Object? _eval(QExpr e, int row, [List<int>? group]) {
    switch (e) {
      case QColumn():
        return row < 0 ? null : table.columns[_column(e)][row];
      case QNumber(:final value):
        return value;
      case QString(:final value):
        return value;
      case QBool(:final value):
        return value;
      case QDateLiteral():
        return _dateLiteral(e);
      case QNegate(:final operand):
        final v = _eval(operand, row, group);
        return v is double ? -v : null;
      case QArith(:final op, :final left, :final right):
        final l = _eval(left, row, group), r = _eval(right, row, group);
        if (l is! double || r is! double) return null;
        return switch (op) {
          QArithOp.add => Numeric.add(l, r),
          QArithOp.sub => Numeric.sub(l, r),
          QArithOp.mul => l * r,
          QArithOp.div => r == 0 ? null : l / r,
          QArithOp.mod => r == 0 ? null : l.remainder(r),
        };
      case QAggregate(:final fn, :final argument):
        final rows = group ?? const <int>[];
        return _aggregate(fn, [for (final r in rows) _eval(argument, r)]);
      case QCall():
        return _call(e, row, group);
    }
  }

  Object? _aggregate(QAggFn fn, List<Object?> values) {
    final present = values.where((v) => v != null).toList();
    if (fn == QAggFn.count) return present.length.toDouble();
    if (present.isEmpty) return null;
    switch (fn) {
      case QAggFn.sum || QAggFn.avg:
        var s = 0.0, c = 0.0;
        for (final v in present.whereType<double>()) {
          final t = s + v;
          c += s.abs() >= v.abs() ? (s - t) + v : (v - t) + s;
          s = t;
        }
        final total = s + c;
        return fn == QAggFn.sum ? total : total / present.length;
      case QAggFn.max || QAggFn.min:
        var best = present.first;
        for (final v in present.skip(1)) {
          final c = _compareValues(v, best);
          if (fn == QAggFn.max ? c > 0 : c < 0) best = v;
        }
        return best;
      case QAggFn.count:
        return present.length.toDouble();
    }
  }

  Object? _call(QCall e, int row, List<int>? group) {
    final args = [for (final a in e.args) _eval(a, row, group)];
    double? serial(int i) => args[i] is double ? args[i]! as double : null;
    switch (e.fn) {
      case QScalarFn.now:
        return _now ??= now();
      case QScalarFn.upper:
        return args[0] is String ? (args[0]! as String).toUpperCase() : null;
      case QScalarFn.lower:
        return args[0] is String ? (args[0]! as String).toLowerCase() : null;
      case QScalarFn.datediff:
        final a = serial(0), b = serial(1);
        if (a == null || b == null) return null;
        return (a.floor() - b.floor()).toDouble();
      case QScalarFn.todate:
        final x = serial(0);
        if (x == null) return null;
        if (_typeOf(e.args[0]) == QType.number) {
          return DateSerial.fromUnixMillis(x.floor()).floorToDouble();
        }
        return x.floorToDouble();
      default:
        break;
    }
    final x = serial(0);
    if (x == null) return null;
    final ymd = DateSerial.toYmd(x);
    final time = DateSerial.timeOf(x);
    return switch (e.fn) {
      QScalarFn.year => ymd.year.toDouble(),
      QScalarFn.month => (ymd.month - 1).toDouble(),
      QScalarFn.day => ymd.day.toDouble(),
      QScalarFn.quarter => ((ymd.month - 1) ~/ 3 + 1).toDouble(),
      QScalarFn.dayofweek => (DateSerial.weekday(x) + 1).toDouble(),
      QScalarFn.hour => time.hour.toDouble(),
      QScalarFn.minute => time.minute.toDouble(),
      QScalarFn.second => time.second.toDouble(),
      QScalarFn.millisecond => time.ms.toDouble(),
      _ => null,
    };
  }

  static final RegExp _dateRe = RegExp(r'^\s*(\d{4})-(\d{1,2})-(\d{1,2})\s*$');
  static final RegExp _timeRe = RegExp(
    r'^\s*(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?\s*$',
  );

  double _dateLiteral(QDateLiteral e) {
    Never bad() => throw QueryException(
      'PARSE_ERROR: Invalid ${e.kind.name} literal: ${e.text}',
    );
    double date(String s) {
      final m = _dateRe.firstMatch(s) ?? bad();
      final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
      if (mo < 1 || mo > 12 || d < 1 || d > DateSerial.daysInMonth(y, mo)) {
        bad();
      }
      return DateSerial.fromYmd(y, mo, d).toDouble();
    }

    double time(String s) {
      final m = _timeRe.firstMatch(s) ?? bad();
      final h = int.parse(m[1]!), mi = int.parse(m[2]!);
      final sec = int.parse(m[3] ?? '0');
      final ms = int.parse((m[4] ?? '0').padRight(3, '0'));
      if (h > 23 || mi > 59 || sec > 59) bad();
      return DateSerial.timeFraction(h, mi, sec + ms / 1000);
    }

    switch (e.kind) {
      case QDateKind.date:
        return date(e.text);
      case QDateKind.timeofday:
        return time(e.text);
      case QDateKind.datetime:
        final t = e.text.trim();
        final sp = t.indexOf(' ');
        if (sp < 0) return date(t);
        return date(t.substring(0, sp)) + time(t.substring(sp + 1));
    }
  }

  // ------------------------------------------------------------------ conditions

  bool _test(QCond c, int row) {
    switch (c) {
      case QOr(:final operands):
        return operands.any((o) => _test(o, row));
      case QAnd(:final operands):
        return operands.every((o) => _test(o, row));
      case QNot(:final operand):
        return !_test(operand, row);
      case QIsNull(:final operand, :final negated):
        final isNull = _eval(operand, row) == null;
        return negated ? !isNull : isNull;
      case QBoolValue(:final operand):
        return _eval(operand, row) == true;
      case QCompare(:final op, :final left, :final right):
        final l = _eval(left, row), r = _eval(right, row);
        if (l == null || r == null || l.runtimeType != r.runtimeType) {
          return false;
        }
        final cmp = switch (l) {
          final double x => Numeric.compare(x, r as double),
          final String s => s.compareTo(r as String).sign,
          final bool b => b == r ? 0 : (b ? 1 : -1),
          _ => 0,
        };
        return switch (op) {
          QCompareOp.eq => cmp == 0,
          QCompareOp.ne => cmp != 0,
          QCompareOp.lt => cmp < 0,
          QCompareOp.gt => cmp > 0,
          QCompareOp.le => cmp <= 0,
          QCompareOp.ge => cmp >= 0,
        };
      case QStringMatch(:final op, :final left, :final right):
        final l = _eval(left, row), r = _eval(right, row);
        if (l is! String || r is! String) return false;
        return switch (op) {
          QStringOp.contains => l.contains(r),
          QStringOp.startsWith => l.startsWith(r),
          QStringOp.endsWith => l.endsWith(r),
          QStringOp.matches => _matches(r).hasMatch(l),
          QStringOp.like => _like(r).hasMatch(l),
        };
    }
  }

  final Map<String, RegExp> _regexCache = {};

  RegExp _matches(String pattern) => _regexCache.putIfAbsent(
    'm:$pattern',
    () => SheetsRegex.compile('^(?:$pattern)\$', fn: 'QUERY'),
  );

  RegExp _like(String pattern) => _regexCache.putIfAbsent('l:$pattern', () {
    final b = StringBuffer('^');
    for (final r in pattern.runes) {
      final ch = String.fromCharCode(r);
      b.write(switch (ch) {
        '%' => r'[\s\S]*',
        '_' => r'[\s\S]',
        _ => RegExp.escape(ch),
      });
    }
    b.write(r'$');
    return RegExp(b.toString(), unicode: true);
  });

  // ------------------------------------------------------------------ ordering

  /// Type ordering of 05 §6.4 with nulls first.
  static int _compareValues(Object? a, Object? b) {
    if (a == null || b == null) {
      return a == null ? (b == null ? 0 : -1) : 1;
    }
    int rank(Object v) => switch (v) {
      double() => 0,
      String() => 1,
      _ => 2,
    };
    final ra = rank(a), rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    return switch (a) {
      final double x => Numeric.compare(x, b as double),
      final String s => s.toLowerCase().compareTo((b as String).toLowerCase()),
      final bool x => x == b ? 0 : (x ? 1 : -1),
      _ => 0,
    };
  }

  List<T> _orderAndSlice<T>(List<T> items, Object? Function(QExpr, T) eval) {
    if (query.orderBy.isNotEmpty) {
      final keys = [
        for (final it in items)
          [for (final o in query.orderBy) eval(o.expr, it)],
      ];
      final indexed = [for (var i = 0; i < items.length; i++) i];
      indexed.sort((x, y) {
        final kx = keys[x], ky = keys[y];
        for (var k = 0; k < query.orderBy.length; k++) {
          var c = _compareValues(kx[k], ky[k]);
          if (query.orderBy[k].descending) c = -c;
          if (c != 0) return c;
        }
        return x.compareTo(y);
      });
      items = [for (final i in indexed) items[i]];
    }
    final offset = query.offset ?? 0;
    if (offset > 0) {
      items = offset >= items.length ? <T>[] : items.sublist(offset);
    }
    final limit = query.limit;
    if (limit != null && limit < items.length) items = items.sublist(0, limit);
    return items;
  }

  // ------------------------------------------------------------------ output

  FValue _cell(Object? v, FormatHint hint, QExpr? e) {
    switch (v) {
      case null:
        return FEmpty.instance;
      case final String s:
        return FText(s);
      case final bool b:
        return FBool(b);
      case final double x:
        if (query.options.contains(QOption.noValues) && e != null) {
          for (final (fx, pattern) in query.formats) {
            if (fx == e) {
              final s = formatNumber(x, pattern);
              if (s != null) return FText(s);
            }
          }
        }
        return FNumber(x, hint);
    }
    return FEmpty.instance;
  }

  FArray? _assemble(List<String> headers, List<List<FValue>> body) {
    final hasHeader = headers.any((h) => h.isNotEmpty);
    final out = [
      if (hasHeader) [for (final h in headers) FText(h) as FValue],
      ...body,
    ];
    if (out.isEmpty || headers.isEmpty) return null;
    return FArray.fromRows(out);
  }

  FArray? _plain(List<QExpr> select, List<int> rows) {
    final ordered = _orderAndSlice<int>(rows, (e, r) => _eval(e, r));
    final hints = [for (final e in select) _hint(e)];
    final body = [
      for (final r in ordered)
        [
          for (var i = 0; i < select.length; i++)
            _cell(_eval(select[i], r), hints[i], select[i]),
        ],
    ];
    return _assemble([for (final e in select) _header(e)], body);
  }

  /// Rows grouped by the `group by` values, in ascending group order.
  List<List<int>> _groups(List<int> rows) {
    if (query.groupBy.isEmpty) return [rows];
    final byKey = <String, List<int>>{};
    final keyValues = <String, List<Object?>>{};
    for (final r in rows) {
      final values = [for (final g in query.groupBy) _eval(g, r)];
      final key = values.map(_keyOf).join('\u0001');
      (byKey[key] ??= []).add(r);
      keyValues[key] ??= values;
    }
    final keys = byKey.keys.toList()
      ..sort((a, b) {
        final va = keyValues[a]!, vb = keyValues[b]!;
        for (var i = 0; i < va.length; i++) {
          final c = _compareValues(va[i], vb[i]);
          if (c != 0) return c;
        }
        return 0;
      });
    return [for (final k in keys) byKey[k]!];
  }

  static String _keyOf(Object? v) => switch (v) {
    null => 'n',
    final double x => 'd${x == 0 ? 0.0 : x}',
    final String s => 's$s',
    final bool b => 'b$b',
    _ => '?',
  };

  FArray? _grouped(List<QExpr> select, List<int> rows) {
    final groups = _orderAndSlice<List<int>>(
      _groups(rows),
      (e, g) => _eval(e, g.isEmpty ? -1 : g.first, g),
    );
    final hints = [for (final e in select) _hint(e)];
    final body = [
      for (final g in groups)
        [
          for (var i = 0; i < select.length; i++)
            _cell(
              _eval(select[i], g.isEmpty ? -1 : g.first, g),
              hints[i],
              select[i],
            ),
        ],
    ];
    return _assemble([for (final e in select) _header(e)], body);
  }

  FArray? _pivoted(List<QExpr> select, List<int> rows) {
    final keys = [
      for (final e in select)
        if (!_isAggregate(e)) e,
    ];
    final aggs = [
      for (final e in select)
        if (_isAggregate(e)) e,
    ];
    if (aggs.isEmpty) {
      throw const QueryException(
        'INVALID_QUERY: PIVOT requires at least one aggregation in SELECT.',
      );
    }
    // Distinct pivot values, ascending.
    final pivotRows = <String, List<int>>{};
    final pivotValues = <String, List<Object?>>{};
    for (final r in rows) {
      final values = [for (final p in query.pivot) _eval(p, r)];
      final key = values.map(_keyOf).join('\u0001');
      (pivotRows[key] ??= []).add(r);
      pivotValues[key] ??= values;
    }
    final pivotKeys = pivotRows.keys.toList()
      ..sort((a, b) {
        final va = pivotValues[a]!, vb = pivotValues[b]!;
        for (var i = 0; i < va.length; i++) {
          final c = _compareValues(va[i], vb[i]);
          if (c != 0) return c;
        }
        return 0;
      });
    final pivotSets = {for (final k in pivotKeys) k: pivotRows[k]!.toSet()};

    String valueText(Object? v) => switch (v) {
      null => 'null',
      final double x => Numeric.toText(x),
      final String s => s,
      final bool b => b ? 'TRUE' : 'FALSE',
      _ => '',
    };

    final headers = <String>[
      for (final k in keys) _header(k),
      for (final pk in pivotKeys)
        for (final agg in aggs)
          [
            pivotValues[pk]!.map(valueText).join(', '),
            if (aggs.length > 1) _header(agg),
          ].join(' '),
    ];
    final groups = query.groupBy.isEmpty && rows.isEmpty
        ? <List<int>>[]
        : _orderAndSlice<List<int>>(
            _groups(rows),
            (e, g) => _eval(e, g.isEmpty ? -1 : g.first, g),
          );
    final keyHints = [for (final k in keys) _hint(k)];
    final aggHints = [for (final agg in aggs) _hint(agg)];
    final body = <List<FValue>>[];
    for (final g in groups) {
      final row = <FValue>[
        for (var i = 0; i < keys.length; i++)
          _cell(_eval(keys[i], g.isEmpty ? -1 : g.first), keyHints[i], keys[i]),
      ];
      for (final pk in pivotKeys) {
        final set = pivotSets[pk]!;
        final cellRows = [
          for (final r in g)
            if (set.contains(r)) r,
        ];
        for (var i = 0; i < aggs.length; i++) {
          row.add(
            cellRows.isEmpty
                ? FEmpty.instance
                : _cell(
                    _eval(aggs[i], cellRows.first, cellRows),
                    aggHints[i],
                    aggs[i],
                  ),
          );
        }
      }
      body.add(row);
    }
    return _assemble(headers, body);
  }
}
