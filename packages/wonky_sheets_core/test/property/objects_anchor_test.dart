@Tags(['property'])
library;

import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/model/axis_index.dart';
import 'package:wonky_sheets_core/src/objects/objects.dart';
import 'package:wonky_sync_models/ids.dart';

/// Seeds from `WONKY_SEED` (comma-separated) or the fixed defaults.
List<int> _seeds() {
  final env = Platform.environment['WONKY_SEED'];
  if (env == null || env.trim().isEmpty) return const [1, 42, 20261012, 987654321];
  return [for (final s in env.split(',')) int.parse(s.trim())];
}

int _runs() => int.tryParse(Platform.environment['WONKY_PROPERTY_RUNS'] ?? '') ?? 200;

String _uuid(int ns, int i) =>
    '00000000-0000-4000-8000-${ns.toRadixString(16).padLeft(4, '0')}'
    '${i.toRadixString(16).padLeft(8, '0')}';

/// A random axis: 1–60 entries, random explicit sizes (some fractional),
/// about 15 % hidden but at least one visible.
AxisIndex _axis(Random rnd, int ns) {
  final n = 1 + rnd.nextInt(60);
  final keys = FractionalIndex.nBetween(null, null, n);
  final visible = rnd.nextInt(n);
  return AxisIndex(defaultSize: 21)..load([
    for (var i = 0; i < n; i++)
      (
        _uuid(ns, i),
        keys[i],
        rnd.nextInt(3) == 0 ? null : 2 + rnd.nextDouble() * 200,
        i != visible && rnd.nextInt(7) == 0,
      ),
  ]);
}

void main() {
  for (final seed in _seeds()) {
    group('Given random axes and points (seed $seed)', () {
      test('when normalizing a point inside the sheet then rectIn returns that top-left', () {
        final rnd = Random(seed);
        for (var run = 0; run < _runs(); run++) {
          final rows = _axis(rnd, 1);
          final cols = _axis(rnd, 2);
          final x = rnd.nextDouble() * cols.totalSize;
          final y = rnd.nextDouble() * rows.totalSize;
          final w = rnd.nextDouble() * 5000;
          final h = rnd.nextDouble() * 5000;

          final a = ObjectAnchor.normalizeAt(x, y, width: w, height: h, rows: rows, columns: cols);
          final rect = a.rectIn(rows, cols)!;

          final reason = 'seed $seed run $run: ($x, $y) → $a';
          expect(rect.left, closeTo(x, 1e-9), reason: reason);
          expect(rect.top, closeTo(y, 1e-9), reason: reason);
          expect(rect.width, inInclusiveRange(ObjectAnchor.minSize, ObjectAnchor.maxSize));
          expect(rect.height, inInclusiveRange(ObjectAnchor.minSize, ObjectAnchor.maxSize));
          expect(cols.isHidden(cols.indexOf(a.colId!)), isFalse, reason: reason);
          expect(rows.isHidden(rows.indexOf(a.rowId!)), isFalse, reason: reason);
          expect(a.dx, inInclusiveRange(0, cols.sizeAt(cols.indexOf(a.colId!))), reason: reason);
          expect(a.dy, inInclusiveRange(0, rows.sizeAt(rows.indexOf(a.rowId!))), reason: reason);
          expect(a.normalized(rows, cols), a, reason: reason);
          expect(ObjectAnchor.tryParse(a.encode()), a, reason: reason);
        }
      });

      test('when deleting random rows and columns then re-anchoring is idempotent', () {
        final rnd = Random(seed);
        for (var run = 0; run < _runs(); run++) {
          final rows = _axis(rnd, 1);
          final cols = _axis(rnd, 2);
          final a = ObjectAnchor.normalizeAt(
            rnd.nextDouble() * cols.totalSize,
            rnd.nextDouble() * rows.totalSize,
            width: 100,
            height: 100,
            rows: rows,
            columns: cols,
          );
          if (rows.length > 1 && rnd.nextBool()) rows.remove(a.rowId!);
          if (cols.length > 1 && rnd.nextBool()) cols.remove(a.colId!);

          final fixed = a.reanchor(rows, cols) ?? a;

          final reason = 'seed $seed run $run: $a';
          expect(rows.contains(fixed.rowId!), isTrue, reason: reason);
          expect(cols.contains(fixed.colId!), isTrue, reason: reason);
          expect(fixed.reanchor(rows, cols), isNull, reason: reason);
          expect(a.reanchor(rows, cols), a.reanchor(rows, cols), reason: reason);
        }
      });
    });
  }
}
