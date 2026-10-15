import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

/// Server access of the Storage page (Drive 03 §6.4), replaceable in tests
/// (`StorageHost.api`).
abstract class StorageApi {
  /// `drive.listByStorage`: the caller's owned items (incl. trashed, no
  /// folders) by counted size, largest first; keyset [cursor].
  Future<DriveListPage> listByStorage(
    StorageListFilter filter, {
    String? cursor,
    int limit = 50,
  });
}

/// [StorageApi] on the generated client (errors become `WonkyException` /
/// `OfflineException` through [Api.guard]).
class ServerStorageApi implements StorageApi {
  ServerStorageApi(this.services);

  final ShellServices services;

  @override
  Future<DriveListPage> listByStorage(
    StorageListFilter filter, {
    String? cursor,
    int limit = 50,
  }) {
    final c = services.client;
    if (c == null ||
        Api.simulatedOffline ||
        services.connectivity.forcedOffline) {
      throw const OfflineException('offline');
    }
    return Api(c).guard((c) => c.drive.listByStorage(filter, cursor, limit));
  }
}
