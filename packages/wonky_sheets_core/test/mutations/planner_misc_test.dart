import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

void main() {
  late PlannerHarness h;
  setUp(
    () => h = PlannerHarness(
      WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 5),
    ),
  );

  group('Given objects and pivots', () {
    test('when adding objects then titles and z-order are assigned', () {
      final a = h.apply(
        AddObject(
          h.sheetId,
          EmbeddedObjectKind.chart,
          anchorJson: '{}',
          specJson: '{"v":1}',
        ),
      );
      final b = h.apply(
        AddObject(
          h.sheetId,
          EmbeddedObjectKind.chart,
          anchorJson: '{}',
          specJson: '{"v":1}',
        ),
      );
      final s = h.model.sheets.first;
      expect(s.objects[a.result['objectId']]!.title, 'Chart 1');
      expect(s.objects[b.result['objectId']]!.zIndex, 1);
      h.apply(UpdateObject(b.result['objectId']! as String, title: 'Revenue'));
      expect(s.objects[b.result['objectId']]!.title, 'Revenue');
      h.apply(DeleteObject(a.result['objectId']! as String));
      expect(s.objects, hasLength(1));
    });

    test('when an object moves to another sheet then it leaves the old sheet '
        'and keeps all its columns (08 §11)', () {
      final id =
          h
                  .apply(
                    AddObject(
                      h.sheetId,
                      EmbeddedObjectKind.image,
                      anchorJson: '{}',
                      specJson: '{"v":1}',
                      altText: 'Logo',
                    ),
                  )
                  .result['objectId']!
              as String;
      final other =
          h
                  .apply(
                    const AddSheet(name: 'Chart sheet', kind: SheetKind.chart),
                  )
                  .result['sheetId']!
              as String;

      h.apply(UpdateObject(id, sheetId: other, anchorJson: '{"v":1}'));

      expect(h.model.sheet(h.sheetId)!.objects, isEmpty);
      final moved = h.model.sheet(other)!.objects[id]!;
      expect(moved.kind, EmbeddedObjectKind.image);
      expect(moved.altText, 'Logo');
      expect(moved.title, 'Image 1');
    });

    test(
      'when a row with an object anchor is deleted then the object re-anchors (A-08-4)',
      () {
        final s = h.model.sheets.first;
        final anchor = jsonEncode({
          'v': 1,
          'rowId': s.rows.idAt(3),
          'colId': s.columns.idAt(0),
          'dx': 5.0,
          'dy': 5.0,
          'width': 100.0,
          'height': 50.0,
        });
        final id =
            h
                    .apply(
                      AddObject(
                        s.id,
                        EmbeddedObjectKind.image,
                        anchorJson: anchor,
                        specJson: '{}',
                      ),
                    )
                    .result['objectId']!
                as String;
        final next = s.rows.idAt(4);
        h.apply(DeleteDimension(s.id, Dimension.rows, [s.rows.idAt(3)]));
        final a = jsonDecode(s.objects[id]!.anchorJson) as Map;
        expect(a['dx'], 0.0);
        expect(a['rowId'], isNot(contains('-')));
        expect(h.model.sheets.first.rows.indexOf(next), 3);
      },
    );

    test('when adding and updating a pivot then anchors use ids', () {
      final p = h.apply(
        AddPivotTable(h.sheetId, 0, 3, h.range('A1:B5'), '{"v":1}'),
      );
      final id = p.result['pivotId']! as String;
      h.apply(UpdatePivotTable(id, anchorRow: 2));
      final s = h.model.sheets.first;
      expect(s.pivots[id]!.anchorRowId, s.rows.idAt(2));
    });
  });

  group('Given sheet and spreadsheet settings', () {
    test('when freezing beyond the grid then it is refused', () {
      expect(
        () => h.plan(SetFrozen(h.sheetId, rows: 10)),
        throwsA(isA<PlanException>()),
      );
      h.apply(SetFrozen(h.sheetId, rows: 1, columns: 1));
      expect(h.model.sheets.first.record!.frozenRows, 1);
    });

    test(
      'when setting the theme then themeJson and the default font are written',
      () {
        h.apply(
          SetSpreadsheetProperties(
            themeJson: SpreadsheetTheme.preset('Ocean')!.toJson(),
          ),
        );
        expect(h.model.theme.name, 'Ocean');
        expect(h.model.spreadsheet.defaultFontFamily, 'Montserrat');
      },
    );

    test('when patching print settings then the JSON merges', () {
      h.apply(
        SetPrintSettings(
          [h.sheetId],
          {
            'paper': 'a4',
            'margins': {'preset': 'narrow'},
          },
        ),
      );
      h.apply(
        SetPrintSettings(
          [h.sheetId],
          {
            'margins': {'preset': 'wide'},
            'gridlines': true,
          },
        ),
      );
      final m =
          jsonDecode(h.model.sheets.first.record!.printSettingsJson!) as Map;
      expect(m, {
        'paper': 'a4',
        'margins': {'preset': 'wide'},
        'gridlines': true,
      });
    });

    test('when protecting a range and banding it then records are created', () {
      h.apply(
        AddProtection(
          h.sheetId,
          range: const GridRect(0, 0, 2, 2),
          editors: ['u1'],
        ),
      );
      h.apply(
        AddBanding(
          h.sheetId,
          const GridRect(0, 0, 4, 2),
          const BandingStyle().toJson(),
        ),
      );
      h.apply(
        AddBanding(
          h.sheetId,
          const GridRect(2, 0, 6, 2),
          const BandingStyle().toJson(),
        ),
      );
      final s = h.model.sheets.first;
      expect(s.protections.values.single.editorsJson, '["u1"]');
      expect(s.bandings, hasLength(1));
    });

    test(
      'when creating a spreadsheet then the first sheet has the default grid',
      () {
        final m = WorkbookModel(
          spreadsheetId: '00000000-0000-4000-8000-00000000aaaa',
        );
        final p = const SheetsMutationPlanner().plan(
          const CreateSpreadsheet(
            spreadsheetId: '00000000-0000-4000-8000-00000000aaaa',
            title: 'Budget',
          ),
          m,
          h.ctx,
        );
        m.applyPlan(p);
        expect(m.spreadsheet.title, 'Budget');
        expect(m.sheets.single.rows.length, 1000);
        expect(m.sheets.single.columns.length, 26);
      },
    );

    test('when creating a spreadsheet with the user defaults then locale, time '
        'zone, theme font and size are set', () {
      final m = WorkbookModel(
        spreadsheetId: '00000000-0000-4000-8000-00000000aaab',
      );
      m.applyPlan(
        const SheetsMutationPlanner().plan(
          const CreateSpreadsheet(
            spreadsheetId: '00000000-0000-4000-8000-00000000aaab',
            locale: 'de_DE',
            timeZone: 'Europe/Berlin',
            fontFamily: 'Lato',
            fontSize: 11,
          ),
          m,
          h.ctx,
        ),
      );
      expect(m.spreadsheet.locale, 'de_DE');
      expect(m.spreadsheet.timeZone, 'Europe/Berlin');
      expect(m.theme.textFont, 'Lato');
      expect(m.spreadsheet.defaultFontSize, 11);
    });

    test('when hiding the only visible sheet then it is refused', () {
      expect(
        () => h.plan(SetSheetProperties(h.sheetId, hidden: true)),
        throwsA(isA<PlanException>()),
      );
    });
  });

  group('Given duplicate names after a merge', () {
    test('when running maintenance then the larger id gets a suffix', () {
      final b = WorkbookBuilder()
        ..sheet('Data', rows: 2, cols: 2)
        ..sheet('data', rows: 2, cols: 2);
      final hh = PlannerHarness(b);
      final p = WorkbookMaintenance.plan(hh.model, hh.ctx);
      hh.model.applyPlan(p);
      expect(hh.model.sheets.map((s) => s.name), ['Data', 'data (2)']);
      expect(WorkbookMaintenance.plan(hh.model, hh.ctx).isEmpty, isTrue);
    });
  });
}
