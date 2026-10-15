import '../model/api/deck_model.dart';
import 'change_summary.dart';
import 'operations.dart';
import 'plan_context.dart';

/// Plans [SlidesOperation]s against a [DeckModel] (02 §12.1): the same
/// planner runs in the app (`DeckSession.execute`) and on the server
/// (`ServerSlidesWriter`: MCP, AI, restore, templates), so headless and UI
/// edits are identical.
///
/// Rules every implementation follows: plans name exactly the touched
/// columns (P7); coupled columns are always written together (P4,
/// `SlidesUndoHooks.coupled`); deletes of parents list child rows
/// explicitly so undo can revive them; limits (`SlidesLimits`) throw
/// `PlanException(PlanException.limit, …)` before anything is applied;
/// planning never mutates [deck]. An operation that changes nothing returns
/// an empty plan.
///
/// Contract (SL-3); the implementation is SL-7's (`core/mutations/`).
abstract interface class SlidesMutationPlanner {
  /// The plan of [op] against [deck]. Throws `PlanException`.
  SlidesPlan plan(SlidesOperation op, DeckModel deck, SlidesPlanContext ctx);
}
