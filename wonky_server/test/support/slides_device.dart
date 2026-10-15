import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart' show Session, UuidValue;
import 'package:serverpod/serverpod.dart' as pod show ColumnInt;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart' as osync;
import 'package:test/test.dart';
import 'package:wonky_client/wonky_client.dart' as client;
import 'package:wonky_slides_core/model.dart' show DeckModel;
import 'package:wonky_slides_core/ops.dart' show CreateDeck, SlidesPlanContext;
import 'package:wonky_slides_core/planner.dart' show SlidesPlanner;
import 'package:wonky_slides_core/testing.dart' show DeckBuilder;
import 'package:wonky_sync_models/ids.dart';
import 'package:wonky_sync_models/tables.dart';

/// A Slides device of a test user (Slides 02 §9, the toptap pattern of
/// [SheetsDevice]): the generated client against the test server plus its
/// own SQLite replica, syncing through the custom `slidesSync.sync`
/// endpoint. Runs in its own isolate (the SQL encoder of
/// `serverpod_database` is process-wide).
///
/// Writes follow the app writer's rules in miniature: one transaction,
/// updates name their columns, one `DeckChangeLog` row.
class SlidesDevice {
  SlidesDevice._(this._commands);

  /// Starts a device for [authUserId] against the server of [server].
  static Future<SlidesDevice> open(Session server, UuidValue authUserId) async {
    final directory = await Directory.systemTemp.createTemp('wonky_slides_');
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _deviceMain,
      _DeviceConfig(
        ready.sendPort,
        'http://localhost:${server.server.port}/',
        p.join(directory.path, 'slides.db'),
        authUserId.uuid,
      ),
    );
    final commands = await ready.first as SendPort;
    final device = SlidesDevice._(commands);
    addTearDown(() async {
      try {
        await device._run((d) => d.close());
      } catch (_) {}
      isolate.kill();
      await directory.delete(recursive: true);
    });
    return device;
  }

  final SendPort _commands;

  Future<R> _run<R>(Future<R> Function(_Device d) command) async {
    final reply = ReceivePort();
    _commands.send(_Command(command, reply.sendPort));
    final result = await reply.first as _Result;
    if (result.error != null) {
      throw SlidesDeviceException('${result.error}\n${result.stackTrace}');
    }
    return result.value as R;
  }

  /// One complete sync cycle.
  Future<void> sync() => _run((d) => d.syncOnce());

  Future<List<UuidValue>> reserveSpaces(int n) =>
      _run((d) => d.api.slides.reserveSpaces(n));

  Future<bool> isMember(UuidValue space) => _run((d) => d.isMember(space));

  Future<client.SubscribeResult> subscribe(UuidValue item) =>
      _run((d) => d.api.slides.subscribe(item));

  Future<List<UuidValue>> ensureSubscribed(List<UuidValue> spaces) =>
      _run((d) => d.api.slides.ensureSubscribed(spaces));

  Future<client.SpaceStats> spaceStats(UuidValue item) =>
      _run((d) => d.api.slides.spaceStats(item));

  Future<client.DriveItemView> registerPresentation(
    UuidValue space,
    String name,
  ) => _run((d) => d.api.drive.registerPresentation(space, null, name));

  /// Writes a new deck (built-in theme, one title slide) into [space] (a
  /// reservation) — the rows of *New presentation* (02 §9.3).
  Future<void> createDeck(UuidValue space, String title) =>
      _run((d) => d.createDeck(space, title));

  /// Writes a new deck into [space] with the app's planner (`SlidesPlanner`
  /// `CreateDeck`, exactly the rows `SlidesSyncController
  /// .createLocalPresentation` writes, SL-9) and its change-log summary.
  /// Returns the number of rows written.
  Future<int> createPlannedDeck(UuidValue space, String title) =>
      _run((d) => d.createPlannedDeck(space, title));

  /// Renames the deck (synced `Deck.title`).
  Future<void> rename(UuidValue space, String title) => _run(
    (d) => d.write(space, [
      (
        'deck',
        space.uuid,
        <String, Object?>{'title': title},
      ),
    ], 'Rename presentation'),
  );

  /// The deck title on the device (null when the row is not there).
  Future<String?> title(UuidValue space) => _run(
    (d) async => (await client.Deck.db.findById(d.session, space))?.title,
  );

  /// Visible rows of [space] on the device (deck tables, change log
  /// excluded).
  Future<int> rowCount(UuidValue space) =>
      _run((d) async => (await d.rows(space)).length);

  /// Number of rows per table of [space] on the device.
  Future<Map<String, int>> tableCounts(UuidValue space) => _run((d) async {
    final out = <String, int>{};
    for (final (table, _) in await d.rows(space)) {
      out[table] = (out[table] ?? 0) + 1;
    }
    return out;
  });
}

class SlidesDeviceException implements Exception {
  SlidesDeviceException(this.message);
  final String message;
  @override
  String toString() => 'SlidesDeviceException: $message';
}

class _DeviceConfig {
  _DeviceConfig(this.replyTo, this.serverUrl, this.path, this.user);
  final SendPort replyTo;
  final String serverUrl;
  final String path;
  final String user;
}

class _Command {
  _Command(this.run, this.replyTo);
  final Future<Object?> Function(_Device) run;
  final SendPort replyTo;
}

class _Result {
  _Result({this.value, this.error, this.stackTrace});
  final Object? value;
  final String? error;
  final String? stackTrace;
}

class _KeyProvider implements client.ClientAuthKeyProvider {
  _KeyProvider(this.user);
  final String user;
  @override
  Future<String?> get authHeaderValue async => 'Bearer $user';
}

class _Device {
  _Device(this.api, this.session, this.user)
    : sync = osync.OfflineSyncClient(
        ({required changes, required once}) =>
            api.slidesSync.sync(changes: changes, once: once),
      );

  final client.Client api;
  final osync.OfflineSyncDatabaseSession session;
  final UuidValue user;
  final osync.OfflineSyncClient sync;

  Future<void> syncOnce() => sync.syncOnce(session);

  Future<bool> isMember(UuidValue space) async =>
      (await osync.OfflineSyncSpaceMembership.roleOf(
        session,
        userUuid: user,
        spaceUuid: space,
      )) !=
      null;

  Future<List<(String, Map<String, Object?>)>> rows(UuidValue space) async {
    final key = (await osync.OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(space),
    ))?.id;
    if (key == null) return const [];
    final out = <(String, Map<String, Object?>)>[];
    for (final spec in SlidesSyncedTables.all) {
      if (spec.name == 'deck_change_log') continue;
      final column = spec.column('spaceId');
      if (column is! pod.ColumnInt) continue;
      final pod.ColumnInt spaceColumn = column;
      for (final r in await spec.findWhere(
        session,
        where: spaceColumn.equals(key),
      )) {
        out.add((spec.name, spec.toColumns(r)));
      }
    }
    return out;
  }

  Future<void> createDeck(UuidValue space, String title) async {
    final builder = DeckBuilder(
      deckId: space.uuid,
      ids: const UuidV7IdGenerator(),
      now: DateTime.now().toUtc(),
      title: title,
      userId: user.uuid,
    )..theme();
    builder.slide(layoutKey: 'title', title: title);
    await session.db.transactionForUser(user, (tx) async {
      for (final (table, columns) in builder.rows) {
        await SlidesSyncedTables.of(
          table,
        ).insertRows(session, [columns], transaction: tx);
      }
      await _log(space, 'Create presentation', {'deck', 'structure'}, tx);
    }, spaceId: space);
  }

  Future<int> createPlannedDeck(UuidValue space, String title) async {
    final plan = const SlidesPlanner().plan(
      CreateDeck(deckId: space.uuid, title: title),
      DeckModel(deckId: space.uuid),
      SlidesPlanContext(
        userId: user.uuid,
        now: DateTime.now().toUtc(),
        isOwner: true,
      ),
    );
    await session.db.transactionForUser(user, (tx) async {
      for (final c in plan.changes) {
        await SlidesSyncedTables.of(
          c.table,
        ).insertRows(session, [
          {...c.columnsAfter, 'id': c.rowId},
        ], transaction: tx);
      }
      await client.DeckChangeLog.db.insertRow(
        session,
        client.DeckChangeLog(
          deckId: space,
          userId: user,
          actorKind: client.ActorKind.user,
          sessionId: 'test-device',
          label: plan.label,
          summaryJson: plan.summaryJson,
          at: DateTime.now().toUtc(),
        ),
        transaction: tx,
      );
    }, spaceId: space);
    return plan.changes.length;
  }

  /// Updates (table, id, columns) as one transaction with a change log row.
  Future<void> write(
    UuidValue space,
    List<(String, String, Map<String, Object?>)> updates,
    String label,
  ) => session.db.transactionForUser(user, (tx) async {
    for (final (table, id, columns) in updates) {
      await SlidesSyncedTables.of(table).updateColumns(
        session,
        UuidValue.fromString(id),
        columns,
        transaction: tx,
      );
    }
    await _log(space, label, {'deck'}, tx);
  }, spaceId: space);

  Future<void> _log(
    UuidValue space,
    String label,
    Set<String> kinds,
    dynamic tx,
  ) => client.DeckChangeLog.db.insertRow(
    session,
    client.DeckChangeLog(
      deckId: space,
      userId: user,
      actorKind: client.ActorKind.user,
      sessionId: 'test-device',
      label: label,
      summaryJson: jsonEncode({'v': 1, 'kinds': kinds.toList()}),
      at: DateTime.now().toUtc(),
    ),
    transaction: tx,
  );

  Future<void> close() async {
    await session.close();
    api.close();
  }
}

Future<void> _deviceMain(_DeviceConfig config) async {
  final user = UuidValue.fromString(config.user);
  final api = client.Client(config.serverUrl)
    ..authKeyProvider = _KeyProvider(config.user);
  final session = await api.createSyncSession(
    config.path,
    persistentUserId: user,
  );
  final device = _Device(api, session, user);
  final commands = ReceivePort();
  config.replyTo.send(commands.sendPort);
  await for (final message in commands) {
    final command = message as _Command;
    try {
      final value = await command.run(device);
      command.replyTo.send(_Result(value: value));
    } catch (e, st) {
      command.replyTo.send(_Result(error: '$e', stackTrace: '$st'));
    }
  }
}
