import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/names/name_rules.dart';

void main() {
  group('Given named range names (07 §8.2)', () {
    final cases = <(String, String?)>[
      ('Sales', null),
      ('_tax_rate', null),
      ('Sales_2026', null),
      ('TAX2024', NameRules.cellLike),
      ('A1', NameRules.cellLike),
      ('R1C1', NameRules.cellLike),
      ('R2C', NameRules.cellLike),
      ('rc', NameRules.cellLike),
      ('1abc', NameRules.badStart),
      ('true_x', NameRules.badStart),
      ('FALSEHOOD', NameRules.badStart),
      ('my name', NameRules.invalidChars),
      ('a-b', NameRules.invalidChars),
      ('', NameRules.invalidChars),
      ('x' * 251, NameRules.invalidChars),
      ('ABCD1', null),
    ];
    for (final (name, message) in cases) {
      test(
        'when validating "${name.length > 20 ? '${name.substring(0, 5)}…' : name}" then the result is ${message ?? 'valid'}',
        () {
          expect(NameRules.validateRangeName(name), message);
        },
      );
    }

    test(
      'when the name exists case-insensitively then it is a duplicate unless it is the current name',
      () {
        expect(
          NameRules.validateRangeName('sales', existing: ['Sales']),
          NameRules.duplicate,
        );
        expect(
          NameRules.validateRangeName(
            'sales',
            existing: ['Sales'],
            current: 'Sales',
          ),
          isNull,
        );
      },
    );

    test(
      'when two rows share a name then the larger id gets _2 and the suffix avoids taken names',
      () {
        expect(
          NameRules.dedupeRenames([
            ('b', 'Sales'),
            ('a', 'sales'),
            ('c', 'Sales_2'),
            ('d', 'SALES'),
          ]),
          {'b': 'Sales_3', 'd': 'SALES_4'},
        );
        expect(
          NameRules.dedupeRenames([('a', 'Sales'), ('b', 'Sales_3')]),
          isEmpty,
        );
      },
    );
  });

  group('Given named function names (07 §9.3)', () {
    test('when the name is valid after uppercasing then it passes', () {
      expect(NameRules.validateFunctionName('gross'), isNull);
    });

    test(
      'when the name starts with a digit or underscore then it is invalid',
      () {
        expect(NameRules.validateFunctionName('1X'), NameRules.functionInvalid);
        expect(NameRules.validateFunctionName('_X'), NameRules.functionInvalid);
      },
    );

    test('when the name is a built-in or exists then it is refused', () {
      expect(
        NameRules.validateFunctionName('sum', isBuiltIn: (n) => n == 'SUM'),
        NameRules.functionExists,
      );
      expect(
        NameRules.validateFunctionName('Gross', existing: ['GROSS']),
        NameRules.functionExists,
      );
    });

    test('when the name looks like a cell then it is refused', () {
      expect(
        NameRules.validateFunctionName('ab12'),
        NameRules.functionCellLike,
      );
    });

    test(
      'when validating parameters then invalid or duplicate placeholders are reported',
      () {
        expect(NameRules.validateParams(['price', 'rate']), isNull);
        expect(
          NameRules.validateParams(['price', 'Price']),
          'Invalid argument placeholder "Price".',
        );
        expect(
          NameRules.validateParams(['A1']),
          'Invalid argument placeholder "A1".',
        );
        expect(
          NameRules.validateParams([for (var i = 0; i < 31; i++) 'p$i']),
          isNotNull,
        );
      },
    );
  });

  group('Given sheet names', () {
    final cases = <(String, String?)>[
      ('Sheet1', null),
      ('Q3 plan', null),
      ('', NameRules.sheetNameLength),
      ('x' * 101, NameRules.sheetNameLength),
      ('a/b', NameRules.sheetNameChars),
      ('a:b', NameRules.sheetNameChars),
      ('[x]', NameRules.sheetNameChars),
    ];
    for (final (name, message) in cases) {
      test(
        'when validating sheet name "${name.length > 20 ? 'long' : name}" then the result is ${message ?? 'valid'}',
        () {
          expect(NameRules.validateSheetName(name), message);
        },
      );
    }

    test('when the sheet name is taken then the message names it', () {
      expect(
        NameRules.validateSheetName('sheet1', existing: ['Sheet1']),
        NameRules.sheetNameTaken('sheet1'),
      );
    });

    test(
      'when two sheets share a name after a merge then the larger id gets " (2)"',
      () {
        expect(
          NameRules.sheetRenames([
            ('b', 'Sheet2'),
            ('a', 'Sheet2'),
            ('c', 'Sheet3'),
          ]),
          {'b': 'Sheet2 (2)'},
        );
        expect(
          NameRules.sheetRenames([('a', 'Sheet2'), ('b', 'Sheet2 (2)')]),
          isEmpty,
        );
      },
    );
  });
}
