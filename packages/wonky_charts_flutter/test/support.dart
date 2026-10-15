import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_charts/wonky_charts.dart';

ChartData twoSeries() => ChartData(
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
      values: Float64List.fromList([30, double.nan, 26]),
    ),
  ],
);

ChartTheme exportTheme() => ChartTheme.from(
  const ChartThemeColors(accentArgbs: [0xFF4285F4, 0xFFEA4335]),
  export: true,
);

/// Pumps [child] in a shad app of [size].
Future<void> pumpShad(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 600),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ShadApp(
      theme: ShadThemeData(
        brightness: brightness,
        colorScheme: brightness == Brightness.dark
            ? const ShadSlateColorScheme.dark()
            : const ShadSlateColorScheme.light(),
      ),
      home: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
  await tester.pumpAndSettle();
}
