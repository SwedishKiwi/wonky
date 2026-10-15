import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show AccessRole, Deck, DeckChangeLog;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides/features/model/deck_session.dart';
import 'package:wonky_slides/features/sync/slides_sync_controller.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart' show SlidesTables;
import 'package:wonky_slides_core/templates.dart' show SlidesTemplates;

import 'support/random_ops.dart';
import 'support/slides_sync_harness.dart';

void main() {
  group('Given two devices and a sync server', () {
    late FakeSlidesServer server;
    late SlidesSyncController a;
    late FakeRemote remoteA;
    late FakeConnectivity netA;

    setUp(() async {
      server = await FakeSlidesServer.open();
      (a, remoteA, netA) = await openDevice(server, testUser);
    });

    test('when reservations are refilled then a pool of three deck spaces is '
        'reserved and usable after the next sync', () async {
      await a.syncNow();
      await a.refillReservations();
      expect(await a.replica.reservations(), hasLength(3));
      expect(await a.replica.usableReservations(), isEmpty);

      await a.syncNow();

      expect(await a.replica.usableReservations(), hasLength(3));
    });

    test('when no reservation is usable then offline creation is refused', () {
      expect(
        () => a.createLocalPresentation(title: 'x'),
        throwsA(isA<NoReservedSpaceException>()),
      );
    });

    test('when a deck is created offline then it syncs once online and a '
        'collaborator it is shared with opens it', () async {
      await prepareReservations(a);
      netA.online.value = false;
      remoteA.offline = true;

      final space = await a.createLocalPresentation(title: 'Offline made');
      expect(await a.replica.hasDeck(space), isTrue);
      expect(await a.replica.reservations(), hasLength(2));
      expect(await a.replica.dirtySpaces(), [space]);
      final logs = await DeckChangeLog.db.find(a.replica.session);
      expect(logs.single.deckId, space);
      // The deck opens at once, offline.
      final sa = a.openSession(itemUuid: space, spaceUuid: space);
      addTearDown(sa.dispose);
      await sa.opened;
      expect(sa.loadState.value, isA<DeckReady>());
      expect(sa.model.slides, hasLength(1));

      remoteA.offline = false;
      netA.online.value = true;
      await a.syncNow();
      expect(remoteA.ensureCalls.last, [space]);
      expect(await a.replica.dirtySpaces(), isEmpty);

      // Shared with another user: the server mirrors the ACL into the
      // membership; their device subscribes when opening.
      final (b, _, _) = await openDevice(server, otherUser);
      final sb = b.openSession(itemUuid: space, spaceUuid: space);
      addTearDown(sb.dispose);
      b.start();
      await eventually(
        () => sb.loadState.value is DeckReady,
        timeout: const Duration(seconds: 20),
      );
      expect(sb.model.deck?.title, 'Offline made');
      expect(sb.role.value, Role.editor);
      expect(canonical(sb.model), canonical(sa.model));
      expect(
        (await Deck.db.findById(b.replica.session, space))?.title,
        'Offline made',
      );
    });

    test('when a viewer opens a deck then the session is read-only', () async {
      await prepareReservations(a);
      final space = await a.createLocalPresentation(title: 'Shared');
      await a.syncNow();
      final (b, remoteB, _) = await openDevice(server, otherUser);
      remoteB.subscribeRole = AccessRole.viewer;

      final sb = b.openSession(itemUuid: space, spaceUuid: space);
      addTearDown(sb.dispose);
      b.start();
      await eventually(
        () => sb.loadState.value is DeckReady,
        timeout: const Duration(seconds: 20),
      );

      expect(sb.role.value, Role.viewer);
      expect(sb.canEdit, isFalse);
      expect(
        () => sb.execute(const AddSlides()),
        throwsA(isA<PlanException>()),
      );
    });

    for (final template in [null, SlidesTemplates.all.first]) {
      final kind = template == null ? 'a blank deck' : 'a built-in template';
      test(
        'when $kind is created and opened as the sync loop starts then '
        'the session holds its theme package before and after the sync',
        () async {
          await prepareReservations(a);
          final space = await a.createLocalPresentation(
            title: 'Fresh',
            template: template,
          );
          await a.syncNow();
          final (b, _, _) = await openDevice(server, otherUser);
          // The sessions subscribe while the loops' first cycles run (the
          // creator is already a member: its subscribe must not drop the
          // membership, or the deck's rows vanish from the device's reads).
          final sa = a.openSession(
            itemUuid: space,
            spaceUuid: space,
            role: Role.owner,
          );
          final sb = b.openSession(itemUuid: space, spaceUuid: space);
          addTearDown(sa.dispose);
          addTearDown(sb.dispose);
          a.start();
          b.start();
          await sa.opened;

          Future<void> expectThemePackage() async {
            expect(sa.loadState.value, isA<DeckReady>());
            final m = sa.model;
            expect(m.count(SlidesTables.deckTheme), greaterThanOrEqualTo(1));
            expect(m.count(SlidesTables.slideMaster), greaterThanOrEqualTo(1));
            expect(m.count(SlidesTables.slideLayout), greaterThan(1));
            expect(m.slides, isNotEmpty);
            expect(
              canonical(m),
              canonical(await reloadModel(a.replica, space)),
            );
          }

          await expectThemePackage();
          // The deck's first upload and the subscribe of the open session.
          await a.stop();
          await a.syncNow();
          await a.syncNow();
          await sa.ingestRemote();
          expect(await a.replica.dirtySpaces(), isEmpty);
          expect(await a.replica.roleOf(space), isNotNull);
          await expectThemePackage();
          await eventually(
            () => sb.loadState.value is DeckReady,
            timeout: const Duration(seconds: 20),
          );
          expect(canonical(sb.model), canonical(sa.model));
        },
      );
    }

    test(
      'when two devices edit the same deck at random then both converge '
      'through continuous sync',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        await prepareReservations(a);
        final space = await a.createLocalPresentation(title: 'Converge');
        await a.syncNow();
        final (b, _, _) = await openDevice(server, otherUser);
        final sa = a.openSession(
          itemUuid: space,
          spaceUuid: space,
          role: Role.owner,
        );
        final sb = b.openSession(itemUuid: space, spaceUuid: space);
        addTearDown(sa.dispose);
        addTearDown(sb.dispose);
        a.start();
        b.start();
        await sa.opened;
        await eventually(
          () => sb.loadState.value is DeckReady,
          timeout: const Duration(seconds: 20),
        );

        final r = Random(7);
        var edits = 0;
        for (var step = 0; step < 16; step++) {
          final s = step.isEven ? sa : sb;
          final op = randomOp(r, s.model);
          if (op == null) continue;
          try {
            s.execute(op);
            edits++;
          } on PlanException {
            continue;
          }
          await s.flush();
          if (step % 4 == 3) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }
        expect(edits, greaterThan(5));

        // Settle deterministically: stop the streams, then complete cycles.
        await a.stop();
        await b.stop();
        for (final c in [a, b, a, b]) {
          await c.syncNow();
        }
        var last = '';
        try {
          await eventually(() async {
            await sa.ingestRemote();
            await sb.ingestRemote();
            final ra = canonical(await reloadModel(a.replica, space));
            final rb = canonical(await reloadModel(b.replica, space));
            final ma = canonical(sa.model);
            final mb = canonical(sb.model);
            last = [
              'ra-rb ${ra.toSet().difference(rb.toSet())}',
              'rb-ra ${rb.toSet().difference(ra.toSet())}',
              'ma-ra ${ma.toSet().difference(ra.toSet())}',
              'ra-ma ${ra.toSet().difference(ma.toSet())}',
              'mb-rb ${mb.toSet().difference(rb.toSet())}',
              'rb-mb ${rb.toSet().difference(mb.toSet())}',
            ].join('\n');
            return _same(ra, rb) && _same(ma, ra) && _same(mb, rb);
          }, timeout: const Duration(seconds: 20));
        } catch (_) {
          fail('Not converged:\n$last');
        }
      },
    );
  });
}

bool _same(List<String> a, List<String> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
