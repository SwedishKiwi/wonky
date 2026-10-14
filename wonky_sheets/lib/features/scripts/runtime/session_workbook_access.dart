import 'package:wonky_app/wonky_app.dart' show CommandContext;
import 'package:wonky_sheets_core/formula.dart' show FormulaEngine;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';
import 'package:wonky_sync_models/ids.dart' show IdGenerator, UuidV7IdGenerator;

import '../../sheet_editor/sheet_editor_controller.dart';
import '../../sheet_editor/write_gate.dart';

/// [WorkbookAccess] of client executions (09 §8.4): script writes are
/// planned, applied and persisted through the open workbook session like
/// commands (actor kind `script`), after the editor's write gates
/// (protected ranges). The plans collect in [applied]; the script service
/// turns the plans of one execution into one undo step "Script: fn".
///
/// With a command context [ctx] (stores used by commands, e.g. the
/// triggers dialog through `ModelTriggerStore`), writes go through
/// `SheetEditorController.apply` and become part of that command's step.
class SessionWorkbookAccess implements WorkbookAccess {
  SessionWorkbookAccess(this.editor, {this.ctx})
    : formulas = EngineFormulaHooks(
        editor.model,
        engine: editor.session.engine.engine,
        view: editor.session.engine.view,
      ),
      formats = EffectiveFormatResolver(editor.model);

  final SheetEditorController editor;

  /// The command whose undo step records the writes, if any.
  final CommandContext? ctx;

  @override
  WorkbookModel get model => editor.model;

  @override
  FormulaEngine get engine => editor.session.engine.engine;

  @override
  final FormulaHooks formulas;

  @override
  final EffectiveFormatResolver formats;

  @override
  String get userId => editor.session.userId;

  @override
  final IdGenerator ids = const UuidV7IdGenerator();

  @override
  final List<AppliedPlan> applied = [];

  @override
  MutationPlan apply(SheetsOperation operation, {bool undoable = true}) {
    final c = ctx;
    if (c != null) {
      final plan = editor.apply(c, operation);
      if (!plan.isEmpty) {
        applied.add(AppliedPlan(operation, plan, undoable: true));
      }
      return plan;
    }
    for (final gate in List.of(editor.writeGates)) {
      try {
        gate(null, operation);
      } on WriteRefused catch (e) {
        throw PlanException(e.code ?? 'write_refused', e.message);
      } on WriteNeedsConfirmation {
        // Warning-only protection: scripts write without asking (as in
        // Google Sheets); a person is warned when editing by hand.
      }
    }
    final plan = editor.session.execute(operation, actorKind: 'script');
    if (!plan.isEmpty) {
      applied.add(AppliedPlan(operation, plan, undoable: undoable));
    }
    return plan;
  }
}
