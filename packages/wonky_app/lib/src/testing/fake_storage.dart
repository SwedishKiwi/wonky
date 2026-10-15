import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../storage/storage_controller.dart';

/// An in-memory [StorageController] for widget tests (suite 15): set
/// [value] (or call [emit]) to simulate `storageChanged` events.
class FakeStorage extends ValueNotifier<StorageUsage?>
    implements StorageController {
  FakeStorage([super.value]);

  /// A fake with [usedBytes] of [quotaBytes] used (50 MB by default) and the
  /// derived fields filled in.
  factory FakeStorage.used(
    int usedBytes, {
    int quotaBytes = 50 * 1024 * 1024,
    int reservedBytes = 0,
    int trashBytes = 0,
    bool calculating = false,
  }) => FakeStorage(
    usageOf(
      usedBytes,
      quotaBytes: quotaBytes,
      reservedBytes: reservedBytes,
      trashBytes: trashBytes,
      calculating: calculating,
    ),
  );

  /// A consistent [StorageUsage] (available, over quota, max upload).
  static StorageUsage usageOf(
    int usedBytes, {
    int quotaBytes = 50 * 1024 * 1024,
    int reservedBytes = 0,
    int trashBytes = 0,
    bool calculating = false,
  }) {
    final free = quotaBytes - usedBytes - reservedBytes;
    final available = free > 0 ? free : 0;
    return StorageUsage(
      bytesUsed: usedBytes,
      documents: 0,
      spreadsheets: 0,
      folders: 0,
      files: 0,
      quotaBytes: quotaBytes,
      reservedBytes: reservedBytes,
      availableBytes: available,
      overQuota: usedBytes > quotaBytes,
      trashBytes: trashBytes,
      maxFileUploadBytes: available < 50 * 1024 * 1024
          ? available
          : 50 * 1024 * 1024,
      calculating: calculating,
    );
  }

  /// How often [refresh] was called.
  int refreshCount = 0;

  @override
  bool stale = false;

  /// Replaces the usage (as a `storageChanged` event would).
  void emit(StorageUsage? usage) => value = usage;

  @override
  Future<StorageUsage?> refresh() async {
    refreshCount++;
    return value;
  }

  @override
  void report(StorageUsage usage) => value = usage;

  /// The `drive.checkRoom` calls: `(bytes, itemUuid)`.
  final List<(int, UuidValue?)> checkRoomCalls = [];

  /// The server's answer to [checkRoom]: an error to throw (e.g.
  /// [quotaError]) or null to pass. Without it, [checkRoom] refuses when the
  /// bytes don't [StorageUsageChecks.fits] the caller's usage (the item
  /// owner's room is unknown: those pass).
  Object? Function(int bytes, UuidValue? itemUuid)? onCheckRoom;

  @override
  Future<void> checkRoom(int bytes, {UuidValue? itemUuid}) async {
    checkRoomCalls.add((bytes, itemUuid));
    final hook = onCheckRoom;
    final error = hook != null
        ? hook(bytes, itemUuid)
        : (itemUuid == null && value != null && !value!.fits(bytes))
        ? quotaError(
            neededBytes: bytes,
            availableBytes: value!.availableBytes,
            quotaBytes: value!.quotaBytes,
          )
        : null;
    if (error != null) throw error;
  }

  /// The `quotaExceeded` error the server sends (Drive 03 §7.1).
  static WonkyException quotaError({
    required int neededBytes,
    int availableBytes = 0,
    int quotaBytes = 50 * 1024 * 1024,
    bool isCaller = true,
    String chargedUserName = 'Me',
    String reason = 'upload',
  }) => WonkyException(
    code: WonkyErrorCode.quotaExceeded,
    message: 'Not enough storage',
    detailsJson: jsonEncode(
      QuotaExceededDetails(
        neededBytes: neededBytes,
        availableBytes: availableBytes,
        quotaBytes: quotaBytes,
        chargedUserId: isCaller ? 1 : 2,
        chargedUserName: chargedUserName,
        isCaller: isCaller,
        reason: reason,
      ).toJson(),
    ),
  );
}
