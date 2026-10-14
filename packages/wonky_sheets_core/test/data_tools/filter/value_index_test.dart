import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';

/// A column of values; display text = automatic text.
final class _Column implements FilterDataSource {
  _Column(this.values);

  final List<CellValue> values;

  @override
  CellValue valueAt(int row, int col) => values[row];

  @override
  String displayTextAt(int row, int col) => ValueText.automatic(values[row]);

  @override
  String? numberFormatAt(int row, int col) => null;

  @override
  String? fillColorAt(int row, int col) => null;

  @override
  String? textColorAt(int row, int col) => null;
}

void main() {
  group('Given a filter column with repeated values (07 §3.4)', () {
    late ValueIndex index;
    setUp(() {
      index = ValueIndex.build(
        _Column([
          const TextValue('Header'),
          const TextValue('b'),
          NumberValue(10),
          CellValue.empty,
          const TextValue('b'),
          NumberValue(2),
          const TextValue(''),
        ]),
        0,
        1,
        6,
      );
    });

    test('when building then rows are grouped by display text', () {
      expect(index.length, 6);
      expect(index.rowsOf('b'), [1, 4]);
      expect(index.count(''), 2);
      expect(index.textAt(2), '10');
      expect(index.textAt(0), '', reason: 'rows outside the index');
    });

    test(
      'when listing texts then blanks come first and values follow the sort order',
      () {
        expect(index.sortedTexts, ['', '2', '10', 'b']);
      },
    );

    test('when a row changes then it moves to its new text in order', () {
      index.update(5, const TextValue('b'), 'b');
      expect(index.rowsOf('b'), [1, 4, 5]);
      expect(index.rowsOf('2'), isEmpty);
      expect(index.sortedTexts, ['', '10', 'b']);
    });

    test('when a row becomes blank then it counts as blank', () {
      index.update(1, CellValue.empty, 'ignored');
      expect(index.count(''), 3);
      expect(index.rowsOf(''), [1, 3, 6]);
    });

    test('when updating a row outside the index then nothing changes', () {
      index.update(9, const TextValue('z'), 'z');
      expect(index.texts, isNot(contains('z')));
    });
  });
}
