/// Charts in Wonky Slides (specs/wonky_slides/08, 12 §4.8 SL-27), pure Dart (client, server,
/// PDF, MCP):
///
/// - `ChartElementData`: the chart element's `dataJson` (source, deck style, camera,
///   overrides, static snapshot, background, interactive);
/// - `ChartOverrides`: the override allowlist (08 §8.2);
/// - `SlideChartSpec.effective`: the rendered spec and theme (08 §3.5);
/// - `SlideChartLayout`: the `ChartSceneSource` of the slide scene (linked snapshots incl.
///   `gz:` columns, static snapshots; reveal and 3D camera for builds);
/// - `SlideChartMotion`: chart shapes for the timeline (`SlideMotionInput.fromDeck
///   (chartShapeOf:)`), frame state → `ChartReveal` and the 3D camera of a frame;
/// - `ChartLinkService`, `ChartLinkOps`: the client contract of the `slidesCharts` endpoint and
///   the link operations built from resolved snapshots.
///
/// The engine types (`ChartSourceSnapshot`, `ChartDataSnapshot`, `ChartReveal`,
/// `ChartSceneMorph`, `Chart3DView`, …) come from `package:wonky_charts`.
library;

export 'src/charts/chart_element_data.dart';
export 'src/charts/chart_link_service.dart';
export 'src/charts/chart_motion.dart';
export 'src/charts/chart_overrides.dart';
export 'src/charts/slide_chart_layout.dart';
export 'src/charts/slide_chart_spec.dart';
