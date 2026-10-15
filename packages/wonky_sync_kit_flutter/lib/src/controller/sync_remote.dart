import 'package:flutter/foundation.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncClient, OfflineSyncTransport;
import 'package:wonky_app/wonky_app.dart' show Api, OfflineException;
import 'package:wonky_client/wonky_client.dart'
    show SpaceStats, SubscribeResult, UuidValue;

/// The server calls of an app's sync layer (suite 12 §2): the custom sync
/// endpoint (`sheetsSync.sync`, `slidesSync.sync`) and the space endpoints.
/// Production uses [EndpointSyncRemote]; tests use fakes.
abstract interface class SyncRemote {
  /// The sync client on the app's custom sync endpoint (so the server runs
  /// `onMergeSuccess` → change-log consumption).
  OfflineSyncClient get sync;

  /// Reserves [count] empty spaces for offline creation.
  Future<List<UuidValue>> reserveSpaces(int count);

  /// Joins the active set of the file [itemUuid] (membership = subscription).
  Future<SubscribeResult> subscribe(UuidValue itemUuid);

  /// Row counts of the file's space (download progress).
  Future<SpaceStats> spaceStats(UuidValue itemUuid);

  /// The pending-change guard: re-subscribes [spaces] with local writes.
  Future<List<UuidValue>> ensureSubscribed(List<UuidValue> spaces);

  /// Leaves the active set (the device drops the space; owners keep it).
  Future<void> unsubscribe(UuidValue itemUuid);
}

/// [SyncRemote] on generated endpoint methods. Every call (and the sync
/// stream, which bypasses [Api]) honours *Simulate offline*.
class EndpointSyncRemote implements SyncRemote {
  EndpointSyncRemote({
    required OfflineSyncTransport sync,
    required this._reserveSpaces,
    required this._subscribe,
    required this._spaceStats,
    required this._ensureSubscribed,
    required this._unsubscribe,
  }) : sync = OfflineSyncClient(({required changes, required once}) {
         if (Api.simulatedOffline) {
           throw const OfflineException('simulated offline');
         }
         return sync(changes: changes, once: once);
       });

  @override
  final OfflineSyncClient sync;

  final Future<List<UuidValue>> Function(int) _reserveSpaces;
  final Future<SubscribeResult> Function(UuidValue) _subscribe;
  final Future<SpaceStats> Function(UuidValue) _spaceStats;
  final Future<List<UuidValue>> Function(List<UuidValue>) _ensureSubscribed;
  final Future<void> Function(UuidValue) _unsubscribe;

  Future<T> _call<T>(Future<T> Function() f) {
    if (Api.simulatedOffline) {
      throw const OfflineException('simulated offline');
    }
    return f();
  }

  @override
  Future<List<UuidValue>> reserveSpaces(int count) =>
      _call(() => _reserveSpaces(count));

  @override
  Future<SubscribeResult> subscribe(UuidValue itemUuid) =>
      _call(() => _subscribe(itemUuid));

  @override
  Future<SpaceStats> spaceStats(UuidValue itemUuid) =>
      _call(() => _spaceStats(itemUuid));

  @override
  Future<List<UuidValue>> ensureSubscribed(List<UuidValue> spaces) =>
      _call(() => _ensureSubscribed(spaces));

  @override
  Future<void> unsubscribe(UuidValue itemUuid) =>
      _call(() => _unsubscribe(itemUuid));
}

/// Connection state for the sync controller (the shell's
/// `ConnectivityService` in the app via `ShellSyncConnectivity`, a plain
/// notifier in tests).
abstract interface class SyncConnectivity {
  /// Whether the server is reachable (false while *Simulate offline*).
  ValueListenable<bool> get online;

  void reportFailure();
  void reportSuccess();
}

/// Thrown by [SyncSessionHost] calls that need the server while offline.
class SyncOfflineException implements Exception {
  const SyncOfflineException([this.message = 'offline']);

  final String message;

  @override
  String toString() => 'SyncOfflineException: $message';
}

/// Thrown when no reserved space is usable for creating a file (offline
/// before the first reservation arrived).
class NoReservedSpaceException implements Exception {
  const NoReservedSpaceException();

  @override
  String toString() =>
      'NoReservedSpaceException: connect to the internet to create a file.';
}
