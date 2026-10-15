// Each device runs in its own isolate and syncs over HTTP.
@Tags(['integration'])
@Timeout(Duration(minutes: 3))
library;

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';
import 'package:wonky_slides_core/interfaces.dart' show DeckChangeLogEntry;
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/spaces/space_service.dart';
import 'package:wonky_server/src/sheets/spaces/spreadsheet_factory.dart';
import 'package:wonky_server/src/sheets/sync/sync_db.dart';
import 'package:wonky_server/src/slides/changelog/deck_change_log_processor.dart';
import 'package:wonky_server/src/slides/changelog/deck_drive_mirror.dart';

import '../../support/sheets_device.dart';
import '../../support/slides_device.dart';
import '../../support/test_drive.dart';
import '../../support/test_users.dart';
import '../../support/wonky_serverpod.dart';

/// Deck spaces and `slidesSync.sync` (Slides 02 §9, 12 §4 SL-5): offline
/// creation in reserved deck spaces, registration, sync to other devices,
/// the space filter between Sheets and Slides replicas (patch OS-8), role
/// mirroring and title mirroring.
void main() {
  withWonkyServerpod('Given Slides devices', (sessionBuilder, endpoints) {
    late Session server;

    setUpAll(() {
      server = sessionBuilder.build();
      installDeviceAuthentication(server);
    });

    tearDown(DeckDriveMirror.reset);

    test('when a deck is created offline in a reserved space, registered and '
        'synced, then a second device of a collaborator receives it and the '
        'change log is consumed', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      final a = await SlidesDevice.open(server, anna.authUserId);
      final space = (await a.reserveSpaces(1)).single;
      await a.sync();
      expect(await a.isMember(space), isTrue);

      // Offline: the rows are written locally, then synced before the
      // registration reached the server (the consumer waits for it).
      await a.createDeck(space, 'Pitch');
      await a.sync();
      final deck = await Deck.db.findById(syncSessionOf(server), space);
      expect(deck?.title, 'Pitch');
      expect(
        await DeckChangeLogReceipt.db.count(
          server,
          where: (t) => t.deckUuid.equals(space),
        ),
        0,
      );

      final item = await a.registerPresentation(space, 'Pitch');
      expect(item.uuid, space);
      expect(item.kind.name, 'presentation');
      final receipts = await DeckChangeLogReceipt.db.find(
        server,
        where: (t) => t.deckUuid.equals(space),
      );
      expect(receipts, hasLength(1));
      expect(receipts.single.completedAt, isNotNull);
      expect(
        receipts.single.doneConsumers.toSet(),
        containsAll({'drive', 'activity', 'storage'}),
      );

      await endpoints.sharing.share(
        anna.endpointSession,
        space,
        [bo.email],
        AccessRole.editor,
        false,
        null,
        null,
      );
      final b = await SlidesDevice.open(server, bo.authUserId);
      final sub = await b.subscribe(space);
      expect(sub.canWrite, isTrue);
      expect(sub.stats.sheetCount, 1, reason: 'one slide');
      expect(sub.stats.totalRows, greaterThan(10));
      await b.sync();

      expect(await b.title(space), 'Pitch');
      expect(await b.rowCount(space), await a.rowCount(space));
      final counts = await b.tableCounts(space);
      expect(counts['deck'], 1);
      expect(counts['deck_theme'], 1);
      expect(counts['slide'], 1);
      expect(counts['slide_layout'], greaterThanOrEqualTo(16));
    });

    test(
      'when a user has decks and spreadsheets, then the Slides replica '
      'only receives decks and the Sheets replica only spreadsheets',
      () async {
        final user = await TestUsers.create(sessionBuilder);
        final deck = await endpoints.drive.createPresentation(
          user.endpointSession,
          null,
          'Deck',
          null,
        );
        final sheet = await SpaceService.createSpace(
          server,
          user.actor,
          kind: SpaceKind.spreadsheet,
        );
        await SpreadsheetFactory.write(
          server,
          spaceUuid: sheet,
          authorUuid: user.authUserId,
          title: 'Sheet',
        );
        final slides = await SlidesDevice.open(server, user.authUserId);
        final sheets = await SheetsDevice.open(server, user.authUserId);

        await slides.sync();
        await sheets.sync();

        expect(await slides.isMember(user.authUserId), isTrue);
        expect(await slides.isMember(deck.uuid), isTrue);
        expect(await slides.title(deck.uuid), 'Deck');
        expect(await slides.isMember(sheet), isFalse);
        expect(await sheets.isMember(sheet), isTrue);
        expect(await sheets.title(sheet), 'Sheet');
        expect(await sheets.isMember(deck.uuid), isFalse);
        expect(await sheets.rowCount(deck.uuid), 0);

        // Reservations are kind-aware too.
        final reserved = (await slides.reserveSpaces(1)).single;
        await slides.sync();
        await sheets.sync();
        expect(await slides.isMember(reserved), isTrue);
        expect(await sheets.isMember(reserved), isFalse);
      },
    );

    test('when collaborators subscribe, then their space role mirrors the '
        'drive role and follows role changes and removal', () async {
      final owner = await TestUsers.create(sessionBuilder, name: 'Owner');
      final viewer = await TestUsers.create(sessionBuilder, name: 'Viewer');
      final editor = await TestUsers.create(sessionBuilder, name: 'Editor');
      final item = await endpoints.drive.createPresentation(
        owner.endpointSession,
        null,
        'Shared',
        null,
      );
      await TestDrive.share(endpoints, item, owner, viewer, AccessRole.viewer);
      await TestDrive.share(endpoints, item, owner, editor, AccessRole.editor);
      Future<OfflineSyncSpaceRole?> roleOf(TestUser u) =>
          server.offlineSync.spaces.roleOf(
            user: u.authUserId,
            space: item.uuid,
          );

      final v = await endpoints.slides.subscribe(
        viewer.endpointSession,
        item.uuid,
      );
      final e = await endpoints.slides.subscribe(
        editor.endpointSession,
        item.uuid,
      );

      expect(v.canWrite, isFalse);
      expect(v.role, AccessRole.viewer);
      expect(await roleOf(viewer), OfflineSyncSpaceRole.readOnly);
      expect(e.canWrite, isTrue);
      expect(await roleOf(editor), OfflineSyncSpaceRole.readWrite);
      final subscription = await SpaceSubscription.db.findFirstRow(
        server,
        where: (t) =>
            t.userId.equals(viewer.id) & t.spaceUuid.equals(item.uuid),
      );
      expect(subscription?.kind, SpaceKind.deck);

      await endpoints.sharing.updateRole(
        owner.endpointSession,
        item.uuid,
        viewer.id,
        AccessRole.editor,
      );
      expect(await roleOf(viewer), OfflineSyncSpaceRole.readWrite);
      await endpoints.sharing.remove(
        owner.endpointSession,
        item.uuid,
        editor.id,
      );
      expect(await roleOf(editor), isNull);
      await expectLater(
        endpoints.slides.subscribe(editor.endpointSession, item.uuid),
        throwsA(isA<WonkyException>()),
      );
    });

    test('when a non-member or a spreadsheet is subscribed, then it is '
        'refused, and the guard only re-grants deck spaces', () async {
      final owner = await TestUsers.create(sessionBuilder, name: 'Owner');
      final stranger = await TestUsers.create(sessionBuilder, name: 'X');
      final deck = await endpoints.drive.createPresentation(
        owner.endpointSession,
        null,
        'Deck',
        null,
      );
      final reservedDeck = (await endpoints.slides.reserveSpaces(
        owner.endpointSession,
        1,
      )).single;
      final reservedSheet = (await endpoints.sheets.reserveSpaces(
        owner.endpointSession,
        1,
      )).single;

      await expectLater(
        endpoints.slides.subscribe(stranger.endpointSession, deck.uuid),
        throwsA(isA<WonkyException>()),
      );
      expect(
        await endpoints.slides.ensureSubscribed(owner.endpointSession, [
          deck.uuid,
          reservedDeck,
          reservedSheet,
        ]),
        unorderedEquals([deck.uuid, reservedDeck]),
      );
      expect(
        await endpoints.slides.ensureSubscribed(stranger.endpointSession, [
          deck.uuid,
          reservedDeck,
        ]),
        isEmpty,
      );
      final stats = await endpoints.slides.spaceStats(
        owner.endpointSession,
        deck.uuid,
      );
      expect(stats.rowCounts['deck'], 1);
      expect(stats.sheetCount, 1);
    });

    test(
      'when the deck is renamed on a device, then the drive item follows; '
      'when the drive item is renamed, then the deck title follows',
      () async {
        final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
        final a = await SlidesDevice.open(server, anna.authUserId);
        final space = (await a.reserveSpaces(1)).single;
        await a.sync();
        await a.createDeck(space, 'Draft');
        await a.registerPresentation(space, 'Draft');
        await a.sync();

        await a.rename(space, 'Quarterly review');
        await a.sync();

        final item = await DriveItem.db.findFirstRow(
          server,
          where: (t) => t.uuid.equals(space),
        );
        expect(item?.name, 'Quarterly review');

        await endpoints.drive.rename(anna.endpointSession, space, 'Final');
        final deck = await Deck.db.findById(syncSessionOf(server), space);
        expect(deck?.title, 'Final');
        await a.sync();
        expect(await a.title(space), 'Final');
      },
    );

    test('when a deck is created on the server, then it holds the default '
        'theme and a title slide, is searchable and has a size', () async {
      final user = await TestUsers.create(sessionBuilder);
      final item = await endpoints.drive.createPresentation(
        user.endpointSession,
        null,
        'Launch plan',
        null,
      );

      final db = syncSessionOf(server);
      final deck = await Deck.db.findById(db, item.uuid);
      expect(deck?.title, 'Launch plan');
      expect(deck?.createdBy, user.authUserId);
      final themes = await DeckTheme.db.find(
        db,
        where: (t) => t.deckId.equals(item.uuid),
      );
      expect(themes.single.id, deck!.themeId);
      expect(themes.single.sourceKey, startsWith('builtin:wonky@'));
      final slides = await Slide.db.find(
        db,
        where: (t) => t.deckId.equals(item.uuid),
      );
      expect(slides, hasLength(1));
      final placeholders = await SlideElement.db.find(
        db,
        where: (t) => t.slideId.equals(slides.single.id),
      );
      expect(placeholders, isNotEmpty);
      final fresh = await DriveItem.db.findFirstRow(
        server,
        where: (t) => t.uuid.equals(item.uuid),
      );
      expect(fresh?.searchText, contains('Launch plan'));
      expect(fresh?.sizeBytes, greaterThan(0));
      final log = await DeckChangeLog.db.find(
        db,
        where: (t) => t.deckId.equals(item.uuid),
      );
      expect(log.single.label, 'Create presentation');
      final receipt = await DeckChangeLogReceipt.db.findFirstRow(
        server,
        where: (t) => t.changeLogId.equals(log.single.id),
      );
      expect(receipt?.completedAt, isNotNull);
    });

    test('when a template is passed, then server creation is refused for '
        'now', () async {
      final user = await TestUsers.create(sessionBuilder);
      await expectLater(
        endpoints.drive.createPresentation(
          user.endpointSession,
          null,
          'From template',
          const Uuid().v7obj(),
        ),
        throwsA(isA<WonkyException>()),
      );
    });

    test('when the change log is processed again, after a crash or by a '
        'second call, then every plugin consumes each row once', () async {
      final user = await TestUsers.create(sessionBuilder);
      final counter = _CountingPlugin();
      DeckChangeLogProcessor.register(counter);
      addTearDown(() => DeckChangeLogProcessor.unregister(counter.id));
      final item = await endpoints.drive.createPresentation(
        user.endpointSession,
        null,
        'Once',
        null,
      );
      expect(counter.consumed, hasLength(1));

      // A second pass finds nothing new.
      expect(
        await DeckChangeLogProcessor.processSpace(server, item.uuid),
        0,
      );
      expect(counter.consumed, hasLength(1));

      // A crash after the counting plugin ran: the claim is stale and not
      // completed; re-processing skips the plugins already recorded.
      final receipt = (await DeckChangeLogReceipt.db.find(
        server,
        where: (t) => t.deckUuid.equals(item.uuid),
      )).single;
      await DeckChangeLogReceipt.db.updateRow(
        server,
        receipt.copyWith(
          completedAt: null,
          processedAt: DateTime.now().toUtc().subtract(
            const Duration(hours: 1),
          ),
          doneConsumers: [counter.id],
        ),
      );
      final row = await DriveItem.db.findFirstRow(
        server,
        where: (t) => t.uuid.equals(item.uuid),
      );
      final activityBefore = await ActivityEvent.db.count(
        server,
        where: (t) => t.itemId.equals(row!.id),
      );

      expect(
        await DeckChangeLogProcessor.processSpace(server, item.uuid),
        1,
      );

      expect(counter.consumed, hasLength(1));
      final after = await DeckChangeLogReceipt.db.findById(
        server,
        receipt.id!,
      );
      expect(after?.completedAt, isNotNull);
      expect(
        after?.doneConsumers.toSet(),
        containsAll({counter.id, 'drive', 'activity', 'storage'}),
      );
      expect(
        await ActivityEvent.db.count(
          server,
          where: (t) => t.itemId.equals(row!.id),
        ),
        greaterThanOrEqualTo(activityBefore),
      );
    });

    test('when a plugin throws, then the others still run and the row is '
        'completed', () async {
      final user = await TestUsers.create(sessionBuilder);
      final failing = _FailingPlugin();
      final counter = _CountingPlugin(id: 'test.after-failure');
      DeckChangeLogProcessor.register(failing);
      DeckChangeLogProcessor.register(counter);
      addTearDown(() {
        DeckChangeLogProcessor.unregister(failing.id);
        DeckChangeLogProcessor.unregister(counter.id);
      });

      final item = await endpoints.drive.createPresentation(
        user.endpointSession,
        null,
        'Robust',
        null,
      );

      expect(counter.consumed, hasLength(1));
      final receipt = await DeckChangeLogReceipt.db.findFirstRow(
        server,
        where: (t) => t.deckUuid.equals(item.uuid),
      );
      expect(receipt?.completedAt, isNotNull);
      expect(receipt?.doneConsumers, contains(failing.id));
    });
  });
}

class _CountingPlugin implements DeckChangeLogPlugin {
  _CountingPlugin({this.id = 'test.counter'});

  @override
  final String id;

  final List<String> consumed = [];

  @override
  Future<void> consume(
    DeckConsumerContext context,
    String deckId,
    List<DeckChangeLogEntry> rows,
  ) async {
    for (final r in rows) {
      consumed.add(r.id);
    }
  }
}

class _FailingPlugin implements DeckChangeLogPlugin {
  @override
  String get id => 'test.failing';

  @override
  Future<void> consume(
    DeckConsumerContext context,
    String deckId,
    List<DeckChangeLogEntry> rows,
  ) async => throw Exception('boom');
}
