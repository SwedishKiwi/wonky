import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show Client, UuidValue;
import 'package:wonky_slides/features/sync/replica_recovery.dart';
import 'package:wonky_slides/features/sync/slides_replica.dart';

import 'support/slides_sync_harness.dart';

void main() {
  test('Given a replica with an unsynced deck when it is read for recovery '
      'then the deck and its rows are exported as JSON', () async {
    final dir = await Directory.systemTemp.createTemp('wonky_slides_rec_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/slides.db';
    final replica = await SlidesReplica.open(
      client: Client('http://localhost:1/'),
      path: path,
      userUuid: testUser,
    );
    final space = UuidValue.fromString('0190a000-0000-7000-8000-0000000000f1');
    final plan = await createDeck(replica, space, title: 'Unsynced talk');
    await replica.close();

    final recovery = await SlidesReplicaRecovery.read(path);

    expect(recovery, isNotNull);
    expect(recovery!.decks.single.deckId, space.uuid);
    expect(recovery.decks.single.title, 'Unsynced talk');
    expect(recovery.decks.single.rows, hasLength(plan.changes.length));
    final json =
        jsonDecode(utf8.decode(recovery.toJsonBytes())) as Map<String, Object?>;
    final decks = json['decks']! as List<Object?>;
    expect((decks.single! as Map)['title'], 'Unsynced talk');
    expect(
      SlidesReplicaRecovery.fileName(DateTime(2026, 3, 4)),
      'Wonky Slides unsynced changes 2026-03-04.json',
    );
  });
}
