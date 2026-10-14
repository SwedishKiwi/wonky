import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/cell_editor/cell_editor_controller.dart';
import 'package:wonky_sheets/features/formatting/sheets_user_defaults.dart';

import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() {
    s = SheetsHarness.open();
    addTearDown(s.dispose);
  });

  CellEditorController editor() => s.editor.editor;

  void typeText(String t) => editor().text.value = TextEditingValue(
    text: t,
    selection: TextSelection.collapsed(offset: t.length),
  );

  Future<void> pref(String key, Object? value) =>
      SheetsUserDefaults.of(s.services).set(key, value);

  group('Column autocomplete (03 §8.5)', () {
    setUp(() async {
      await s.type('A1', 'Apple');
      await s.type('A2', 'Banana');
      await s.type('A3', 'Cherry');
      await s.select('A4');
    });

    test('Given values above, when typing the start of one then the rest is '
        'suggested selected and Enter accepts it', () async {
      editor().begin(initialText: 'B', mode: EditMode.enter);

      expect(editor().text.text, 'Banana');
      expect(
        editor().text.selection,
        const TextSelection(baseOffset: 1, extentOffset: 6),
      );
      await editor().commit();
      expect(s.content('A4'), 's:Banana');
    });

    test('Given a suggestion, when typing on then it refines, and Backspace '
        'drops it', () async {
      editor().begin(initialText: 'C', mode: EditMode.enter);
      expect(editor().text.text, 'Cherry');
      typeText('Cx');
      expect(editor().text.text, 'Cx');
      typeText('C');
      expect(editor().text.text, 'C');
    });

    test(
      'Given two values with the prefix, then nothing is suggested',
      () async {
        await s.type('A3', 'Bandana');
        editor().begin(initialText: 'Ban', mode: EditMode.enter);
        expect(editor().text.text, 'Ban');
      },
    );

    test('Given the preference is off, then nothing is suggested, and the '
        'Tools toggle turns it back on', () async {
      await pref(SheetsUserDefaults.keyColumnAutocomplete, false);
      editor().begin(initialText: 'B', mode: EditMode.enter);
      expect(editor().text.text, 'B');
      editor().cancel();

      await s.run('sheets.tools.toggleAutocomplete');
      expect(SheetsUserDefaults.of(s.services).columnAutocomplete, isTrue);
      editor().begin(initialText: 'B', mode: EditMode.enter);
      expect(editor().text.text, 'Banana');
    });

    test(
      'Given an empty cell between, then values beyond it are ignored',
      () async {
        await s.select('A6');
        editor().begin(initialText: 'B', mode: EditMode.enter);
        expect(editor().text.text, 'B');
      },
    );
  });

  group('Formula preview (03 §8.7)', () {
    test('Given a formula, when it is typed then the result shows formatted '
        'after a pause', () async {
      await s.type('A1', '1200.5');
      await s.type('A2', '34');
      await s.select('A3');
      editor().begin(initialText: '=', mode: EditMode.enter);
      typeText('=SUM(A1:A2)');
      expect(editor().preview.value, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(editor().preview.value?.text, '= 1234.5');
      typeText('=1/0');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(editor().preview.value?.text, '#DIV/0!');
      expect(editor().preview.value?.isError, isTrue);
      editor().cancel();
      expect(editor().preview.value, isNull);
    });

    test(
      'Given an array formula, then the top-left value and the size show',
      () async {
        await s.select('C1');
        editor().begin(initialText: '=', mode: EditMode.enter);
        final p = editor().preview.compute('={1,2;3,4}', s.sheetId, 0, 2);
        expect(p?.text, '= 1');
        expect(p?.detail, '(2×2 array)');
        editor().cancel();
      },
    );
  });

  group('Editing preferences', () {
    test('Given Enter starts editing, when Enter is pressed on a cell then '
        'the editor opens; by default Enter moves down', () async {
      await s.select('B2');
      await s.run('sheets.nav.enter');
      expect(editor().isEditing, isFalse);
      expect(s.editor.activeA1, 'B3');

      await pref(SheetsUserDefaults.keyEnterStartsEditing, true);
      await s.run('sheets.nav.enter');
      expect(editor().isEditing, isTrue);
      editor().cancel();
    });

    test('Given formula autocomplete and help are off, when typing a '
        'function then no list and no signature show', () async {
      await s.select('A1');
      editor().begin(initialText: '=', mode: EditMode.enter);
      typeText('=SU');
      expect(editor().completions.items, isNotEmpty);
      typeText('=SUM(');
      expect(editor().signature, isNotNull);
      editor().cancel();

      await pref(SheetsUserDefaults.keyFormulaAutocomplete, false);
      await pref(SheetsUserDefaults.keyFormulaHelp, false);
      editor().begin(initialText: '=', mode: EditMode.enter);
      typeText('=SU');
      expect(editor().completions.items, isEmpty);
      typeText('=SUM(');
      expect(editor().signature, isNull);
      editor().cancel();
    });
  });
}
