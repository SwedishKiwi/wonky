import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show ActorKind, Deck, DeckChangeLog, Slide, SlideTableCell, UuidValue;
import 'package:wonky_slides/features/sync/slides_replica.dart';
import 'package:wonky_slides/features/sync/slides_writer.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_models/ids.dart' show SlidesIds;

import 'support/slides_sync_harness.dart';

final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000d1');

void main() {
  test('when naming the replica of a user then it is slides_<userId>.db', () {
    expect(
      SlidesReplica.fileNameFor(testUser.uuid),
      'slides_${testUser.uuid}.db',
    );
    expect(SlidesReplica.slidesTables.rootTable, SlidesTables.deck);
    expect(
      SlidesReplica.modelTables.map((t) => t.name),
      isNot(contains(SlidesTables.deckChangeLog)),
    );
  });

  group('Given a Slides replica', () {
    late SlidesReplica replica;

    setUp(() async => replica = await openTestReplica());

    test('when a deck is created then its rows, one change-log row and a '
        'dirty mark are stored', () async {
      final plan = await createDeck(replica, space, title: 'Quarterly');

      expect(await replica.hasDeck(space), isTrue);
      expect(
        (await Deck.db.findById(replica.session, space))?.title,
        'Quarterly',
      );
      final model = await reloadModel(replica, space);
      expect(model.slides, hasLength(1));
      expect(model.themes, hasLength(1));
      expect(canonical(model).length, plan.changes.length);
      final logs = await DeckChangeLog.db.find(replica.session);
      expect(logs, hasLength(1));
      expect(logs.single.deckId, space);
      expect(logs.single.label, plan.label);
      expect(logs.single.userId, testUser);
      expect(logs.single.actorKind, ActorKind.user);
      expect(jsonDecode(logs.single.summaryJson), plan.summary.toJson());
      expect(await replica.dirtySpaces(), [space]);
    });

    test('when an update names one column then the other columns of the row '
        'keep their stored values', () async {
      await createDeck(replica, space);
      final slide = (await reloadModel(replica, space)).slides.single;
      await writeOp(
        replica,
        space,
        (_) => SetSlideProps([
          slide.id,
        ], notes: const Patch('[{"insert":"Speak slowly\\n"}]')),
      );

      // Another device's view: only `skipped` changes.
      await SlidesWriter(replica).write(
        spaceId: space,
        changes: [
          RowChange(
            table: SlidesTables.slide,
            rowId: slide.id,
            op: RowOp.update,
            columnsBefore: const {'skipped': false},
            columnsAfter: const {'skipped': true},
          ),
        ],
        label: 'Skip slide',
        actorKind: 'user',
        sessionId: 'other',
      );

      final row = await Slide.db.findById(
        replica.session,
        UuidValue.fromString(slide.id),
      );
      expect(row?.skipped, isTrue);
      expect(row?.notes, contains('Speak slowly'));
    });

    test('when an insert hits a visible table cell then the given columns '
        'update and the cell keys stay', () async {
      await createDeck(replica, space);
      final slide = (await reloadModel(replica, space)).slides.single;
      await writeOp(
        replica,
        space,
        (_) => InsertElements(slide.id, const [
          ElementSpec(
            kind: ElementKind.table,
            x: 10,
            y: 10,
            width: 400,
            height: 200,
          ),
        ]),
      );
      final model = await reloadModel(replica, space);
      final table = model
          .elementsOf(slide.id)
          .firstWhere((e) => e.kind == ElementKind.table);
      final rows = model.axesOf(table.id, TableAxisDimension.row);
      final cols = model.axesOf(table.id, TableAxisDimension.column);
      final id = SlidesIds.tableCellId(table.id, rows.first.id, cols.first.id);

      Future<void> insertCell(Map<String, Object?> columns) =>
          SlidesWriter(replica).write(
            spaceId: space,
            changes: [
              RowChange.insert(SlidesTables.slideTableCell, id, {
                'id': id,
                'elementId': table.id,
                'rowId': rows.first.id,
                'columnId': cols.first.id,
                ...columns,
              }),
            ],
            label: 'Typing',
            actorKind: 'user',
            sessionId: 'a',
          );
      await insertCell({'fill': '{"color":"#ff0000"}'});
      // A second device creating the same deterministic cell with text.
      await insertCell({'text': '[{"insert":"Hi\\n"}]'});

      final cell = await SlideTableCell.db.findById(
        replica.session,
        UuidValue.fromString(id),
      );
      expect(cell?.fill, '{"color":"#ff0000"}');
      expect(cell?.text, '[{"insert":"Hi\\n"}]');
      expect(cell?.elementId.uuid, table.id);
    });

    test('when changes are written without a plan then the summary is '
        'derived from them', () async {
      final plan = await createDeck(replica, space);
      final slide = plan.changes.firstWhere(
        (c) => c.table == SlidesTables.slide,
      );
      await SlidesWriter(replica).write(
        spaceId: space,
        changes: [slide.inverse()],
        label: 'Undo',
        actorKind: 'user',
        sessionId: 's',
      );

      final log = (await DeckChangeLog.db.find(
        replica.session,
      )).firstWhere((l) => l.label == 'Undo');
      final summary = jsonDecode(log.summaryJson) as Map<String, Object?>;
      expect(summary['slides'], contains(slide.rowId));
    });

    test('when an undo re-inserts a deleted slide then the summary lists it '
        'as revived (the server revives its orphaned comments)', () async {
      final plan = await createDeck(replica, space);
      final slide = plan.changes.firstWhere(
        (c) => c.table == SlidesTables.slide,
      );
      final writer = SlidesWriter(replica);
      final delete = slide.inverse();
      await writer.write(
        spaceId: space,
        changes: [delete],
        label: 'Delete slide',
        actorKind: 'user',
        sessionId: 's',
      );
      await writer.write(
        spaceId: space,
        changes: [delete.inverse()],
        label: 'Undo delete',
        actorKind: 'user',
        sessionId: 's',
      );

      final log = (await DeckChangeLog.db.find(
        replica.session,
      )).firstWhere((l) => l.label == 'Undo delete');
      final summary = jsonDecode(log.summaryJson) as Map<String, Object?>;
      expect((summary['revived'] as Map)['slides'], [slide.rowId]);
    });

    test('when the actor kind is unknown then the log says user', () {
      expect(SlidesWriter.actorKindOf('mcp'), ActorKind.mcp);
      expect(SlidesWriter.actorKindOf('nope'), ActorKind.user);
    });
  });
}
