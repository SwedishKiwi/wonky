@Tags(['property'])
library;

import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sync_models/ids.dart';

List<int> _seeds() {
  final env = Platform.environment['WONKY_SEED'];
  if (env != null) return [int.parse(env)];
  return const [1, 2, 3, 42, 1337];
}

int _runs() =>
    int.tryParse(Platform.environment['WONKY_PROPERTY_RUNS'] ?? '') ?? 300;

void main() {
  for (final seed in _seeds()) {
    group('Given random insertions (seed $seed)', () {
      test(
        'when inserting keys at random positions then the list stays strictly ordered',
        () {
          final random = Random(seed);
          final keys = <String>[];
          for (var i = 0; i < _runs(); i++) {
            final pos = random.nextInt(keys.length + 1);
            final a = pos == 0 ? null : keys[pos - 1];
            final b = pos == keys.length ? null : keys[pos];
            final k = FractionalIndex.between(a, b);
            expect(
              FractionalIndex.isValid(k),
              isTrue,
              reason: 'seed $seed key $k',
            );
            if (a != null) {
              expect(a.compareTo(k), lessThan(0), reason: 'seed $seed');
            }
            if (b != null) {
              expect(k.compareTo(b), lessThan(0), reason: 'seed $seed');
            }
            keys.insert(pos, k);
          }
          expect([...keys]..sort(), keys, reason: 'seed $seed');
        },
      );

      test(
        'when bulk-generating n keys then they are ordered, unique and short',
        () {
          final random = Random(seed);
          final base = FractionalIndex.nBetween(null, null, 50);
          for (var i = 0; i < 20; i++) {
            final p = random.nextInt(base.length - 1);
            final n = 1 + random.nextInt(5000);
            final keys = FractionalIndex.nBetween(base[p], base[p + 1], n);
            expect(keys.length, n);
            expect(keys.toSet().length, n, reason: 'seed $seed');
            for (var j = 1; j < keys.length; j++) {
              expect(
                keys[j - 1].compareTo(keys[j]),
                lessThan(0),
                reason: 'seed $seed',
              );
            }
            expect(keys.first.compareTo(base[p]), greaterThan(0));
            expect(keys.last.compareTo(base[p + 1]), lessThan(0));
            // Density: keys grow by about log62(n) + small constant characters.
            final maxLen = keys.map((k) => k.length).reduce(max);
            expect(
              maxLen,
              lessThanOrEqualTo(base[p].length + 4),
              reason: 'seed $seed n $n',
            );
          }
        },
      );

      test('when appending many keys then they remain short', () {
        final keys = FractionalIndex.nBetween(null, null, 10000);
        expect(keys.last.length, lessThanOrEqualTo(4));
        expect([...keys]..sort(), keys);
      });
    });
  }
}
