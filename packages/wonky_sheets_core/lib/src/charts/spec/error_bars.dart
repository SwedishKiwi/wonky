import 'dart:math' as math;

/// How the size of an error bar is computed (08 §8.2 *Series › Error
/// bars*, Google Sheets: constant, percent, standard deviation).
enum ErrorBarType { constant, percent, stdev }

/// Error bars of a series (`series.<key>.errorBars` in the spec, kept as
/// JSON by `SeriesStyle.errorBars`):
/// `{"type": "constant"|"percent"|"stdev", "value": 10, "color": "#RRGGBB"}`.
final class ErrorBarsSpec {
  /// Creates error bars.
  const ErrorBarsSpec({
    this.type = ErrorBarType.constant,
    this.value = 10,
    this.color,
  });

  /// Parses `errorBars` JSON; null when absent or disabled
  /// (`{"show": false}`).
  static ErrorBarsSpec? fromJson(Map<String, Object?>? json) {
    if (json == null || json['show'] == false) return null;
    final t = ErrorBarType.values.asNameMap()[json['type']];
    final v = json['value'];
    final c = json['color'];
    return ErrorBarsSpec(
      type: t ?? ErrorBarType.constant,
      value: v is num && v.isFinite && v >= 0
          ? v.toDouble()
          : (t == ErrorBarType.stdev ? 1 : 10),
      color: c is String ? c : null,
    );
  }

  final ErrorBarType type;

  /// Constant: value units; percent: % of each value; stdev: multiples of
  /// the series' standard deviation.
  final double value;

  /// `#RRGGBB`; null = the series color darkened.
  final String? color;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'value': value,
    'color': ?color,
  };

  /// The ± extent of each of [values] (NaN where the value is NaN).
  List<double> extents(List<double> values) {
    double? sd;
    if (type == ErrorBarType.stdev) {
      final finite = [
        for (final v in values)
          if (v.isFinite) v,
      ];
      if (finite.length < 2) {
        sd = 0;
      } else {
        final mean = finite.reduce((a, b) => a + b) / finite.length;
        var ss = 0.0;
        for (final v in finite) {
          ss += (v - mean) * (v - mean);
        }
        sd = math.sqrt(ss / (finite.length - 1));
      }
    }
    return [
      for (final v in values)
        if (!v.isFinite)
          double.nan
        else
          switch (type) {
            ErrorBarType.constant => value,
            ErrorBarType.percent => v.abs() * value / 100,
            ErrorBarType.stdev => sd! * value,
          },
    ];
  }
}
