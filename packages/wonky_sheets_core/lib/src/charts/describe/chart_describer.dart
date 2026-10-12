import '../data/chart_data.dart';
import '../spec/chart_spec.dart';
import '../spec/chart_type.dart';

/// Automatic accessible description of a chart (08 §14).
abstract final class ChartDescriber {
  /// `<Type> chart: <title>. <n> series: <names>. X axis: <domain name>, <first> to <last>.`
  static String describe(ChartSpec spec, ChartData data) {
    final type = spec.type == ChartType.pie && spec.pieOptions.pieHole > 0
        ? 'Doughnut'
        : spec.type.displayName;
    final b = StringBuffer('$type chart');
    final title = spec.title.text.trim();
    b.write(title.isEmpty ? '.' : ': $title.');
    final names = [for (final s in data.series) s.name];
    if (spec.type == ChartType.table) {
      final t = data.table;
      if (t != null) b.write(' ${t.rowCount} rows, ${t.columnCount} columns.');
      return b.toString();
    }
    if (names.isNotEmpty) {
      b.write(' ${names.length} series: ${names.join(', ')}.');
    }
    final d = data.domain;
    if (!d.isSynthetic && d.length > 0 && spec.type != ChartType.histogram && spec.type != ChartType.scorecard) {
      final name = d.name.trim().isEmpty ? 'X axis' : d.name.trim();
      final labels = d.labels.where((l) => l.isNotEmpty).toList();
      if (labels.isNotEmpty) {
        b.write(' X axis: $name, ${labels.first} to ${labels.last}.');
      } else {
        b.write(' X axis: $name.');
      }
    }
    return b.toString();
  }
}
