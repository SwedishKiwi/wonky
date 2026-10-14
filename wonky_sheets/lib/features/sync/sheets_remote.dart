import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncClient;
import 'package:wonky_app/wonky_app.dart' show Api, OfflineException;
import 'package:wonky_client/wonky_client.dart';

/// The server calls of the Sheets data layer (suite 12 §2): the custom sync
/// endpoint and the space endpoints. Production uses [ClientSheetsRemote];
/// tests use fakes.
abstract interface class SheetsRemote {
  /// The sync client on the custom `sheetsSync.sync` endpoint (so the server
  /// runs `onMergeSuccess` → change-log consumption).
  OfflineSyncClient get sync;

  Future<List<UuidValue>> reserveSpaces(int count);

  Future<SubscribeResult> subscribe(UuidValue itemUuid);

  Future<SpaceStats> spaceStats(UuidValue itemUuid);

  Future<List<UuidValue>> ensureSubscribed(List<UuidValue> spaces);

  /// Leaves the active set (the device drops the space; owners keep it).
  Future<void> unsubscribe(UuidValue itemUuid);
}

/// [SheetsRemote] on the generated client.
class ClientSheetsRemote implements SheetsRemote {
  ClientSheetsRemote(this.client)
    : sync = OfflineSyncClient(({required changes, required once}) {
        // The stream bypasses [Api]; honour *Simulate offline* here too.
        if (Api.simulatedOffline) {
          throw const OfflineException('simulated offline');
        }
        return client.sheetsSync.sync(changes: changes, once: once);
      });

  final Client client;

  @override
  final OfflineSyncClient sync;

  Future<T> _call<T>(Future<T> Function() f) {
    if (Api.simulatedOffline) {
      throw const OfflineException('simulated offline');
    }
    return f();
  }

  @override
  Future<List<UuidValue>> reserveSpaces(int count) =>
      _call(() => client.sheets.reserveSpaces(count));

  @override
  Future<SubscribeResult> subscribe(UuidValue itemUuid) =>
      _call(() => client.sheets.subscribe(itemUuid));

  @override
  Future<SpaceStats> spaceStats(UuidValue itemUuid) =>
      _call(() => client.sheets.spaceStats(itemUuid));

  @override
  Future<List<UuidValue>> ensureSubscribed(List<UuidValue> spaces) =>
      _call(() => client.sheets.ensureSubscribed(spaces));

  @override
  Future<void> unsubscribe(UuidValue itemUuid) =>
      _call(() => client.sheets.unsubscribe(itemUuid));
}
