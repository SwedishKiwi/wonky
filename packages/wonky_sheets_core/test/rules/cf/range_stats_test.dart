import 'package:test/test.dart';

import '../support/core.dart';

void main() {
  group('Given range statistics of 1, 2, 3, 4', () {
    final stats = RangeStats.fromValues([4, 2, double.nan, 1, 3]);

    test(
      'when reading count, min and max then non-finite values are ignored',
      () {
        expect((stats.count, stats.min, stats.max), (4, 1.0, 4.0));
      },
    );

    final cases = <(double, double)>[
      (0, 1),
      (1, 4),
      (0.5, 2.5),
      (0.25, 1.75),
      (2, 4),
      (-1, 1),
    ];
    for (final (p, expected) in cases) {
      test('when asking for percentile $p then it is $expected', () {
        expect(stats.percentile(p), expected);
      });
    }
  });

  group('Given empty range statistics', () {
    test('when reading values then they are zero', () {
      expect(RangeStats.empty.isEmpty, isTrue);
      expect((RangeStats.empty.min, RangeStats.empty.max), (0.0, 0.0));
      expect(RangeStats.empty.percentile(0.5), 0.0);
    });
  });
}
