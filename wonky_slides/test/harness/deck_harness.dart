import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemKind, UuidValue;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/editor_screen/deck_document_controller.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/model/memory_deck_session.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart' show SlidesPlanner;
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart' show SequentialIdGenerator;

import '../support/slides_harness.dart';

/// Command tests of Wonky Slides (Slides 12 §7.2): a [CommandTestHarness]
/// with the Slides config (every `slides.*` command registered), a
/// [MemoryDeckSession] over a [DeckBuilder] fixture and the editor's real
/// [DeckDocumentController] (the `slides.rows` undo handler) with a
/// headless [DeckEditorController] attached and active, so commands run
/// through the real dispatcher and `UndoService` without widgets:
///
/// ```dart
/// final d = DeckHarness.open();
/// d.registerOp('test.rename', (a) => SetDeckProps(title: a.requireString('title')));
/// await d.run('test.rename', {'title': 'Q3'});
/// await d.undo();
/// ```
///
/// The planner is the core `SlidesPlanner` (pass [planner] to use another).
class DeckHarness {
  DeckHarness._(this.h, this.session, this.doc, this.editor, this.fixture);

  static DeckHarness open({
    Role role = Role.owner,
    DeckBuilder? fixture,
    SlidesMutationPlanner planner = const SlidesPlanner(),
  }) {
    final h = slidesHarness();
    final b =
        fixture ?? (DeckBuilder()..slide(layoutKey: 'title', title: 'Hi'));
    final uuid = UuidValue.fromString(b.deckId);
    h.drive.seed(name: b.title, uuid: uuid, kind: DriveItemKind.presentation);
    final session = MemoryDeckSession(
      itemUuid: uuid,
      userId: b.userId,
      model: b.build(),
      planner: planner,
      role: role,
      ids: SequentialIdGenerator(10000),
    );
    final doc = DeckDocumentController(
      services: h.services,
      itemUuid: uuid,
      title: b.title,
      role: role,
      persistUndo: false,
    );
    final editor = DeckEditorController(
      services: h.services,
      session: session,
      itemRole: role,
    );
    doc.attach(editor);
    h.services.activate(doc);
    return DeckHarness._(h, session, doc, editor, b);
  }

  final CommandTestHarness h;
  final MemoryDeckSession session;
  final DeckDocumentController doc;

  /// The headless editor state (current slide, selection, panes, zoom).
  final DeckEditorController editor;

  /// The fixture the deck was built from (ids of slides and elements).
  final DeckBuilder fixture;

  ShellServices get services => h.services;
  DeckModel get model => session.model;

  /// Registers an undoable command [id] that executes the operation built
  /// from its arguments and records the plan as one `slides.rows` entry —
  /// the pattern of the Slides commands (`DeckEditorController.apply`).
  void registerOp(
    String id,
    SlidesOperation Function(JsonArgs args) op, {
    JsonSchema argsSchema = JsonSchema.empty,
    Role requiredRole = Role.editor,
  }) => services.registry.register(
    CallbackCommand(
      id: id,
      title: (_) => id,
      isUndoable: true,
      requiredRole: requiredRole,
      argsSchema: argsSchema,
      run: (ctx, args) async {
        final plan = editor.apply(ctx, op(args));
        return CommandResult.ok(plan.result);
      },
    ),
  );

  /// Invokes a command as a UI gesture.
  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => h.invoke(id, args, InvocationSource.ui);

  Future<UndoOutcome?> undo() => h.undo();
  Future<UndoOutcome?> redo() => h.redo();

  /// Undo labels of the deck's stack, newest first.
  List<String> get undoLabels => h.undoLabels;

  Future<void> dispose() async {
    services.deactivate(doc);
    editor.dispose();
    doc.dispose();
    await session.dispose();
    await h.dispose();
  }
}
