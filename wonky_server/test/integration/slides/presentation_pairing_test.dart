@Tags(['integration'])
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/slides/present/presentation_service.dart';

import '../../support/streams.dart';
import '../../support/test_drive.dart';
import '../../support/test_users.dart';
import '../../support/wonky_serverpod.dart';

class _Client {
  _Client(this.updates, this.events);

  final StreamController<PresentationUpdate> updates;
  final StreamQueue<PresentationEvent> events;

  Future<T> next<T extends PresentationEvent>() async =>
      await nextWhere(events, (e) => e is T) as T;

  Future<void> close() async {
    await updates.close();
    await events.cancel(immediate: true);
  }
}

/// Phone remote pairing (Slides 10 §6.4; SL-41): pairing keys and six-digit
/// codes issued by the presenter, single use, 10 min, other accounts need
/// a key and ≥ viewer, paired remotes rejoin without one.
void main() {
  withWonkyServerpod('Given a presenter on a shared deck', (
    sessionBuilder,
    endpoints,
  ) {
    late TestUser anna;
    late TestUser bo;
    late DriveItemView deck;

    setUp(() async {
      PresentationService.presenterGrace = const Duration(milliseconds: 200);
      PresentationService.joinTimeout = const Duration(milliseconds: 600);
      PresentationService.probeTimeout = const Duration(milliseconds: 150);
      anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      deck = await endpoints.drive.createPresentation(
        anna.endpointSession,
        null,
        'Q3 Review',
        null,
      );
      await TestDrive.share(endpoints, deck, anna, bo, AccessRole.viewer);
    });

    tearDown(() {
      PresentationService.presenterGrace = const Duration(seconds: 30);
      PresentationService.joinTimeout = const Duration(seconds: 3);
      PresentationService.probeTimeout = const Duration(milliseconds: 400);
      PresentationService.pairingTtl = const Duration(minutes: 10);
    });

    _Client connect(
      TestUser user,
      PresentationRole role, {
      String? sessionId,
      String? pairingKey,
    }) {
      final updates = StreamController<PresentationUpdate>();
      final events = StreamQueue(
        endpoints.presentation.join(
          user.endpointSession,
          deck.uuid,
          PresentationJoin(
            sessionId: sessionId,
            role: role,
            deviceLabel: 'Phone',
            pairingKey: pairingKey,
          ),
          updates.stream,
        ),
      );
      return _Client(updates, events);
    }

    Future<(_Client, String, PresentationPairingEvent)> pair() async {
      final presenter = connect(anna, PresentationRole.presenter);
      final welcome = await presenter.next<PresentationWelcome>();
      presenter.updates.add(PresentationPairingUpdate());
      final pairing = await presenter.next<PresentationPairingEvent>();
      return (presenter, welcome.sessionId, pairing);
    }

    test('when the presenter asks for a pairing then it gets a 128-bit key '
        'and a six-digit code valid for 10 minutes', () async {
      final (presenter, _, pairing) = await pair();

      expect(pairing.pairingKey, matches(RegExp(r'^[0-9A-Za-z]{22}$')));
      expect(pairing.code, matches(RegExp(r'^[0-9]{6}$')));
      expect(
        pairing.expiresAtMs - pairing.serverTimeMs,
        const Duration(minutes: 10).inMilliseconds,
      );
      await presenter.close();
    });

    test(
      'when another account joins as remote with the key then it is '
      'admitted, its commands reach the presenter, and the key is used up',
      () async {
        final (presenter, sessionId, pairing) = await pair();

        final remote = connect(
          bo,
          PresentationRole.remote,
          sessionId: sessionId,
          pairingKey: pairing.pairingKey,
        );
        final welcome = await remote.next<PresentationWelcome>();
        final roster = await presenter.next<PresentationRosterEvent>();
        expect(welcome.role, PresentationRole.remote);
        expect(roster.participants.single.role, PresentationRole.remote);
        expect(roster.participants.single.displayName, 'Bo');

        remote.updates.add(PresentationCommandUpdate(command: 'next'));
        final command = await presenter.next<PresentationCommandEvent>();
        expect(command.command, 'next');

        final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
        await TestDrive.share(endpoints, deck, anna, eve, AccessRole.viewer);
        final reused = connect(
          eve,
          PresentationRole.remote,
          sessionId: sessionId,
          pairingKey: pairing.pairingKey,
        );
        final refused = await reused.next<PresentationEndedEvent>();
        expect(refused.reason, 'pairingExpired');

        await remote.close();
        await reused.close();
        await presenter.close();
      },
    );

    test('when a paired remote reconnects then it is admitted again without '
        'a new key', () async {
      final (presenter, sessionId, pairing) = await pair();
      final first = connect(
        bo,
        PresentationRole.remote,
        sessionId: sessionId,
        pairingKey: pairing.pairingKey,
      );
      await first.next<PresentationWelcome>();
      await first.close();

      final again = connect(
        bo,
        PresentationRole.remote,
        sessionId: sessionId,
        pairingKey: pairing.pairingKey,
      );
      final welcome = await again.next<PresentationWelcome>();
      expect(welcome.role, PresentationRole.remote);
      await again.close();
      await presenter.close();
    });

    test('when another account joins as remote without a key, with a wrong '
        'or an expired key then it is refused', () async {
      PresentationService.pairingTtl = Duration.zero;
      final (presenter, sessionId, pairing) = await pair();

      final noKey = connect(bo, PresentationRole.remote, sessionId: sessionId);
      expect((await noKey.next<PresentationEndedEvent>()).reason, 'noAccess');

      final wrong = connect(
        bo,
        PresentationRole.remote,
        sessionId: sessionId,
        pairingKey: PresentationService.newSessionId(),
      );
      expect(
        (await wrong.next<PresentationEndedEvent>()).reason,
        'pairingExpired',
      );

      final expired = connect(
        bo,
        PresentationRole.remote,
        sessionId: sessionId,
        pairingKey: pairing.pairingKey,
      );
      expect(
        (await expired.next<PresentationEndedEvent>()).reason,
        'pairingExpired',
      );
      await noKey.close();
      await wrong.close();
      await expired.close();
      await presenter.close();
    });

    test('when an account without access uses a valid key then joining is '
        'refused', () async {
      final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
      final (presenter, sessionId, pairing) = await pair();
      final remote = connect(
        eve,
        PresentationRole.remote,
        sessionId: sessionId,
        pairingKey: pairing.pairingKey,
      );
      await expectLater(remote.events.next, throwsA(isA<WonkyException>()));
      await remote.close();
      await presenter.close();
    });

    test(
      'when the presenter revokes the pairing then the key is refused',
      () async {
        final (presenter, sessionId, pairing) = await pair();
        presenter.updates.add(PresentationPairingUpdate(revoke: true));
        // The revoke is handled before the next update.
        presenter.updates.add(PresentationPairingUpdate());
        await presenter.next<PresentationPairingEvent>();

        final remote = connect(
          bo,
          PresentationRole.remote,
          sessionId: sessionId,
          pairingKey: pairing.pairingKey,
        );
        expect(
          (await remote.next<PresentationEndedEvent>()).reason,
          'pairingExpired',
        );
        await remote.close();
        await presenter.close();
      },
    );

    test('when the code is typed then it resolves to the session and key, '
        'for viewers only; unknown codes resolve to null', () async {
      final (presenter, sessionId, pairing) = await pair();

      final target = await endpoints.presentation.resolvePairingCode(
        bo.endpointSession,
        pairing.code,
      );
      expect(target?.deckUuid, deck.uuid);
      expect(target?.sessionId, sessionId);
      expect(target?.pairingKey, pairing.pairingKey);

      final unknown = pairing.code == '000000' ? '000001' : '000000';
      expect(
        await endpoints.presentation.resolvePairingCode(
          bo.endpointSession,
          unknown,
        ),
        isNull,
      );
      expect(
        await endpoints.presentation.resolvePairingCode(
          bo.endpointSession,
          'abc',
        ),
        isNull,
      );

      final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
      await expectLater(
        endpoints.presentation.resolvePairingCode(
          eve.endpointSession,
          pairing.code,
        ),
        throwsA(isA<WonkyException>()),
      );
      await presenter.close();
    });

    test('when a user types more than 10 codes a minute then resolving is '
        'refused', () async {
      final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
      for (var i = 0; i < PresentationService.maxResolvesPerWindow; i++) {
        await endpoints.presentation.resolvePairingCode(
          eve.endpointSession,
          'x$i',
        );
      }
      await expectLater(
        endpoints.presentation.resolvePairingCode(eve.endpointSession, 'x'),
        throwsA(
          isA<WonkyException>().having(
            (e) => e.code,
            'code',
            WonkyErrorCode.limitExceeded,
          ),
        ),
      );
    });
  });
}
