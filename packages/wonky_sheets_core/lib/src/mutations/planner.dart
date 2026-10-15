import '../model/workbook_model.dart';
import 'handlers/data.dart';
import 'handlers/format.dart';
import 'handlers/move.dart';
import 'handlers/objects.dart';
import 'handlers/rules.dart';
import 'handlers/sheets.dart';
import 'handlers/structure.dart';
import 'handlers/values.dart';
import 'operations.dart';
import 'plan_builder.dart';
import 'row_change.dart';

/// Turns user operations into synced row changes (13 §4.1, 12 §2.4).
///
/// Pure: reads [WorkbookModel] (and the context's computed values / formula
/// hooks), never mutates it. The client `SheetsWriter` and the server
/// `ServerSheetsWriter` apply the resulting [MutationPlan] with named columns
/// and a `ChangeLog` row; the model ingests it with
/// `WorkbookModel.applyPlan`. Undo = `SheetsUndo.invert(plan, current)`.
///
/// Throws [PlanException] for refused operations.
final class SheetsMutationPlanner {
  /// Creates a planner.
  const SheetsMutationPlanner();

  static final Expando<(WorkbookModel, MutationPlan)> _offered = Expando(
    'SheetsMutationPlanner.offered',
  );

  /// Hands a plan of [op] computed ahead with [steps] to the next [plan]
  /// call for this very [op] instance on [model] (a `DataJob` plans
  /// cooperatively, then applies through the normal write path, 07 §1.4).
  /// The caller guarantees [model] didn't change since the plan was made.
  static void offer(
    SheetsOperation op,
    WorkbookModel model,
    MutationPlan plan,
  ) => _offered[op] = (model, plan);

  /// Plans [op] against [model] as cooperative steps (07 §1.4 compute
  /// phase): progress values (0–1) and, last, the [MutationPlan]. Sort,
  /// randomize and remove duplicates report progress; other operations are
  /// one step. Throws [PlanException] while iterating. The model must not
  /// change during the iteration.
  Iterable<Object> steps(
    SheetsOperation op,
    WorkbookModel model,
    PlanContext ctx,
  ) {
    final b = PlanBuilder(model, ctx);
    return switch (op) {
      SortRange() => planSortRangeSteps(b, op),
      RandomizeRange() => planRandomizeRangeSteps(b, op),
      RemoveDuplicates() => planRemoveDuplicatesSteps(b, op),
      _ => _oneStep(op, model, ctx),
    };
  }

  Iterable<Object> _oneStep(
    SheetsOperation op,
    WorkbookModel model,
    PlanContext ctx,
  ) sync* {
    yield plan(op, model, ctx);
  }

  /// Plans [op] against [model].
  MutationPlan plan(SheetsOperation op, WorkbookModel model, PlanContext ctx) {
    final offered = _offered[op];
    if (offered != null) {
      _offered[op] = null;
      if (identical(offered.$1, model)) return offered.$2;
    }
    final b = PlanBuilder(model, ctx);
    return switch (op) {
      SetCellInputs() => planSetCellInputs(b, op),
      ClearRanges() => planClearRanges(b, op),
      SetNote() => planSetNote(b, op),
      SetLink() => planSetLink(b, op),
      RestoreCellValue() => planRestoreCellValue(b, op),
      SetFormat() => planSetFormat(b, op),
      ToggleFormat() => planToggleFormat(b, op),
      SetBorders() => planSetBorders(b, op),
      ClearFormatting() => planClearFormatting(b, op),
      AdjustDecimals() => planAdjustDecimals(b, op),
      StepFontSize() => planStepFontSize(b, op),
      MergeCells() => planMerge(b, op),
      UnmergeCells() => planUnmerge(b, op),
      InsertDimension() => planInsertDimension(b, op),
      DeleteDimension() => planDeleteDimension(b, op),
      MoveDimension() => planMoveDimension(b, op),
      SetDimensionHidden() => planSetHidden(b, op),
      ResizeDimension() => planResize(b, op),
      SetFrozen() => planSetFrozen(b, op),
      ShiftCells() => planShiftCells(b, op),
      GroupOperation() => planGroupOperation(b, op),
      CreateSpreadsheet() => planCreateSpreadsheet(b, op),
      AddSheet() => planAddSheet(b, op),
      DeleteSheet() => planDeleteSheet(b, op),
      RenameSheet() => planRenameSheet(b, op),
      DuplicateSheet() => planDuplicateSheet(b, op),
      MoveSheet() => planMoveSheet(b, op),
      SetSheetProperties() => planSetSheetProperties(b, op),
      SetSpreadsheetProperties() => planSetSpreadsheetProperties(b, op),
      SetPrintSettings() => planSetPrintSettings(b, op),
      AddCfRule() => planAddCfRule(b, op),
      UpdateCfRule() => planUpdateCfRule(b, op),
      DeleteCfRule() => planDeleteCfRule(b, op),
      ReorderCfRule() => planReorderCfRule(b, op),
      SetCfEnabled() => planSetCfEnabled(b, op),
      SetDataValidation() => planSetDataValidation(b, op),
      DeleteDvRule() => planDeleteDvRule(b, op),
      InsertCheckboxes() => planInsertCheckboxes(b, op),
      SetBasicFilter() => planSetBasicFilter(b, op),
      SetFilterColumnCriteria() => planSetFilterColumnCriteria(b, op),
      RemoveBasicFilter() => planRemoveBasicFilter(b, op),
      CreateFilterView() => planCreateFilterView(b, op),
      UpdateFilterView() => planUpdateFilterView(b, op),
      DeleteFilterView() => planDeleteFilterView(b, op),
      AddNamedRange() => planAddNamedRange(b, op),
      UpdateNamedRange() => planUpdateNamedRange(b, op),
      DeleteNamedRange() => planDeleteNamedRange(b, op),
      AddProtection() => planAddProtection(b, op),
      UpdateProtection() => planUpdateProtection(b, op),
      DeleteProtection() => planDeleteProtection(b, op),
      AddBanding() => planAddBanding(b, op),
      UpdateBanding() => planUpdateBanding(b, op),
      RemoveBanding() => planRemoveBanding(b, op),
      AddObject() => planAddObject(b, op),
      UpdateObject() => planUpdateObject(b, op),
      DeleteObject() => planDeleteObject(b, op),
      AddPivotTable() => planAddPivotTable(b, op),
      UpdatePivotTable() => planUpdatePivotTable(b, op),
      DeletePivotTable() => planDeletePivotTable(b, op),
      GenericRowWrite() => planGenericRowWrite(b, op),
      SortRange() => planSortRange(b, op),
      RandomizeRange() => planRandomizeRange(b, op),
      RemoveDuplicates() => planRemoveDuplicates(b, op),
      TrimWhitespace() => planTrimWhitespace(b, op),
      SplitTextToColumns() => planSplitTextToColumns(b, op),
      FindReplace() => planFindReplace(b, op),
      FillSeries() => planFillSeries(b, op),
      MoveRange() => planMoveRange(b, op),
      PasteClipboard() => planPaste(b, op),
    };
  }
}
