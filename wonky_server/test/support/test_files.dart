import 'dart:convert';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/files/file_preview_service.dart';

import 'test_users.dart';
import 'wonky_serverpod.dart';

/// Uploads of Drive `file` items in tests (Drive 02 §3.3): the client's
/// `FileUploader` is simulated by writing the bytes to the database cloud
/// storage as an unverified upload.
abstract final class TestFiles {
  /// Previews run inline in tests (no future call).
  static void runPreviewsInline() =>
      FilePreviewService.schedule = FilePreviewService.generate;

  /// Previews are not generated.
  static void skipPreviews() =>
      FilePreviewService.schedule = (session, itemId) async {};

  static FileUploadRequest request({
    required String name,
    required int size,
    UuidValue? parentUuid,
    UuidValue? itemUuid,
    UuidValue? fileUuid,
    UploadConflictMode conflict = UploadConflictMode.keepBoth,
  }) => FileUploadRequest(
    itemUuid: itemUuid ?? const Uuid().v7obj(),
    fileUuid: fileUuid ?? const Uuid().v7obj(),
    parentUuid: parentUuid,
    name: name,
    sizeBytes: size,
    conflict: conflict,
  );

  /// Starts an upload of [bytes].
  static Future<FileUploadStart> start(
    TestEndpoints endpoints,
    TestUser owner, {
    required String name,
    required List<int> bytes,
    UuidValue? parentUuid,
    UploadConflictMode conflict = UploadConflictMode.keepBoth,
  }) => endpoints.drive.createFileUpload(
    owner.endpointSession,
    request(
      name: name,
      size: bytes.length,
      parentUuid: parentUuid,
      conflict: conflict,
    ),
  );

  /// Writes [bytes] where the client's upload would put them.
  static Future<void> putBytes(
    Session session,
    UuidValue fileUuid,
    List<int> bytes,
  ) async {
    final file = (await StoredFile.db.findFirstRow(
      session,
      where: (t) => t.fileUuid.equals(fileUuid),
    ))!;
    final storage = session.serverpod.storage[file.storageId]!;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    if (storage is DatabaseCloudStorage) {
      await storage.storeUnverifiedFile(
        session: session,
        path: file.path,
        byteData: data,
      );
    } else {
      await session.storage.storeFile(
        storageId: file.storageId,
        path: file.path,
        byteData: data,
      );
    }
  }

  /// Uploads [bytes] (create → bytes → complete) and returns the ready item.
  static Future<DriveItemView> upload(
    TestEndpoints endpoints,
    TestUser owner, {
    String name = 'notes.txt',
    List<int>? bytes,
    UuidValue? parentUuid,
  }) async {
    final content = bytes ?? utf8.encode('hello');
    final start = await TestFiles.start(
      endpoints,
      owner,
      name: name,
      bytes: content,
      parentUuid: parentUuid,
    );
    if (content.isNotEmpty) {
      await putBytes(owner.session, start.ticket.fileUuid, content);
    }
    return endpoints.drive.completeFileUpload(
      owner.endpointSession,
      start.item.uuid,
    );
  }

  /// The server row of [uuid].
  static Future<DriveItem> row(Session session, UuidValue uuid) async =>
      (await DriveItem.db.findFirstRow(
        session,
        where: (t) => t.uuid.equals(uuid),
      ))!;
}
