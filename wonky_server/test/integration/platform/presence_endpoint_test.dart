import 'dart:async';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';

import '../../support/streams.dart';
import '../../support/test_drive.dart';
import '../../support/test_users.dart';
import '../../support/wonky_serverpod.dart';

void main() {
  withWonkyServerpod('Given two users on one document', (
    sessionBuilder,
    endpoints,
  ) {
    test(
      'when the second joins then both see each other and leaving is announced',
      () async {
        final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
        final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
        final doc = await TestDrive.document(endpoints, anna);
        await TestDrive.share(endpoints, doc, anna, bo, AccessRole.viewer);

        final annaUpdates = StreamController<PresenceUpdate>();
        final annaEvents = StreamQueue(
          endpoints.presence.join(
            anna.endpointSession,
            doc.uuid,
            annaUpdates.stream,
          ),
        );
        final annaRoster =
            await nextWhere(annaEvents, (e) => e is PresenceRoster)
                as PresenceRoster;

        final boUpdates = StreamController<PresenceUpdate>();
        final boEvents = StreamQueue(
          endpoints.presence.join(
            bo.endpointSession,
            doc.uuid,
            boUpdates.stream,
          ),
        );
        final boRoster =
            await nextWhere(boEvents, (e) => e is PresenceRoster)
                as PresenceRoster;
        final joined =
            await nextWhere(annaEvents, (e) => e is PresenceJoined)
                as PresenceJoined;

        annaUpdates.add(PresenceUpdate(state: PresenceState.idle));
        final updated =
            await nextWhere(boEvents, (e) => e is PresenceUpdated)
                as PresenceUpdated;

        await boUpdates.close();
        final left =
            await nextWhere(annaEvents, (e) => e is PresenceLeft)
                as PresenceLeft;

        expect(annaRoster.participants.map((p) => p.userId), [anna.id]);
        expect(boRoster.participants.map((p) => p.userId).toSet(), {
          anna.id,
          bo.id,
        });
        expect(joined.participant.userId, bo.id);
        expect(updated.state, PresenceState.idle);
        expect(left.sessionId, boRoster.sessionId);
        await annaUpdates.close();
        await annaEvents.cancel(immediate: true);
        await boEvents.cancel(immediate: true);
      },
    );

    test('when a user without access joins then it is refused', () async {
      final anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      final eve = await TestUsers.create(sessionBuilder, name: 'Eve');
      final doc = await TestDrive.document(endpoints, anna);

      final stream = endpoints.presence.join(
        eve.endpointSession,
        doc.uuid,
        const Stream<PresenceUpdate>.empty(),
      );

      await expectLater(stream.first, throwsA(isA<WonkyException>()));
    });
  });
}
