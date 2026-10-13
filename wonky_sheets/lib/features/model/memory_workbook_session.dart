import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart' show SyncStatus;

import 'workbook_session.dart';

/// Shared implementation of [WorkbookSession]: planning, applying plans to
/// the model and the engine binding. Subclasses persist (the synced SQLite
/// replica in `features/sync`) by overriding [persist].
abstract class WorkbookSessionBase extends WorkbookSession {
  WorkbookSessionBase({
    required this.itemUuid,
    required this.userId,
    required this.model,
    Role role = Role.owner,
    this.maxCells = 1000000,
  }) : _role = ValueNotifier(role) {
    engine = ModelEngineBinding.create(model);
  }

  @override
  final UuidValue itemUuid;

  @override
  final String userId;

  @override
  final WorkbookModel model;

  @override
  late final ModelEngineBinding engine;

  /// `sheets.maxCellsPerSpreadsheet`.
  final int maxCells;

  final ValueNotifier<Role> _role;

  @override
  ValueListenable<Role> get role => _role;

  set roleValue(Role value) => _role.value = value;

  @protected
  final ValueNotifier<WorkbookLoadState> loadStateNotifier = ValueNotifier(
    const WorkbookLoading(),
  );

  @protected
  final ValueNotifier<SyncStatus> syncStatusNotifier = ValueNotifier(
    SyncStatus.saved,
  );

  @protected
  final StreamController<WorkbookChangeBatch> remoteController =
      StreamController.broadcast();

  @override
  String get spreadsheetId => model.spreadsheetId;

  @override
  ValueListenable<WorkbookLoadState> get loadState => loadStateNotifier;

  @override
  ValueListenable<SyncStatus> get syncStatus => syncStatusNotifier;

  @override
  Stream<WorkbookChangeBatch> get remoteBatches => remoteController.stream;

  static const _planner = SheetsMutationPlanner();

  @override
  PlanContext planContext() => PlanContext(
    userId: userId,
    now: clock.now().toUtc(),
    formulas: EngineFormulaHooks(
      model,
      engine: engine.engine,
      view: engine.view,
    ),
    values: ModelCellSource(model),
    locale: model.spreadsheet.locale,
    maxCells: maxCells,
    isOwner: role.value == Role.owner,
  );

  @override
  MutationPlan execute(SheetsOperation op, {String actorKind = 'user'}) {
    final plan = _planner.plan(op, model, planContext());
    if (plan.isEmpty) return plan;
    model.applyPlan(plan);
    persist(plan.changes, plan: plan, label: plan.label, actorKind: actorKind);
    return plan;
  }

  @override
  void applyChanges(
    List<RowChange> changes, {
    required String label,
    String actorKind = 'user',
  }) {
    if (changes.isEmpty) return;
    model.applyChanges(changes);
    persist(changes, label: label, actorKind: actorKind);
  }

  /// Stores [changes] (already applied to [model]). [plan] is set for
  /// planned operations (its summary/detail feed the `ChangeLog` row).
  @protected
  void persist(
    List<RowChange> changes, {
    MutationPlan? plan,
    required String label,
    required String actorKind,
  });

  @override
  Future<void> dispose() async {
    await flush();
    engine.dispose();
    await remoteController.close();
    loadStateNotifier.dispose();
    syncStatusNotifier.dispose();
    _role.dispose();
  }
}

/// A session that only lives in memory: widget tests, previews, and the
/// grid while the data layer isn't wired.
class MemoryWorkbookSession extends WorkbookSessionBase {
  MemoryWorkbookSession({
    required super.itemUuid,
    required super.userId,
    required super.model,
    super.role,
  }) {
    loadStateNotifier.value = const WorkbookReady();
  }

  /// A new spreadsheet with one empty sheet.
  factory MemoryWorkbookSession.blank({
    UuidValue? itemUuid,
    String userId = '00000000-0000-7000-8000-000000000001',
    String title = 'Untitled spreadsheet',
    Role role = Role.owner,
  }) {
    final id = itemUuid ?? UuidV7Generator().next();
    final model = WorkbookModel(spreadsheetId: id.uuid);
    final plan = const SheetsMutationPlanner().plan(
      CreateSpreadsheet(spreadsheetId: id.uuid, title: title),
      model,
      PlanContext(userId: userId, now: clock.now().toUtc()),
    );
    model.applyPlan(plan);
    return MemoryWorkbookSession(
      itemUuid: id,
      userId: userId,
      model: model,
      role: role,
    );
  }

  /// Every change persisted so far (tests).
  final List<RowChange> persisted = [];

  @override
  void persist(
    List<RowChange> changes, {
    MutationPlan? plan,
    required String label,
    required String actorKind,
  }) => persisted.addAll(changes);

  @override
  Future<void> flush() async {}
}
