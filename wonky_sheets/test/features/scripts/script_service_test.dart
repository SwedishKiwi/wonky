import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets/features/scripts/script_project.dart';
import 'package:wonky_sheets/features/scripts/script_service.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../support/sheets_harness.dart';
import 'script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

/// Doubles a number.
///
/// @customfunction
Object? MYFN(Object? x) => x is num ? x * 2 : null;

void fill() {
  final sheet = SpreadsheetApp.activeSheet;
  sheet.getRange('A1').value = 1;
  sheet.getRange('A2').value = 2;
  sheet.getRange('A3').value = 3;
}

void onOpen(OpenEvent e) {
  SpreadsheetApp.ui.createMenu('Tools').addItem('Fill', 'fill').addToUi();
}

void onEdit(EditEvent e) {
  if (e.range.column == 4) e.range.offset(0, 1).value = 'stamped';
}

void boom() {
  throw StateError('kaput');
}
''';

UndoStackKey get _stack => const UndoStackKey(testItemUuid);

void main() {
  late ScriptHarness h;

  setUp(() async => h = await ScriptHarness.open({'main.dart': _main}));
  tearDown(() => h.dispose());

  group('Given a spreadsheet with a built script', () {
    test('then the build is installed and onOpen added its menu', () {
      expect(h.svc.program, isNotNull);
      expect(h.svc.exports.function('fill'), isNotNull);
      expect(h.svc.menus.map((m) => m.caption), ['Tools']);
    });

    test('when a cell calls a custom function then it shows #LOADING and '
        'then the value', () async {
      await h.s.type('A1', '21');
      await h.s.type('B1', '=MYFN(A1)');

      expect(h.s.text('B1'), '#LOADING');

      await h.svc.session!.customFunctions.idle();
      await pumpScripts();

      expect(h.s.text('B1'), '42');
    });

    test('when a function writes three cells then the run is one undo step '
        '"Script: fill" and one undo removes all writes', () async {
      final before = h.s.services.undo.undoStepsOf(_stack).length;

      final r = await h.s.run('sheets.script.run', {'functionName': 'fill'});

      expect(r.isOk, isTrue);
      expect([h.s.text('A1'), h.s.text('A2'), h.s.text('A3')], ['1', '2', '3']);
      final steps = h.s.services.undo.undoStepsOf(_stack);
      expect(steps.length, before + 1);
      expect(steps.last.label, 'Script: fill');

      await h.s.undo();

      expect([h.s.text('A1'), h.s.text('A2'), h.s.text('A3')], ['', '', '']);
    });

    test('when a custom menu item runs then it writes like a run', () async {
      final r = await h.s.run('sheets.script.runMenuItem', {
        'functionName': 'fill',
        'caption': 'Fill',
      });

      expect(r.isOk, isTrue);
      expect(h.s.text('A3'), '3');
    });

    test('when a person edits a cell then onEdit runs and its write joins '
        'the edit\'s undo step', () async {
      await h.s.type('D2', 'x');
      await pumpScripts(20);

      expect(h.s.text('E2'), 'stamped');

      await h.s.undo();

      expect(h.s.text('D2'), '');
      expect(h.s.text('E2'), '');
    });

    test('when a function throws then the result reports the error and '
        'the execution is logged', () async {
      final r = await h.s.run('sheets.script.run', {'functionName': 'boom'});

      expect(r.isOk, isTrue);
      expect((r.data as Map)['status'], 'failed');
      expect((r.data as Map)['error'], contains('kaput'));
      expect(h.svc.log.any((l) => l.function == 'boom'), isTrue);

      await h.svc.uploadExecutions();
      expect(h.backend.reported.map((e) => e.functionName), contains('boom'));
    });

    test(
      'when a viewer runs a writing function then nothing is written',
      () async {
        h.s.editor.viewMode = true;

        final r = await h.svc.run('fill', kind: ExecutionKind.menu);

        expect(r?.ok, isFalse);
        expect(h.s.text('A1'), '');
      },
    );
  });

  group('Given the script files', () {
    test('when a file is created, renamed and deleted then each is one undo '
        'step', () async {
      await h.s.run('sheets.script.newFile', {'name': 'utils.dart'});
      final f = ScriptProjectRows.fileNamed(h.s.model, 'utils.dart')!;
      await h.s.run('sheets.script.renameFile', {
        'fileId': f.id,
        'name': 'helpers.dart',
      });
      expect(ScriptProjectRows.fileNamed(h.s.model, 'helpers.dart'), isNotNull);

      await h.s.run('sheets.script.deleteFile', {'fileId': f.id});
      expect(ScriptProjectRows.file(h.s.model, f.id), isNull);

      await h.s.undo();
      expect(ScriptProjectRows.fileNamed(h.s.model, 'helpers.dart'), isNotNull);
      await h.s.undo();
      expect(ScriptProjectRows.fileNamed(h.s.model, 'utils.dart'), isNotNull);
    });

    test('when a name breaks the rule then the command fails', () async {
      final r = await h.s.run('sheets.script.newFile', {'name': 'Bad.js'});

      expect(r.isOk, isFalse);
    });

    test('when a draft is saved then the source and hash are written, it is '
        'not an undo step, and the build is refreshed', () async {
      final main = ScriptProjectRows.fileNamed(h.s.model, 'main.dart')!;
      final steps = h.s.services.undo.undoStepsOf(_stack).length;
      final source = '$_main\nvoid extra() {}\n';
      h.svc.setDraft(main.id, source);
      expect(h.svc.isDirty(main.id), isTrue);

      final r = await h.s.run('sheets.script.saveFile', {'fileId': main.id});
      await pumpScripts(20);

      expect(r.isOk, isTrue);
      final saved = ScriptProjectRows.file(h.s.model, main.id)!;
      expect(ScriptProjectRows.sourceOf(saved), source);
      expect(ScriptProjectRows.hashOf(saved), scriptContentHash(source));
      expect(h.s.services.undo.undoStepsOf(_stack).length, steps);
      expect(h.svc.isDirty(main.id), isFalse);
      expect(h.svc.exports.function('extra'), isNotNull);
    });
  });

  group('Given installable triggers', () {
    test('when a time-driven trigger is added then it asks for the triggers '
        'scope, stores the row and one undo removes it', () async {
      h.backend.granted = {ScriptScopes.triggers};
      await h.svc.refreshGrant();
      final r = await h.s.run('sheets.script.addTrigger', {
        'functionName': 'fill',
        'event': 'timeDriven',
        'schedule': {'type': 'hours', 'interval': 2},
      });

      expect(r.isOk, isTrue);
      final rows = ScriptProjectRows.triggers(h.s.model);
      expect(rows, hasLength(1));
      expect(rows.single.columns[ScriptCols.kind], 'timeDriven');

      await h.s.run('sheets.script.updateTrigger', {
        'triggerId': rows.single.id,
        'enabled': false,
      });
      expect(
        ScriptProjectRows.triggers(h.s.model).single.columns['enabled'],
        isFalse,
      );

      await h.s.undo();
      await h.s.undo();
      expect(ScriptProjectRows.triggers(h.s.model), isEmpty);
    });
  });

  group('Given the service lifecycle', () {
    test('when the project is deleted then custom functions and menus are '
        'removed', () async {
      await h.s.run('sheets.script.deleteProject');
      await pumpScripts(10);

      expect(scriptProjectOf(h.s.model), isNull);
      expect(h.svc.program, isNull);
      expect(h.svc.menus, isEmpty);
      expect(ScriptService.maybeOf(h.s.editor), same(h.svc));
    });
  });
}
