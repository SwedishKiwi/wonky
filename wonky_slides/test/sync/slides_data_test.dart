import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_client/wonky_client.dart'
    show AccessRole, Client, DriveItemKind, UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides/config/slides_app_config.dart';
import 'package:wonky_slides/features/model/deck_session.dart';
import 'package:wonky_slides/features/model/memory_deck_session.dart';
import 'package:wonky_slides/features/model/synced_deck_session.dart';
import 'package:wonky_slides/features/sync/slides_data.dart';
import 'package:wonky_slides/features/sync/slides_replica.dart';
import 'package:wonky_app/wonky_app.dart' show MemoryStore;

import 'support/slides_sync_harness.dart';

final item = UuidValue.fromString('01a13917-7cdf-7a38-9d0c-6c7f8ba7db90');

void main() {
  const config = SlidesAppConfig();

  test('Given the data layer is not installed when a presentation opens then '
      'it is an in-memory blank deck', () async {
    final h = CommandTestHarness(config: config);
    addTearDown(h.dispose);

    final s = await openDeckSession(h.services, item);
    addTearDown(s.dispose);

    expect(s, isA<MemoryDeckSession>());
    expect(s.loadState.value, isA<DeckReady>());
    expect(s.model.slides, hasLength(1));
  });

  test('Given the data layer is installed but its replica fails to open '
      'when a presentation opens then it fails instead of showing an empty '
      'in-memory deck', () async {
    final h = CommandTestHarness(config: config);
    addTearDown(h.dispose);
    SlidesData.install(
      h.services,
      open: (_) async => throw StateError('sqlite3.wasm failed to load'),
    );
    addTearDown(() => SlidesData.uninstall(h.services));

    await expectLater(
      openDeckSession(
        h.services,
        item,
        readyTimeout: const Duration(milliseconds: 200),
      ),
      throwsA(isA<SlidesDataUnavailableException>()),
    );
  });

  group('Given a signed-in user with the Slides data layer', () {
    late CommandTestHarness h;
    late FakeSlidesServer server;
    late UuidValue me;

    setUp(() async {
      server = await FakeSlidesServer.open();
      h = CommandTestHarness(config: config);
      addTearDown(h.dispose);
      me = h.services.me!.uuid;
      // The data layer closes its replica on uninstall (before the
      // directory goes).
      final dir = await Directory.systemTemp.createTemp('wonky_slides_data_');
      addTearDown(() => dir.delete(recursive: true));
      var n = 0;
      SlidesData.install(
        h.services,
        open: (user) => SlidesReplica.open(
          client: Client('http://localhost:1/'),
          path: '${dir.path}/slides_${n++}.db',
          userUuid: user,
        ),
        remote: () => FakeRemote(server, me)..subscribeRole = AccessRole.owner,
      );
      addTearDown(() => SlidesData.uninstall(h.services));
    });

    test('when New presentation runs then the deck is created locally, '
        'registered in the drive with the space as item uuid, and opens from '
        'the replica', () async {
      final c = (await SlidesData.ready(h.services))!;
      await prepareReservations(c);

      final uuid = await config.createItem(h.services, name: 'Pitch');

      expect(h.drive.calls, contains('registerPresentation'));
      expect(h.drive.calls, isNot(contains('createPresentation')));
      final driveItem = h.drive.item(uuid!);
      expect(driveItem.kind, DriveItemKind.presentation);
      expect(driveItem.contentRef, uuid);
      expect(driveItem.name, 'Pitch');
      expect(await c.replica.hasDeck(uuid), isTrue);

      final s = await openDeckSession(h.services, uuid);
      addTearDown(s.dispose);
      expect(s, isA<SyncedDeckSession>());
      await (s as SyncedDeckSession).opened;
      expect(s.loadState.value, isA<DeckReady>());
      expect(s.model.deck?.title, 'Pitch');
      expect(s.role.value, Role.owner);
      expect(
        (await DeckOpenHistory(h.services.userStore).lastOpened()).keys,
        contains(uuid.uuid),
      );
    });

    test('when New presentation runs online before any reservation then the '
        'server creates it', () async {
      await SlidesData.ready(h.services);

      final uuid = await config.createItem(h.services, name: 'Server made');

      expect(h.drive.calls, contains('createPresentation'));
      expect(h.drive.item(uuid!).kind, DriveItemKind.presentation);
    });

    test('when New presentation runs offline before any reservation then '
        'nothing is created', () async {
      final c = (await SlidesData.ready(h.services))!;
      h.services.connectivity.forceOffline(true);
      await eventually(() => !c.online.value);

      final uuid = await config.createItem(h.services);

      expect(uuid, isNull);
      expect(h.drive.items, isEmpty);
    });

    test('when signed out then the controller closes', () async {
      final c = (await SlidesData.ready(h.services))!;

      await SlidesData.uninstall(h.services);

      expect(SlidesData.current(h.services), isNull);
      expect(c.isClosed, isTrue);
    });
  });

  test('when decks are opened then the history keeps the newest', () async {
    final history = DeckOpenHistory(MemoryStore());
    for (var i = 0; i < DeckOpenHistory.keep + 3; i++) {
      await history.record('deck-$i');
    }

    final opened = await history.lastOpened();
    expect(opened, hasLength(DeckOpenHistory.keep));
  });
}
