import 'dart:typed_data';

import 'package:wonky_charts/wonky_charts.dart';

/// Months × two regions, resolved data as Sheets or a snapshot would hand it to the engine.
ChartData sampleData() => ChartData(
  domain: ChartDomain(
    kind: DomainKind.categorical,
    values: Float64List.fromList([double.nan, double.nan, double.nan]),
    labels: const ['Jan', 'Feb', 'Mar'],
    name: 'Month',
  ),
  series: [
    ChartSeries(
      key: 'north',
      name: 'North',
      values: Float64List.fromList([10, 13, 16]),
    ),
    ChartSeries(
      key: 'south',
      name: 'South',
      values: Float64List.fromList([30, 28.5, 26]),
      numberFormat: '#,##0.0',
    ),
  ],
);

/// The light export theme of a plain document theme.
final sampleTheme = ChartTheme.from(
  const ChartThemeColors(
    accentArgbs: [
      0xFF4285F4,
      0xFFEA4335,
      0xFFFBBC04,
      0xFF34A853,
      0xFFFF6D01,
      0xFF46BDC6,
    ],
  ),
  export: true,
);
