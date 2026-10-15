/// The Wonky Work chart engine (specs/wonky_sheets/08-charts-and-objects.md, Slides 08 §2):
/// the chart spec model and schema, [ChartData] (the engine's only data input), layout, the
/// renderer-independent scene, 3D charts, SVG/PDF/PNG renderers, trendline statistics and the
/// accessible describer. Pure Dart; Flutter painting is in `wonky_charts_flutter`.
///
/// Wonky Sheets resolves cells into [ChartData] (`wonky_sheets_core`); Wonky Slides uses
/// snapshots of that data.
library;

export 'src/chart_pipeline.dart';
export 'src/data/chart_data.dart';
export 'src/data/data_algorithms.dart';
export 'src/data/value_formatter.dart';
export 'src/describe/chart_describer.dart';
export 'src/layout/chart_layout_engine.dart';
export 'src/layout/chart_theme.dart';
export 'src/layout/chart_theme_source.dart';
export 'src/layout/scales.dart';
export 'src/layout/text_measurer.dart';
export 'src/render/render.dart';
export 'src/scene/geometry.dart';
export 'src/scene/path.dart';
export 'src/scene/scene.dart';
export 'src/spec/chart_data_spec.dart';
export 'src/spec/chart_spec.dart' show ChartSpec, ChartSpecUpgrade;
export 'src/spec/chart_spec_parts.dart';
export 'src/spec/chart_type.dart';
export 'src/spec/data_range_ref.dart';
export 'src/spec/error_bars.dart';
export 'src/spec/series_style.dart';
export 'src/spec/spec_json.dart' show JsonReader, JsonWriter, SpecNode, jsonNum;
export 'src/spec/spec_schema.dart'
    show ChartSpecIssue, ChartSpecSchema, ChartSpecValidationException;
export 'src/spec/three_d_options.dart';
export 'src/spec/type_options.dart';
export 'src/stats/stats.dart';
export 'src/three_d/chart3d_camera.dart';
export 'src/three_d/chart3d_mesh.dart';
export 'src/three_d/chart3d_model.dart';
export 'src/three_d/chart3d_scene.dart';
export 'src/three_d/chart3d_shading.dart';
export 'src/three_d/vec3.dart';
