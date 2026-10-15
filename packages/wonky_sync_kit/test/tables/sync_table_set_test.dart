import 'package:test/test.dart';
import 'package:wonky_sync_kit/tables.dart';
import 'package:wonky_sync_models/tables.dart';
import 'package:wonky_sync_models/wonky_sync_models.dart'
    show Sheet, Spreadsheet;

void main() {
  group('Given the Sheets tables as a set', () {
    final set = SyncTableSet(
      SyncedTables.all,
      nonModelTables: const {'change_log'},
      rootTable: 'spreadsheet',
    );

    test('when ranking tables then parents come first and unknown tables '
        'last', () {
      expect(set.rank('spreadsheet'), 0);
      expect(set.rank('sheet'), lessThan(set.rank('cell')));
      expect(set.rank('nope'), set.all.length);
    });

    test('when listing the model tables then the non-model tables are left '
        'out in order', () {
      expect(set.modelTableNames, isNot(contains('change_log')));
      expect(set.modelTables.first.name, 'spreadsheet');
      expect(set.modelTables, hasLength(set.all.length - 1));
    });

    test('when looking up an unknown table then it throws', () {
      expect(() => set.of('nope'), throwsArgumentError);
      expect(set.of('cell').name, 'cell');
    });
  });

  test(
    'Given a root table outside the set, when creating it then it throws',
    () {
      expect(
        () => SyncTableSet(SyncedTables.all, rootTable: 'deck'),
        throwsArgumentError,
      );
    },
  );

  test('Given specs built from generated tables, when used as a set then '
      'they convert rows like the built-in specs', () {
    final set = SyncTableSet([
      SyncedTableSpec<Spreadsheet>.of(Spreadsheet.t, Spreadsheet.fromJson),
      SyncedTableSpec<Sheet>.of(Sheet.t, Sheet.fromJson),
    ], rootTable: 'spreadsheet');

    expect(set.all.map((s) => s.name), ['spreadsheet', 'sheet']);
    expect(set.of('sheet').column('sortKey'), isNotNull);
  });
}
