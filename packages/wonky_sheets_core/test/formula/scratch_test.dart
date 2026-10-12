import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';

void main() {
  test('scratch', () {
    final t = FormulaTestBench();
    t.setColumn('A1', [1, 2, 3, 'x', 5]);
    t.setColumn('B1', ['a', 'b', 'c', 'd', 'e']);
    for (final f in ['=SUM(A1:A5)', '=SUM(A:A)', '=COUNTIF(A1:A5,">2")', '=SUMIF(A1:A5,">2",A1:A5)', '=VLOOKUP(3,A1:B5,2,FALSE)', '=VLOOKUP(2.5,A1:B5,2)', '=INDEX(B1:B5,2)', '=MATCH("c",B1:B5,0)', '=XLOOKUP("d",B1:B5,A1:A5)', '=SUM(A1:INDEX(A1:A5,3))', '=ROWS(A:A)', '=ROUND(2.675,2)', '=SEQUENCE(2,2)', '=SUMPRODUCT((A1:A3>1)*A1:A3)', '=FILTER(B1:B5,A1:A5>2)', '=SORT({3;1;2})', '=UNIQUE({1;1;2})', '=MAP({1,2},LAMBDA(x,x*10))', '=REDUCE(0,A1:A3,LAMBDA(a,v,a+v))', '=IFERROR(1/0,"z")', '=ARRAYFORMULA(A1:A3*2)', '=ISBLANK(C1)', '=CELL("address",B2)', '=OFFSET(A1,1,0)', '=INDIRECT("B3")', '=TYPE({1,2})', '=HYPERLINK("https://x.com","X")', '=1/3&""', '=0.1+0.2=0.3', '=-2^2', '=2^3^2', '="a"&1+2', '=COUNTIFS(A1:A5,">1",B1:B5,"<>c")', '=AVERAGEIF(A1:A5,">1")', '=MAXIFS(A1:A5,B1:B5,"<d")']) {
      print('$f => ${t.eval(f)}');
    }
    t.set('D1', '=SEQUENCE(3)');
    t.set('E1', '=SUM(D1:D3)');
    print('${t.value('D2')} ${t.value('E1')}');
    t.set('D2', 'x');
    print('${t.value('D1')} ${(t.value('D1') as FError).message} ${t.value('E1')}');
    t.set('D2', null);
    print('${t.value('D1')} ${t.value('E1')}');
  });
}
