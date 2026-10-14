import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/pivot/pivot_controller.dart';
import 'package:wonky_sheets/features/pivot/ui/pivot_editor_panel.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

/// [testWidgets] that lets debounce timers (refresh, toasts) run out.
void pivotTestWidgets(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pump(const Duration(seconds: 5));
    });

void main() {
  late SheetsHarness s;
  late String dataSheet;
  late String pivotId;

  Future<void> seed() async {
    final rows = [
      ['Region', 'Product', 'Revenue'],
      ['East', 'Apples', '10'],
      ['West', 'Apples', '20'],
      ['East', 'Pears', '5'],
    ];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        await s.type('${'ABC'[c]}${r + 1}', rows[r][c]);
      }
    }
    final r = await s.run('sheets.insert.pivotTable', {
      'range': 'Sheet1!A1:C4',
    });
    pivotId = (r.data! as Map)['pivotId'] as String;
  }

  PivotSpec spec() => PivotController.of(s.editor).service.byId(pivotId)!.spec;

  String col(int i) => s.model.sheet(dataSheet)!.columns.idAt(i);

  Future<void> pumpPanel(
    WidgetTester tester, {
    bool dark = false,
    double width = 360,
    double height = 900,
  }) => pumpSheets(
    tester,
    s,
    dark: dark,
    size: Size(1200, height),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: height,
        child: PivotEditorPanel(editor: s.editor),
      ),
    ),
  );

  setUp(() {
    s = SheetsHarness.open();
    dataSheet = s.sheetId;
  });
  tearDown(() => s.dispose());

  group('Given a new pivot table', () {
    pivotTestWidgets('when the panel opens then the four areas and suggestions '
        'show, in light and dark', (tester) async {
      await seed();
      for (final dark in [false, true]) {
        await pumpPanel(tester, dark: dark);

        expect(find.byKey(const ValueKey('pivot.area.row')), findsOneWidget);
        expect(find.byKey(const ValueKey('pivot.area.filter')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('pivot.suggestion.0')),
          findsOneWidget,
        );
      }
    });

    pivotTestWidgets(
      'when a suggestion is clicked then the spec is applied in one '
      'step',
      (tester) async {
        await seed();
        await pumpPanel(tester);
        final before = s.h.undoLabels.length;

        await tester.tap(find.byKey(const ValueKey('pivot.suggestion.0')));
        await tester.pumpAndSettle();

        expect(spec().rows.single.source, col(0));
        expect(spec().values.single.source, col(2));
        expect(s.h.undoLabels.length, before + 1);
        expect(s.text('B2'), '15');
      },
    );

    pivotTestWidgets(
      'when a field is added from the Add list then it appears as '
      'a card',
      (tester) async {
        await seed();
        await pumpPanel(tester);

        await tester.tap(find.byKey(const ValueKey('pivot.add.row')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('pivot.addField.row.1')));
        await tester.pumpAndSettle();

        expect(spec().rows.single.source, col(1));
        expect(find.byKey(const ValueKey('pivot.card.row.0')), findsOneWidget);
      },
    );

    pivotTestWidgets(
      'when typing in the field search and pressing Enter then the '
      'matching field is added to Values with SUM',
      (tester) async {
        await seed();
        await pumpPanel(tester);

        await tester.tap(find.byKey(const ValueKey('pivot.add.value')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('pivot.addField.search.value')),
          'rev',
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(spec().values.single.source, col(2));
        expect(spec().values.single.summarizeBy, PivotSummarize.sum);
      },
    );

    pivotTestWidgets(
      'when a card is dragged from Rows to Columns then the field '
      'moves',
      (tester) async {
        await seed();
        await s.run('sheets.pivot.update', {
          'pivotId': pivotId,
          'spec': {
            'rows': [
              {'source': col(0)},
            ],
          },
        });
        await pumpPanel(tester);

        final handle = find.descendant(
          of: find.byKey(const ValueKey('pivot.card.row.0')),
          matching: find.byWidgetPredicate((w) => w is Draggable),
        );
        final target = find.byKey(const ValueKey('pivot.drop.column'));
        final g = await tester.startGesture(tester.getCenter(handle.first));
        await tester.pump(const Duration(milliseconds: 50));
        await g.moveTo(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 50));
        await g.up();
        await tester.pumpAndSettle();

        expect(spec().rows, isEmpty);
        expect(spec().columns.single.source, col(0));
      },
    );

    pivotTestWidgets(
      'when the remove button of a card is clicked then the field '
      'goes away',
      (tester) async {
        await seed();
        await s.run('sheets.pivot.update', {
          'pivotId': pivotId,
          'spec': {
            'rows': [
              {'source': col(0)},
            ],
          },
        });
        await pumpPanel(tester);

        await tester.tap(find.byKey(const ValueKey('pivot.card.remove.row.0')));
        await tester.pumpAndSettle();

        expect(spec().rows, isEmpty);
      },
    );

    pivotTestWidgets(
      'when the panel is 300 px wide with every area filled then '
      'nothing overflows',
      (tester) async {
        await seed();
        await s.run('sheets.pivot.update', {
          'pivotId': pivotId,
          'spec': {
            'rows': [
              {'source': col(0)},
            ],
            'columns': [
              {'source': col(1)},
            ],
            'values': [
              {'source': col(2), 'summarizeBy': 'sum'},
              {'source': col(2), 'summarizeBy': 'average'},
            ],
            'filters': [
              {'source': col(0), 'criteria': <String, Object?>{}},
            ],
          },
        });

        await pumpPanel(tester, width: 300, height: 2400);
        await pumpPanel(tester, width: 300, height: 2400, dark: true);

        expect(tester.takeException(), isNull);
        expect(spec().filters, hasLength(1));
        expect(
          find.byKey(const ValueKey('pivot.filterButton.0')),
          findsOneWidget,
        );
      },
    );
  });

  group('Given a pivot with a Region filter', () {
    for (final dark in [false, true]) {
      pivotTestWidgets('when filtering by a custom formula and a fill color '
          '(${dark ? 'dark' : 'light'}) then the criteria are stored in '
          'stored form and the output follows', (tester) async {
        await seed();
        await s.run('sheets.format.fillColor', {
          'ranges': ['Sheet1!A2'],
          'color': '#FF0000',
        });
        await s.run('sheets.pivot.update', {
          'pivotId': pivotId,
          'spec': {
            'rows': [
              {'source': col(0)},
            ],
            'values': [
              {'source': col(2), 'summarizeBy': 'sum'},
            ],
            'filters': [
              {
                'source': col(0),
                'criteria': {
                  'condition': {
                    'type': 'customFormula',
                    'values': [
                      {
                        'v': s.editor.hooks.toStored(
                          '=C2>6',
                          sheetId: dataSheet,
                          row: 1,
                          col: 0,
                          locale: s.editor.locale,
                        ),
                      },
                    ],
                  },
                },
              },
            ],
          },
        });
        await pumpPanel(tester, dark: dark, height: 1400);
        // East 10 and West 20 pass (Pears 5 doesn't).
        expect(s.text('B2'), '10');
        expect(s.text('B3'), '20');

        await tester.tap(find.byKey(const ValueKey('pivot.filterButton.0')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('pivot.filter.fill')), findsOneWidget);
        final field = find.descendant(
          of: find.byKey(const ValueKey('pivot.filter.value1')),
          matching: find.byType(EditableText),
        );
        expect(tester.widget<EditableText>(field).controller.text, '=C2>6');
        await tester.enterText(field, '=C2>15');
        await tester.tap(find.byKey(const ValueKey('pivot.filter.apply')));
        await tester.pumpAndSettle();

        final c = spec().filters.single.criteria.condition!;
        expect(c.type, ConditionType.customFormula);
        final stored = (c.values.single as ConditionFormula).stored;
        expect(stored, isNot(contains('C2')), reason: 'stored form');
        expect(s.text('A2'), 'West');
        expect(s.text('B2'), '20');
        expect(tester.takeException(), isNull);
      });
    }

    pivotTestWidgets('when "Show items with no data" is checked then the '
        'spec keeps it in one step', (tester) async {
      await seed();
      await s.run('sheets.pivot.update', {
        'pivotId': pivotId,
        'spec': {
          'rows': [
            {'source': col(0)},
          ],
        },
      });
      await pumpPanel(tester);
      final before = s.h.undoLabels.length;

      await tester.tap(find.byKey(const ValueKey('pivot.showEmptyGroups')));
      await tester.pumpAndSettle();

      expect(spec().showEmptyGroups, isTrue);
      expect(s.h.undoLabels.length, before + 1);
    });
  });

  group('Given a pivot on the grid', () {
    pivotTestWidgets(
      'when the active cell is in the output then the Edit button '
      'shows and opens the editor',
      (tester) async {
        await seed();
        await s.run('sheets.pivot.update', {
          'pivotId': pivotId,
          'spec': {
            'rows': [
              {'source': col(0)},
            ],
          },
        });
        PivotController.of(s.editor).editing.value = null;
        await pumpSheets(
          tester,
          s,
          child: GridArea(controller: s.editor, services: s.services),
        );
        await s.select('A2');
        await tester.pump();

        final button = find.byKey(const ValueKey('sheets.pivot.editButton'));
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pump();

        expect(PivotController.of(s.editor).editing.value, pivotId);
        expect(s.services.panels.isOpen(PivotController.panelId), isTrue);
      },
    );

    pivotTestWidgets(
      'when the active cell leaves the output then the Edit button '
      'hides',
      (tester) async {
        await seed();
        await pumpSheets(
          tester,
          s,
          child: GridArea(controller: s.editor, services: s.services),
        );
        await s.select('E9');
        await tester.pump();

        expect(
          find.byKey(const ValueKey('sheets.pivot.editButton')),
          findsNothing,
        );
      },
    );
  });
}
