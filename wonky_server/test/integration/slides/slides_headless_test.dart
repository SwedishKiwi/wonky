// Devices run in their own isolates and sync over HTTP.
@Tags(['integration'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/files/file_service.dart';
import 'package:wonky_server/src/sheets/sync/sync_db.dart';
import 'package:wonky_server/src/slides/changelog/deck_drive_mirror.dart';
import 'package:wonky_server/src/slides/headless/deck_text_claims.dart';
import 'package:wonky_server/src/slides/headless/headless_deck.dart';
import 'package:wonky_server/src/slides/headless/headless_deck_cache.dart';
import 'package:wonky_server/src/slides/sync/server_slides_writer.dart';
import 'package:wonky_slides_core/model.dart' show ElementKind, SlidesText;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_sync_kit/rows.dart';

import '../../support/sheets_device.dart' show installDeviceAuthentication;
import '../../support/slides_device.dart';
import '../../support/test_drive.dart';
import '../../support/test_storage.dart';
import '../../support/test_users.dart';
import '../../support/wonky_serverpod.dart';

/// A 1×1 PNG.
final _png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  ),
);

String _text(String s) => jsonEncode([
  {'insert': '$s\n'},
]);

/// Headless writes, copies, templates, server-change undo and soft locks
/// (Slides 11 §2.1, 02 §9.3, 12 §4 SL-8).
void main() {
  withWonkyServerpod('Given decks on the server', (sessionBuilder, endpoints) {
    late Session server;

    setUpAll(() {
      server = sessionBuilder.build();
      installDeviceAuthentication(server);
      DeckTextClaims.probeWait = const Duration(milliseconds: 300);
    });

    tearDown(() {
      DeckDriveMirror.reset();
      DeckTextClaims.clear();
      HeadlessDeckCache.clear();
    });

    Future<DriveItemView> create(TestUser u, String name) =>
        endpoints.drive.createPresentation(u.endpointSession, null, name, null);

    Future<ServerHeadlessDeck> open(TestUser u, UuidValue deck) =>
        const SlidesHeadlessProvider().open(
          HeadlessDeckContext(u.session, u.actor.copyWith(kind: ActorKind.mcp)),
          deck.uuid,
        );

    Future<List<Slide>> slidesOf(UuidValue deck) => Slide.db.find(
      syncSessionOf(server),
      where: (t) => t.deckId.equals(deck),
    );

    Future<SlideElement> element(UuidValue id) async =>
        (await SlideElement.db.findById(syncSessionOf(server), id))!;

    /// A deck with a text box; returns (item, element id).
    Future<(DriveItemView, String)> deckWithBox(TestUser u) async {
      final item = await create(u, 'Pitch');
      final deck = await open(u, item.uuid);
      final slide = deck.model.slides.single.id;
      final w = await deck.write(
        InsertElements(slide, [
          ElementSpec(
            kind: ElementKind.text,
            x: 100,
            y: 100,
            width: 400,
            height: 100,
            columns: {'text': _text('Hello')},
          ),
        ]),
      );
      return (item, (w.plan.result['elementIds']! as List).single as String);
    }

    test(
      'when a deck is created, opened headless and edited, then the '
      'writes are recorded, logged and visible in the cached model',
      () async {
        final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
        final item = await create(anna, 'Pitch');

        final deck = await open(anna, item.uuid);
        expect(deck.model.deck!.title, 'Pitch');
        expect(deck.model.slides, hasLength(1));
        expect(
          deck.model.layout(deck.model.slides.single.layoutId!)!.key,
          'title',
        );
        final loads = HeadlessDeckCache.loads;

        final w = await deck.write(
          AddSlides(afterSlideId: deck.model.slides.single.id, count: 2),
        );

        expect(w.changeId, isNotNull);
        expect(w.syncVersion, isNotNull);
        expect(await slidesOf(item.uuid), hasLength(3));
        final again = await open(anna, item.uuid);
        expect(again.model.slides, hasLength(3), reason: 'written through');
        expect(HeadlessDeckCache.loads, loads, reason: 'no reload');
        final log = await DeckChangeLog.db.findById(
          syncSessionOf(server),
          w.syncVersion!,
        );
        expect(log!.actorKind, ActorKind.mcp);
        expect(log.label, w.plan.label);
        final record = await ServerChangeRecord.db.findFirstRow(
          server,
          where: (t) => t.changeId.equals(w.changeId!),
        );
        expect(record!.spreadsheetUuid, item.uuid);
      },
    );

    test(
      'when a viewer writes headless, then it is refused; reading works',
      () async {
        final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
        final vic = await TestUsers.create(sessionBuilder, name: 'Vic');
        final item = await create(anna, 'Pitch');
        await TestDrive.share(endpoints, item, anna, vic, AccessRole.viewer);

        final deck = await open(vic, item.uuid);
        expect(deck.model.slides, hasLength(1));
        await expectLater(
          deck.write(const AddSlides()),
          throwsA(
            isA<WonkyException>().having(
              (e) => e.code,
              'code',
              WonkyErrorCode.forbidden,
            ),
          ),
        );
        final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
        await expectLater(open(eve, item.uuid), throwsA(isA<WonkyException>()));
      },
    );

    test('when a deck is copied, then the copy has its own ids, the new '
        'title, the same content and a size; images are re-homed', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final (item, box) = await deckWithBox(anna);
      final src = (await DriveItem.db.findFirstRow(
        server,
        where: (t) => t.uuid.equals(item.uuid),
      ))!;
      final file = await FileService.storeServerFile(
        server,
        ownerId: anna.id,
        itemId: src.id,
        kind: StoredFileKind.image,
        fileName: 'dot.png',
        mimeType: 'image/png',
        bytes: _png,
      );
      final deck = await open(anna, item.uuid);
      await deck.write(
        InsertElements(deck.model.slides.single.id, [
          ElementSpec(
            kind: ElementKind.image,
            x: 0,
            y: 0,
            width: 10,
            height: 10,
            columns: {
              'dataJson': jsonEncode({
                'v': 1,
                'src': 'wonky-file://${file.fileUuid.uuid}',
              }),
            },
          ),
        ]),
      );

      final copy = await endpoints.drive.copy(
        anna.endpointSession,
        item.uuid,
        'Pitch (copy)',
        null,
        false,
        false,
      );

      expect(copy.kind, DriveItemKind.presentation);
      expect(copy.uuid, isNot(item.uuid));
      final db = syncSessionOf(server);
      expect((await Deck.db.findById(db, copy.uuid))!.title, 'Pitch (copy)');
      final a = await slidesOf(item.uuid), b = await slidesOf(copy.uuid);
      expect(b, hasLength(a.length));
      expect(
        {for (final s in a) s.id}.intersection({for (final s in b) s.id}),
        isEmpty,
      );
      final copied = await SlideElement.db.find(
        db,
        where: (t) => t.slideId.equals(b.single.id),
      );
      final texts = [
        for (final e in copied)
          if (e.text != null) SlidesText.plainText(e.text).trim(),
      ];
      expect(texts, contains('Hello'));
      expect(copied.any((e) => e.id.uuid == box), isFalse);
      final image = copied.firstWhere((e) => e.kind.name == 'image');
      final src2 = jsonDecode(image.dataJson!)['src'] as String;
      expect(src2, isNot('wonky-file://${file.fileUuid.uuid}'));
      final newFile = await FileService.byUuid(
        server,
        UuidValue.withValidation(src2.substring('wonky-file://'.length)),
      );
      final copyItem = (await DriveItem.db.findFirstRow(
        server,
        where: (t) => t.uuid.equals(copy.uuid),
      ))!;
      expect(newFile!.itemId, copyItem.id);
      expect(copyItem.attachmentBytes, _png.length);
      expect(copyItem.sizeBytes, greaterThan(0));
      final logs = await DeckChangeLog.db.find(
        db,
        where: (t) => t.deckId.equals(copy.uuid),
      );
      expect(logs.single.label, 'Copy presentation');
      expect(copyItem.searchText, contains('Hello'));
    });

    test('when copying exceeds the quota, then nothing is created', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final item = await create(anna, 'Pitch');
      await TestStorage.setQuota(anna, 1);
      await expectLater(
        endpoints.drive.copy(
          anna.endpointSession,
          item.uuid,
          'Copy',
          null,
          false,
          false,
        ),
        throwsA(
          isA<WonkyException>().having(
            (e) => e.code,
            'code',
            WonkyErrorCode.quotaExceeded,
          ),
        ),
      );
      final items = await DriveItem.db.count(
        server,
        where: (t) => t.ownerId.equals(anna.id),
      );
      expect(items, 1);
    });

    test(
      'when a presentation is used as a template, then the new deck is a '
      'copy owned by the caller; strangers and other kinds are refused',
      () async {
        final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
        final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
        final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
        final (template, _) = await deckWithBox(anna);
        await TestDrive.share(endpoints, template, anna, bo, AccessRole.viewer);

        final mine = await endpoints.drive.createPresentation(
          bo.endpointSession,
          null,
          'My talk',
          template.uuid,
        );

        expect(mine.owner.id, bo.id);
        final db = syncSessionOf(server);
        final deck = await Deck.db.findById(db, mine.uuid);
        expect(deck!.title, 'My talk');
        expect(deck.createdBy, bo.authUserId);
        expect(await slidesOf(mine.uuid), hasLength(1));
        await expectLater(
          endpoints.drive.createPresentation(
            eve.endpointSession,
            null,
            'Nope',
            template.uuid,
          ),
          throwsA(isA<WonkyException>()),
        );
        final doc = await TestDrive.document(endpoints, anna);
        await expectLater(
          endpoints.drive.createPresentation(
            anna.endpointSession,
            null,
            'Nope',
            doc.uuid,
          ),
          throwsA(
            isA<WonkyException>().having(
              (e) => e.code,
              'code',
              WonkyErrorCode.invalidArgument,
            ),
          ),
        );
      },
    );

    test('when a headless change is reverted and reapplied, then other '
        "users' columns stay and the change comes back", () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      final (item, box) = await deckWithBox(anna);
      await TestDrive.share(endpoints, item, anna, bo, AccessRole.editor);
      final id = UuidValue.withValidation(box);

      final w = await (await open(anna, item.uuid)).write(
        SetText(ElementText(box), _text('Anna')),
      );
      await (await open(bo, item.uuid)).write(
        SetElementProps([
          box,
        ], fillJson: const Patch('{"v":1,"type":"solid","color":"#FF0000"}')),
      );

      final r = await endpoints.slides.revertChange(
        anna.endpointSession,
        w.changeId!,
      );

      expect(r.skipped, isEmpty);
      var e = await element(id);
      expect(SlidesText.plainText(e.text).trim(), 'Hello');
      expect(e.fillJson, contains('#FF0000'));
      final redo = await endpoints.slides.reapplyChange(
        anna.endpointSession,
        r.changeId,
      );
      expect(redo.skipped, isEmpty);
      e = await element(id);
      expect(SlidesText.plainText(e.text).trim(), 'Anna');
      final cached = (await open(anna, item.uuid)).model.element(box)!;
      expect(
        SlidesText.plainText(cached.columns['text'] as String?).trim(),
        'Anna',
      );
    });

    test('when someone changed a reverted column since, then it is skipped '
        'with its coupled columns', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      final (item, box) = await deckWithBox(anna);
      await TestDrive.share(endpoints, item, anna, bo, AccessRole.editor);
      final id = UuidValue.withValidation(box);

      final text = await (await open(anna, item.uuid)).write(
        SetText(ElementText(box), _text('Anna')),
      );
      final move = await (await open(anna, item.uuid)).write(
        UpdateFrames([FrameUpdate(box, x: 300, y: 400)]),
      );
      await (await open(bo, item.uuid)).write(
        SetText(ElementText(box), _text('Bo')),
      );
      // Bo nudges only x (a raw write): y belongs to the same group (P4).
      await ServerSlidesWriter.apply(
        server,
        actor: bo.actor,
        deckSpace: item.uuid,
        changes: [
          RowChange.update('slide_element', box, {'x': 300.0}, {'x': 310.0}),
        ],
        label: 'Nudge',
      );

      final r1 = await endpoints.slides.revertChange(
        anna.endpointSession,
        text.changeId!,
      );
      final r2 = await endpoints.slides.revertChange(
        anna.endpointSession,
        move.changeId!,
      );

      expect(
        [for (final s in r1.skipped) (s.column, s.reason)],
        [('text', 'changed_by_other')],
      );
      expect({for (final s in r2.skipped) s.column}, {'x', 'y'});
      final e = await element(id);
      expect(SlidesText.plainText(e.text).trim(), 'Bo');
      expect((e.x, e.y), (310.0, 400.0));
    });

    test('when a change of a deck is reverted through Sheets or by a '
        'stranger, then it is not found', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
      final (item, box) = await deckWithBox(anna);
      final w = await (await open(anna, item.uuid)).write(
        SetText(ElementText(box), _text('x')),
      );
      for (final call in [
        () => endpoints.sheets.revertChange(anna.endpointSession, w.changeId!),
        () => endpoints.slides.revertChange(eve.endpointSession, w.changeId!),
        () => endpoints.slides.revertChange(
          anna.endpointSession,
          const Uuid().v7obj(),
        ),
      ]) {
        await expectLater(call(), throwsA(isA<WonkyException>()));
      }
    });

    test(
      'when another user is editing a text body, then headless writes to '
      'it fail with being_edited unless forced; box-level writes pass',
      () async {
        final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
        final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
        final (item, box) = await deckWithBox(anna);
        await TestDrive.share(endpoints, item, anna, bo, AccessRole.editor);
        final slide = (await open(anna, item.uuid)).model.slides.single.id;

        final updates = StreamController<PresenceUpdate>();
        final events = endpoints.presence
            .join(bo.endpointSession, item.uuid, updates.stream)
            .listen((_) {});
        addTearDown(() async {
          await updates.close();
          await events.cancel();
        });
        await Future<void>.delayed(const Duration(milliseconds: 200));
        updates.add(
          PresenceUpdate(
            state: PresenceState.active,
            cursorJson: jsonEncode({
              'route': 'editor',
              'slideId': slide,
              'editing': {
                'kind': 'text',
                'slideId': slide,
                'elementId': box,
                'since': 1,
                'forced': false,
              },
            }),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final deck = await open(anna, item.uuid);
        await expectLater(
          deck.write(SetText(ElementText(box), _text('Agent'))),
          throwsA(
            isA<WonkyException>()
                .having((e) => e.code, 'code', WonkyErrorCode.conflict)
                .having(
                  (e) => jsonDecode(e.detailsJson!),
                  'details',
                  allOf(
                    containsPair('code', 'being_edited'),
                    containsPair('targets', [
                      containsPair('user', 'Bo'),
                    ]),
                  ),
                ),
          ),
        );
        final box2 = await deck.write(
          SetElementProps([box], opacity: const Patch(0.5)),
        );
        expect(box2.changeId, isNotNull);
        final forced = await deck.write(
          SetText(ElementText(box), _text('Agent')),
          force: true,
        );
        expect(forced.changeId, isNotNull);

        // The claim ends: writes pass again.
        updates.add(
          PresenceUpdate(
            state: PresenceState.active,
            cursorJson: jsonEncode({'route': 'editor', 'editing': null}),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final after = await deck.write(
          SetText(ElementText(box), _text('Again')),
        );
        expect(after.changeId, isNotNull);
      },
    );

    test('when the deck violates an invariant, then the headless write '
        'repairs it first without recording the repair', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final item = await create(anna, 'Pitch');
      final slide = (await slidesOf(item.uuid)).single;
      await ServerSlidesWriter.apply(
        server,
        actor: anna.actor,
        deckSpace: item.uuid,
        changes: [
          RowChange.update(
            'slide',
            slide.id.uuid,
            {'groupId': null, 'sortKey': slide.sortKey},
            {
              'groupId': '00000000-0000-4000-8000-00000000dead',
              'sortKey': slide.sortKey,
            },
          ),
        ],
        label: 'Break',
      );

      final w = await (await open(anna, item.uuid)).write(
        const SetDeckProps(title: 'Fixed'),
      );

      expect(w.repaired, isTrue);
      final fixed = (await slidesOf(item.uuid)).single;
      expect(fixed.groupId, isNull);
      final record = await ServerChangeRecord.db.findFirstRow(
        server,
        where: (t) => t.changeId.equals(w.changeId!),
      );
      expect(record!.label, w.plan.label);
      expect(record.cellsAffected, 1, reason: 'only the deck row');
    });

    test('when a device merges a change, then the cached deck is marked '
        'stale and patched on the next open', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final a = await SlidesDevice.open(server, anna.authUserId);
      final space = (await a.reserveSpaces(1)).single;
      await a.sync();
      await a.createDeck(space, 'Draft');
      await a.registerPresentation(space, 'Draft');
      await a.sync();
      final deck = await open(anna, space);
      expect(deck.model.deck!.title, 'Draft');
      final loads = HeadlessDeckCache.loads;

      await a.rename(space, 'Renamed');
      await a.sync();
      for (var i = 0; i < 50; i++) {
        if (HeadlessDeckCache.peek(space)?.stale ?? false) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(HeadlessDeckCache.peek(space)!.stale, isTrue);

      final again = await open(anna, space);
      expect(again.model.deck!.title, 'Renamed');
      expect(HeadlessDeckCache.loads, loads);
      expect(HeadlessDeckCache.peek(space)!.patches, greaterThanOrEqualTo(1));
    });

    test(
      'when an image is copied into an item, then the copy is idempotent, '
      'charged to the target owner and refused without access or quota',
      () async {
        final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
        final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
        final a = await create(anna, 'A');
        final b = await create(anna, 'B');
        final itemA = (await DriveItem.db.findFirstRow(
          server,
          where: (t) => t.uuid.equals(a.uuid),
        ))!;
        final file = await FileService.storeServerFile(
          server,
          ownerId: anna.id,
          itemId: itemA.id,
          kind: StoredFileKind.image,
          fileName: 'dot.png',
          mimeType: 'image/png',
          bytes: _png,
        );
        final target = const Uuid().v7obj();

        final v1 = await endpoints.file.copyToItem(
          anna.endpointSession,
          file.fileUuid,
          target,
          b.uuid,
        );
        final v2 = await endpoints.file.copyToItem(
          anna.endpointSession,
          file.fileUuid,
          target,
          b.uuid,
        );

        expect(v1.fileUuid, target);
        expect(v2.sizeBytes, _png.length);
        final itemB = (await DriveItem.db.findFirstRow(
          server,
          where: (t) => t.uuid.equals(b.uuid),
        ))!;
        expect(itemB.attachmentBytes, _png.length, reason: 'charged once');
        final eveDeck = await create(eve, 'E');
        await expectLater(
          endpoints.file.copyToItem(
            eve.endpointSession,
            file.fileUuid,
            const Uuid().v7obj(),
            eveDeck.uuid,
          ),
          throwsA(
            isA<WonkyException>().having(
              (e) => e.code,
              'code',
              WonkyErrorCode.notFound,
            ),
          ),
        );
        await TestStorage.setQuota(anna, 1);
        await expectLater(
          endpoints.file.copyToItem(
            anna.endpointSession,
            file.fileUuid,
            const Uuid().v7obj(),
            b.uuid,
          ),
          throwsA(
            isA<WonkyException>().having(
              (e) => e.code,
              'code',
              WonkyErrorCode.quotaExceeded,
            ),
          ),
        );
      },
    );
  });
}
