/// Payloads of renderable formula values (`FRich.payload`, 05 §6.1), painted by the grid
/// (03 §14.4 hyperlinks) and the in-cell renderers of 08 (sparklines §2, images §10.2).
library;

/// `SPARKLINE(data, options)` result (05 §17).
final class SparklineValue {
  /// `line`, `column`, `winloss` or `bar`.
  final String chartType;

  /// Data points (NaN = empty/ignored point, per the `empty`/`nan` options already applied).
  final List<double> values;

  /// Normalized options (lower-case keys); colors as given (`#RRGGBB` or CSS names).
  final Map<String, Object> options;

  const SparklineValue(this.chartType, this.values, this.options);

  @override
  bool operator ==(Object other) =>
      other is SparklineValue &&
      other.chartType == chartType &&
      _listEq(other.values, values) &&
      _mapEq(other.options, options);

  @override
  int get hashCode => Object.hash(chartType, values.length, options.length);

  @override
  String toString() => 'SparklineValue($chartType, ${values.length} points, $options)';
}

/// `IMAGE(url, mode, height, width, alt_text)` result (08 §10.2).
final class ImageValue {
  final String url;

  /// 1 fit (default), 2 stretch, 3 original size, 4 custom size.
  final int mode;
  final double? height;
  final double? width;
  final String? altText;

  const ImageValue(this.url, {this.mode = 1, this.height, this.width, this.altText});

  /// Whether the URL refers to a Wonky Drive file (`wonky-file://<uuid>`).
  bool get isWonkyFile => url.startsWith('wonky-file://');

  @override
  bool operator ==(Object other) =>
      other is ImageValue &&
      other.url == url &&
      other.mode == mode &&
      other.height == height &&
      other.width == width &&
      other.altText == altText;

  @override
  int get hashCode => Object.hash(url, mode, height, width, altText);

  @override
  String toString() => 'ImageValue($url, mode $mode)';
}

/// `HYPERLINK(url, label)` result (03 §14.4).
final class LinkValue {
  final String url;
  final String label;
  const LinkValue(this.url, this.label);

  /// Internal sheet link (`#gid=…`).
  bool get isInternal => url.startsWith('#');

  @override
  bool operator ==(Object other) => other is LinkValue && other.url == url && other.label == label;

  @override
  int get hashCode => Object.hash(url, label);

  @override
  String toString() => 'LinkValue($url, $label)';
}

bool _listEq(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i] && !(a[i].isNaN && b[i].isNaN)) return false;
  }
  return true;
}

bool _mapEq(Map<String, Object> a, Map<String, Object> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
