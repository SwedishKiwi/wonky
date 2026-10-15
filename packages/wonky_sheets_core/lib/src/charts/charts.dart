/// Wonky Sheets charts (specs/wonky_sheets/08-charts-and-objects.md): the shared engine of
/// `wonky_charts` (spec model, layout, scene, renderers, 3D, statistics; 08 §24) plus the
/// Sheets parts — cell data resolution, header detection, recommendations, sparklines and
/// the workbook pipeline.
library;

export 'package:wonky_charts/wonky_charts.dart';

export 'chart_pipeline.dart';
export 'chart_ranges.dart';
export 'data/chart_data_resolver.dart';
export 'data/header_detection.dart';
export 'recommend/chart_recommender.dart';
export 'sparkline/sparkline.dart';
