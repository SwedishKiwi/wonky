import 'package:test/test.dart';
import 'package:wonky_sync_models/ids.dart';

void main() {
  group('Given deterministic sheet ids', () {
    const sheet = '0190f6a0-0000-7000-8000-000000000001';
    const row = '0190f6a0-0000-7000-8000-000000000002';
    const col = '0190f6a0-0000-7000-8000-000000000003';

    test('when computing a cell id twice then both are equal', () {
      expect(SheetsIds.cellId(sheet, row, col), SheetsIds.cellId(sheet, row, col));
    });

    test('when the input case differs then the cell id is the same', () {
      expect(
        SheetsIds.cellId(sheet.toUpperCase(), row, col.toUpperCase()),
        SheetsIds.cellId(sheet, row, col),
      );
    });

    test('when row and column are swapped then the cell ids differ', () {
      expect(SheetsIds.cellId(sheet, row, col), isNot(SheetsIds.cellId(sheet, col, row)));
    });

    test('when computing a cell id then it is a version-5 UUID', () {
      final id = SheetsIds.cellId(sheet, row, col);
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('when computing ids then they match the frozen vectors', () {
      // These ids are part of the synced data format and must never change.
      expect(SheetsIds.cellId(sheet, row, col), '7964be44-d005-5663-a857-a35ce06d99d9');
      expect(SheetsIds.basicFilterId(sheet), 'b245b271-6000-5903-be0a-fe6d5287499e');
      expect(SheetsIds.scriptBuildId(sheet), '526a2236-95d2-5d06-8e56-04000974bb39');
    });
  });

  group('Given the test id generators', () {
    test('when seeding twice with the same seed then the sequences are equal', () {
      final a = SeededIdGenerator(7);
      final b = SeededIdGenerator(7);
      expect(List.generate(5, (_) => a.newId()), List.generate(5, (_) => b.newId()));
    });

    test('when generating sequential ids then they increase', () {
      final g = SequentialIdGenerator();
      expect(g.newId(), '00000000-0000-4000-8000-000000000001');
      expect(g.newId(), '00000000-0000-4000-8000-000000000002');
    });
  });
}
