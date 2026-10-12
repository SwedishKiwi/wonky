part of 'chart_layout_engine.dart';

void _layoutRadar(_Ctx c, ChartRect r) {
  final data = c.data;
  final n = data.domain.length;
  final opts = c.spec.radarOptions;
  final labelStyle = c.font(c.spec.axes.h.labels.font, size: 12, color: c.theme.mutedText);
  final lineH = c.measure('Ag', labelStyle).height;
  var maxLabel = 0.0;
  for (final l in data.domain.labels) {
    maxLabel = math.max(maxLabel, c.measure(l, labelStyle).width);
  }
  maxLabel = math.min(maxLabel, r.width * 0.25);
  final radius = math.max(10.0, math.min(r.width / 2 - maxLabel - 10, r.height / 2 - lineH - 8));
  final center = r.center;
  c.plotArea = ChartRect(center.x - radius, center.y - radius, 2 * radius, 2 * radius);
  var hi = -double.infinity, lo = double.infinity;
  for (final s in data.series) {
    for (final v in s.values) {
      if (v.isNaN) continue;
      hi = math.max(hi, v);
      lo = math.min(lo, v);
    }
  }
  if (hi < lo) {
    hi = 1;
    lo = 0;
  }
  final axis = c.spec.axes.v;
  final nr = NiceTicks.compute(math.min(0, lo), hi, target: math.max(2, (radius / 40).floor() + 1), fixedMin: axis.min, fixedMax: axis.max);
  final scale = LinearScale(nr.min, nr.max, 0, radius, ticks: nr.ticks);
  double ang(int i) => -math.pi / 2 + (n == 0 ? 0 : 2 * math.pi * i / n);
  // Grid.
  final grid = PathBuilder();
  for (final t in nr.ticks) {
    final rr = scale.map(t);
    if (rr <= 0) continue;
    if (opts.gridShape == RadarGridShape.circle || n < 3) {
      grid
        ..arc(center.x, center.y, rr, -math.pi / 2, math.pi)
        ..arc(center.x, center.y, rr, math.pi / 2, math.pi)
        ..close();
    } else {
      grid.polygon([
        for (var i = 0; i < n; i++) ...[center.x + rr * math.cos(ang(i)), center.y + rr * math.sin(ang(i))],
      ]);
    }
  }
  for (var i = 0; i < n; i++) {
    grid
      ..moveTo(center.x, center.y)
      ..lineTo(center.x + radius * math.cos(ang(i)), center.y + radius * math.sin(ang(i)));
  }
  c.out.add(SPath(grid.commands, stroke: SStroke(c.theme.gridline), tag: const SceneTag(SceneRole.gridline, detail: 'v')));
  // Value labels along the first spoke.
  if (axis.labels.show) {
    final vs = c.font(axis.labels.font, size: 10, color: c.theme.mutedText);
    final pattern = axis.numberFormat ?? (data.series.isEmpty ? null : data.series.first.numberFormat) ?? ChartFormats.tickPattern(nr.decimals);
    for (var k = 0; k < nr.ticks.length; k++) {
      final rr = scale.map(nr.ticks[k]);
      c.out.add(c.text(c.formatValue(nr.ticks[k], pattern), center.x + 3, center.y - rr, vs, anchor: TextAnchor.bottomLeft, tag: SceneTag(SceneRole.axisLabel, detail: 'v', pointIndex: k)));
    }
  }
  // Category labels.
  if (c.spec.axes.h.labels.show) {
    for (var i = 0; i < n; i++) {
      final a = ang(i);
      final x = center.x + (radius + 8) * math.cos(a), y = center.y + (radius + 8) * math.sin(a);
      final cos = math.cos(a), sin = math.sin(a);
      final anchor = cos.abs() < 0.3
          ? (sin < 0 ? TextAnchor.bottomCenter : TextAnchor.topCenter)
          : (cos > 0 ? TextAnchor.middleLeft : TextAnchor.middleRight);
      c.out.add(c.text(c.measurer.ellipsize(data.domain.labels[i], labelStyle, maxLabel + 0.5), x, y, labelStyle, anchor: anchor, tag: SceneTag(SceneRole.axisLabel, detail: 'h', pointIndex: i)));
    }
  }
  // Series.
  for (final s in c.seriesInfos) {
    final xy = Float64List(n * 2);
    for (var i = 0; i < n; i++) {
      final v = s.series.values[i];
      final rr = v.isNaN ? 0.0 : scale.map(v).clamp(0.0, radius);
      xy[2 * i] = center.x + rr * math.cos(ang(i));
      xy[2 * i + 1] = center.y + rr * math.sin(ang(i));
    }
    final items = <ScenePrimitive>[];
    final pb = PathBuilder()..polygon(xy);
    final width = s.style.lineWidth ?? 2;
    items.add(
      SPath(
        pb.commands,
        fill: Argb.withOpacity(s.color, s.style.fillOpacity ?? opts.fillOpacity),
        stroke: width > 0 ? SStroke(Argb.withOpacity(c.theme.color(s.style.lineColor, s.color), s.style.lineOpacity), width: width, dash: c.seriesDash(s, width), join: SStrokeJoin.round) : null,
        tag: SceneTag(SceneRole.series, seriesKey: s.key),
      ),
    );
    final ps = s.style.pointSize ?? 5;
    if (ps > 0) {
      items.add(SMarkers(xy, c.seriesShape(s), ps, fill: s.color, tag: SceneTag(SceneRole.point, seriesKey: s.key)));
    }
    c.addSeriesGroup(s.key, items, c.out);
  }
}

void _layoutScorecard(_Ctx c, ChartRect r) {
  final sd = c.data.scorecard!;
  final o = c.spec.scorecardOptions;
  c.plotArea = r;
  final keyText = sd.keyValue.isNaN ? '—' : c.formatValue(sd.keyValue, sd.keyFormat);
  var size = math.min(r.height * 0.4, 72.0);
  var style = c.font(c.spec.title.font.copyWith(size: null), size: size, bold: true);
  while (size > 10 && c.measure(keyText, style).width > r.width * 0.9) {
    size *= 0.9;
    style = style.copyWith(size: size);
  }
  final keyM = c.measure(keyText, style);
  final labelStyle = c.font(ChartFont.inherit, size: 14, color: c.theme.mutedText);
  final hasLabel = sd.label.isNotEmpty && !c.spec.title.hasText;
  String? compare;
  int? compareColor;
  if (sd.baseline != null && !sd.keyValue.isNaN) {
    final diff = sd.keyValue - sd.baseline!;
    final up = diff >= 0;
    final arrow = diff == 0 ? '' : (up ? '▲ ' : '▼ ');
    final value = o.compareMode == ScorecardCompareMode.percent
        ? (sd.baseline == 0 ? '—' : c.formatValue((diff / sd.baseline!).abs(), '0.0%'))
        : c.formatValue(diff.abs(), sd.baselineFormat);
    compare = '$arrow$value';
    compareColor = up ? c.theme.color(o.positiveColor, c.theme.positive) : c.theme.color(o.negativeColor, c.theme.negative);
  }
  final compareStyle = c.font(ChartFont.inherit, size: math.max(12, size * 0.3), color: compareColor ?? c.theme.text);
  final labelH = hasLabel ? c.measure('Ag', labelStyle).height + 6 : 0.0;
  final compareH = compare != null ? c.measure('Ag', compareStyle).height + 6 : 0.0;
  final blockH = keyM.height + labelH + compareH;
  var y = r.top + (r.height - blockH) / 2;
  c.out.add(c.text(keyText, r.centerX, y, style, anchor: TextAnchor.topCenter, tag: const SceneTag(SceneRole.keyValue)));
  y += keyM.height + 6;
  if (compare != null) {
    c.out.add(c.text(compare, r.centerX, y, compareStyle, anchor: TextAnchor.topCenter, tag: const SceneTag(SceneRole.baseline)));
    y += compareH;
  }
  if (hasLabel) {
    c.out.add(c.text(c.measurer.ellipsize(sd.label, labelStyle, r.width), r.centerX, y, labelStyle, anchor: TextAnchor.topCenter, tag: const SceneTag(SceneRole.title, detail: 'label')));
  }
}
