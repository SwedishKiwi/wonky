import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/formatting/sheets_user_defaults.dart';
import 'package:wonky_sheets/features/scripts/local/script_local_store.dart';
import 'package:wonky_sheets/features/scripts/script_project.dart';
import 'package:wonky_sheets_core/model.dart' show SheetsTables;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import 'script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

/// @customfunction
Object? TWICE(Object? x) => x is num ? x * 2 : null;

void chatty() {
  Logger.log('one');
  Logger.log('two');
}

void fill() {
  SpreadsheetApp.activeSheet.getRange('A1').value = 7;
}
''';

void main() {
  group('Given the device-local script store (09 §19 A-09-7)', () {
    late ScriptHarness h;
    setUp(() async => h = await ScriptHarness.open({'main.dart': _main}));
    tearDown(() => h.dispose());

    test('when a build is installed then its bytecode is cached locally', () {
      final hash = h.svc.program!.buildHash;
      expect(h.local.blobs.keys, contains(hash));
    });

    test('when the spreadsheet is reopened offline then the cached build '
        'installs without the server', () async {
      final local = h.local;
      final hash = h.svc.program!.buildHash;
      await h.dispose();
      h = await ScriptHarness.open({'main.dart': _main}, local: local);
      // A fresh in-memory cache and no server bytecode: only the local
      // store has it.
      // The synced build row names the last good build.
      h.s.model.upsertRow(SheetsTables.scriptBuild, 'build', {
        ScriptCols.projectId: h.svc.project!.id,
        'status': 'ok',
        'lastGoodSourceHash': hash,
        'lastGoodExportsJson': h.svc.exports.encode(),
      });
      h.backend.last = null;
      h.s.services.connectivity.forceOffline(true);
      h.svc.forgetBuild();
      expect(h.svc.program, isNull);
      await h.svc.reloadBuild();
      expect(h.svc.program?.buildHash, hash);
      h.s.services.connectivity.forceOffline(false);
    });

    test('when a function runs offline then the execution waits in the '
        'local log and is uploaded later', () async {
      h.s.services.connectivity.forceOffline(true);
      await h.svc.run('fill');
      await pumpScripts();
      expect(h.local.executions, isNotEmpty);
      expect(h.backend.reported, isEmpty);

      h.s.services.connectivity.forceOffline(false);
      await h.svc.uploadExecutions();

      expect(h.backend.reported.map((e) => e.functionName), contains('fill'));
      expect(h.local.executions, isEmpty);
    });

    test('when a file has unsaved changes then the draft is stored and '
        'restored after a reload', () async {
      final main = ScriptProjectRows.fileNamed(h.s.model, 'main.dart')!;
      h.svc.setDraft(main.id, '$_main\nvoid draft() {}\n');
      await h.svc.flushDrafts();
      final key = h.s.editor.session.itemUuid.uuid;
      expect(h.local.draftsBySpreadsheet[key]!.single.fileId, main.id);

      // A reload: the editor content is gone, the store still has it.
      h.svc.clearDraft(main.id);
      await h.svc.flushDrafts();
      await h.local.saveDrafts(key, [
        ScriptDraft(
          fileId: main.id,
          text: '$_main\nvoid draft() {}\n',
          baseHash: ScriptProjectRows.hashOf(main),
          baseText: _main,
        ),
      ]);
      await h.svc.restoreDrafts();

      expect(h.svc.isDirty(main.id), isTrue);
      expect(h.svc.drafts[main.id], contains('void draft()'));
      expect(h.svc.baseSources[main.id], _main);
    });

    test('when a file is saved then the version is kept in the local '
        'history', () async {
      final main = ScriptProjectRows.fileNamed(h.s.model, 'main.dart')!;
      h.svc.setDraft(main.id, '$_main\nvoid v2() {}\n');
      await h.svc.save(main.id, compileAfter: false);
      await pumpScripts();

      final versions = await h.svc.historyOf(main.id);
      expect(versions.first.source, contains('void v2()'));
      expect(versions.first.note, 'saved');
    });

    test('when a restored version is applied then it becomes a draft', () {
      final main = ScriptProjectRows.fileNamed(h.s.model, 'main.dart')!;
      h.svc.restoreDraft(main.id, 'void old() {}');
      expect(h.svc.isDirty(main.id), isTrue);
      expect(h.svc.drafts[main.id], 'void old() {}');
    });
  });

  group('Given live logs (09 §14.1)', () {
    late ScriptHarness h;
    setUp(() async => h = await ScriptHarness.open({'main.dart': _main}));
    tearDown(() => h.dispose());

    test('when a function logs then each line is in the log once', () async {
      h.svc.log.clear();
      await h.svc.run('chatty');
      await pumpScripts();
      final messages = [
        for (final l in h.svc.log)
          if (l.function == 'chatty') l.entry.message,
      ];
      expect(messages, ['one', 'two']);
    });
  });

  group('Given scripts turned off for the user (09 §11.3)', () {
    late ScriptHarness h;
    setUp(() async => h = await ScriptHarness.open({'main.dart': _main}));
    tearDown(() => h.dispose());

    test('when a function is run then nothing runs and custom functions '
        'report that scripts are disabled', () async {
      await SheetsUserDefaults.of(
        h.s.services,
      ).set(SheetsUserDefaults.keyScriptsEnabled, false);
      await pumpScripts();
      expect(h.svc.scriptsEnabled, isFalse);

      final r = await h.svc.run('fill');
      expect(r, isNull);
      expect(h.s.text('A1'), '');

      await h.s.type('B1', '=TWICE(2)');
      await pumpScripts();
      expect(h.s.text('B1'), '#ERROR!');

      await SheetsUserDefaults.of(
        h.s.services,
      ).set(SheetsUserDefaults.keyScriptsEnabled, true);
      await pumpScripts();
      expect(h.svc.scriptsEnabled, isTrue);
      final ok = await h.svc.run('fill');
      expect(ok?.status, ExecutionStatus.completed);
    });
  });

  group('Given the memory store', () {
    test('when more than 20 versions are kept then the oldest drop', () async {
      final store = MemoryScriptLocalStore();
      for (var i = 0; i < 25; i++) {
        await store.addHistory(
          ScriptHistoryEntry(
            fileId: 'f',
            savedAt: DateTime.utc(2026, 1, 1, 0, i),
            source: 'v$i',
          ),
        );
      }
      final h = await store.history('f');
      expect(h, hasLength(ScriptLocalStore.maxHistory));
      expect(h.first.source, 'v24');
    });

    test('when the same source is kept twice then it is stored once', () async {
      final store = MemoryScriptLocalStore();
      for (var i = 0; i < 2; i++) {
        await store.addHistory(
          ScriptHistoryEntry(
            fileId: 'f',
            savedAt: DateTime.utc(2026),
            source: 'x',
          ),
        );
      }
      expect(await store.history('f'), hasLength(1));
    });
  });
}
