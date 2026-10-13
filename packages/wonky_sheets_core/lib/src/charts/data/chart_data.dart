import 'dart:typed_data';

/// Kind of the domain (X) values (08 §4.1 step 5).
enum DomainKind { categorical, numeric, dateTime }

/// The domain column of a chart.
final class ChartDomain {
  /// Creates a domain.
  ChartDomain({
    required this.kind,
    required this.values,
    required this.labels,
    this.name = '',
    this.key,
    this.numberFormat,
    this.isSynthetic = false,
  }) : assert(values.length == labels.length, 'values and labels must align');

  /// A synthetic 1..n domain (no X column).
  factory ChartDomain.synthetic(int n) => ChartDomain(
    kind: DomainKind.categorical,
    values: Float64List.fromList([for (var i = 1; i <= n; i++) i.toDouble()]),
    labels: [for (var i = 1; i <= n; i++) '$i'],
    isSynthetic: true,
  );

  final DomainKind kind;

  /// Numeric value per point (date serials for [DomainKind.dateTime]); NaN when not a number.
  final Float64List values;

  /// Formatted text per point (the cells' formatted text).
  final List<String> labels;

  /// Header text.
  final String name;

  /// Source column id (row id when switched).
  final String? key;

  /// Number format of the first numeric cell.
  final String? numberFormat;

  /// Whether there is no X column (labels are 1..n).
  final bool isSynthetic;

  /// Number of points.
  int get length => labels.length;

  /// Whether the domain is continuous-capable (numbers or dates).
  bool get isContinuous => kind != DomainKind.categorical;
}

/// One data series (08 §4).
final class ChartSeries {
  /// Creates a series.
  ChartSeries({
    required this.key,
    required this.name,
    required this.values,
    this.numberFormat,
    this.isPercent = false,
    this.texts,
  });

  /// Stable series key (08 §3.2).
  final String key;

  /// Header text (or a generated name).
  final String name;

  /// Value per point; NaN = empty.
  final Float64List values;

  /// Number format of the first numeric cell (labels keep percent formats).
  final String? numberFormat;

  /// Whether the source is percent-formatted.
  final bool isPercent;

  /// Formatted cell texts per point (table and bubble charts only).
  final List<String>? texts;

  /// Number of points.
  int get length => values.length;

  /// Copy with other values (aggregation, reordering).
  ChartSeries withValues(Float64List values, {List<String>? texts}) =>
      ChartSeries(
        key: key,
        name: name,
        values: values,
        numberFormat: numberFormat,
        isPercent: isPercent,
        texts:
            texts ??
            (this.texts == null || this.texts!.length != values.length
                ? null
                : this.texts),
      );
}

/// Machine-readable warning codes shown in the chart editor.
enum ChartWarningCode {
  noData,
  rangeNotFound,
  rangeSizeMismatch,
  errorValuesIgnored,
  logNonPositiveSkipped,
  tooManyCategories,
  missingSeries,
  pieOtherGrouped,
  pieNegativeIgnored,
  trendlineInvalidPoints,
  downsampled,
  tooManyCells,
}

/// A data or layout warning (08 §4).
final class ChartWarning {
  /// Creates a warning.
  const ChartWarning(this.code, this.message, {this.count = 0, this.seriesKey});

  final ChartWarningCode code;

  /// English message (the app localizes by [code]).
  final String message;
  final int count;
  final String? seriesKey;

  @override
  bool operator ==(Object other) =>
      other is ChartWarning &&
      other.code == code &&
      other.count == count &&
      other.seriesKey == seriesKey;

  @override
  int get hashCode => Object.hash(code, count, seriesKey);

  @override
  String toString() => 'ChartWarning(${code.name}: $message)';
}

/// Histogram buckets (08 §3.7, 08 §4).
final class HistogramData {
  /// Creates bucket data.
  HistogramData({
    required this.start,
    required this.bucketSize,
    required this.counts,
    required this.seriesKeys,
    this.items,
  });

  /// Lower edge of the first bucket.
  final double start;
  final double bucketSize;

  /// Counts per series (outer) per bucket (inner).
  final List<Int32List> counts;
  final List<String> seriesKeys;

  /// Per series, per bucket the item values in that bucket (for item dividers), or null.
  final List<List<List<double>>>? items;

  /// Number of buckets.
  int get bucketCount => counts.isEmpty ? 0 : counts.first.length;

  /// Lower edge of bucket [i].
  double edge(int i) => start + i * bucketSize;
}

/// Key value and baseline of a scorecard.
final class ScorecardData {
  /// Creates scorecard data.
  const ScorecardData({
    required this.keyValue,
    this.baseline,
    this.keyFormat,
    this.baselineFormat,
    this.label = '',
  });

  /// NaN when there is no numeric key value.
  final double keyValue;
  final double? baseline;
  final String? keyFormat;
  final String? baselineFormat;

  /// Description (header of the key column).
  final String label;
}

/// Columns of a table chart.
final class ChartTableData {
  /// Creates table data.
  ChartTableData({
    required this.headers,
    required this.texts,
    required this.values,
  });

  /// Header per column.
  final List<String> headers;

  /// Formatted text per column per row.
  final List<List<String>> texts;

  /// Numeric value per column per row (NaN for non-numbers), used for sorting/alignment.
  final List<Float64List> values;

  /// Number of rows.
  int get rowCount => texts.isEmpty ? 0 : texts.first.length;

  /// Number of columns.
  int get columnCount => headers.length;
}

/// Resolved chart data (08 §4), immutable.
final class ChartData {
  /// Creates chart data.
  ChartData({
    required this.domain,
    required this.series,
    this.warnings = const [],
    this.sourceCellCount = 0,
    this.dataVersion = 0,
    this.missingSeriesKeys = const [],
    this.histogram,
    this.scorecard,
    this.table,
  });

  /// Empty data ("No data").
  factory ChartData.empty({List<ChartWarning> warnings = const []}) =>
      ChartData(
        domain: ChartDomain.synthetic(0),
        series: const [],
        warnings: warnings,
      );

  final ChartDomain domain;
  final List<ChartSeries> series;
  final List<ChartWarning> warnings;
  final int sourceCellCount;

  /// Hash of all source values (cache invalidation).
  final int dataVersion;

  /// Series refs whose column no longer resolves (08 §15.2).
  final List<String> missingSeriesKeys;
  final HistogramData? histogram;
  final ScorecardData? scorecard;
  final ChartTableData? table;

  /// Number of points.
  int get pointCount => domain.length;

  /// Whether nothing can be drawn.
  bool get isEmpty {
    if (table != null) return table!.rowCount == 0 && table!.columnCount == 0;
    if (scorecard != null) return false;
    if (histogram != null) return histogram!.bucketCount == 0;
    if (series.isEmpty || domain.length == 0) return true;
    for (final s in series) {
      for (final v in s.values) {
        if (!v.isNaN) return false;
      }
    }
    return true;
  }

  /// Series by key.
  ChartSeries? seriesByKey(String key) {
    for (final s in series) {
      if (s.key == key) return s;
    }
    return null;
  }
}
