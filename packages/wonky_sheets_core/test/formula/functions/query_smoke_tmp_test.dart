import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/formula/query/query_grammar.dart';
import 'package:wonky_sheets_core/src/formula/query/query_error.dart';

void main() {
  test('smoke', () {
    for (final q in [
      'select A, sum(B) where C > 3 and not (D contains \'x\' or E is not null) group by A pivot F order by sum(B) desc limit 5 offset 2 label sum(B) \'Total\' format A \'0.0\' options no_format',
      'SELECT * WHERE (A + 1) > 2',
      "select year(A), dayOfWeek(A), now(), dateDiff(A, date '2024-01-01') where B like 'a%'",
      'select A where A >',
      'select A wher A > 1',
      'select A,',
      'select',
      '',
      'select `BY`, Col1 where Col1 = -2.5e1',
      'select A where A > 1 and',
      "select A where B matches '.*x' order by A",
    ]) {
      try {
        final r = QueryParser.parse(q);
        print('OK $q -> sel=${r.select} where=${r.where} gb=${r.groupBy} pv=${r.pivot} ob=${r.orderBy.map((o) => '${o.expr}${o.descending}')} lim=${r.limit} off=${r.offset} lab=${r.labels} fmt=${r.formats} opt=${r.options}');
      } on QueryException catch (e) {
        print('ERR $q -> ${e.message}');
      }
    }
  });
}
