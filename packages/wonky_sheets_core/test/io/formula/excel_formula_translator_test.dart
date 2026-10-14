import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/formula/functions/registry.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  final translator = ExcelFormulaTranslator(
    isSupportedFunction: FunctionMap.isWonkyFunction,
  );

  group('Given Excel storage formulas', () {
    const vectors = [
      ('SUM(A1:B2)', 'SUM(A1:B2)'),
      ('_xlfn.CONCAT(A1,B1)', 'CONCAT(A1,B1)'),
      ('_xlfn._xlws.SORT(A1:A3)', 'SORT(A1:A3)'),
      ('_xlfn.LET(_xlpm.x,1,_xlpm.x+1)', 'LET(x,1,x+1)'),
      ('IF(TRUE(),1,FALSE())', 'IF(TRUE,1,FALSE)'),
      ('sum( a1 , \$B\$2 )', 'SUM( A1 , \$B\$2 )'),
      ("'Q3 plan'!A1&\"x \"\"y\"\"\"", "'Q3 plan'!A1&\"x \"\"y\"\"\""),
      ('#REF!+1', '#REF!+1'),
      ('1.5E+3*-A1%', '1.5E+3*-A1%'),
      ('A:A+1:1', 'A:A+1:1'),
      ('{1,2;3,4}', '{1,2;3,4}'),
    ];
    for (final (excel, wonky) in vectors) {
      test('when importing "$excel" then it is "$wonky"', () {
        final t = translator.importFormula(excel);
        expect(t.formula, wonky);
        expect(t.isSupported, isTrue);
      });
    }

    test('when importing the implicit intersection operator then it is '
        'removed and flagged', () {
      final t = translator.importFormula('SUM(@A1:A3)+_xlfn.SINGLE(B1:B2)');
      expect(t.formula, 'SUM(A1:A3)+(B1:B2)');
      expect(t.changedSemantics, isTrue);
    });

    const unsupported = [
      ('CUBEVALUE("c")', 'CUBEVALUE'),
      ('[1]Sheet1!A1+1', 'external reference'),
      ('SUM(Table1[Amount])', 'structured reference'),
      ('SUM(Sheet1:Sheet3!A1)', '3D reference'),
      ('A1#', 'ANCHORARRAY'),
    ];
    for (final (excel, what) in unsupported) {
      test('when importing "$excel" then $what is unsupported', () {
        expect(translator.importFormula(excel).unsupported, contains(what));
      });
    }

    test('when importing a spill reference then it becomes ANCHORARRAY', () {
      expect(
        translator.importFormula('SUM(A1#)').formula,
        'SUM(ANCHORARRAY(A1))',
      );
    });

    test('when sheets were renamed then references follow', () {
      final t = ExcelFormulaTranslator(sheetRenames: {'Old': 'New one'});
      expect(
        t.importFormula('Old!A1+old!B2').formula,
        "'New one'!A1+'New one'!B2",
      );
    });

    test('when names were renamed then name tokens follow', () {
      final t = ExcelFormulaTranslator(nameRenames: {'Rate': 'Sheet1_Rate'});
      expect(t.importFormula('A1*Rate').formula, 'A1*Sheet1_Rate');
    });
  });

  group('Given Wonky formulas', () {
    const vectors = [
      ('CONCAT(A1,B1)', '_xlfn.CONCAT(A1,B1)'),
      ('sort(A1:A3)', '_xlfn._xlws.SORT(A1:A3)'),
      ('LET(x,1,x+1)', '_xlfn.LET(_xlpm.x,1,_xlpm.x+1)'),
      ('LAMBDA(a,a*2)(3)', '_xlfn.LAMBDA(_xlpm.a,_xlpm.a*2)(3)'),
      ('SUM(A1:A3)', 'SUM(A1:A3)'),
      ('XLOOKUP(1,A:A,B:B)', '_xlfn.XLOOKUP(1,A:A,B:B)'),
    ];
    for (final (wonky, excel) in vectors) {
      test('when exporting "$wonky" then it is "$excel"', () {
        expect(translator.exportFormula(wonky).formula, excel);
      });
    }

    test('when exporting a Google-only function then it is reported', () {
      final t = translator.exportFormula('QUERY(A1:B9,"select A")');
      expect(t.unsupported, {'QUERY'});
      expect(t.notes.single, contains('not available in Excel'));
    });
  });

  group('Given every implemented function of the catalog', () {
    test(
      'when exporting and importing a call then the formula is unchanged',
      () {
        final failures = <String>[];
        for (final spec in FunctionRegistry.standard.all) {
          if (!spec.implemented) continue;
          final f = '${spec.name}(A1)';
          final back = translator.importFormula(
            translator.exportFormula(f).formula,
          );
          if (back.formula != f) failures.add('$f → ${back.formula}');
        }
        expect(failures, isEmpty);
      },
    );

    test(
      'when a function is introduced after Excel 2007 then it gets a prefix',
      () {
        for (final name in FunctionMap.xlfn) {
          expect(
            FunctionMap.excelPrefix(name),
            anyOf('_xlfn.', '_xlfn._xlws.'),
          );
        }
      },
    );
  });

  group('Given a shared formula', () {
    test(
      'when expanding it to another cell then relative references shift',
      () {
        final f = SharedFormula(r'A1*$B$1+C$1+$D2', 0, 4);
        expect(f.at(0, 4), r'A1*$B$1+C$1+$D2');
        expect(f.at(2, 5), r'B3*$B$1+D$1+$D4');
      },
    );

    test('when a shifted reference leaves the grid then it is #REF!', () {
      expect(FormulaRewriter.shift('A1+B2', -1, 0), '#REF!+B1');
    });
  });

  group('Given formula tokens', () {
    const formulas = [
      'SUM(A1:B2, 3)',
      "'It''s'!A1&\"a,b\"",
      'IF(A1<>"",{1,2;3,4},#N/A)',
      'Table1[[#Headers],[Col]]',
      '[1]Book!Name+⟦r:abc⟧',
    ];
    for (final f in formulas) {
      test('when tokenizing "$f" then rendering reproduces it', () {
        expect(FormulaTokenizer.render(FormulaTokenizer.tokenize(f)), f);
      });
    }

    test('when converting a decimal-comma formula then separators are '
        'canonical', () {
      expect(
        FormulaRewriter.toCanonical(
          'SUMME(1,5;A1;{1\\2;3\\4})',
          FormulaDialect.decimalComma,
        ),
        'SUMME(1.5,A1,{1,2;3,4})',
      );
    });

    const arrayMode = [
      ('A1:A3*2', true),
      ('SEQUENCE(3)', false),
      ('_xlfn.SEQUENCE(3)+1', true),
      ('FILTER(A1:A3,A1:A3>0)', false),
      ('A1:B3', false),
      ('{1,2,3}', false),
      ('SUM(A1:A3*2)', true),
    ];
    for (final (f, needs) in arrayMode) {
      test(
        'when "$f" is a dynamic array then array mode is ${needs ? '' : 'not '}'
        'needed',
        () {
          expect(FormulaRewriter.needsArrayMode(f), needs);
        },
      );
    }
  });

  group('Given OpenFormula', () {
    final odf = OpenFormulaTranslator();
    const vectors = [
      ('of:=SUM([.A1:.A3])', 'SUM(A1:A3)'),
      (r"of:=[$'Q3 plan'.$B$2]*2", r"'Q3 plan'!$B$2*2"),
      ('of:=IF([.A1]>0;1;2)', 'IF(A1>0,1,2)'),
      ('of:=COM.MICROSOFT.IFS([.A1]>0;1)', 'IFS(A1>0,1)'),
      ('of:={1;2|3;4}', '{1,2;3,4}'),
      ('of:=TRUE()', 'TRUE'),
    ];
    for (final (input, wonky) in vectors) {
      test('when importing "$input" then it is "$wonky"', () {
        expect(odf.importFormula(input).formula, wonky);
      });
    }

    test('when a quoted sheet name is not closed then the reference is '
        'unsupported', () {
      final t = odf.importFormula(r"of:=[$'Q3]+1");
      expect(t.formula, startsWith('#REF!'));
      expect(t.isSupported, isFalse);
    });

    test('when exporting then references and separators use ODF syntax', () {
      expect(
        odf.exportFormula("IF('Q3 plan'!A1>0,{1,2;3,4},TRUE)"),
        "of:=IF([\$'Q3 plan'.A1]>0;{1;2|3;4};TRUE())",
      );
    });
  });
}
