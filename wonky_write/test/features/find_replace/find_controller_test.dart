import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_write/features/editor/applier/delta_applier.dart';
import 'package:wonky_write/features/editor/controller/editor_types.dart';
import 'package:wonky_write/features/editor/controller/write_editor_controller.dart';
import 'package:wonky_write/features/find_replace/find_controller.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show DeltaUtils;

WriteEditorController editorWith(String text) => WriteEditorController(
  initialDelta: Delta()..insert('$text\n'),
  documentUuid: 'doc',
  userUuid: 'me',
);

void main() {
  group('Given a document "The colour of the colour wheel"', () {
    late WriteEditorController editor;
    late FindController find;
    late List<LocalDeltaChange> changes;

    setUp(() {
      editor = editorWith('The colour of the colour wheel');
      find = FindController(editor);
      changes = [];
      editor.localChanges.listen(changes.add);
      find.open();
    });

    tearDown(() {
      find.dispose();
      editor.dispose();
    });

    test('when searching "colour" then two matches are highlighted', () {
      find.query = 'colour';

      expect(find.matches.map((m) => m.start), [4, 18]);
      expect(editor.view.findMatches.length, 2);
      expect(find.countLabel, '1 of 2');
    });

    test('when moving next twice then the selection wraps to the first match', () {
      find.query = 'colour';

      find
        ..next()
        ..next();

      expect(find.current, 0);
      expect(editor.selection, const DeltaSelection(4, 10));
    });

    test('when replacing one match then only the active match changes', () {
      find
        ..query = 'colour'
        ..replacement = 'color';

      find.replace();

      expect(DeltaUtils.text(editor.delta), 'The color of the colour wheel\n');
      expect(find.matches.length, 1);
    });

    test('when replacing all then every match changes in one undo step', () {
      find
        ..query = 'colour'
        ..replacement = 'color';

      final n = find.replaceAll();

      expect(n, 2);
      expect(DeltaUtils.text(editor.delta), 'The color of the color wheel\n');
      expect(changes, hasLength(1));
      expect(changes.single.label, 'Replace all');
    });

    test('when the regex is invalid then an error is shown and nothing matches', () {
      find
        ..regex = true
        ..query = '(col';

      expect(find.error, 'Invalid regular expression');
      expect(find.matches, isEmpty);
    });

    test('when using a regex with a group then the replacement expands it', () {
      find
        ..regex = true
        ..query = r'col(our)'
        ..replacement = r'[$1]';

      find.replaceAll();

      expect(DeltaUtils.text(editor.delta), 'The [our] of the [our] wheel\n');
    });

    test('when "whole word" is on then partial words do not match', () {
      find
        ..wholeWord = true
        ..query = 'the';

      expect(find.matches.map((m) => m.start), [0, 14]);
    });

    test('when "match case" is on then "The" matches only the first word', () {
      find
        ..matchCase = true
        ..query = 'The';

      expect(find.matches.map((m) => m.start), [0]);
    });

    test('when closing then the highlights are cleared', () {
      find.query = 'colour';

      find.close();

      expect(editor.view.findMatches, isEmpty);
      expect(find.isActive, isFalse);
    });
  });

  test('Given Viewing mode when replacing then nothing changes', () {
    final editor = editorWith('aaa');
    final find = FindController(editor)..open();
    editor.mode = EditorMode.viewing;
    find
      ..query = 'a'
      ..replacement = 'b';

    expect(find.replaceAll(), 0);
    expect(DeltaUtils.text(editor.delta), 'aaa\n');
    find.dispose();
    editor.dispose();
  });
}
