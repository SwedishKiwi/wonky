import 'package:clock/clock.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_write/features/editor/applier/delta_applier.dart';
import 'package:wonky_write/features/editor/controller/editor_types.dart';
import 'package:wonky_write/features/editor/controller/write_editor_controller.dart';

/// A [WriteEditorController] with deterministic ids and clock, recording its
/// local changes, plus helpers to type and select like a user.
class EditorHarness {
  EditorHarness(
    Delta initial, {
    EditorMode mode = EditorMode.editing,
    WriteEditorPreferences preferences = const WriteEditorPreferences(),
    String userUuid = 'me',
    DateTime? now,
  }) : clockTime = now ?? DateTime.utc(2026, 10, 12, 12) {
    var nodeIds = 0;
    var embedIds = 0;
    controller = WriteEditorController(
      initialDelta: initial,
      userUuid: userUuid,
      mode: mode,
      preferences: preferences,
      newNodeId: () => 'node-${nodeIds++}',
      newEmbedId: () => 'embed-${embedIds++}',
      clock: Clock(() => clockTime),
      verifyInvariants: true,
    );
    controller.localChanges.listen(changes.add);
  }

  /// Parses `[` `]` markers in [text] (one line) as the selection.
  factory EditorHarness.text(String text, {EditorMode mode = EditorMode.editing}) {
    final start = text.indexOf('[');
    final end = text.indexOf(']');
    final plain = text.replaceAll('[', '').replaceAll(']', '');
    final harness = EditorHarness(Delta()..insert('$plain\n'), mode: mode);
    if (start >= 0) {
      harness.select(start, end < 0 ? start : end - 1);
    }
    return harness;
  }

  late final WriteEditorController controller;
  final changes = <LocalDeltaChange>[];
  DateTime clockTime;

  Editor get editor => controller.editor;

  Delta get delta => controller.delta;

  DeltaSelection? get selection => controller.selection;

  void advance(Duration duration) => clockTime = clockTime.add(duration);

  void select(int base, [int? extent]) => controller.select(DeltaSelection(base, extent ?? base));

  /// Types [text] one character at a time at the caret (like the keyboard).
  void type(String text) {
    for (final char in text.split('')) {
      if (char == '\n') {
        editor.execute([InsertNewlineAtCaretRequest()]);
      } else {
        editor.execute([InsertCharacterAtCaretRequest(character: char)]);
      }
    }
  }

  void backspace() => editor.execute([const DeleteUpstreamRequest()]);

  void delete() => editor.execute([const DeleteDownstreamRequest()]);

  /// Undoes [change] like the undo handler: applies its inverse locally.
  void undo(LocalDeltaChange change) =>
      controller.applyLocal(change.inverse, label: 'Undo', source: LocalChangeSource.undo, selectionAfter: change.selectionBefore);

  String get plainText => delta.operations.map((op) => op.data is String ? op.data : '￼').join();

  void dispose() => controller.dispose();
}
