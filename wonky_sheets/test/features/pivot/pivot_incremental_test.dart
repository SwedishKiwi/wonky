import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/model/memory_workbook_session.dart';
import 'package:wonky_sheets/features/pivot/pivot_overlay_service.dart';
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

  String addPivot(String anchor, String source, Map<String, Object?> spec) {
    final at = model().parseA1(anchor, contextSheetId: sheetId);
    final plan = session.execute(
      AddPivotTable(
        at.sheetId,
        at.rect.top,
        at.rect.left,
        model().parseA1(source, contextSheetId: sheetId),
        PivotSpec.parse(spec).encode(),
      ),
    );
    return plan.result['pivotId']! as String;
  }

  CellValue value(String a1) {
    final r = model().parseA1(a1, contextSheetId: sheetId);
    return session.engine.engine
        .valueAt(r.sheetId, r.rect.top, r.rect.left)
        .toCellValue();
  }

  Map<String, Object?> byRegion(String summarize) => {
    'rows': [
      {'source': col(0)},
    ],
    'values': [
      {'source': col(2), 'summarizeBy': summarize},
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
  });
  tearDown(() async {
    service.dispose();
    await session.dispose();
  });

  group('Incremental refresh (07 §7.10)', () {
    setUp(() {
      service = PivotOverlayService(
        model: model(),
        engine: session.engine.engine,
        debounce: const Duration(days: 1),
      )..attach(session.engine.view);
    });

    test('when a value in the source changes then the SUM refreshes as a '
        'delta; a changed group key or header computes anew', () {
      final id = addPivot('F1', 'A1:C5', byRegion('sum'));
      expect(value('G2'), const NumberValue(4));

      put('C2', [
        ['10'],
      ]);
      service.flush();
      expect(service.lastWasDelta(id), isTrue);
      expect(value('G2'), const NumberValue(13));
      expect(value('G4'), const NumberValue(19));

      put('A3', [
        ['East'],
      ]);
      service.flush();
      expect(service.lastWasDelta(id), isFalse);
      expect(value('G2'), const NumberValue(15));

      put('C1', [
        ['Pieces'],
      ]);
      service.flush();
      expect(service.lastWasDelta(id), isFalse);
      expect(value('G1'), const TextValue('SUM of Pieces'));
    });

    test('when a non-extreme value changes under MAX then it is a delta', () {
      final id = addPivot('F1', 'A1:C5', byRegion('max'));
      expect(value('G3'), const NumberValue(4));
      put('C3', [
        ['3'],
      ]);
      service.flush();
      expect(service.lastWasDelta(id), isTrue);
      expect(value('G3'), const NumberValue(4));
      put('C5', [
        ['0'],
      ]);
      service.flush();
      expect(service.lastWasDelta(id), isFalse, reason: 'the MAX left');
      expect(value('G3'), const NumberValue(3));
    });
  });

  group('Sliced source snapshot (07 §7.4 step 7)', () {
    setUp(() {
      service = PivotOverlayService(
        model: model(),
        engine: session.engine.engine,
        debounce: const Duration(days: 1),
        backgroundRows: 2,
        useIsolate: false,
        snapshotSlice: 2,
        snapshotBudget: Duration.zero,
      )..attach(session.engine.view);
    });

    test('when a big pivot is added then its source is read in slices '
        'between event-loop turns and placed when done', () async {
      final id = addPivot('F1', 'A1:C5', byRegion('sum'));
      expect(service.isComputing(id), isTrue);
      expect(service.byId(id), isNull, reason: 'nothing read synchronously');
      for (var i = 0; i < 50 && service.isComputing(id); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(service.isComputing(id), isFalse);
      expect(value('G2'), const NumberValue(4));
    });

    test('when the source changes during the snapshot then a new job reads '
        'it again and the output has the new value', () async {
      final id = addPivot('F1', 'A1:C5', byRegion('sum'));
      await Future<void>.delayed(Duration.zero);
      put('C2', [
        ['10'],
      ]);
      service.flush();
      for (var i = 0; i < 100 && service.isComputing(id); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(value('G2'), const NumberValue(13));
    });
  });
}
