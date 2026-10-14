/// Workbook model, formatting, mutation planner, data tools, rules, pivots,
/// charts, objects, clipboard and import/export of Wonky Sheets
/// (specs/wonky_sheets/02, 03, 06–08, 10–12).
///
/// Import together with `formula.dart`; the two barrels have no name clashes
/// (checked by `test/barrels_test.dart`). See the package README for the
/// main entry points of each area.
library;

// Workbook model and cell content (02).
export 'src/content/cell_content.dart';
export 'src/content/rich_text.dart';
export 'src/model/axis_index.dart';
export 'src/model/cell_store.dart';
export 'src/model/events.dart';
export 'src/model/grid_range.dart';
export 'src/model/records.dart';
export 'src/model/rect_index.dart';
export 'src/model/schema.dart';
export 'src/model/sheet_model.dart';
export 'src/model/workbook_model.dart';

// Formatting core, number formats and input parsing (03 §8.6, 06).
export 'src/format/attributes.dart';
export 'src/format/banding.dart';
export 'src/format/borders.dart';
export 'src/format/format_resolver.dart';
export 'src/format/theme.dart';
export 'src/format/number_format/number_format.dart';
export 'src/input/input.dart';
export 'src/fill/fill.dart';

// Mutation planner, undo and maintenance (02, 08).
export 'src/mutations/maintenance.dart';
export 'src/mutations/operations.dart';
export 'src/mutations/plan_builder.dart' show PlanContext, PlanException;
export 'src/mutations/planner.dart';
export 'src/mutations/row_change.dart';

// Engine ↔ model bridge (05 §7).
export 'src/engine_bridge/engine_binding.dart';
export 'src/engine_bridge/engine_formula_hooks.dart';
export 'src/engine_bridge/formula_hooks.dart';
export 'src/engine_bridge/model_cell_source.dart';
export 'src/engine_bridge/model_workbook_view.dart';
export 'src/engine_bridge/pivot_formula_evaluator.dart';
export 'src/engine_bridge/pivot_outputs.dart';
export 'src/engine_bridge/stored_formula.dart';
export 'src/engine_bridge/value_bridge.dart';

// Rules (CF/DV), data tools, pivot tables (06 §15, 07).
export 'src/rules/rules.dart';
export 'src/data_tools/data_tools.dart';
export 'src/pivot/pivot.dart';

// Charts and floating objects (08).
export 'src/charts/charts.dart';
export 'src/objects/objects.dart';

// Clipboard (03 §12).
export 'src/clipboard/clipboard.dart';

// Import/export: IR, CSV/TSV, XLSX, ODS, HTML, print/PDF (11).
export 'src/io/io.dart';

// Snapshots, version diff, space copy (10).
export 'src/copy/space_copier.dart';
export 'src/snapshot/diff.dart';
export 'src/snapshot/snapshot.dart';
