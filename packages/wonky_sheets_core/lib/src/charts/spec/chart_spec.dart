import 'dart:convert';

import 'chart_data_spec.dart';
import 'chart_spec_parts.dart';
import 'chart_type.dart';
import 'series_style.dart';
import 'spec_json.dart';
import 'spec_schema.dart';
import 'type_options.dart';

/// RFC 7386 JSON merge patch of [target] with [patch] (returns a new value).
Object? jsonMergePatch(Object? target, Object? patch) {
  if (patch is! Map) return deepCopyJson(patch);
  final out = target is Map
      ? {for (final e in target.entries) '${e.key}': deepCopyJson(e.value)}
      : <String, Object?>{};
  for (final e in patch.entries) {
    final k = '${e.key}';
    if (e.value == null) {
      out.remove(k);
    } else {
      out[k] = jsonMergePatch(out[k], e.value);
    }
  }
  return out;
}

/// An in-memory upgrade of a spec JSON from version `v` to `v + 1`.
typedef ChartSpecUpgrade =
    Map<String, Object?> Function(Map<String, Object?> json);

/// `ChartSpec` v1 (08 §3): the `specJson` of chart objects.
///
/// JSON round-trip keeps unknown keys at every level (`extras`). `toJson` is canonical: values
/// equal to their defaults are omitted, so merge-patching a key to `null` resets it.
final class ChartSpec extends SpecNode {
  /// Creates a spec.
  const ChartSpec({
    this.type = ChartType.column,
    this.stacking = ChartStacking.none,
    this.data = const ChartDataSpec(),
    this.style = const ChartStyle(),
    this.title = ChartTitle.none,
    this.subtitle = ChartTitle.none,
    this.axes = const ChartAxes(),
    this.legend = const ChartLegend(),
    this.gridlines = const ChartGridlines(),
    this.series = const {},
    this.typeOptions = const {},
    this.extras = const {},
  }) : _rawType = null,
       _newer = null;

  const ChartSpec._raw({
    required this.type,
    required this.stacking,
    required this.data,
    required this.style,
    required this.title,
    required this.subtitle,
    required this.axes,
    required this.legend,
    required this.gridlines,
    required this.series,
    required this.typeOptions,
    required this.extras,
    this._rawType,
    this._newer,
  });

  /// Schema version written by this code.
  static const int currentVersion = 1;

  /// Upgrades from version key `v` to `v + 1` (none yet: v1 is the first version). Specs
  /// without `v` are treated as v1.
  static final Map<int, ChartSpecUpgrade> upgrades = {};

  /// Parses a spec (map or JSON string) leniently. Newer versions are kept verbatim
  /// ([isFromNewerVersion]) and written back unchanged.
  factory ChartSpec.fromJson(Object? jsonOrString) {
    var m = _decode(jsonOrString);
    var v = JsonReader(m).integer('v') ?? 1;
    if (v > currentVersion) return _newerSpec(m, v);
    while (v < currentVersion) {
      final up = upgrades[v];
      if (up != null) m = up(m);
      v++;
    }
    final r = JsonReader(m);
    final typeId = r.str('type');
    final type = ChartType.tryParse(typeId);
    final seriesJson = r.obj('series') ?? const {};
    return ChartSpec._raw(
      type: type ?? ChartType.column,
      rawType: type == null ? typeId : null,
      stacking: r.enumOr('stacking', ChartStacking.values, ChartStacking.none),
      data: ChartDataSpec.fromJson(r.obj('data')),
      style: ChartStyle.fromJson(r.obj('style')),
      title: ChartTitle.fromJson(r.obj('title')),
      subtitle: ChartTitle.fromJson(r.obj('subtitle')),
      axes: ChartAxes.fromJson(r.obj('axes')),
      legend: ChartLegend.fromJson(r.obj('legend')),
      gridlines: ChartGridlines.fromJson(r.obj('gridlines')),
      series: {
        for (final e in seriesJson.entries)
          e.key: SeriesStyle.fromJson(e.value),
      },
      typeOptions: (deepCopyJson(r.obj('typeOptions') ?? const {})! as Map)
          .cast(),
      extras: r.extras(_keys),
    );
  }

  /// Parses and validates strictly; throws [ChartSpecValidationException].
  factory ChartSpec.parseStrict(Object? jsonOrString) {
    final m = _decode(jsonOrString);
    final issues = ChartSpecSchema.validate(m);
    if (issues.isNotEmpty) throw ChartSpecValidationException(issues);
    return ChartSpec.fromJson(m);
  }

  static ChartSpec _newerSpec(Map<String, Object?> m, int v) {
    final r = JsonReader(m);
    return ChartSpec._raw(
      type: ChartType.tryParse(r.str('type')) ?? ChartType.column,
      stacking: ChartStacking.none,
      data: ChartDataSpec.fromJson(r.obj('data')),
      style: const ChartStyle(),
      title: ChartTitle.fromJson(r.obj('title')),
      subtitle: ChartTitle.none,
      axes: const ChartAxes(),
      legend: const ChartLegend(),
      gridlines: const ChartGridlines(),
      series: const {},
      typeOptions: const {},
      extras: const {},
      newer: (deepCopyJson(m)! as Map).cast(),
    );
  }

  static Map<String, Object?> _decode(Object? jsonOrString) {
    Object? m = jsonOrString;
    if (m is String) {
      if (m.trim().isEmpty) return const {};
      try {
        m = jsonDecode(m);
      } on FormatException {
        return const {};
      }
    }
    if (m is! Map) return const {};
    return m.map((k, v) => MapEntry('$k', v));
  }

  static const _keys = {
    'v',
    'type',
    'stacking',
    'data',
    'style',
    'title',
    'subtitle',
    'axes',
    'legend',
    'gridlines',
    'series',
    'typeOptions',
  };

  final ChartType type;
  final ChartStacking stacking;
  final ChartDataSpec data;
  final ChartStyle style;
  final ChartTitle title;
  final ChartTitle subtitle;
  final ChartAxes axes;
  final ChartLegend legend;
  final ChartGridlines gridlines;

  /// Per-series style overrides keyed by series key.
  final Map<String, SeriesStyle> series;

  /// Type-specific options (raw; see the typed getters).
  final Map<String, Object?> typeOptions;

  /// Unknown top-level keys.
  final Map<String, Object?> extras;

  final String? _rawType;
  final Map<String, Object?>? _newer;

  /// Whether the JSON was written by a newer app version (08 §1.3): render a placeholder,
  /// editing disabled, written back unchanged.
  bool get isFromNewerVersion => _newer != null;

  /// The type id as stored (may be an id unknown to this version).
  String get typeId => _rawType ?? type.id;

  /// Whether the stored type id is known.
  bool get hasKnownType => _rawType == null;

  /// Style of [key] (defaults when not overridden).
  SeriesStyle seriesStyle(String key) => series[key] ?? SeriesStyle.standard;

  /// Pie options.
  PieOptions get pieOptions => PieOptions.fromJson(typeOptions);

  /// Histogram options.
  HistogramOptions get histogramOptions =>
      HistogramOptions.fromJson(typeOptions);

  /// Candlestick options.
  CandlestickOptions get candlestickOptions =>
      CandlestickOptions.fromJson(typeOptions);

  /// Waterfall options.
  WaterfallOptions get waterfallOptions =>
      WaterfallOptions.fromJson(typeOptions);

  /// Scorecard options.
  ScorecardOptions get scorecardOptions =>
      ScorecardOptions.fromJson(typeOptions);

  /// Table options.
  TableOptions get tableOptions => TableOptions.fromJson(typeOptions);

  /// Radar options.
  RadarOptions get radarOptions => RadarOptions.fromJson(typeOptions);

  /// Bubble options.
  BubbleOptions get bubbleOptions => BubbleOptions.fromJson(typeOptions);

  @override
  Map<String, Object?> toJson() {
    final newer = _newer;
    if (newer != null) return (deepCopyJson(newer)! as Map).cast();
    final keys = series.keys.toList()..sort();
    return (JsonWriter(extras)
          ..put('v', currentVersion)
          ..put('type', typeId)
          ..unlessDefault('stacking', stacking.name, ChartStacking.none.name)
          ..put('data', data.toJson())
          ..nested('style', style.toJson())
          ..nested('title', title.toJson())
          ..nested('subtitle', subtitle.toJson())
          ..nested('axes', axes.toJson())
          ..nested('legend', legend.toJson())
          ..nested('gridlines', gridlines.toJson())
          ..nested('series', {
            for (final k in keys)
              if (series[k]!.toJson().isNotEmpty) k: series[k]!.toJson(),
          })
          ..nested('typeOptions', (deepCopyJson(typeOptions)! as Map).cast()))
        .json;
  }

  /// `specJson` string.
  String encode() => jsonEncode(toJson());

  /// Applies an RFC 7386 merge patch (08 §16 `sheets.chart.update`) and validates the result.
  /// Throws [ChartSpecValidationException] when invalid and [StateError] for specs written by a
  /// newer version.
  ChartSpec patch(Map<String, Object?> patch) {
    if (isFromNewerVersion) {
      throw StateError('Chart created with a newer version of Wonky Sheets');
    }
    final merged = (jsonMergePatch(toJson(), patch)! as Map)
        .cast<String, Object?>();
    merged['v'] = currentVersion;
    final issues = ChartSpecSchema.validate(merged);
    if (issues.isNotEmpty) throw ChartSpecValidationException(issues);
    return ChartSpec.fromJson(merged);
  }

  /// Validation issues of this spec's JSON.
  List<ChartSpecIssue> validate() => ChartSpecSchema.validate(toJson());

  /// Changes the type (08 §8.1): data and compatible style are kept; the current `typeOptions`
  /// are parked in `extras.typeOptionsByType[<old type>]` and the new type's parked options are
  /// restored, so switching back restores them.
  ChartSpec withType(ChartType newType, {ChartStacking? stacking}) {
    if (newType == type && stacking == null) return this;
    final parked = extras['typeOptionsByType'] is Map
        ? (deepCopyJson(extras['typeOptionsByType'])! as Map)
              .cast<String, Object?>()
        : <String, Object?>{};
    var restored = typeOptions;
    if (newType != type) {
      if (typeOptions.isNotEmpty) {
        parked[typeId] = deepCopyJson(typeOptions);
      } else {
        parked.remove(typeId);
      }
      final r = parked.remove(newType.id);
      restored = r is Map
          ? r.cast<String, Object?>()
          : const <String, Object?>{};
    }
    final newExtras = {...extras}..remove('typeOptionsByType');
    if (parked.isNotEmpty) newExtras['typeOptionsByType'] = parked;
    return ChartSpec._raw(
      type: newType,
      stacking: newType.supportsStacking
          ? (stacking ?? this.stacking)
          : ChartStacking.none,
      data: data,
      style: style,
      title: title,
      subtitle: subtitle,
      axes: axes,
      legend: legend,
      gridlines: gridlines,
      series: series,
      typeOptions: restored,
      extras: newExtras,
    );
  }

  /// Copy with changes.
  ChartSpec copyWith({
    ChartType? type,
    ChartStacking? stacking,
    ChartDataSpec? data,
    ChartStyle? style,
    ChartTitle? title,
    ChartTitle? subtitle,
    ChartAxes? axes,
    ChartLegend? legend,
    ChartGridlines? gridlines,
    Map<String, SeriesStyle>? series,
    Map<String, Object?>? typeOptions,
    Map<String, Object?>? extras,
  }) => ChartSpec._raw(
    type: type ?? this.type,
    rawType: type == null ? _rawType : null,
    stacking: stacking ?? this.stacking,
    data: data ?? this.data,
    style: style ?? this.style,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    axes: axes ?? this.axes,
    legend: legend ?? this.legend,
    gridlines: gridlines ?? this.gridlines,
    series: series ?? this.series,
    typeOptions: typeOptions ?? this.typeOptions,
    extras: extras ?? this.extras,
    newer: _newer,
  );

  /// Copy with the style of series [key] replaced.
  ChartSpec withSeriesStyle(String key, SeriesStyle style) =>
      copyWith(series: {...series, key: style});
}
