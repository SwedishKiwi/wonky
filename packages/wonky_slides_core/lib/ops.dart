/// Operations, plans and the planner contract of Wonky Slides
/// (specs/wonky_slides/02 §12): the sealed `SlidesOperation` family,
/// `SlidesPlanContext`, `SlidesLimits`, `PlanException`,
/// `SlidesChangeSummary` / `SlidesPlan` and `SlidesMutationPlanner`.
///
/// Pure Dart (client, server, MCP).
library;

export 'src/ops/change_summary.dart';
export 'src/ops/operations.dart';
export 'src/ops/plan_context.dart';
export 'src/ops/planner.dart';
