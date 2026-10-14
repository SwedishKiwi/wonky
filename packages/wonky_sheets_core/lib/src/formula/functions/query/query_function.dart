import '../../../addressing/column_letters.dart';
import '../../eval/eval_context.dart';
import '../../query/query_error.dart';
import '../../query/query_grammar.dart';
import '../../query/query_table.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../date_time/calendar.dart' show localNowSerial;
import '../registry.dart';
import 'query_executor.dart';

/// QUERY (05 §16): the Google Visualization API query language over a range or array.
void registerQuery(FunctionRegistryBuilder b) {
  b.fn(
    'QUERY',
    'Runs a Google Visualization API Query Language query across data.',
    [
      P.array(
        'data',
        'The range of cells to perform the query on. Each column of data can only hold boolean, numeric (including date/time types) or string values.',
      ),
      P.text(
        'query',
        'The query to perform, written in the Google Visualization API Query Language.',
      ),
      P.num(
        'headers',
        'The number of header rows at the top of data. If omitted or -1, the value is guessed based on the content of data.',
        true,
        -1,
      ),
    ],
    _query,
    category: FunctionCategory.google,
    returns: ReturnKind.array,
    cost: FunctionCost.heavy,
    examples: [
      'QUERY(A1:C20, "select A, sum(C) where B > 10 group by A", 1)',
      'QUERY(Sheet2!A:D, "select * where D = \'Paid\' order by B desc limit 10")',
    ],
    seeAlso: ['FILTER', 'SORT', 'UNIQUE'],
    notes:
        'Column identifiers are the sheet column letters of data (A, B, …), or Col1, Col2, … when data is an array. '
        'Each column takes the majority type of its values; values of other types are treated as null.',
  );
}

FValue _query(FunctionArgs a) {
  final data = a.array(0);
  final text = a.text(1);
  final headers = a.has(2) ? a.integer(2) : -1;
  final v = a[0];
  final ids = [
    for (var c = 0; c < data.cols; c++)
      v is FRef ? ColumnLetters.fromIndex(v.area.left + c) : 'Col${c + 1}',
  ];
  try {
    final query = QueryParser.parse(text);
    final table = QueryTable.build(data, ids, headers < 0 ? -1 : headers);
    final result = QueryExecutor(
      table,
      query,
      now: () => localNowSerial(a.ctx),
      formatNumber: (x, pattern) =>
          a.ctx.host.textFormatter.format(FNumber(x), pattern, a.locale),
    ).run();
    if (result == null) {
      return const FError(
        ErrorKind.na,
        'Query completed with an empty output.',
      );
    }
    return result;
  } on QueryException catch (e) {
    fail(ErrorKind.value, e.fullMessage);
  }
}
