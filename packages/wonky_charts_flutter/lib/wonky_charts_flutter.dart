/// Flutter rendering of the Wonky Work chart engine (`wonky_charts`; Sheets 08 §24, Slides 08
/// §2): the scene painter ([ChartScenePainter], [paintChartScene], [chartSceneToPng]), the
/// TextPainter-backed [FlutterTextMeasurer], the 3D GPU backend hook ([Chart3DBackends]), the
/// orbit gesture of 3D charts and the 3D chart glyphs.
///
/// The `flutter_scene` GPU backend itself is in `package:wonky_charts_flutter/gpu.dart`, which
/// only the app's entry point imports (it registers [Chart3DBackends.starter]).
library;

export 'src/icons/chart3d_glyph.dart';
export 'src/orbit/chart_orbit.dart';
export 'src/render/chart_painter.dart';
export 'src/three_d/chart3d_gpu.dart';
