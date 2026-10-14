import 'package:test/test.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

const _source = r'''
import 'package:wonky/wonky.dart';

UiPanel _form(String note) => UiPanel(title: 'Import', children: [
  UiText('Choose a **source**'),
  UiSelect(id: 'source', options: ['CRM', 'Shop'], value: 'CRM'),
  UiTextField(id: 'from', label: 'From date', type: 'date'),
  UiCheckbox(id: 'clear', label: 'Clear sheet first'),
  UiTable(headers: ['A'], rows: [[1], [null]]),
  UiRow(children: [
    UiButton('Import', onClick: 'runImport', primary: true),
    UiButton('Close', onClick: '_close'),
  ]),
  UiText(note),
]);

void open() {
  SpreadsheetApp.ui.showSidebar(_form(''));
}

void dialog() {
  SpreadsheetApp.ui.showModalDialog(_form(''), 'Import data');
}

void runImport(UiEvent e) {
  SpreadsheetApp.activeSheet.getRange('A1').value = '${e.values['source']} ${e.button}';
  e.panel.update(_form('Imported'));
  if (e.values['clear'] == true) e.panel.close();
}

void bad() {
  SpreadsheetApp.ui.showSidebar(UiPanel(title: 'x', children: [UiButton('Go', onClick: 'nope')]));
}
''';

void main() {
  late ScriptProgram program;
  setUpAll(() => program = compileScript({'main.dart': _source}));

  group('Given the UI DSL (09 §16.3)', () {
    late ScriptTestBench bench;
    late FakeScriptUi ui;
    setUp(() {
      bench = ScriptTestBench(conformanceWorkbook());
      ui = FakeScriptUi();
    });
    tearDown(() => bench.dispose());

    test(
      'when a sidebar is shown then the validated panel reaches the UI',
      () async {
        final r = await bench.run(program, 'open', ui: ui);
        expect(r.status, ExecutionStatus.completed, reason: '${r.error}');
        final p = ui.panels.single;
        expect(p.mode, ScriptPanelMode.sidebar);
        expect(p.id, 'main');
        final children = p.panel['children']! as List;
        expect((children[1] as Map)['options'], ['CRM', 'Shop']);
        expect((children[4] as Map)['rows'], [
          ['1'],
          [''],
        ]);
        final row = (children[5] as Map)['children']! as List;
        expect((row.first as Map)['onClick'], 'runImport');
      },
    );

    test('when a dialog is shown then it has its title', () async {
      await bench.run(program, 'dialog', ui: ui);
      expect(ui.panels.single.mode, ScriptPanelMode.dialog);
      expect(ui.panels.single.dialogTitle, 'Import data');
    });

    test('when a button runs its function then it gets the values and can '
        'update and close the panel', () async {
      final r = await bench.run(
        program,
        'runImport',
        kind: ExecutionKind.menu,
        ui: ui,
        event: const UiEventData(
          panelId: 'main',
          values: {'source': 'Shop', 'clear': true},
          button: 'Import',
        ),
      );
      expect(r.status, ExecutionStatus.completed, reason: '${r.error}');
      expect(bench.value('A1'), 'Shop Import');
      expect(ui.panelUpdates.single.$1, 'main');
      expect(ui.closedPanels, ['main']);
    });

    test(
      'when a button names an unknown function then the call fails',
      () async {
        final r = await bench.run(program, 'bad', ui: ui);
        expect(r.status, ExecutionStatus.failed);
        expect(r.error!.message, contains('nope'));
      },
    );

    test('when run on the server then panels are unavailable', () async {
      final r = await bench.run(program, 'open', ui: ui, isServer: true);
      expect(r.error?.type, 'UiUnavailableException');
    });
  });
}
