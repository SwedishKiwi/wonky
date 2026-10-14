import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/model/memory_workbook_session.dart';
import 'package:wonky_sheets/features/pivot/pivot_overlay_service.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

void main() {
  late MemoryWorkbookSession session;
  late PivotOverlayService service;
  late String sheetId;

  WorkbookModel model() => session.model;

  void put(String a1, List<List<String>> rows) {
    final at = model().parseA1(a1, contextSheetId: sheetId);
    session.execute(
      SetCellInputs(
        sheetId: at.sheetId,
        row: at.rect.top,
        col: at.rect.left,
        inputs: [
          for (final r in rows) [for (final v in r) CellInput.user(v)],
        ],
      ),
    );
  }

  String col(int i) => model().sheet(sheetId)!.columns.idAt(i);

  String addPivot(String anchor, Map<String, Object?> spec) {
    final at = model().parseA1(anchor, contextSheetId: sheetId);
    final plan = session.execute(
      AddPivotTable(
        at.sheetId,
        at.rect.top,
        at.rect.left,
        model().parseA1('A1:C5', contextSheetId: sheetId),
        PivotSpec.parse(spec).encode(),
      ),
    );
    return plan.result['pivotId']! as String;
  }

  String text(String a1) {
    final r = model().parseA1(a1, contextSheetId: sheetId);
    return session.engine.engine
        .valueAt(r.sheetId, r.rect.top, r.rect.left)
        .toCellValue()
        .toString();
  }

  Map<String, Object?> byRegion() => {
    'rows': [
      {'source': col(0)},
    ],
    'values': [
      {'source': col(2), 'summarizeBy': 'sum'},
    ],
  };

  setUp(() {
    session = MemoryWorkbookSession.blank();
    sheetId = model().sheets.first.id;
    put('A1', [
      ['Region', 'Product', 'Units'],
      ['East', 'A', '1'],
      ['West', 'A', '2'],
      ['East', 'B', '3'],
      ['West', 'B', '4'],
    ]);
    service = PivotOverlayService(
      model: model(),
      engine: session.engine.engine,
      debounce: const Duration(days: 1),
    )..attach(session.engine.view);
  });
  tearDown(() async {
    service.dispose();
    await session.dispose();
  });

  group('Given a pivot anchored at F1', () {
    test('when the pivot is added then its output is an overlay the engine '
        'reads', () {
      final id = addPivot('F1', byRegion());

      final o = service.byId(id)!;
      expect(o.rect, const GridRect(0, 5, 3, 6));
      expect(text('F2'), 'TextValue(East)');
      expect(text('G2'), 'NumberValue(4.0)');
      expect(text('G4'), 'NumberValue(10.0)');
      expect(service.outputAt(sheetId, 3, 6)?.id, id);
    });

    test('when a cell in the output rectangle has content then the anchor '
        'shows the collision error naming it', () {
      put('G3', [
        ['x'],
      ]);

      final id = addPivot('F1', byRegion());

      final o = service.byId(id)!;
      expect(o.problem, PivotProblem.collision);
      expect(o.error?.message, contains('G3'));
      expect(o.rect, GridRect.cell(0, 5));
    });

    test('when two pivots overlap then the earlier anchor wins', () {
      final first = addPivot('F1', byRegion());
      final second = addPivot('F3', byRegion());

      expect(service.byId(first)!.hasOutput, isTrue);
      expect(service.byId(second)!.problem, PivotProblem.collision);
    });

    test('when the output needs more rows than the sheet has then it shows '
        'the grid edge error', () {
      final rows = model().sheet(sheetId)!.rows.length;

      final id = addPivot('F${rows - 1}', byRegion());

      final o = service.byId(id)!;
      expect(o.problem, PivotProblem.gridEdge);
      expect(o.missingRows, 2);
    });

    test('when a source value changes then the output updates after the '
        'debounce (flush)', () {
      final id = addPivot('F1', byRegion());
      put('C2', [
        ['10'],
      ]);

      expect(service.byId(id)!.stale, isTrue);
      service.flush();

      expect(text('G2'), 'NumberValue(13.0)');
    });

    test('when the pivot is deleted then its overlay disappears', () {
      final id = addPivot('F1', byRegion());

      session.execute(DeletePivotTable(id));

      expect(service.byId(id), isNull);
      expect(text('F2'), 'EmptyValue');
    });

    test('when an empty spec is used then the pivot shows its message and no '
        'values', () {
      final id = addPivot('F1', const {});

      expect(service.byId(id)!.message, PivotGrid.emptyMessage);
      expect(text('F1'), 'EmptyValue');
    });
  });

  group('Given dynamic arrays next to a pivot', () {
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('when an array anchored earlier spills over the pivot then the array '
        'wins and the pivot comes back once the array is gone', () async {
      final id = addPivot('F2', byRegion());
      expect(service.byId(id)!.hasOutput, isTrue);

      put('F1', [
        ['=SEQUENCE(3)'],
      ]);
      text('F1');
      await settle();
      text('F1');
      await settle();

      final o = service.byId(id)!;
      expect(o.problem, PivotProblem.collision);
      expect(o.yielded, isTrue, reason: 'the array covers the anchor');
      expect(text('F2'), 'NumberValue(2.0)');
      expect(text('F3'), 'NumberValue(3.0)');

      put('F1', [
        [''],
      ]);
      await settle();
      service.flush();
      expect(service.byId(id)!.hasOutput, isTrue);
      expect(text('F3'), 'TextValue(East)');
    });

    test('when an array anchored later would spill into the output (even '
        'blank cells) then the pivot wins and the array shows #SPILL!', () {
      final id = addPivot('F2', byRegion());
      // F2 is the empty corner of the header? The field-name row: F2 =
      // "Region", G2 = "SUM of Units"; a row array from E3 runs into F3:G3.
      put('E3', [
        ['=SEQUENCE(1,3)'],
      ]);

      expect(service.byId(id)!.hasOutput, isTrue);
      expect(text('E3'), contains('ErrorValue'));
    });
  });

  group('Given a big source (background compute)', () {
    late PivotOverlayService bg;
    setUp(() {
      service.dispose();
      bg = PivotOverlayService(
        model: model(),
        engine: session.engine.engine,
        debounce: const Duration(days: 1),
        backgroundRows: 2,
        useIsolate: false,
      )..attach(session.engine.view);
      service = bg;
    });

    test('when a pivot is added then it is computed time-sliced and placed '
        'when done; a source edit keeps the stale output until then', () async {
      final id = addPivot('F1', byRegion());
      expect(bg.isComputing(id), isTrue);
      expect(bg.byId(id), isNull);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bg.isComputing(id), isFalse);
      expect(text('G2'), 'NumberValue(4.0)');

      put('C2', [
        ['10'],
      ]);
      bg.flush();
      expect(bg.isComputing(id), isTrue);
      expect(bg.byId(id)!.stale, isTrue);
      expect(text('G2'), 'NumberValue(4.0)', reason: 'old output stays');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(text('G2'), 'NumberValue(13.0)');
      expect(bg.byId(id)!.stale, isFalse);
    });

    test('when the isolate is used then the result is the same', () async {
      bg.dispose();
      service = PivotOverlayService(
        model: model(),
        engine: session.engine.engine,
        debounce: const Duration(days: 1),
        backgroundRows: 2,
      )..attach(session.engine.view);
      final id = addPivot('F1', byRegion());
      expect(service.isComputing(id), isTrue);
      for (var i = 0; i < 100 && service.isComputing(id); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(text('G4'), 'NumberValue(10.0)');
    });
  });

  group('Given pivot filters by color and empty groups', () {
    test('when a filter keeps a fill color then only those rows count', () {
      session.execute(
        SetFormat(
          [model().parseA1('A2:C2', contextSheetId: sheetId)],
          {FormatAttr.fillColor: '#FF0000'},
        ),
      );
      final spec = byRegion()
        ..['filters'] = [
          {
            'source': col(0),
            'criteria': {'visibleBackgroundColor': '#FF0000'},
          },
        ];
      final id = addPivot('F1', spec);

      final o = service.byId(id)!;
      expect(o.rect, const GridRect(0, 5, 2, 6));
      expect(text('G2'), 'NumberValue(1.0)');
    });

    test('when showEmptyGroups is set then products without data show', () {
      final spec = {
        'rows': [
          {'source': col(0), 'showTotals': false},
          {'source': col(1)},
        ],
        'values': [
          {'source': col(2), 'summarizeBy': 'sum'},
        ],
        'filters': [
          {
            'source': col(1),
            'criteria': {
              'hiddenValues': ['B'],
            },
          },
        ],
      };
      final without = service.byId(addPivot('F1', spec))!.rect.rowCount;
      final withEmpty = service
          .byId(addPivot('J1', {...spec, 'showEmptyGroups': true}))!
          .rect
          .rowCount;
      expect(withEmpty, greaterThan(without));
    });
  });

  group('Given a slicer on the source range', () {
    test('when the slicer hides West then the pivot only counts East, and '
        'clearing it restores West', () {
      final id = addPivot('F1', byRegion());
      final source = model().parseA1('A1:C5', contextSheetId: sheetId);
      final range = model().sheet(sheetId)!.gridRange(source.rect);
      String spec(List<String> hidden) => jsonEncode({
        'v': 1,
        'dataRange': range.toJson(),
        'colId': col(0),
        'criteria': {'hiddenValues': hidden},
        'applyToPivotTables': true,
      });
      final plan = session.execute(
        AddObject(
          sheetId,
          EmbeddedObjectKind.slicer,
          anchorJson: '{}',
          specJson: spec(['West']),
        ),
      );
      service.flush();

      expect(service.byId(id)!.rect, const GridRect(0, 5, 2, 6));
      expect(text('G2'), 'NumberValue(4.0)');

      session.execute(
        UpdateObject(plan.result['objectId']! as String, specJson: spec([])),
      );
      service.flush();
      expect(service.byId(id)!.rect, const GridRect(0, 5, 3, 6));
    });
  });
}
