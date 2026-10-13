import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';

void main() {
  group('Given column letters', () {
    const cases = <(int, String)>[
      (0, 'A'),
      (25, 'Z'),
      (26, 'AA'),
      (51, 'AZ'),
      (52, 'BA'),
      (701, 'ZZ'),
      (702, 'AAA'),
      (18277, 'ZZZ'),
    ];
    for (final (index, letters) in cases) {
      test('when converting $index then it is $letters and back', () {
        expect(ColumnLetters.fromIndex(index), letters);
        expect(ColumnLetters.toIndex(letters), index);
        expect(ColumnLetters.toIndex(letters.toLowerCase()), index);
      });
    }
    test('when converting invalid letters then the index is -1', () {
      expect(ColumnLetters.toIndex('AAAA'), -1);
      expect(ColumnLetters.toIndex('A1'), -1);
      expect(ColumnLetters.toIndex(''), -1);
    });
  });

  group('Given A1 reference text', () {
    final cases = <(String, A1Area)>[
      ('A1', const A1Area.cell(0, 0)),
      (r'$B$3', const A1Area.cell(2, 1, absRow: true, absCol: true)),
      (r'B$3', const A1Area.cell(2, 1, absRow: true)),
      ('A1:B5', A1Area.rect(0, 0, 4, 1)),
      ('A:C', const A1Area.columns(0, 2)),
      (r'$A:$A', const A1Area.columns(0, 0, absCol1: true, absCol2: true)),
      ('1:3', const A1Area.rows(0, 2)),
      ('A2:B', const A1Area.raw(A1Kind.openRows, row1: 1, col1: 0, col2: 1)),
      ('B3:5', const A1Area.raw(A1Kind.openColumns, row1: 2, col1: 1, row2: 4)),
      ("'Q3 plan'!A1:B2", A1Area.rect(0, 0, 1, 1, sheet: 'Q3 plan')),
      ("'It''s'!C7", const A1Area.cell(6, 2, sheet: "It's")),
      (
        'Sheet2!ZZZ10000000',
        const A1Area.cell(9999999, 18277, sheet: 'Sheet2'),
      ),
    ];
    for (final (text, area) in cases) {
      test(
        'when parsing "$text" then it is ${area.kind.name} and formats back',
        () {
          expect(A1Area.tryParse(text), area);
          expect(area.format(), text);
        },
      );
    }
    for (final bad in [
      'A0',
      'AAAA1',
      'A10000001',
      'A1B',
      'A01',
      'LOG10(',
      '1',
      'A',
      "'unterminated!A1",
    ]) {
      test('when parsing "$bad" then it is not a reference', () {
        expect(A1Area.tryParse(bad), isNull);
      });
    }
    test(
      'when resolving an open area then missing bounds use the sheet size',
      () {
        expect(
          const A1Area.columns(0, 1).toRect(100, 26),
          const GridRect(0, 0, 99, 1),
        );
        expect(
          A1Area.rect(4, 1, 0, 0).toRect(10, 10),
          const GridRect(0, 0, 4, 1),
        );
      },
    );
  });

  group('Given sheet names', () {
    const cases = <(String, String)>[
      ('Sheet1', 'Sheet1'),
      ('Q3 plan', "'Q3 plan'"),
      ("It's", "'It''s'"),
      ('A1', "'A1'"),
      ('R1C1', "'R1C1'"),
      ('TRUE', "'TRUE'"),
      ('2024', "'2024'"),
      ('Data_2024', 'Data_2024'),
    ];
    for (final (name, quoted) in cases) {
      test('when quoting "$name" then it is $quoted', () {
        expect(SheetNames.quoteIfNeeded(name), quoted);
        expect(SheetNames.unquote(quoted), name);
      });
    }
  });

  group('Given UUIDs', () {
    test('when encoding to base-62 then 22 characters round-trip', () {
      const id = '0192f0a4-1b2c-7d3e-8f40-123456789abc';
      final b = Base62Uuid.encode(id);
      expect(b.length, 22);
      expect(Base62Uuid.isBase62(b), isTrue);
      expect(Base62Uuid.decode(b), id);
    });
    test('when encoding the zero and max UUID then they round-trip', () {
      for (final id in [
        '00000000-0000-0000-0000-000000000000',
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
      ]) {
        expect(Base62Uuid.decode(Base62Uuid.encode(id)), id);
      }
    });
    test('when an id is not a UUID then it is written verbatim', () {
      expect(Base62Uuid.toToken('r1'), 'r1');
      expect(Base62Uuid.fromToken('r1'), 'r1');
    });
  });

  group('Given R1C1 text', () {
    final cases = <(String, int, int, String)>[
      ('R1C1', 5, 5, r'$A$1'),
      ('RC', 2, 3, 'D3'),
      ('R[1]C[-1]', 2, 3, 'C4'),
      ('R2C3:R[2]C[2]', 0, 0, r'$C$2:C3'),
      ('C2:C3', 0, 0, r'$B:$C'),
      ('R[1]:R[2]', 0, 0, '2:3'),
    ];
    for (final (text, r, c, a1) in cases) {
      test(
        'when parsing "$text" at R${r + 1}C${c + 1} then it is $a1 and formats back',
        () {
          final area = R1C1.tryParse(text, r, c);
          expect(area?.format(), a1);
          expect(R1C1.format(area!, r, c), text);
        },
      );
    }
    test('when a relative reference leaves the grid then it is invalid', () {
      expect(R1C1.tryParse('R[-1]C', 0, 0), isNull);
    });
  });

  group('Given grid rectangles', () {
    const r = GridRect(1, 1, 3, 4);
    test(
      'when testing containment and intersection then edges are inclusive',
      () {
        expect(r.contains(3, 4), isTrue);
        expect(r.contains(4, 4), isFalse);
        expect(
          r.intersection(const GridRect(3, 4, 9, 9)),
          const GridRect(3, 4, 3, 4),
        );
        expect(r.intersects(const GridRect(4, 0, 5, 0)), isFalse);
        expect(r.a1, 'B2:E4');
      },
    );
  });
}
