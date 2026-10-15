# wonky_charts_flutter

Flutter rendering of the pure-Dart chart engine `wonky_charts`, shared by Wonky Sheets and
Wonky Slides (specs/wonky_slides/08-charts-from-sheets.md §2, Sheets 08 §24).

| Import | Contents |
|--------|----------|
| `package:wonky_charts_flutter/wonky_charts_flutter.dart` | `ChartScenePainter` (scene `Picture` cache), `paintChartScene`, `chartSceneToPng`, `FlutterTextMeasurer`, `chartTextStyle`, `Chart3DGpuRenderer` / `Chart3DBackends`, `ChartOrbitGesture`, `ChartPointerClaims`, `Chart3DGlyphPainter`, `ChartTypeIcon`; the shared widgets of Sheets and Slides: `ChartView` (hover tooltips, legend highlight), `ChartTooltip` / `chartTooltipLines`, the data table dialog (`showChartDataTableDialog`, `chartDataRows`, `chartDataJson`) and `ChartStyleEditor` (full or override mode, texts via `ChartStyleEditorStrings`) |
| `package:wonky_charts_flutter/gpu.dart` | The `flutter_scene` backend: `installChart3DGpuBackend`, `FlutterSceneChart3DRenderer`, `gpuTriangleIndices`. Only the app entry point imports it. |
