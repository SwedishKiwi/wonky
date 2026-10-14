import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

const _source = '''
import 'package:wonky/wonky.dart';

void onOpen(OpenEvent e) {
  SpreadsheetApp.ui
      .createMenu('Report')
      .addItem('Highlight', 'highlight')
      .addSeparator()
      .addSubMenu(SpreadsheetApp.ui.createMenu('Export').addItem('Archive', 'archive'))
      .addToUi();
  Logger.log('auth \${e.authMode.name}');
}

void onEdit(EditEvent e) {
  final range = e.range;
  if (range.column != 1) return;
  range.offset(0, 1).value = 'edited \${e.value} (was \${e.oldValue})';
}

void onSelectionChange(SelectionChangeEvent e) {
  SpreadsheetApp.active.toast('Selected \${e.range.a1Notation}');
}

void highlight() {
  SpreadsheetApp.activeRange.background = '#FFFF00';
}

void archive() {}

void fetchSomething() {
  UrlFetchApp.fetch('https://example.com/data');
}
''';

void main() {
  late ScriptProgram program;
  setUpAll(() => program = compileScript({'main.dart': _source}));

  group('Given a script session', () {
    late WorkbookModel model;
    late ModelWorkbookAccess access;
    late FakeScriptUi ui;
    late ScriptSession session;

    setUp(() {
      model = conformanceWorkbook();
      access = ModelWorkbookAccess(model: model, userId: testUser.id);
      ui = FakeScriptUi();
      session = ScriptSession(
        workbook: access,
        uiRunner: InlineScriptRunner(),
        user: testUser,
        role: Role.editor,
        ui: ui,
        timeZones: const FixedOffsetResolver(),
      )..setProgram(program);
    });
    tearDown(() async {
      await session.close();
      access.dispose();
    });

    test('when onOpen runs then the menus are registered', () async {
      final r = await session.fireSimpleTrigger(
        ExecutionKind.onOpen,
        const OpenEventData(),
      );
      expect(r!.status, ExecutionStatus.completed, reason: '${r.error}');
      final menu = session.menus.single;
      expect(menu.caption, 'Report');
      expect(menu.items.first.functionName, 'highlight');
      expect(menu.items[1].separator, isTrue);
      expect(menu.items[2].items.single.caption, 'Archive');
      expect(ui.menus, hasLength(1));
      expect(r.logs.single.message, 'auth limited');
    });

    test(
      'when the user authorized the scopes then onOpen runs with full auth',
      () async {
        session.grantedScopes = {'external_request'};
        final r = await session.fireSimpleTrigger(
          ExecutionKind.onOpen,
          const OpenEventData(),
        );
        expect(r!.logs.single.message, 'auth full');
      },
    );

    test(
      'when onEdit fires then it sees the edited range and values',
      () async {
        final sheetId = model.sheets.first.id;
        final r = await session.fireSimpleTrigger(
          ExecutionKind.onEdit,
          EditEventData(
            sheetId: sheetId,
            range: const GridRect(0, 0, 0, 0),
            value: 1,
            oldValue: 0,
          ),
        );
        expect(r!.status, ExecutionStatus.completed, reason: '${r.error}');
        expect(
          access.engine.valueAt(sheetId, 0, 1).toCellValue(),
          const TextValue('edited 1 (was 0)'),
        );
        expect(r.applied, hasLength(1));
      },
    );

    test('when a menu item runs then it uses the selection', () async {
      final sheetId = model.sheets.first.id;
      session.selection = ScriptSelection(
        sheetId: sheetId,
        ranges: const [GridRect(1, 1, 2, 2)],
      );
      final r = await session.run('highlight', kind: ExecutionKind.menu);
      expect(r.status, ExecutionStatus.completed);
      expect(
        EffectiveFormatResolver(model).resolve(sheetId, 2, 2).fillColor,
        '#FFFF00',
      );
    });

    test(
      'when onSelectionChange shows a toast then the UI receives it',
      () async {
        await session.fireSimpleTrigger(
          ExecutionKind.onSelectionChange,
          SelectionChangeEventData(
            sheetId: model.sheets.first.id,
            range: const GridRect(3, 3, 3, 3),
          ),
        );
        expect(ui.toasts, ['Selected D4']);
      },
    );

    test('when a trigger is not declared then nothing runs', () async {
      expect(
        await session.fireSimpleTrigger(
          ExecutionKind.onChange,
          const ChangeEventData('EDIT'),
        ),
        isNull,
      );
    });

    test('then the build needs the external_request scope', () {
      expect(session.missingScopes(), {'external_request'});
    });

    test('when a build needs a newer API then it is not installed', () {
      final newer = ScriptProgram(
        buildHash: 'x',
        bytecode: program.bytecode,
        exports: const ScriptExports(apiVersion: 99),
      );
      expect(session.setProgram(newer), isFalse);
      expect(session.program, isNull);
    });

    test('when executions finish then they are published', () async {
      final results = <ExecutionResult>[];
      session.executions.listen(results.add);
      await session.run('archive', kind: ExecutionKind.editor);
      await Future<void>.delayed(Duration.zero);
      expect(results.single.functionName, 'archive');
    });
  });
}
