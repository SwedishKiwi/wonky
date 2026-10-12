import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_server/src/platform/common/models.dart';

import 'test_users.dart';
import 'wonky_serverpod.dart';

/// Drive builders for tests.
abstract final class TestDrive {
  static Future<DriveItemView> document(
    TestEndpoints endpoints,
    TestUser owner, {
    String name = 'Doc',
    String? markdown,
    UuidValue? parentUuid,
  }) => endpoints.drive.createDocument(
    owner.endpointSession,
    parentUuid,
    name,
    null,
    markdown,
  );

  static Future<DriveItemView> folder(
    TestEndpoints endpoints,
    TestUser owner, {
    String name = 'Folder',
    UuidValue? parentUuid,
  }) => endpoints.drive.createFolder(owner.endpointSession, parentUuid, name);

  static Future<SharingInfo> share(
    TestEndpoints endpoints,
    DriveItemView item,
    TestUser owner,
    TestUser withUser,
    AccessRole role,
  ) => endpoints.sharing.share(
    owner.endpointSession,
    item.uuid,
    [withUser.email],
    role,
    false,
    null,
    null,
  );

  /// A delta JSON inserting [text] at [offset].
  static String insertAt(int offset, String text) => jsonEncode([
    if (offset > 0) {'retain': offset},
    {'insert': text},
  ]);
}

/// The roles of a permission matrix, `null` = no access.
const allRoles = <AccessRole?>[
  AccessRole.owner,
  AccessRole.editor,
  AccessRole.commenter,
  AccessRole.viewer,
  null,
];
