import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/clipboard/clipboard.dart';

void main() {
  group('Given A1 formulas and their host cell', () {
    // (formula, host row, host col, R1C1)
    const cases = [
      ('=A1', 2, 1, '=R[-2]C[-1]'),
      ('=SUM(A1:A2)', 2, 1, '=SUM(R[-2]C[-1]:R[-1]C[-1])'),
      (r'=$A$1+A$1+$A1', 0, 0, '=R1C1+R1C+RC1'),
      ("='Q3 plan'!B2*2", 1, 1, "='Q3 plan'!RC*2"),
      ('=Sheet2!C:C', 5, 0, '=Sheet2!C[2]:C[2]'),
      ('=SUM(3:5)', 0, 0, '=SUM(R[2]:R[4])'),
      ('="A1 is text"&A1', 0, 1, '="A1 is text"&RC[-1]'),
      ('=LOG10(B1)+Total', 0, 0, '=LOG10(RC[1])+Total'),
      ('=1.5E+3+B1', 0, 0, '=1.5E+3+RC[1]'),
    ];
    for (final (a1, row, col, r1c1) in cases) {
      test('when converting $a1 at ($row, $col) to R1C1 then it is $r1c1', () {
        expect(R1C1Relative.fromA1(a1, row, col), r1c1);
      });
    }

    for (final (a1, row, col, r1c1) in cases) {
      test('when converting $r1c1 back at ($row, $col) then it is $a1', () {
        expect(R1C1Relative.toA1(r1c1, row, col), a1);
      });
    }
  });

  group('Given R1C1 formulas pasted elsewhere', () {
    const cases = [
      ('=R[-1]C*2', 9, 4, '=E9*2'),
      ('=SUM(R[-1]C[-1]:R[-1]C)', 9, 4, '=SUM(D9:E9)'),
      ('=ROUND(RC[1],2)', 0, 0, '=ROUND(B1,2)'),
      ('=COUNT(R1C1:R3C1)', 5, 5, r'=COUNT($A$1:$A$3)'),
      ('=R[-5]C', 2, 0, '=#REF!'),
      ('=SUM(RC[-3]:RC)', 0, 1, '=SUM(#REF!)'),
    ];
    for (final (r1c1, row, col, a1) in cases) {
      test('when resolving $r1c1 at ($row, $col) then it is $a1', () {
        expect(R1C1Relative.toA1(r1c1, row, col), a1);
      });
    }
  });
}
