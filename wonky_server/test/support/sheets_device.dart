import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart' show Session, UuidValue;
// ignore: implementation_imports
import 'package:serverpod/src/server/server.dart' show ServerInternalMethods;
import 'package:serverpod/serverpod.dart'
    as pod
    show AuthenticationInfo, ColumnInt, Scope;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart' as osync;
import 'package:test/test.dart';
import 'package:wonky_client/wonky_client.dart' as client;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart';
import 'package:wonky_sync_models/tables.dart';

/// Lets test devices authenticate with `Bearer <authUserId>` (the JWT
/// handler is replaced on the test server only).
void installDeviceAuthentication(Session session) {
  session.server.setAuthenticationHandlerForTesting((session, token) async {
    final id = token.startsWith('Bearer ') ? token.substring(7) : token;
    return pod.AuthenticationInfo(id, <pod.Scope>{}, authId: id);
  });
}

/// A Sheets device of a test user: the generated client against the test
/// server plus its own SQLite replica (`createSyncSession`), syncing through
/// the custom `sheetsSync.sync` endpoint (Sheets 13 §7.3).
///
/// Each device runs in its own isolate: `serverpod_database` keeps its SQL
/// value encoder in a process-wide static, so a SQLite client in the
/// isolate of the Postgres test server would encode its queries for
/// Postgres (toptap pattern).
class SheetsDevice {
  SheetsDevice._(this._commands, this._isolate);

  /// Starts a device for [authUserId] against the server of [server].
  static Future<SheetsDevice> open(Session server, UuidValue authUserId) async {
    final directory = await Directory.systemTemp.createTemp('wonky_device_');
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _deviceMain,
      _DeviceConfig(
        ready.sendPort,
        'http://localhost:${server.server.port}/',
        p.join(directory.path, 'sheets.db'),
        authUserId.uuid,
      ),
    );
    final commands = await ready.first as SendPort;
    final device = SheetsDevice._(commands, isolate);
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
  // ignore: unused_field
  final Isolate _isolate;

  Future<R> _run<R>(Future<R> Function(_Device d) command) async {
    final reply = ReceivePort();
    _commands.send(_Command(command, reply.sendPort));
    final result = await reply.first as _Result;
    if (result.error != null) {
      throw SheetsDeviceException('${result.error}\n${result.stackTrace}');
    }
    return result.value as R;
  }

  /// One complete sync cycle.
  Future<void> sync() => _run((d) => d.syncOnce());

  /// Spaces merged by the last [sync] (`onMergeSuccess`).
  Future<List<String>> lastMerged() => _run((d) async => d.merged.toList());

  Future<List<UuidValue>> reserveSpaces(int n) =>
      _run((d) => d.api.sheets.reserveSpaces(n));

  Future<bool> isMember(UuidValue space) => _run((d) => d.isMember(space));

  Future<client.SubscribeResult> subscribe(UuidValue item) =>
      _run((d) => d.api.sheets.subscribe(item));

  Future<client.SpaceStats> spaceStats(UuidValue item) =>
      _run((d) => d.api.sheets.spaceStats(item));

  Future<client.DriveItemView> registerSpreadsheet(
    UuidValue space,
    String name,
  ) => _run((d) => d.api.drive.registerSpreadsheet(space, null, name));

  /// Writes the `CreateSpreadsheet` plan into [space] (a reservation).
  Future<void> createSpreadsheet(UuidValue space, String title) => _run(
    (d) => d.apply(
      space,
      CreateSpreadsheet(spreadsheetId: space.uuid, title: title),
    ),
  );

  /// Sets the input of the cell at (row, col) of the first sheet.
  Future<void> setCell(UuidValue space, int row, int col, String input) =>
      _run((d) => d.setCell(space, row, col, input));

  /// Content (stored encoding) of the cell at (row, col) of the first sheet.
  Future<String?> cell(UuidValue space, int row, int col) => _run(
    (d) async => (await d.model(space))
        .cellAt(
          (await d.model(space)).sheets.first.id,
          row,
          col,
        )
        ?.content,
  );

  /// Title of the spreadsheet row on the device.
  Future<String?> title(UuidValue space) => _run(
    (d) async =>
        (await client.Spreadsheet.db.findById(d.session, space))?.title,
  );

  /// Visible rows of [space] on the device (table → count).
  Future<int> rowCount(UuidValue space) =>
      _run((d) async => (await d.rows(space)).length);

  /// Renames the spreadsheet (synced title).
  Future<void> rename(UuidValue space, String title) => _run(
    (d) => d.write(space, [
      RowChange.update(
        SheetsTables.spreadsheet,
        space.uuid,
        const {},
        {SpreadsheetCols.title: title},
      ),
    ], 'Rename'),
  );
}

class SheetsDeviceException implements Exception {
  SheetsDeviceException(this.message);
  final String message;
  @override
  String toString() => 'SheetsDeviceException: $message';
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
            api.sheetsSync.sync(changes: changes, once: once),
      );

  final client.Client api;
  final osync.OfflineSyncDatabaseSession session;
  final UuidValue user;
  final osync.OfflineSyncClient sync;
  final Set<String> merged = {};

  Future<void> syncOnce() async {
    merged.clear();
    await sync.syncOnce(
      session,
      onMergeSuccess: (space, _) => merged.add(space.uuid),
    );
  }

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
    for (final spec in SyncedTables.all) {
      if (spec.name == 'change_log') continue;
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

  Future<WorkbookModel> model(UuidValue space) async =>
      WorkbookModel.fromRows(space.uuid, await rows(space));

  Future<void> apply(UuidValue space, SheetsOperation op) async {
    final m = await model(space);
    final plan = const SheetsMutationPlanner().plan(
      op,
      m,
      PlanContext(userId: user.uuid, now: DateTime.now().toUtc()),
    );
    await write(space, plan.changes, plan.label, plan: plan);
  }

  Future<void> setCell(UuidValue space, int row, int col, String input) async {
    final m = await model(space);
    final sheet = m.sheets.first;
    final rowId = sheet.rows.idAt(row);
    final colId = sheet.columns.idAt(col);
    final id = SheetsIds.cellId(sheet.id, rowId, colId);
    final content = TextContent(input).encode();
    final existing = m.cell(sheet.id, rowId, colId);
    await write(space, [
      existing == null
          ? RowChange.insert(SheetsTables.cell, id, {
              Cols.sheetId: sheet.id,
              CellCols.rowId: rowId,
              CellCols.columnId: colId,
              CellCols.content: content,
              Cols.createdAt: DateTime.now().toUtc(),
            })
          : RowChange.update(
              SheetsTables.cell,
              id,
              {CellCols.content: existing.content},
              {CellCols.content: content},
            ),
    ], 'Edit cell');
  }

  /// The app writer's rules in miniature: one transaction, updates name
  /// their columns, a ChangeLog row.
  Future<void> write(
    UuidValue space,
    List<RowChange> changes,
    String label, {
    MutationPlan? plan,
  }) => session.db.transactionForUser(user, (tx) async {
    for (final c in changes) {
      final spec = SyncedTables.of(c.table);
      final id = UuidValue.fromString(c.rowId);
      switch (c.op) {
        case RowOp.insert:
          await spec.insertRows(session, [c.columnsAfter], transaction: tx);
        case RowOp.update:
          await spec.updateColumns(
            session,
            id,
            c.columnsAfter,
            transaction: tx,
          );
        case RowOp.delete:
          await spec.deleteByIds(session, [id], transaction: tx);
      }
    }
    await client.ChangeLog.db.insertRow(
      session,
      client.ChangeLog(
        spreadsheetId: space,
        userId: user,
        actorKind: client.ActorKind.user,
        sessionId: 'test-device',
        label: label,
        summaryJson: (plan?.summary ?? ChangeSummary(kinds: {'values'}))
            .encode(),
        detailJson: plan?.detailJson,
        at: DateTime.now().toUtc(),
      ),
      transaction: tx,
    );
  }, spaceId: space);

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
