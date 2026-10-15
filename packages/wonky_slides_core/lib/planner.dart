/// The mutation planner of Wonky Slides (specs/wonky_slides/02 §12.1):
/// `SlidesPlanner` (every `SlidesOperation` → `SlidesPlan`), the
/// `PlanBuilder` that coalesces row changes, fractional key helpers
/// (`OrderKeys`) and deterministic theme copies (`ThemeCopy`).
///
/// Pure Dart (client, server, MCP).
library;

export 'src/planner/order_keys.dart';
export 'src/planner/plan_builder.dart';
export 'src/planner/slides_planner.dart';
export 'src/planner/theme_copy.dart';
