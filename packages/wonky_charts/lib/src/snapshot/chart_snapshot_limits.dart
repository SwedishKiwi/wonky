import 'dart:typed_data';

import '../data/chart_data.dart';
import '../data/data_algorithms.dart';
import '../spec/chart_spec.dart';
import '../spec/chart_type.dart';

/// Reduces resolved data to the size limits of a snapshot (Slides 08 §3.4) before it is
/// stored in a deck: LTTB to ≤ [maxLinePoints] points for line/area/scatter/bubble charts,
/// ≤ [maxCategories] categories for the other cartesian charts (also LTTB, so peaks survive),
/// pie "Other" grouping beyond [maxPieSlices] slices and ≤ [maxTableRows] table rows. Each
/// reduction adds a [ChartWarningCode.downsampled] / [ChartWarningCode.pieOtherGrouped]
/// warning. Data within the limits is returned unchanged (identical).
final class ChartSnapshotLimits {
  /// Creates limits.
  const ChartSnapshotLimits({
    this.maxLinePoints = 2000,
    this.maxCategories = 500,
    this.maxPieSlices = 50,
    this.maxTableRows = 200,
  });

  /// The limits of insert-dialog previews (08 §13: ≤ 200 points).
  static const preview = ChartSnapshotLimits(
    maxLinePoints: 200,
    maxCategories: 200,
    maxPieSlices: 50,
    maxTableRows: 50,
  );

  final int maxLinePoints;
  final int maxCategories;
  final int maxPieSlices;
  final int maxTableRows;

  /// [data] of [spec] within the limits.
  ChartData apply(ChartSpec spec, ChartData data) {
    var out = data;
    if (data.table case final t? when t.rowCount > maxTableRows) {
      out = _copy(
        out,
        table: ChartTableData(
          headers: t.headers,
          texts: [for (final c in t.texts) c.sublist(0, maxTableRows)],
          values: [
            for (final v in t.values)
              Float64List.fromList(v.sublist(0, maxTableRows)),
          ],
        ),
        warning: ChartWarning(
          ChartWarningCode.downsampled,
          'Only the first $maxTableRows rows are shown',
          count: t.rowCount - maxTableRows,
        ),
      );
    }
    if (out.series.isEmpty || out.domain.length == 0) return out;
    if (spec.type == ChartType.pie) {
      if (out.series.length != 1) return out;
      final g = PieGrouping.group(
        out.domain,
        out.series.first,
        threshold: maxPieSlices,
      );
      if (g == null) return out;
      return _copy(
        out,
        domain: g.$1,
        series: [g.$2],
        warning: ChartWarning(
          ChartWarningCode.pieOtherGrouped,
          'Small slices are grouped as "Other"',
          count: out.domain.length - g.$1.length + 1,
        ),
      );
    }
    if (!spec.type.isCartesian && spec.type != ChartType.radar) return out;
    final continuous = switch (spec.type) {
      ChartType.line ||
      ChartType.area ||
      ChartType.scatter ||
      ChartType.bubble => true,
      _ => false,
    };
    final limit = continuous ? maxLinePoints : maxCategories;
    final n = out.domain.length;
    if (n <= limit) return out;
    final keep = _keep(out, limit);
    return _copy(
      out,
      domain: ChartDomain(
        kind: out.domain.kind,
        values: _pick(out.domain.values, keep),
        labels: [for (final i in keep) out.domain.labels[i]],
        name: out.domain.name,
        key: out.domain.key,
        numberFormat: out.domain.numberFormat,
        isSynthetic: out.domain.isSynthetic,
      ),
      series: [
        for (final s in out.series)
          s.withValues(
            _pick(s.values, keep),
            texts: s.texts == null ? null : [for (final i in keep) s.texts![i]],
          ),
      ],
      warning: ChartWarning(
        ChartWarningCode.downsampled,
        'Showing $limit of $n points',
        count: n - keep.length,
      ),
    );
  }

  /// The union of every series' LTTB indices, each series getting an equal share of [limit].
  static List<int> _keep(ChartData data, int limit) {
    final n = data.domain.length;
    final xs = data.domain.isContinuous
        ? data.domain.values
        : Float64List.fromList([for (var i = 0; i < n; i++) i.toDouble()]);
    final share = (limit ~/ data.series.length).clamp(3, limit);
    final keep = <int>{0, n - 1};
    for (final s in data.series) {
      final ys = s.values.length == n ? s.values : Float64List(n);
      // Gaps (NaN) are kept as gaps: LTTB over the valid points of the series.
      final x = Float64List.fromList([
        for (var i = 0; i < n; i++) xs[i].isNaN ? i.toDouble() : xs[i],
      ]);
      keep.addAll(Lttb.downsample(x, ys, share));
    }
    final sorted = keep.toList()..sort();
    if (sorted.length <= limit) return sorted;
    // Too many after the union: evenly thin while keeping the ends.
    final step = (sorted.length - 1) / (limit - 1);
    return {for (var k = 0; k < limit; k++) sorted[(k * step).round()]}.toList()
      ..sort();
  }

  static Float64List _pick(Float64List v, List<int> keep) =>
      Float64List.fromList([
        for (final i in keep) i < v.length ? v[i] : double.nan,
      ]);

  static ChartData _copy(
    ChartData d, {
    ChartDomain? domain,
    List<ChartSeries>? series,
    ChartTableData? table,
    required ChartWarning warning,
  }) => ChartData(
    domain: domain ?? d.domain,
    series: series ?? d.series,
    warnings: [...d.warnings, warning],
    sourceCellCount: d.sourceCellCount,
    dataVersion: d.dataVersion,
    missingSeriesKeys: d.missingSeriesKeys,
    histogram: d.histogram,
    scorecard: d.scorecard,
    table: table ?? d.table,
  );
}
