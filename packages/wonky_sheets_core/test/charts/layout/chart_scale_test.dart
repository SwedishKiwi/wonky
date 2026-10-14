import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/chart_test_support.dart';

/// 08 §12 / AC 8: a line chart with 1,000,000 points lays out (LTTB to
/// ≤ max(2 × plot width, 2000) points) well within budget.
void main() {
  test('when a line chart has 1,000,000 points then the layout is '
      'downsampled and fast', () {
    const n = 1000000;
    final xs = Float64List(n), ys = Float64List(n);
    for (var i = 0; i < n; i++) {
      xs[i] = i.toDouble();
      ys[i] = math.sin(i / 5000) * 100 + (i % 97);
    }
    final data = ChartData(
      domain: ChartDomain(
        kind: DomainKind.numeric,
        values: xs,
        labels: List<String>.filled(n, ''),
        name: 'X',
      ),
      series: [ChartSeries(key: 's', name: 'Y', values: ys)],
      sourceCellCount: 2 * n,
    );
    const spec = ChartSpec(type: ChartType.line);
    final sw = Stopwatch()..start();
    final layout = layoutChart(spec, data);
    sw.stop();
    final points = layout.scene.flattened.whereType<SPolyline>().fold<int>(
      0,
      (s, p) => s + p.xy.length ~/ 2,
    );
    expect(points, lessThanOrEqualTo(2 * 600 + 2000));
    expect(points, greaterThan(500));
    // Budget 08 §12: ≤ 120 ms on the reference machine; generous in CI.
    expect(sw.elapsedMilliseconds, lessThan(2000));
    // ignore: avoid_print
    print('1M-point line layout: ${sw.elapsedMilliseconds} ms, $points points');
  });
}
