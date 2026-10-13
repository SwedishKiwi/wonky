import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/scene/geometry.dart';
import 'package:wonky_sheets_core/src/objects/objects.dart';

void main() {
  const overlapA = ChartRect(0, 0, 100, 100);
  const overlapB = ChartRect(50, 50, 100, 100);
  const apart = ChartRect(500, 500, 50, 50);

  group(
    'Given objects a (z 1), b (z 2, overlaps a), c (z 3, apart), d (z 4, overlaps a)',
    () {
      const items = [
        ZOrderItem('a', 1, overlapA),
        ZOrderItem('b', 2, overlapB),
        ZOrderItem('c', 3, apart),
        ZOrderItem('d', 4, overlapB),
      ];

      test('when sorting then the order is by zIndex', () {
        expect(
          [for (final e in ZOrder.sorted(items.reversed)) e.id],
          ['a', 'b', 'c', 'd'],
        );
      });

      for (final (op, id, expected) in <(String, String, Map<String, int>)>[
        ('bringToFront', 'a', {'a': 5}),
        ('bringToFront', 'd', {}),
        ('sendToBack', 'd', {'d': 0}),
        ('sendToBack', 'a', {}),
        ('bringForward', 'a', {'a': 2, 'b': 1}),
        ('bringForward', 'b', {'b': 4, 'd': 2}),
        ('bringForward', 'c', {}),
        ('bringForward', 'd', {}),
        ('sendBackward', 'd', {'d': 2, 'b': 4}),
        ('sendBackward', 'b', {'b': 1, 'a': 2}),
        ('sendBackward', 'c', {}),
        ('sendBackward', 'missing', {}),
      ]) {
        test('when calling $op on $id then the changes are $expected', () {
          final result = switch (op) {
            'bringToFront' => ZOrder.bringToFront(items, id),
            'sendToBack' => ZOrder.sendToBack(items, id),
            'bringForward' => ZOrder.bringForward(items, id),
            _ => ZOrder.sendBackward(items, id),
          };

          expect(result, expected);
        });
      }

      for (final (current, next, previous) in <(String?, String, String)>[
        (null, 'd', 'a'),
        ('d', 'c', 'a'),
        ('a', 'd', 'b'),
        ('missing', 'd', 'a'),
      ]) {
        test(
          'when cycling from $current then next is $next and previous is $previous',
          () {
            expect(ZOrder.selectNext(items, current), next);
            expect(ZOrder.selectPrevious(items, current), previous);
          },
        );
      }

      test('when there are no objects then selection cycling returns null', () {
        expect(ZOrder.selectNext(const [], null), isNull);
      });
    },
  );

  group('Given objects with tied zIndex values', () {
    test(
      'when bringing the lower of two tied objects forward then distinct values are written',
      () {
        const items = [
          ZOrderItem('a', 1, overlapA),
          ZOrderItem('b', 1, overlapB),
        ];

        final result = ZOrder.bringForward(items, 'a');

        expect(result, {'a': 2});
        expect(_order(items, result), ['b', 'a']);
      },
    );

    test(
      'when sending the upper of two tied objects backward then distinct values are written',
      () {
        const items = [
          ZOrderItem('a', 1, overlapA),
          ZOrderItem('b', 1, overlapB),
        ];

        final result = ZOrder.sendBackward(items, 'b');

        expect(result, {'b': 0});
        expect(_order(items, result), ['b', 'a']);
      },
    );

    test(
      'when ties with a third object make a swap ambiguous then the order still changes',
      () {
        const items = [
          ZOrderItem('a', 1, overlapA),
          ZOrderItem('b', 2, overlapB),
          ZOrderItem('c', 2, overlapB),
        ];

        final result = ZOrder.bringForward(items, 'a');

        expect(_order(items, result), ['b', 'a', 'c']);
      },
    );

    test('when bringing to front past a tie then the object ends on top', () {
      const items = [
        ZOrderItem('a', 3, overlapA),
        ZOrderItem('b', 3, overlapB),
      ];

      final result = ZOrder.bringToFront(items, 'a');

      expect(result, {'a': 4});
      expect(_order(items, result), ['b', 'a']);
    });
  });
}

List<String> _order(List<ZOrderItem> items, Map<String, int> changes) => [
  for (final e in ZOrder.sorted([
    for (final i in items) ZOrderItem(i.id, changes[i.id] ?? i.zIndex, i.rect),
  ]))
    e.id,
];
