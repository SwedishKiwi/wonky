import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';

void main() {
  test('scratch', () {
    for (final f in ['=1+2*3', '=-2^2', '=SUM(A1:B2, 3)', "='My sheet'!A1+Sheet2!B:B", '=LAMBDA(x,x+1)(5)', '={1,2;3,4}', '=IF(A1>5,"a",)', '=50%', '=A1:INDEX(B:B,5)', '=sum()', '=1:3', '=A2:B', '=TRUE', '=TRUE()', '=#N/A', '=SUM(1', '=1+', '={1,,2}']) {
      final r = FormulaParser.tryParse(f);
      print('$f => ${r.$1 ?? r.$2}');
    }
    final de = FormulaLocale.forId('de_DE');
    print(de.argSeparator); 
    print(FormulaParser.tryParse('=ROUND(1,5;0)', locale: de).$1);
    print(FormulaParser.tryParse('=SUM(A1,B1)', locale: de).$1);
    print(FormulaParser.tryParse(r'={1\2;3\4}', locale: de).$1);
    print(const FormulaLexer().tokenize("=SUM('My s'!A1:B2, \"x\") + 1.5"));
  });
}
