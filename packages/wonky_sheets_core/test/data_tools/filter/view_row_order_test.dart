import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';

void main() {
  group('Given a filter view sorted for display (07 §4.4)', () {
    late ViewRowOrder order;
    setUp(() {
      final table = SortTable(4, {
        'a': SortKeyColumn.fromValues([
          const TextValue('x'),
          const TextValue('x'),
          const TextValue('a'),
          CellValue.empty,
        ]),
        'b': SortKeyColumn.fromValues([
          NumberValue(1),
          NumberValue(2),
          NumberValue(3),
          NumberValue(4),
        ]),
      });
      order = ViewRowOrder.compute(table, const [
        ValueSortSpec('a'),
        ValueSortSpec('b', ascending: false),
      ], top: 10);
    });

    test('when mapping display rows then the sorted order is shown', () {
      expect(
        [for (var r = 10; r < 14; r++) order.modelRow(r)],
        [12, 11, 10, 13],
      );
      expect(order.isIdentity, isFalse);
      expect(order.length, 4);
    });

    test('when mapping back and forth then both directions agree', () {
      for (var r = 10; r < 14; r++) {
        expect(order.displayRow(order.modelRow(r)), r);
      }
    });

    test('when a row lies outside the block then it maps to itself', () {
      expect((order.modelRow(9), order.displayRow(14)), (9, 14));
    });

    test('when the order is the identity then it reports so', () {
      final id = ViewRowOrder.identity(3, 5);
      expect(id.isIdentity, isTrue);
      expect(id.modelRow(5), 5);
    });
  });
}
