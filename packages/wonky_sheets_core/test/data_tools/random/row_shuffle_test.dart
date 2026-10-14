import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

void main() {
  group('Given row shuffling (07 §14)', () {
    test('when shuffling three rows many times then every order appears', () {
      final random = Random(2026);
      final seen = <String>{};
      for (var i = 0; i < 300; i++) {
        seen.add(RowShuffle.permutation(3, random).join(','));
      }
      expect(seen, {'0,1,2', '0,2,1', '1,0,2', '1,2,0', '2,0,1', '2,1,0'});
    });

    test('when shuffling one row then it stays', () {
      expect(RowShuffle.permutation(1, Random(1)), [0]);
    });

    test('when shuffling then the result is a permutation of the rows', () {
      final p = RowShuffle.permutation(100, Random(9));
      expect(p.toSet(), {for (var i = 0; i < 100; i++) i});
      expect(p.length, 100);
    });
  });
}
