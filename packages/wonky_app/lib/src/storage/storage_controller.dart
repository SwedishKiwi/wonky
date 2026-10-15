import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

/// The signed-in user's storage for meters, banners and client pre-checks
/// (Drive 03 §6): the last known [StorageUsage] (null until loaded), kept
/// live from `drive.storageChanged` events and cached for offline display.
///
/// The shell installs `LiveStorageController` (D-11) in production;
/// [StorageController.none] is the default of hand-built services (pre-checks
/// pass, meters hide). Tests use `FakeStorage` from
/// `package:wonky_app/testing.dart`.
abstract class StorageController implements ValueListenable<StorageUsage?> {
  /// A controller that never knows the usage (pre-checks pass; meters hide).
  factory StorageController.none() = _NoStorage;

  /// Fetches the usage now (e.g. after the Storage page frees space).
  /// Offline or on errors the last value stays.
  Future<StorageUsage?> refresh();

  /// Whether the value is the cached one of an offline session.
  bool get stale;

  /// (D-11) Applies a usage returned by a byte-adding endpoint (e.g.
  /// `FileUploadStart.storage`) without waiting for the `storageChanged`
  /// event.
  void report(StorageUsage usage);

  /// (D-11) The server pre-check `drive.checkRoom(bytes, itemUuid)`: throws
  /// a `WonkyException` with `quotaExceeded` when [bytes] don't fit the
  /// charged user's room (the owner of [itemUuid], else the caller), an
  /// `OfflineException` when the server is unreachable. Never reserves.
  Future<void> checkRoom(int bytes, {UuidValue? itemUuid});

  void dispose();
}

/// Derived values of a [StorageUsage] the UI uses (Drive 03 §6).
extension StorageUsageChecks on StorageUsage {
  /// Used share of the quota, 0…n (over 1 when over quota).
  double get usedFraction => quotaBytes <= 0 ? 0 : bytesUsed / quotaBytes;

  /// At or above [warnAtPercent] (default 90 %, `drive.warnAtPercent`).
  bool isWarning({int warnAtPercent = 90}) =>
      usedFraction * 100 >= warnAtPercent;

  /// Whether [bytes] fit the available room (client pre-check; the server
  /// stays authoritative). Always true while the backfill is calculating
  /// (enforcement fails open, Drive 03 §9).
  bool fits(int bytes) => calculating || bytes <= availableBytes;
}

class _NoStorage extends ValueNotifier<StorageUsage?>
    implements StorageController {
  _NoStorage() : super(null);

  @override
  Future<StorageUsage?> refresh() async => null;

  @override
  bool get stale => false;

  @override
  void report(StorageUsage usage) {}

  @override
  Future<void> checkRoom(int bytes, {UuidValue? itemUuid}) async {}
}
