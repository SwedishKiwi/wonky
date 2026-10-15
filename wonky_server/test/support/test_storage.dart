import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/storage/storage_service.dart';

import 'test_drive.dart';
import 'test_users.dart';
import 'wonky_serverpod.dart';

/// Storage quota helpers (Drive 03).
abstract final class TestStorage {
  /// Sets [user]'s quota (`user_storage.quotaBytesOverride`).
  static Future<void> setQuota(TestUser user, int bytes) async {
    await UserStorage.db.updateWhere(
      user.session,
      columnValues: (t) => [t.quotaBytesOverride(bytes)],
      where: (t) => t.userId.equals(user.id),
    );
  }

  /// The stored counters of [user].
  static Future<UserStorage> row(TestUser user) async =>
      (await UserStorage.db.findFirstRow(
        user.session,
        where: (t) => t.userId.equals(user.id),
      ))!;

  /// [user]'s usage through the service.
  static Future<StorageUsage> usage(TestUser user) =>
      StorageService.instance.usage(user.session, user.id);

  /// A document owned by [user] counting [bytes] (its content size set
  /// through the service, like the OT size update).
  static Future<DriveItem> fill(
    TestEndpoints endpoints,
    TestUser user,
    int bytes, {
    String name = 'Filler',
  }) async {
    final view = await TestDrive.document(endpoints, user, name: name);
    final item = (await DriveItem.db.findFirstRow(
      user.session,
      where: (t) => t.uuid.equals(view.uuid),
    ))!;
    await StorageService.instance.setItemSize(user.session, item, bytes);
    return (await DriveItem.db.findById(user.session, item.id!))!;
  }
}

/// Throws `quotaExceeded` with the details' [reason] (and [isCaller]).
Matcher throwsQuota(String reason, {bool? isCaller, int? chargedUserId}) =>
    throwsA(
      isA<WonkyException>()
          .having((e) => e.code, 'code', WonkyErrorCode.quotaExceeded)
          .having(
            (e) => QuotaExceededDetails.fromJson(
              jsonDecode(e.detailsJson!) as Map<String, dynamic>,
            ),
            'details',
            isA<QuotaExceededDetails>()
                .having((d) => d.reason, 'reason', reason)
                .having(
                  (d) => isCaller == null || d.isCaller == isCaller,
                  'isCaller matches',
                  isTrue,
                )
                .having(
                  (d) =>
                      chargedUserId == null || d.chargedUserId == chargedUserId,
                  'chargedUserId matches',
                  isTrue,
                ),
          ),
    );
