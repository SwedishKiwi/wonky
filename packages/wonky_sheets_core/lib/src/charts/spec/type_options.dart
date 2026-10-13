import '../../model/grid_range.dart';
import 'chart_type.dart';
import 'spec_json.dart';

/// Typed views over `typeOptions` (08 §3.7). The spec keeps `typeOptions` as a raw JSON map so
/// unknown keys survive; these classes read it leniently and write canonical maps.

/// Pie slice override.
final class SliceStyle extends SpecNode {
  /// Creates a slice style.
  const SliceStyle({this.color, this.offset = 0, this.extras = const {}});

  /// Parses JSON leniently.
  factory SliceStyle.fromJson(Object? json) {
    final r = JsonReader(json);
    return SliceStyle(
      color: r.str('color'),
      offset: r.dblOr('offset', 0).clamp(0.0, 1.0),
      extras: r.extras(const {'color', 'offset'}),
    );
  }

  final String? color;

  /// Distance from the center as a fraction of the radius (0..1).
  final double offset;
  final Map<String, Object?> extras;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter(extras)
            ..opt('color', color)
            ..unlessDefault('offset', jsonNum(offset), 0))
          .json;
}

/// Pie / doughnut options.
final class PieOptions extends SpecNode {
  /// Creates pie options.
  const PieOptions({
    this.pieHole = 0,
    this.sliceLabel = SliceLabel.percentage,
    this.borderColor,
    this.slices = const {},
    this.startAngle = 0,
    this.otherThreshold = 50,
  });

  /// Reads `typeOptions`.
  factory PieOptions.fromJson(Object? json) {
    final r = JsonReader(json);
    final s = r.obj('slices') ?? const {};
    return PieOptions(
      pieHole: r.dblOr('pieHole', 0).clamp(0.0, 0.9),
      sliceLabel: r.enumOr(
        'sliceLabel',
        SliceLabel.values,
        SliceLabel.percentage,
      ),
      borderColor: r.str('borderColor'),
      slices: {
        for (final e in s.entries)
          if (int.tryParse(e.key) case final int i)
            i: SliceStyle.fromJson(e.value),
      },
      startAngle: r.dblOr('startAngle', 0),
      otherThreshold: r.intOr('pieOtherThreshold', 50),
    );
  }

  /// 0 = pie, > 0 = doughnut (0..0.9).
  final double pieHole;
  final SliceLabel sliceLabel;
  final String? borderColor;
  final Map<int, SliceStyle> slices;

  /// Degrees clockwise from 12 o'clock.
  final double startAngle;

  /// Slices beyond this count are grouped into "Other" (08 §12).
  final int otherThreshold;

  @override
  Map<String, Object?> toJson() {
    final keys = slices.keys.toList()..sort();
    return (JsonWriter()
          ..unlessDefault('pieHole', jsonNum(pieHole), 0)
          ..unlessDefault(
            'sliceLabel',
            sliceLabel.name,
            SliceLabel.percentage.name,
          )
          ..opt('borderColor', borderColor)
          ..nested('slices', {for (final k in keys) '$k': slices[k]!.toJson()})
          ..unlessDefault('startAngle', jsonNum(startAngle), 0)
          ..unlessDefault('pieOtherThreshold', otherThreshold, 50))
        .json;
  }
}

/// Histogram options.
final class HistogramOptions extends SpecNode {
  /// Creates histogram options.
  const HistogramOptions({
    this.bucketSize,
    this.outlierPercentile = 0,
    this.showItemDividers = false,
  });

  /// Reads `typeOptions`.
  factory HistogramOptions.fromJson(Object? json) {
    final r = JsonReader(json);
    final b = r.dbl('bucketSize');
    return HistogramOptions(
      bucketSize: b != null && b > 0 ? b : null,
      outlierPercentile: r.dblOr('outlierPercentile', 0).clamp(0.0, 25.0),
      showItemDividers: r.boolOr('showItemDividers', false),
    );
  }

  /// Null = automatic (Freedman–Diaconis, ≤ 100 buckets).
  final double? bucketSize;

  /// Percent (0..25) trimmed into the first/last bucket on each side.
  final double outlierPercentile;
  final bool showItemDividers;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter()
            ..opt(
              'bucketSize',
              bucketSize == null ? null : jsonNum(bucketSize!),
            )
            ..unlessDefault('outlierPercentile', jsonNum(outlierPercentile), 0)
            ..unlessDefault('showItemDividers', showItemDividers, false))
          .json;
}

/// Candlestick options.
final class CandlestickOptions extends SpecNode {
  /// Creates candlestick options.
  const CandlestickOptions({
    this.risingColor,
    this.fallingColor,
    this.risingFilled = false,
    this.fallingFilled = true,
  });

  /// Reads `typeOptions`.
  factory CandlestickOptions.fromJson(Object? json) {
    final r = JsonReader(json);
    return CandlestickOptions(
      risingColor: r.str('risingColor'),
      fallingColor: r.str('fallingColor'),
      risingFilled: r.boolOr('risingFilled', false),
      fallingFilled: r.boolOr('fallingFilled', true),
    );
  }

  final String? risingColor;
  final String? fallingColor;
  final bool risingFilled;
  final bool fallingFilled;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter()
            ..opt('risingColor', risingColor)
            ..opt('fallingColor', fallingColor)
            ..unlessDefault('risingFilled', risingFilled, false)
            ..unlessDefault('fallingFilled', fallingFilled, true))
          .json;
}

/// Waterfall subtotal.
final class WaterfallSubtotal extends SpecNode {
  /// Creates a subtotal after domain index [afterIndex].
  const WaterfallSubtotal({required this.afterIndex, this.label = ''});

  /// Parses JSON leniently (null without an index).
  static WaterfallSubtotal? fromJson(Object? json) {
    final r = JsonReader(json);
    final i = r.integer('afterIndex');
    if (i == null || i < 0) return null;
    return WaterfallSubtotal(afterIndex: i, label: r.strOr('label', ''));
  }

  final int afterIndex;
  final String label;

  @override
  Map<String, Object?> toJson() => {
    'afterIndex': afterIndex,
    if (label.isNotEmpty) 'label': label,
  };
}

/// Waterfall options.
final class WaterfallOptions extends SpecNode {
  /// Creates waterfall options.
  const WaterfallOptions({
    this.connectorShow = true,
    this.connectorColor,
    this.connectorDash = LineDash.solid,
    this.subtotals = const [],
    this.firstValueIsSubtotal = false,
    this.positiveColor,
    this.negativeColor,
    this.subtotalColor,
  });

  /// Reads `typeOptions`.
  factory WaterfallOptions.fromJson(Object? json) {
    final r = JsonReader(json);
    final c = JsonReader(r.obj('connectorLines'));
    final subs = [
      for (final s in r.list('subtotals') ?? const <Object?>[])
        if (WaterfallSubtotal.fromJson(s) case final WaterfallSubtotal w) w,
    ]..sort((a, b) => a.afterIndex.compareTo(b.afterIndex));
    return WaterfallOptions(
      connectorShow: c.boolOr('show', true),
      connectorColor: c.str('color'),
      connectorDash: c.enumOr('dash', LineDash.values, LineDash.solid),
      subtotals: subs,
      firstValueIsSubtotal: r.boolOr('firstValueIsSubtotal', false),
      positiveColor: r.str('positiveColor'),
      negativeColor: r.str('negativeColor'),
      subtotalColor: r.str('subtotalColor'),
    );
  }

  final bool connectorShow;
  final String? connectorColor;
  final LineDash connectorDash;
  final List<WaterfallSubtotal> subtotals;
  final bool firstValueIsSubtotal;
  final String? positiveColor;
  final String? negativeColor;
  final String? subtotalColor;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter()
            ..nested(
              'connectorLines',
              (JsonWriter()
                    ..unlessDefault('show', connectorShow, true)
                    ..opt('color', connectorColor)
                    ..unlessDefault(
                      'dash',
                      connectorDash.name,
                      LineDash.solid.name,
                    ))
                  .json,
            )
            ..opt(
              'subtotals',
              subtotals.isEmpty
                  ? null
                  : [for (final s in subtotals) s.toJson()],
            )
            ..unlessDefault('firstValueIsSubtotal', firstValueIsSubtotal, false)
            ..opt('positiveColor', positiveColor)
            ..opt('negativeColor', negativeColor)
            ..opt('subtotalColor', subtotalColor))
          .json;
}

/// Scorecard options. [keyValueRef] / [baselineRef] are GridRange JSON (a single cell or a
/// range aggregated with [aggregate]); null key = the first series of the data ranges.
final class ScorecardOptions extends SpecNode {
  /// Creates scorecard options.
  const ScorecardOptions({
    this.keyValueRef,
    this.baselineRef,
    this.aggregate = ChartAggregate.sum,
    this.compareMode = ScorecardCompareMode.absolute,
    this.keyFormat,
    this.baselineFormat,
    this.positiveColor,
    this.negativeColor,
    this.showSparkline = false,
  });

  /// Reads `typeOptions`.
  factory ScorecardOptions.fromJson(Object? json) {
    final r = JsonReader(json);
    return ScorecardOptions(
      keyValueRef: GridRange.tryParse(r.map['keyValueRef']),
      baselineRef: GridRange.tryParse(r.map['baselineRef']),
      aggregate: r.enumOr(
        'aggregate',
        ChartAggregate.values,
        ChartAggregate.sum,
      ),
      compareMode: r.enumOr(
        'compareMode',
        ScorecardCompareMode.values,
        ScorecardCompareMode.absolute,
      ),
      keyFormat: r.str('keyFormat'),
      baselineFormat: r.str('baselineFormat'),
      positiveColor: r.str('positiveColor'),
      negativeColor: r.str('negativeColor'),
      showSparkline: r.boolOr('showSparkline', false),
    );
  }

  final GridRange? keyValueRef;
  final GridRange? baselineRef;
  final ChartAggregate aggregate;
  final ScorecardCompareMode compareMode;
  final String? keyFormat;
  final String? baselineFormat;
  final String? positiveColor;
  final String? negativeColor;

  /// P2.
  final bool showSparkline;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter()
            ..opt('keyValueRef', keyValueRef?.toJson())
            ..opt('baselineRef', baselineRef?.toJson())
            ..unlessDefault(
              'aggregate',
              aggregate.name,
              ChartAggregate.sum.name,
            )
            ..unlessDefault(
              'compareMode',
              compareMode.name,
              ScorecardCompareMode.absolute.name,
            )
            ..opt('keyFormat', keyFormat)
            ..opt('baselineFormat', baselineFormat)
            ..opt('positiveColor', positiveColor)
            ..opt('negativeColor', negativeColor)
            ..unlessDefault('showSparkline', showSparkline, false))
          .json;
}

/// Table chart options.
final class TableOptions extends SpecNode {
  /// Creates table options.
  const TableOptions({
    this.pageSize = 0,
    this.sortColumn,
    this.sortAscending = true,
    this.showRowNumbers = false,
    this.alternatingColors = true,
    this.formatFromSource = true,
  });

  /// Reads `typeOptions`.
  factory TableOptions.fromJson(Object? json) {
    final r = JsonReader(json);
    final ps = r.intOr('pageSize', 0);
    return TableOptions(
      pageSize: ps < 0 ? 0 : ps,
      sortColumn: r.integer('sortColumn'),
      sortAscending: r.boolOr('sortAscending', true),
      showRowNumbers: r.boolOr('showRowNumbers', false),
      alternatingColors: r.boolOr('alternatingColors', true),
      formatFromSource: r.boolOr('formatFromSource', true),
    );
  }

  /// Rows per page; 0 = no paging.
  final int pageSize;

  /// Logical column index to sort by (null = source order).
  final int? sortColumn;
  final bool sortAscending;
  final bool showRowNumbers;
  final bool alternatingColors;
  final bool formatFromSource;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter()
            ..unlessDefault('pageSize', pageSize, 0)
            ..opt('sortColumn', sortColumn)
            ..unlessDefault('sortAscending', sortAscending, true)
            ..unlessDefault('showRowNumbers', showRowNumbers, false)
            ..unlessDefault('alternatingColors', alternatingColors, true)
            ..unlessDefault('formatFromSource', formatFromSource, true))
          .json;
}

/// Radar options.
final class RadarOptions extends SpecNode {
  /// Creates radar options.
  const RadarOptions({
    this.fillOpacity = 0.2,
    this.gridShape = RadarGridShape.polygon,
  });

  /// Reads `typeOptions`.
  factory RadarOptions.fromJson(Object? json) {
    final r = JsonReader(json);
    return RadarOptions(
      fillOpacity: r.dblOr('fillOpacity', 0.2).clamp(0.0, 1.0),
      gridShape: r.enumOr(
        'gridShape',
        RadarGridShape.values,
        RadarGridShape.polygon,
      ),
    );
  }

  final double fillOpacity;
  final RadarGridShape gridShape;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter()
            ..unlessDefault('fillOpacity', jsonNum(fillOpacity), jsonNum(0.2))
            ..unlessDefault(
              'gridShape',
              gridShape.name,
              RadarGridShape.polygon.name,
            ))
          .json;
}

/// Bubble options.
final class BubbleOptions extends SpecNode {
  /// Creates bubble options.
  const BubbleOptions({
    this.minSize = 6,
    this.maxSize = 36,
    this.colorBy = BubbleColorBy.series,
  });

  /// Reads `typeOptions`.
  factory BubbleOptions.fromJson(Object? json) {
    final r = JsonReader(json);
    final range = r.list('sizeRange');
    var lo = 6.0, hi = 36.0;
    if (range != null &&
        range.length == 2 &&
        range[0] is num &&
        range[1] is num) {
      lo = (range[0] as num).toDouble().clamp(1.0, 200.0);
      hi = (range[1] as num).toDouble().clamp(lo, 400.0);
    }
    return BubbleOptions(
      minSize: lo,
      maxSize: hi,
      colorBy: r.enumOr('colorBy', BubbleColorBy.values, BubbleColorBy.series),
    );
  }

  /// Bubble diameter range in px.
  final double minSize;
  final double maxSize;
  final BubbleColorBy colorBy;

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter()
            ..opt(
              'sizeRange',
              minSize == 6 && maxSize == 36
                  ? null
                  : [jsonNum(minSize), jsonNum(maxSize)],
            )
            ..unlessDefault('colorBy', colorBy.name, BubbleColorBy.series.name))
          .json;
}
