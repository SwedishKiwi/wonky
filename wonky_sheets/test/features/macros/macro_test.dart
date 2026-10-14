import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets/features/macros/macro_service.dart';
import 'package:wonky_sheets/features/scripts/script_project.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../support/sheets_harness.dart';
import '../scripts/script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

void stamp() {
  SpreadsheetApp.activeSheet.getRange('C1').value = 'stamped';
}
''';

String _macrosSource(SheetsHarness s) => ScriptProjectRows.sourceOf(
  ScriptProjectRows.fileNamed(s.model, macrosFileName)!,
);

void main() {
  late ScriptHarness h;

  setUp(() async => h = await ScriptHarness.open({'main.dart': _main}));
  tearDown(() => h.dispose());

  group('Given the macro recorder', () {
    test('when edits are recorded and saved then macros.dart gets the '
        'function, a Macro row is created in one undo step, and replaying '
        'the macro repeats the edits', () async {
      final s = h.s;
      await s.run('sheets.macro.record');
      final macros = MacroService.of(s.editor);
      expect(macros.recording, isTrue);

      await s.type('B2', 'Hello');
      await s.select('B2');
      await s.run('sheets.format.bold');
      expect(macros.recordedCount, greaterThanOrEqualTo(2));

      final steps = s.services.undo
          .undoStepsOf(const UndoStackKey(testItemUuid))
          .length;
      final r = await s.run('sheets.macro.saveRecording', {
        'name': 'Format header',
        'shortcutSlot': 1,
      });
      await pumpScripts(20);

      expect(r.isOk, isTrue);
      expect(macros.recording, isFalse);
      final code = _macrosSource(s);
      expect(code, contains('void formatHeader()'));
      expect(code, contains('"Hello"'));
      expect(code, contains('// Not recorded'));
      final rows = ScriptProjectRows.macros(s.model);
      expect(rows.single.columns[ScriptCols.functionName], 'formatHeader');
      expect(
        s.services.undo.undoStepsOf(const UndoStackKey(testItemUuid)).length,
        steps + 1,
      );
      // The save compiled the project: the macro is runnable.
      expect(h.svc.exports.function('formatHeader'), isNotNull);

      // Replay on a fresh cell state.
      await s.run('sheets.edit.clearValues', {
        'ranges': ['B2'],
      });
      expect(s.text('B2'), '');
      final id = macroCommandId(rows.single.id);
      expect(s.services.registry.contains(id), isTrue);
      final replay = await s.run(id);

      expect(replay.isOk, isTrue);
      expect(s.text('B2'), 'Hello');
    });

    test('when the recording is cancelled then nothing is written', () async {
      await h.s.run('sheets.macro.record', {'mode': 'relative'});
      expect(MacroService.of(h.s.editor).mode, MacroReferenceMode.relative);
      await h.s.type('A1', 'x');

      await h.s.run('sheets.macro.cancelRecording');

      expect(MacroService.of(h.s.editor).recording, isFalse);
      expect(ScriptProjectRows.fileNamed(h.s.model, macrosFileName), isNull);
      expect(ScriptProjectRows.macros(h.s.model), isEmpty);
    });
  });

  group('Given an imported macro', () {
    test('when it is imported with a shortcut then the dynamic command has '
        'Mod+Alt+Shift+2, runs the function, and updates/removal follow the '
        'row', () async {
      final s = h.s;
      final r = await s.run('sheets.macro.import', {
        'functionName': 'stamp',
        'name': 'Stamp it',
        'shortcutSlot': 2,
      });
      expect(r.isOk, isTrue);
      final macroId = (r.data as Map)['macroId'] as String;
      final id = macroCommandId(macroId);

      final cmd = s.services.registry.byId(id)!;
      expect(cmd.defaultBindings.single.mod, isTrue);
      expect(cmd.defaultBindings.single.alt, isTrue);
      expect(cmd.defaultBindings.single.shift, isTrue);
      expect(cmd.defaultBindings.single.key, '2');

      expect((await s.run(id)).isOk, isTrue);
      expect(s.text('C1'), 'stamped');

      await s.run('sheets.macro.update', {
        'macroId': macroId,
        'name': 'Stamp',
        'shortcutSlot': 10,
      });
      expect(s.services.registry.byId(id)!.defaultBindings.single.key, '0');

      await s.run('sheets.macro.delete', {'macroId': macroId});
      expect(s.services.registry.contains(id), isFalse);

      await s.undo();
      expect(s.services.registry.contains(id), isTrue);
    });

    test(
      'when macros are listed without a dialog then they are returned',
      () async {
        await h.s.run('sheets.macro.import', {
          'functionName': 'stamp',
          'name': 'Stamp it',
        });
        final r = await h.s.run('sheets.macro.manage');
        final list = (r.data as Map)['macros'] as List;
        expect(list.single['name'], 'Stamp it');
      },
    );
  });
}
