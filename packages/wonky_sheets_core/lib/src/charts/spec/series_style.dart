import 'chart_spec_parts.dart';
import 'chart_type.dart';
import 'spec_json.dart';

/// Data labels of a series.
final class DataLabelsSpec extends SpecNode {
  /// Creates data label settings.
  const DataLabelsSpec({
    this.show = false,
    this.position = DataLabelPosition.auto,
    this.type = DataLabelType.value,
    this.font = ChartFont.inherit,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory DataLabelsSpec.fromJson(Object? json) {
    final r = JsonReader(json);
    return DataLabelsSpec(
      show: r.boolOr('show', false),
      position: r.enumOr(
        'position',
        DataLabelPosition.values,
        DataLabelPosition.auto,
      ),
      type: r.enumOr('type', DataLabelType.values, DataLabelType.value),
      font: ChartFont.fromJson(r.obj('font')),
      extras: r.extras(const {'show', 'position', 'type', 'font'}),
    );
  }

  final bool show;
  final DataLabelPosition position;
  final DataLabelType type;
  final ChartFont font;
  final Map<String, Object?> extras;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter(extras)
            ..unlessDefault('show', show, false)
            ..unlessDefault(
              'position',
              position.name,
              DataLabelPosition.auto.name,
            )
            ..unlessDefault('type', type.name, DataLabelType.value.name)
            ..nested('font', font.toJson()))
          .json;
}

/// Trendline of a series (08 §7).
final class TrendlineSpec extends SpecNode {
  /// Creates a trendline.
  const TrendlineSpec({
    this.type = TrendlineType.linear,
    this.degree = 2,
    this.period = 2,
    this.label = TrendlineLabel.none,
    this.customLabel = '',
    this.showR2 = false,
    this.color,
    this.opacity = 1,
    this.lineWidth = 2,
    this.lineDash = LineDash.solid,
    this.forward = 0,
    this.backward = 0,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory TrendlineSpec.fromJson(Object? json) {
    final r = JsonReader(json);
    return TrendlineSpec(
      type: r.enumOr('type', TrendlineType.values, TrendlineType.linear),
      degree: r.intOr('degree', 2),
      period: r.intOr('period', 2),
      label: r.enumOr('label', TrendlineLabel.values, TrendlineLabel.none),
      customLabel: r.strOr('customLabel', ''),
      showR2: r.boolOr('showR2', false),
      color: r.str('color'),
      opacity: r.dblOr('opacity', 1),
      lineWidth: r.dblOr('lineWidth', 2),
      lineDash: r.enumOr('lineDash', LineDash.values, LineDash.solid),
      forward: r.dblOr('forward', 0),
      backward: r.dblOr('backward', 0),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {
    'type',
    'degree',
    'period',
    'label',
    'customLabel',
    'showR2',
    'color',
    'opacity',
    'lineWidth',
    'lineDash',
    'forward',
    'backward',
  };

  final TrendlineType type;

  /// Polynomial degree 2..10.
  final int degree;

  /// Moving average period ≥ 2.
  final int period;
  final TrendlineLabel label;
  final String customLabel;
  final bool showR2;
  final String? color;
  final double opacity;
  final double lineWidth;
  final LineDash lineDash;

  /// P2 forecast extension (domain units).
  final double forward;
  final double backward;
  final Map<String, Object?> extras;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter(extras)
            ..put('type', type.name)
            ..unlessDefault('degree', degree, 2)
            ..unlessDefault('period', period, 2)
            ..unlessDefault('label', label.name, TrendlineLabel.none.name)
            ..unlessDefault('customLabel', customLabel, '')
            ..unlessDefault('showR2', showR2, false)
            ..opt('color', color)
            ..unlessDefault('opacity', jsonNum(opacity), 1)
            ..unlessDefault('lineWidth', jsonNum(lineWidth), 2)
            ..unlessDefault('lineDash', lineDash.name, LineDash.solid.name)
            ..unlessDefault('forward', jsonNum(forward), 0)
            ..unlessDefault('backward', jsonNum(backward), 0))
          .json;
}

/// "Format data point" override (08 §3.4 `points`).
final class PointStyle extends SpecNode {
  /// Creates a point style.
  const PointStyle({this.color, this.extras = const {}});

  /// Parses JSON leniently.
  factory PointStyle.fromJson(Object? json) {
    final r = JsonReader(json);
    return PointStyle(color: r.str('color'), extras: r.extras(const {'color'}));
  }

  final String? color;
  final Map<String, Object?> extras;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter(extras)..opt('color', color)).json;
}

/// Per-series style override (08 §3.4). Null fields use the chart type's defaults.
final class SeriesStyle extends SpecNode {
  /// Creates a series style.
  const SeriesStyle({
    this.type,
    this.axis = SeriesAxis.left,
    this.color,
    this.fillOpacity,
    this.lineColor,
    this.lineOpacity = 1,
    this.lineWidth,
    this.lineDash = LineDash.solid,
    this.pointSize,
    this.pointShape = PointShape.circle,
    this.dataLabels = const DataLabelsSpec(),
    this.trendline,
    this.errorBars,
    this.points = const {},
    this.labelOverride,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory SeriesStyle.fromJson(Object? json) {
    final r = JsonReader(json);
    final pts = r.obj('points') ?? const {};
    final tl = r.obj('trendline');
    return SeriesStyle(
      type: r.enumOrNull('type', SeriesChartType.values),
      axis: r.enumOr('axis', SeriesAxis.values, SeriesAxis.left),
      color: r.str('color'),
      fillOpacity: r.dbl('fillOpacity'),
      lineColor: r.str('lineColor'),
      lineOpacity: r.dblOr('lineOpacity', 1),
      lineWidth: r.dbl('lineWidth'),
      lineDash: r.enumOr('lineDash', LineDash.values, LineDash.solid),
      pointSize: r.dbl('pointSize'),
      pointShape: r.enumOr('pointShape', PointShape.values, PointShape.circle),
      dataLabels: DataLabelsSpec.fromJson(r.obj('dataLabels')),
      trendline: tl == null ? null : TrendlineSpec.fromJson(tl),
      errorBars: r.obj('errorBars'),
      points: {
        for (final e in pts.entries)
          if (int.tryParse(e.key) case final int i)
            i: PointStyle.fromJson(e.value),
      },
      labelOverride: r.str('labelOverride'),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {
    'type',
    'axis',
    'color',
    'fillOpacity',
    'lineColor',
    'lineOpacity',
    'lineWidth',
    'lineDash',
    'pointSize',
    'pointShape',
    'dataLabels',
    'trendline',
    'errorBars',
    'points',
    'labelOverride',
  };

  /// Default (no overrides).
  static const standard = SeriesStyle();

  /// Combo only.
  final SeriesChartType? type;
  final SeriesAxis axis;
  final String? color;
  final double? fillOpacity;
  final String? lineColor;
  final double lineOpacity;

  /// 0..8 px; null = type default.
  final double? lineWidth;
  final LineDash lineDash;

  /// 0 = none; null = type default (scatter 7, line 0).
  final double? pointSize;
  final PointShape pointShape;
  final DataLabelsSpec dataLabels;
  final TrendlineSpec? trendline;

  /// P2, kept verbatim.
  final Map<String, Object?>? errorBars;

  /// Per-point overrides by domain index.
  final Map<int, PointStyle> points;

  /// Legend label override.
  final String? labelOverride;
  final Map<String, Object?> extras;

  /// Copy with changes.
  SeriesStyle copyWith({
    SeriesChartType? type,
    SeriesAxis? axis,
    String? color,
    double? fillOpacity,
    String? lineColor,
    double? lineOpacity,
    double? lineWidth,
    LineDash? lineDash,
    double? pointSize,
    PointShape? pointShape,
    DataLabelsSpec? dataLabels,
    TrendlineSpec? trendline,
    Map<int, PointStyle>? points,
    String? labelOverride,
  }) => SeriesStyle(
    type: type ?? this.type,
    axis: axis ?? this.axis,
    color: color ?? this.color,
    fillOpacity: fillOpacity ?? this.fillOpacity,
    lineColor: lineColor ?? this.lineColor,
    lineOpacity: lineOpacity ?? this.lineOpacity,
    lineWidth: lineWidth ?? this.lineWidth,
    lineDash: lineDash ?? this.lineDash,
    pointSize: pointSize ?? this.pointSize,
    pointShape: pointShape ?? this.pointShape,
    dataLabels: dataLabels ?? this.dataLabels,
    trendline: trendline ?? this.trendline,
    errorBars: errorBars,
    points: points ?? this.points,
    labelOverride: labelOverride ?? this.labelOverride,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final sortedPoints = points.keys.toList()..sort();
    return (JsonWriter(extras)
          ..opt('type', type?.name)
          ..unlessDefault('axis', axis.name, SeriesAxis.left.name)
          ..opt('color', color)
          ..opt(
            'fillOpacity',
            fillOpacity == null ? null : jsonNum(fillOpacity!),
          )
          ..opt('lineColor', lineColor)
          ..unlessDefault('lineOpacity', jsonNum(lineOpacity), 1)
          ..opt('lineWidth', lineWidth == null ? null : jsonNum(lineWidth!))
          ..unlessDefault('lineDash', lineDash.name, LineDash.solid.name)
          ..opt('pointSize', pointSize == null ? null : jsonNum(pointSize!))
          ..unlessDefault('pointShape', pointShape.name, PointShape.circle.name)
          ..nested('dataLabels', dataLabels.toJson())
          ..opt('trendline', trendline?.toJson())
          ..opt('errorBars', errorBars == null ? null : deepCopyJson(errorBars))
          ..nested('points', {
            for (final k in sortedPoints) '$k': points[k]!.toJson(),
          })
          ..opt('labelOverride', labelOverride))
        .json;
  }
}
