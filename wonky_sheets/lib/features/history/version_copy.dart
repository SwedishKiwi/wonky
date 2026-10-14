import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart' show UuidV7IdGenerator;

import '../sync/sheets_sessions.dart';
import 'version_snapshots.dart';

/// *Make a copy* of a version (Sheets 10 §5.4): the snapshot's rows get new
/// ids through the core `SpaceCopier` (formulas, ranges, objects remapped)
/// and are written into a reserved space of the local replica, which is
/// then registered with the drive — like a new spreadsheet, so it works
/// with the offline-first data layer. Returns the new item uuid.
Future<UuidValue?> copyVersionToNewSpreadsheet(
  ShellServices services, {
  required SnapshotRows rows,
  required String sourceSpaceId,
  required String name,
}) async {
  final controller = await SheetsData.ready(services);
  if (controller == null) throw StateError('Sheets data is not ready.');
  final usable = await controller.replica.usableReservations();
  if (usable.isEmpty) {
    await controller.refillReservations();
    await controller.syncNow();
  }
  final spaces = await controller.replica.usableReservations();
  if (spaces.isEmpty) throw StateError('No space for a new spreadsheet.');
  final space = spaces.first;
  final copy = SpaceCopier.copy(
    rows,
    sourceSpaceId: sourceSpaceId,
    targetSpaceId: space.uuid,
    ids: const UuidV7IdGenerator(),
    userId: controller.replica.userUuid.uuid,
    now: clock.now().toUtc(),
    title: name,
  );
  final changes = [
    for (final (t, c) in copy.rows)
      RowChange.insert(t, c[Cols.id].toString(), c),
  ];
  await controller.writer.write(
    spaceId: space,
    changes: changes,
    label: 'Make a copy',
    actorKind: 'user',
    sessionId: controller.sessionId,
  );
  await controller.replica.removeReservation(space);
  controller.kick();
  try {
    await services.drive.registerSpreadsheet(spaceUuid: space, name: name);
  } catch (e) {
    debugPrint('Registering copy $space failed: $e');
    if (!isOfflineError(e)) rethrow;
  }
  services.refreshDrive();
  return space;
}
