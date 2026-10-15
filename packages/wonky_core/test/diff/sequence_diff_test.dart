import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_core/diff.dart';

/// Applies [ops] to [a] with elements of [b] for inserts; the result must be
/// [b] for a valid script.
List<T> _apply<T>(List<T> a, List<T> b, List<DiffOp> ops) {
  final out = <T>[];
  var ia = 0, ib = 0;
  for (final op in ops) {
    switch (op) {
      case DiffOp.equal:
        out.add(a[ia]);
        ia++;
        ib++;
      case DiffOp.delete:
        ia++;
      case DiffOp.insert:
        out.add(b[ib]);
        ib++;
    }
  }
  return out;
}

/// Length of the longest common subsequence (brute-force DP).
int _lcs<T>(List<T> a, List<T> b) {
  final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      dp[i][j] = a[i - 1] == b[j - 1]
          ? dp[i - 1][j - 1] + 1
          : max(dp[i - 1][j], dp[i][j - 1]);
    }
  }
  return dp[a.length][b.length];
}

void main() {
  group('Given two token sequences', () {
    test('when one token changes then the script replaces only it', () {
      final ops = SequenceDiff.diff(
        ['final', 'x', '=', '1'],
        ['final', 'y', '=', '1'],
      );

      expect(ops, [
        DiffOp.equal,
        DiffOp.delete,
        DiffOp.insert,
        DiffOp.equal,
        DiffOp.equal,
      ]);
    });

    test('when the sequences are equal then every op is equal', () {
      expect(SequenceDiff.diff([1, 2, 3], [1, 2, 3]), [
        DiffOp.equal,
        DiffOp.equal,
        DiffOp.equal,
      ]);
    });

    test('when a custom equality ignores case then case changes are equal', () {
      final ops = SequenceDiff.diff(
        ['Select', 'a'],
        ['SELECT', 'a'],
        equals: (x, y) => x.toLowerCase() == y.toLowerCase(),
      );

      expect(ops, [DiffOp.equal, DiffOp.equal]);
    });

    test('when one side is empty then all elements are inserted', () {
      expect(SequenceDiff.diff(<int>[], [1, 2]), [
        DiffOp.insert,
        DiffOp.insert,
      ]);
    });
  });

  group('Given random small sequences (property)', () {
    final random = Random(42);
    List<int> gen() =>
        List.generate(random.nextInt(9), (_) => random.nextInt(4));

    for (var i = 0; i < 200; i++) {
      final a = gen(), b = gen();
      test('when diffing $a and $b then the script is valid and minimal', () {
        final ops = SequenceDiff.diff(a, b);

        expect(_apply(a, b, ops), b);
        expect(ops.where((o) => o == DiffOp.equal).length, _lcs(a, b));
      });
    }
  });
}
