import 'package:serverpod_database/serverpod_database.dart'
    show DeferrableConstraint;
import 'package:serverpod_serialization/serverpod_serialization.dart'
    show UuidValue;
import 'package:test/test.dart';
import 'package:wonky_sync_models/tables.dart';
import 'package:wonky_sync_models/wonky_sync_models.dart';

void main() {
  final definitions = {
    for (final d in Protocol().getTargetTableDefinitions()) d.name: d,
  };

  group('Given the Slides synced table codec', () {
    test('when listing the tables then every Slides table of 02 §3 is there '
        'once, in dependency order', () {
      expect(SlidesSyncedTables.all.map((s) => s.name), [
        'deck',
        'deck_theme',
        'slide_master',
        'slide_layout',
        'slide_group',
        'slide',
        'slide_element',
        'slide_table_axis',
        'slide_table_cell',
        'slide_build',
        'code_state',
        'chart_link',
        'deck_change_log',
      ]);
    });

    test('when following each foreign key then the referenced table comes '
        'first (or is the table itself)', () {
      final rank = {
        for (final (i, s) in SlidesSyncedTables.all.indexed) s.name: i,
      };
      for (final s in SlidesSyncedTables.all) {
        final def = definitions[s.name]!;
        for (final fk in def.foreignKeys) {
          if (fk.referenceTable == 'offline_sync_spaces') continue;
          expect(
            rank[fk.referenceTable],
            lessThanOrEqualTo(rank[s.name]!),
            reason: '${s.name}.${fk.columns.single} → ${fk.referenceTable}',
          );
        }
      }
    });

    test('when comparing with the Sheets tables then the sets are '
        'disjoint and both are sync tables', () {
      final sheets = SyncedTables.byName.keys.toSet();
      expect(
        SlidesSyncedTables.byName.keys.toSet().intersection(sheets),
        isEmpty,
      );
      // Sync tables live in a space (engine-managed `spaceId` FK).
      for (final s in SlidesSyncedTables.all) {
        expect(
          definitions[s.name]!.foreignKeys.map((f) => f.referenceTable),
          contains('offline_sync_spaces'),
          reason: s.name,
        );
      }
    });

    test('when reading the foreign keys then they cascade and are deferred, '
        'and only element owners and parents are nullable', () {
      final nullable = <String>{};
      for (final s in SlidesSyncedTables.all) {
        final def = definitions[s.name]!;
        for (final fk in def.foreignKeys) {
          if (fk.referenceTable == 'offline_sync_spaces') continue;
          final column = fk.columns.single;
          expect(fk.onDelete?.name, 'cascade', reason: '${s.name}.$column');
          expect(
            fk.deferrable,
            DeferrableConstraint.initiallyDeferred,
            reason: '${s.name}.$column must be deferred',
          );
          final col = def.columns.firstWhere((c) => c.name == column);
          if (col.isNullable) nullable.add('${s.name}.$column');
        }
      }
      expect(nullable, {
        'slide_element.slideId',
        'slide_element.layoutId',
        'slide_element.masterId',
        'slide_element.parentId',
      });
    });

    test('when a column map becomes a SlideElement and back then enums, '
        'null owners and doubles round-trip', () {
      const id = '0190a000-0000-7000-8000-000000000021';
      const layout = '0190a000-0000-7000-8000-000000000022';
      final created = DateTime.utc(2026, 10, 1, 12);
      final spec = SlidesSyncedTables.of('slide_element');

      final el =
          spec.fromColumns({
                'id': id,
                'layoutId': layout,
                'kind': 'text',
                'x': 10,
                'y': 20.5,
                'zKey': 'a0',
                'placeholderType': 'title',
                'matchKey': '0000000000000000000001',
                'createdAt': created,
              })
              as SlideElement;
      final back = spec.toColumns(el);

      expect(el.id, UuidValue.fromString(id));
      expect(el.kind, SlideElementKind.text);
      expect(el.placeholderType, PlaceholderType.title);
      expect(el.slideId, isNull);
      expect(el.flipH, isFalse);
      expect(back['x'], 10.0);
      expect(back['layoutId'], layout);
      expect(back['slideId'], isNull);
      expect(back['kind'], 'text');
      expect(back['placeholderType'], 'title');
      expect(back.containsKey('spaceId'), isFalse);
    });

    test('when a Deck is built from a partial column map then the model '
        'defaults fill the rest', () {
      final deck =
          SlidesSyncedTables.of('deck').fromColumns({
                'id': '0190a000-0000-7000-8000-000000000031',
                'title': 'Talk',
                'createdBy': '0190a000-0000-7000-8000-000000000032',
              })
              as Deck;

      expect(deck.width, 1920.0);
      expect(deck.height, 1080.0);
      expect(deck.sizePreset, SlideSizePreset.widescreen16x9);
      expect(deck.appearance, DeckAppearance.light);
      expect(deck.firstSlideNumber, 1);
      expect(deck.showSlideNumbers, isFalse);
      expect(deck.hideNumberOnTitle, isTrue);
    });

    test('when column values are built then exactly the given columns are '
        'named and unknown ones throw', () {
      final spec = SlidesSyncedTables.of('slide');

      final values = spec.columnValues({
        'id': '0190a000-0000-7000-8000-000000000041',
        'groupId': '0190a000-0000-7000-8000-000000000042',
        'sortKey': 'a1',
      });

      expect(values.map((v) => v.column.columnName), ['groupId', 'sortKey']);
      expect(values.first.value, isA<UuidValue>());
      expect(() => spec.columnValues({'nope': 1}), throwsArgumentError);
      expect(() => SlidesSyncedTables.of('cell'), throwsArgumentError);
    });

    test('when reading the enums then their values are the 02 §3.11 ones '
        'by name', () {
      expect(SlideElementKind.values.map((v) => v.name), [
        'text',
        'shape',
        'line',
        'image',
        'table',
        'icon',
        'code',
        'chart',
        'group',
      ]);
      expect(BuildKind.values.map((v) => v.name), [
        'buildIn',
        'buildOut',
        'emphasis',
        'motion',
      ]);
      expect(BuildTrigger.values.map((v) => v.name), [
        'onClick',
        'withPrevious',
        'afterPrevious',
        'onElementClick', // S-2: reserved (06 A-06-2)
      ]);
      expect(TableDimension.values.map((v) => v.name), ['row', 'column']);
      expect(DeckAppearance.values.map((v) => v.name), ['light', 'dark']);
      expect(SlideSizePreset.values, hasLength(8));
      expect(PlaceholderType.values, hasLength(15));
      expect(SlideElementKind.fromJson('group'), SlideElementKind.group);
    });
  });
}
