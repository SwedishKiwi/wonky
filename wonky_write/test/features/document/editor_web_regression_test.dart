import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_write/features/editor/controller/editor_types.dart';
import 'package:wonky_write/features/editor/controller/write_editor_controller.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

void main() {
  test(
    'Given an editor on the web when inserting text then a local change is emitted (no 1 << 62 sentinel)',
    () {
      final c = WriteEditorController(initialDelta: Delta()..insert('Hi\n'));
      final changes = <LocalDeltaChange>[];
      c.localChanges.listen(changes.add);
      final id = c.document.first.id;
      c.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: id,
              nodePosition: const TextNodePosition(offset: 2),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
      c.editor.execute([
        InsertTextRequest(
          documentPosition: DocumentPosition(
            nodeId: id,
            nodePosition: const TextNodePosition(offset: 2),
          ),
          textToInsert: '!',
          attributions: {},
        ),
      ]);
      expect(changes, hasLength(1));
      expect(c.delta, Delta()..insert('Hi!\n'));
    },
  );
}
