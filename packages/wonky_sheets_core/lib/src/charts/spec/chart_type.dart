/// Delivery priority of a chart type (08 §2).
enum ChartPriority { p0, p1, p2 }

/// Chart type ids (08 §2). [id] is the JSON value.
enum ChartType {
  column(ChartPriority.p0, 'Column'),
  bar(ChartPriority.p0, 'Bar'),
  line(ChartPriority.p0, 'Line'),
  area(ChartPriority.p0, 'Area'),
  combo(ChartPriority.p0, 'Combo'),
  pie(ChartPriority.p0, 'Pie'),
  scatter(ChartPriority.p0, 'Scatter'),
  bubble(ChartPriority.p1, 'Bubble'),
  histogram(ChartPriority.p1, 'Histogram'),
  candlestick(ChartPriority.p1, 'Candlestick'),
  waterfall(ChartPriority.p1, 'Waterfall'),
  scorecard(ChartPriority.p1, 'Scorecard'),
  table(ChartPriority.p1, 'Table'),
  radar(ChartPriority.p1, 'Radar'),
  ohlc(ChartPriority.p2, 'OHLC'),
  gauge(ChartPriority.p2, 'Gauge'),
  treemap(ChartPriority.p2, 'Tree map'),
  org(ChartPriority.p2, 'Organizational'),
  timeline(ChartPriority.p2, 'Timeline'),
  geo(ChartPriority.p2, 'Geo');

  const ChartType(this.priority, this.displayName);

  /// Delivery priority.
  final ChartPriority priority;

  /// English display name (`"Column"`); the auto description appends " chart".
  final String displayName;

  /// JSON id.
  String get id => name;

  /// Whether the layout engine renders this type (P0 and P1).
  bool get isImplemented => priority != ChartPriority.p2;

  /// Whether the type has a domain axis and value axes (column, bar, line, …).
  bool get isCartesian => switch (this) {
    column || bar || line || area || combo || scatter || bubble || histogram => true,
    candlestick || waterfall || ohlc || timeline => true,
    _ => false,
  };

  /// Whether `stacking` applies (08 §3.1).
  bool get supportsStacking => this == column || this == bar || this == area || this == combo;

  /// Whether trendlines apply (08 §7).
  bool get supportsTrendlines => this == scatter || this == line || this == column || this == bar;

  /// Parses a JSON id (null for unknown ids).
  static ChartType? tryParse(Object? id) {
    if (id is! String) return null;
    for (final t in values) {
      if (t.name == id) return t;
    }
    return null;
  }
}

/// `stacking` (08 §3.1).
enum ChartStacking { none, normal, percent }

/// Data aggregation (08 §3.2 `aggregate`).
enum ChartAggregate { sum, average, count, max, min, median }

/// `data.emptyCells` (08 §3.2).
enum EmptyCellMode { gap, zero, connect }

/// Title alignment.
enum TitleAlign { auto, left, center, right }

/// `style.compareMode` (tooltip mode).
enum CompareMode { off, datum, category }

/// Legend position (08 §8.2).
enum LegendPosition { auto, top, bottom, left, right, inside, none }

/// Legend alignment along its edge.
enum LegendAlignment { start, center, end }

/// Axis label slant.
enum LabelSlant { auto, none, custom }

/// Tick marks.
enum TickMark { none, inside, outside }

/// Combo per-series type.
enum SeriesChartType { column, line, area }

/// Which vertical axis a series uses.
enum SeriesAxis { left, right }

/// Line dash style.
enum LineDash { solid, dash, dot, dashDot, longDash }

/// Point shapes (08 §3.4).
enum PointShape { circle, triangle, square, diamond, star, polygon }

/// Data label position (08 §3.4).
enum DataLabelPosition { auto, center, insideEnd, insideBase, outsideEnd, above, below, left, right }

/// Data label content.
enum DataLabelType { value, percent, label, custom }

/// Trendline model (08 §7).
enum TrendlineType { linear, exponential, polynomial, logarithmic, power, movingAverage }

/// Trendline label.
enum TrendlineLabel { none, equation, custom }

/// Pie slice label (08 §3.7).
enum SliceLabel { none, label, value, percentage, valueAndPercentage }

/// Scorecard comparison.
enum ScorecardCompareMode { absolute, percent }

/// Radar grid shape.
enum RadarGridShape { polygon, circle }

/// Bubble coloring.
enum BubbleColorBy { series, category }

/// Dash pattern (px, for a 1 px line; scaled by line width ≥ 1).
List<double>? dashPattern(LineDash d, double width) {
  final w = width < 1 ? 1.0 : width;
  return switch (d) {
    LineDash.solid => null,
    LineDash.dash => [4 * w, 3 * w],
    LineDash.dot => [w, 2 * w],
    LineDash.dashDot => [4 * w, 2 * w, w, 2 * w],
    LineDash.longDash => [8 * w, 3 * w],
  };
}
