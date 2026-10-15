// Each device runs in its own isolate and syncs over HTTP.
@Tags(['integration'])
@Timeout(Duration(minutes: 3))
library;

import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/sheets/sync/sync_db.dart';
import 'package:wonky_server/src/slides/changelog/deck_drive_mirror.dart';

import '../../support/sheets_device.dart' show installDeviceAuthentication;
import '../../support/slides_device.dart';
import '../../support/test_users.dart';
import '../../support/wonky_serverpod.dart';

/// The Slides app's offline creation against the real server (Slides 02
/// §9.3, 12 §4 SL-9): the rows the app writes (`SlidesPlanner` `CreateDeck`,
/// as `SlidesSyncController.createLocalPresentation`) sync through
/// `slidesSync.sync`, `drive.registerPresentation` makes the space a drive
/// item, the change-log consumer accepts the planner's summary, and a
/// collaborator's device receives every row.
void main() {
  withWonkyServerpod('Given the Slides app creating a deck offline', (
    sessionBuilder,
    endpoints,
  ) {
    late Session server;

    setUpAll(() {
      server = sessionBuilder.build();
      installDeviceAuthentication(server);
    });

    tearDown(DeckDriveMirror.reset);

    test('when the planner rows sync and the deck is registered then the '
        'drive item, the consumed change log and a collaborator device all '
        'see the deck', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      final a = await SlidesDevice.open(server, anna.authUserId);
      final space = (await a.reserveSpaces(1)).single;
      await a.sync();

      final written = await a.createPlannedDeck(space, 'Roadmap');
      await a.sync();
      expect(
        (await Deck.db.findById(syncSessionOf(server), space))?.title,
        'Roadmap',
      );

      final item = await a.registerPresentation(space, 'Roadmap');
      expect(item.uuid, space);
      expect(item.contentRef, space);
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
      expect(
        await DeckDriveMirror.searchText(server, space),
        contains('Roadmap'),
      );

      await endpoints.sharing.share(
        anna.endpointSession,
        space,
        [bo.email],
        AccessRole.viewer,
        false,
        null,
        null,
      );
      final b = await SlidesDevice.open(server, bo.authUserId);
      final sub = await b.subscribe(space);
      expect(sub.canWrite, isFalse);
      // The server's count includes the change-log row.
      expect(sub.stats.totalRows, written + 1);
      await b.sync();

      expect(await b.title(space), 'Roadmap');
      expect(await b.rowCount(space), written);
      expect(await a.rowCount(space), written);
    });
  });
}
