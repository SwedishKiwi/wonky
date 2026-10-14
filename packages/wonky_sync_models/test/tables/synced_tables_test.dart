import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart'
    show UuidValue;
import 'package:test/test.dart';
import 'package:wonky_sync_models/tables.dart';
import 'package:wonky_sync_models/wonky_sync_models.dart';

void main() {
  group('Given the synced table codec', () {
    final cellId = '0190a000-0000-7000-8000-000000000011';
    final sheetId = '0190a000-0000-7000-8000-000000000012';
    final rowId = '0190a000-0000-7000-8000-000000000013';
    final colId = '0190a000-0000-7000-8000-000000000014';
    final created = DateTime.utc(2026, 10, 1, 12);
    final columns = <String, Object?>{
      'id': cellId,
      'sheetId': sheetId,
      'rowId': rowId,
      'columnId': colId,
      'content': 'n:42',
      'bold': true,
      'fontSize': 11,
      'hAlign': 'center',
      'createdAt': created,
    };

    test('when a column map becomes a Cell and back then the values '
        'round-trip with every column present', () {
      final spec = SyncedTables.of('cell');

      final cell = spec.fromColumns(columns) as Cell;
      final back = spec.toColumns(cell);

      expect(cell.id, UuidValue.fromString(cellId));
      expect(cell.hAlign, HorizontalAlign.center);
      expect(cell.fontSize, 11.0);
      expect(back['content'], 'n:42');
      expect(back['hAlign'], 'center');
      expect(back['rowId'], rowId);
      expect(back['createdAt'], created);
      expect(back.containsKey('italic'), isTrue);
      expect(back.containsKey('spaceId'), isFalse);
    });

    test('when column values are built then exactly the given columns are '
        'named with database values', () {
      final spec = SyncedTables.of('cell');

      final values = spec.columnValues({
        'id': cellId,
        'bold': false,
        'rowId': rowId,
        'fontSize': 12,
      });

      expect(values.map((v) => v.column.columnName), [
        'bold',
        'rowId',
        'fontSize',
      ]);
      expect(values[1].value, isA<UuidValue>());
      expect(values[2].value, 12.0);
    });

    test('when an unknown column is named then it throws', () {
      expect(
        () => SyncedTables.of('cell').columnValues({'nope': 1}),
        throwsArgumentError,
      );
    });

    test('when listing the tables then parents come before children', () {
      final names = SyncedTables.all.map((s) => s.name).toList();

      expect(names.indexOf('spreadsheet'), lessThan(names.indexOf('sheet')));
      expect(names.indexOf('sheet'), lessThan(names.indexOf('cell')));
      expect(SyncedTables.byName.keys, contains('change_log'));
      expect(SyncedTables.of('sheet').idColumn, isA<ColumnUuid>());
    });
  });
}
