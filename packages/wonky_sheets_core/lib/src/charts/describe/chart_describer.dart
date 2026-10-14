import '../data/chart_data.dart';
import '../spec/chart_spec.dart';
import '../spec/chart_type.dart';

/// Automatic accessible description of a chart (08 §14), used as the object's semantics label
/// when its `altText` is empty.
abstract final class ChartDescriber {
  /// `<Type> chart: <title>. <n> series: <names>. X axis: <domain name>, <first> to <last>.`
  ///
  /// Pie charts list only the series they draw (the first); table charts give their size
  /// instead of series; the X axis part is left out when there is no domain column (or for
  /// histograms and scorecards), and the domain name when its header is empty.
  static String describe(ChartSpec spec, ChartData data) {
    final type = spec.type == ChartType.pie && spec.pieOptions.pieHole > 0
        ? 'Doughnut'
        : spec.type.displayName;
    final b = StringBuffer('$type chart');
    final title = spec.title.text.trim();
    b.write(title.isEmpty ? '.' : ': $title.');
    if (spec.type == ChartType.table) {
      final t = data.table;
      if (t != null) b.write(' ${t.rowCount} rows, ${t.columnCount} columns.');
      return b.toString();
    }
    final drawn = spec.type == ChartType.pie
        ? data.series.take(1)
        : data.series;
    final names = [for (final s in drawn) s.name];
    if (names.isNotEmpty) {
      b.write(' ${names.length} series: ${names.join(', ')}.');
    }
    final d = data.domain;
    if (!d.isSynthetic &&
        d.length > 0 &&
        spec.type != ChartType.histogram &&
        spec.type != ChartType.scorecard) {
      final name = d.name.trim();
      final labels = d.labels.where((l) => l.trim().isNotEmpty).toList();
      final range = labels.isEmpty ? '' : '${labels.first} to ${labels.last}';
      final parts = [if (name.isNotEmpty) name, if (range.isNotEmpty) range];
      if (parts.isNotEmpty) b.write(' X axis: ${parts.join(', ')}.');
    }
    return b.toString();
  }
}
