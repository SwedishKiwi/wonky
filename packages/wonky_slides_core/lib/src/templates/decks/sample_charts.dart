/// Sample chart snapshots of the built-in templates (Slides 08 §3.1
/// `static`): small, made-up data sets in the snapshot format a linked
/// chart stores, so a template's chart looks and animates like a linked one
/// until the user relinks it to a spreadsheet chart (*Relink…*).
library;

import 'dart:typed_data';

import 'package:wonky_charts/wonky_charts.dart';

/// A sample snapshot: [categories] on the domain, one series per entry of
/// [series] (`(key, name, values)`), chart [type], optional [threeD]
/// options (`{"enabled": true, …}`) and legend [legend] position. [title]
/// names the chart in its source info (the slide title shows on the
/// slide, so the chart draws none).
ChartSourceSnapshot sampleChart({
  required String title,
  required String type,
  required List<String> categories,
  required List<(String key, String name, List<double> values)> series,
  String domainName = '',
  Map<String, Object?>? threeD,
  String legend = 'bottom',
}) => ChartSourceSnapshot(
  spec: ChartSpec.fromJson({
    'v': 1,
    'type': type,
    'legend': {'position': series.length > 1 ? legend : 'none'},
    'threeD': ?threeD,
  }),
  dataSnapshot: ChartDataSnapshot(
    data: ChartData(
      domain: ChartDomain(
        kind: DomainKind.categorical,
        values: Float64List.fromList([for (final _ in categories) double.nan]),
        labels: categories,
        name: domainName,
      ),
      series: [
        for (final (key, name, values) in series)
          ChartSeries(
            key: key,
            name: name,
            values: Float64List.fromList(values),
          ),
      ],
    ),
    source: ChartSourceInfo(spreadsheetTitle: 'Sample data', chartTitle: title),
    version: 'template',
  ),
);
