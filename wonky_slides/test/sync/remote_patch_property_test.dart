import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides/features/model/synced_deck_session.dart';
import 'package:wonky_slides_core/ops.dart';

import 'support/random_ops.dart';
import 'support/slides_sync_harness.dart';

final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000e1');

void main() {
  for (final seed in [1, 2, 3, 4, 5]) {
    test('Given a session open on a deck that two devices edit, when the '
        'remote edits are patched in incrementally (seed $seed) then the '
        'model equals a full reload of the replica', () async {
      final r = Random(seed);
      final replica = await openTestReplica();
      final host = FakeSessionHost(replica);
      await createDeck(replica, space);
      final s = SyncedDeckSession.open(
        host,
        itemUuid: space,
        spaceUuid: space,
        planner: planner,
        role: Role.owner,
      );
      addTearDown(s.dispose);
      await s.opened;

      var remoteWrites = 0;
      var localWrites = 0;
      for (var step = 0; step < 30; step++) {
        if (r.nextBool()) {
          // Another device (its write lands in the replica as a merge).
          await s.flush();
          final m = await reloadModel(replica, space);
          final op = randomOp(r, m);
          if (op == null) continue;
          try {
            await writeOp(replica, space, (_) => op);
            remoteWrites++;
          } on PlanException {
            continue;
          }
          if (r.nextInt(3) == 0) host.mergesController.add(space);
        } else {
          // This device: the model must be current before planning.
          await s.ingestRemote();
          final op = randomOp(r, s.model);
          if (op == null) continue;
          try {
            s.execute(op);
            localWrites++;
          } on PlanException {
            continue;
          }
        }
      }
      await s.flush();
      await s.ingestRemote();

      expect(remoteWrites, greaterThan(3));
      expect(localWrites, greaterThan(3));
      final reloaded = await reloadModel(replica, space);
      expect(canonical(s.model), canonical(reloaded));
      expect(s.fullReloads, 1, reason: 'only the initial load');

      // A session opened now (a full load) sees the same deck.
      final fresh = SyncedDeckSession.open(
        host,
        itemUuid: space,
        spaceUuid: space,
        planner: planner,
      );
      addTearDown(fresh.dispose);
      await fresh.opened;
      expect(canonical(fresh.model), canonical(s.model));
    });
  }
}
