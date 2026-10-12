part of 'chart_layout_engine.dart';

void _layoutPie(_Ctx c, ChartRect r) {
  final data = c.data;
  final s = data.series.first;
  final opts = c.spec.pieOptions;
  var total = 0.0;
  var negatives = 0;
  for (final v in s.values) {
    if (v > 0) {
      total += v;
    } else if (v < 0) {
      negatives++;
    }
  }
  if (negatives > 0) {
    c.warnings.add(
      ChartWarning(ChartWarningCode.pieNegativeIgnored, 'Negative values are not shown in pie charts', count: negatives, seriesKey: s.key),
    );
  }
  if (total <= 0 || r.isEmpty) {
    c.emptyState(r, 'No data');
    return;
  }
  var maxOffset = 0.0;
  for (final st in opts.slices.values) {
    maxOffset = math.max(maxOffset, st.offset);
  }
  final radius = math.max(4.0, math.min(r.width, r.height) / 2 / (1 + maxOffset) - 2);
  final center = r.center;
  final inner = radius * opts.pieHole;
  c.plotArea = ChartRect(center.x - radius * (1 + maxOffset), center.y - radius * (1 + maxOffset), 2 * radius * (1 + maxOffset), 2 * radius * (1 + maxOffset));
  final border = c.theme.color(opts.borderColor, c.background);
  var angle = -math.pi / 2 + opts.startAngle * math.pi / 180;
  final slices = <ScenePrimitive>[];
  final labels = <ScenePrimitive>[];
  final style = c.font(c.spec.seriesStyle(s.key).dataLabels.font, size: 12);
  for (var i = 0; i < s.length; i++) {
    final v = s.values[i];
    if (!(v > 0)) continue;
    final sweep = v / total * 2 * math.pi;
    final mid = angle + sweep / 2;
    final off = (opts.slices[i]?.offset ?? 0) * radius;
    final cx = center.x + math.cos(mid) * off, cy = center.y + math.sin(mid) * off;
    final fill = c.sliceColor(i, opts.slices[i]?.color);
    slices.add(
      SArc(
        ChartPoint(cx, cy),
        radius,
        angle,
        sweep,
        innerRadius: inner,
        fill: fill,
        stroke: sweep < 2 * math.pi - 1e-9 ? SStroke(border) : null,
        tag: SceneTag(SceneRole.point, seriesKey: s.key, pointIndex: i),
      ),
    );
    final frac = v / total;
    final text = switch (opts.sliceLabel) {
      SliceLabel.none => '',
      SliceLabel.label => data.domain.labels[i],
      SliceLabel.value => c.formatValue(v, s.numberFormat),
      SliceLabel.percentage => c.formatValue(frac, '0.0%'),
      SliceLabel.valueAndPercentage => '${c.formatValue(v, s.numberFormat)} (${c.formatValue(frac, '0.0%')})',
    };
    if (text.isNotEmpty) {
      final lr = inner > 0 ? (inner + radius) / 2 : radius * 0.62;
      final m = c.measure(text, style);
      final arc = lr * sweep;
      final thickness = inner > 0 ? radius - inner : radius;
      final fits = sweep >= 2 * math.pi - 1e-9 ||
          (arc > math.min(m.width, m.height) * 1.3 && m.width < thickness * 1.6 + arc * 0.5 && m.height < arc);
      if (fits) {
        labels.add(
          c.text(
            text,
            cx + math.cos(mid) * (sweep >= 2 * math.pi - 1e-9 && inner == 0 ? 0 : lr),
            cy + math.sin(mid) * (sweep >= 2 * math.pi - 1e-9 && inner == 0 ? 0 : lr),
            style.copyWith(color: c.theme.color(c.spec.seriesStyle(s.key).dataLabels.font.color, c.theme.onColor(fill))),
            anchor: TextAnchor.center,
            tag: SceneTag(SceneRole.dataLabel, seriesKey: s.key, pointIndex: i),
          ),
        );
      }
    }
    angle += sweep;
  }
  c.out
    ..addAll(slices)
    ..addAll(labels);
}
