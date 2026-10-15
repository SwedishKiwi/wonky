import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/src/charts/charts.dart';

List<FValue> col(List<Object?> cells) => [
  for (final c in cells)
    switch (c) {
      null => FEmpty.instance,
      final num n => FNumber(n.toDouble()),
      final String s => FText(s),
      _ => throw ArgumentError(c),
    },
];

void main() {
  group('Given header detection (08 §4.2)', () {
    for (final (name, lines, expected) in [
      (
        'a text header over numbers',
        [
          col(['Month', 'Jan', 'Feb']),
          col(['Sales', 1, 2]),
        ],
        1,
      ),
      (
        'numbers only',
        [
          col([1, 2, 3]),
          col([4, 5, 6]),
        ],
        0,
      ),
      (
        'an all-text first row over a numeric second row',
        [
          col(['a', 'x', 'y']),
          col(['b', 2, 'z']),
        ],
        1,
      ),
      (
        'text everywhere',
        [
          col(['a', 'b']),
          col(['c', 'd']),
        ],
        0,
      ),
      (
        'a single row',
        [
          col(['a']),
          col([1]),
        ],
        0,
      ),
      (
        'a header over numbers with empty cells',
        [
          col(['Sales', 1, null, 3]),
        ],
        1,
      ),
    ]) {
      test('when the data is $name then the header count is $expected', () {
        expect(HeaderDetection.detect(lines), expected);
      });
    }
  });
}
