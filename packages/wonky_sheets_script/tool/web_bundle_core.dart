// Baseline for tool/web_bundle_probe.dart: the workbook model, planner and
// formula engine the app already ships, without the script runtime.
import 'package:wonky_sheets_core/wonky_sheets_core.dart';

void main(List<String> args) {
  final model = WorkbookModel(spreadsheetId: 'x');
  final binding = ModelEngineBinding.create(model);
  final plan = const SheetsMutationPlanner().plan(
    const CreateSpreadsheet(spreadsheetId: 'x'),
    model,
    PlanContext(
      userId: 'u',
      now: DateTime.now(),
      formulas: EngineFormulaHooks(model),
    ),
  );
  model.applyPlan(plan);
  print(
    EffectiveFormatResolver(model).resolve(model.sheets.first.id, 0, 0).bold,
  );
  print(binding.engine.valueAt(model.sheets.first.id, 0, 0));
}
