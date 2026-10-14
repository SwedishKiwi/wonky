import 'package:clock/clock.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart';
import 'package:wonky_sync_models/ids.dart';

/// What a [WorkbookAccess] did with one operation.
final class AppliedPlan {
  /// Creates the record.
  const AppliedPlan(this.operation, this.plan, {required this.undoable});

  /// The operation the script asked for.
  final SheetsOperation operation;

  /// The plan that was applied to the model.
  final MutationPlan plan;

  /// False for writes that are not on the undo stack (properties, triggers;
  /// 09 §6.9).
  final bool undoable;
}

/// The workbook a script host works on (09 §3.2).
///
/// Reads go straight to [model] and [engine]; every write is a
/// [SheetsOperation] that [apply] plans with the [SheetsMutationPlanner] and
/// applies to [model] (so the script reads its own writes). The caller
/// persists the plans: the app through its `SheetsWriter` (in the execution's
/// undo transaction), the server through `ServerSheetsWriter`.
abstract interface class WorkbookAccess {
  /// The workbook.
  WorkbookModel get model;

  /// Formula engine bound to [model] (computed values).
  FormulaEngine get engine;

  /// Formula text conversion (A1 ⇄ stored form).
  FormulaHooks get formulas;

  /// Effective formats.
  EffectiveFormatResolver get formats;

  /// Auth user UUID of the caller (`PlanContext.userId`, row authors).
  String get userId;

  /// Generates ids for new rows.
  IdGenerator get ids;

  /// Plans [operation], applies it to [model] and records it. Throws
  /// [PlanException] when the planner rejects it.
  MutationPlan apply(SheetsOperation operation, {bool undoable = true});

  /// The plans applied so far, in order.
  List<AppliedPlan> get applied;
}

/// [WorkbookAccess] over an in-memory [WorkbookModel]: used by the server
/// (headless workbook) and by tests; the app can use it too and persist
/// [applied] (or listen with [onApplied]).
final class ModelWorkbookAccess implements WorkbookAccess {
  /// Creates the access. When [binding] is null an engine binding is created
  /// and disposed by [dispose].
  ModelWorkbookAccess({
    required this.model,
    required this.userId,
    ModelEngineBinding? binding,
    IdGenerator? ids,
    Clock? clock,
    this.onApplied,
    this.maxCells = 10000000,
  }) : _ownsBinding = binding == null,
       _binding = binding ?? ModelEngineBinding.create(model),
       ids = ids ?? UuidV7IdGenerator(),
       _clock = clock ?? const Clock() {
    formulas = EngineFormulaHooks(
      model,
      engine: _binding.engine,
      view: _binding.view,
    );
    formats = EffectiveFormatResolver(model);
  }

  @override
  final WorkbookModel model;

  @override
  final String userId;

  @override
  final IdGenerator ids;

  /// Called after each applied plan.
  final void Function(AppliedPlan applied)? onApplied;

  /// Cell limit passed to the planner.
  final int maxCells;

  final bool _ownsBinding;
  final ModelEngineBinding _binding;
  final Clock _clock;

  @override
  late final FormulaHooks formulas;

  @override
  late final EffectiveFormatResolver formats;

  @override
  FormulaEngine get engine => _binding.engine;

  @override
  final List<AppliedPlan> applied = [];

  static const _planner = SheetsMutationPlanner();

  PlanContext _context() => PlanContext(
    userId: userId,
    now: _clock.now().toUtc(),
    ids: ids,
    formulas: formulas,
    values: engine,
    locale: model.spreadsheet.locale,
    maxCells: maxCells,
  );

  @override
  MutationPlan apply(SheetsOperation operation, {bool undoable = true}) {
    final plan = _planner.plan(operation, model, _context());
    if (plan.isEmpty) return plan;
    model.applyPlan(plan);
    final record = AppliedPlan(operation, plan, undoable: undoable);
    applied.add(record);
    onApplied?.call(record);
    return plan;
  }

  /// All row changes of [applied], in order (for persisting in one go).
  List<RowChange> get changes => [for (final a in applied) ...a.plan.changes];

  /// Releases the engine binding if this access created it.
  void dispose() {
    if (_ownsBinding) _binding.dispose();
  }
}
