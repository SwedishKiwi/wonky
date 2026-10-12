import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../users/user_service.dart';
import 'file_service.dart';

/// Uploads and signed downloads (suite 12 §1.1). Idempotent on the
/// client-generated [fileUuid]; content may reference `wonky-file://<uuid>`
/// before the bytes arrive.
class FileEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Upload description for `FileUploader`. [kind] defaults to image;
  /// imports use `importSource` without an item.
  Future<FileUploadTicket> createUpload(
    Session session,
    UuidValue fileUuid,
    UuidValue? itemUuid,
    String fileName,
    String mimeType,
    int size, {
    StoredFileKind? kind,
  }) async => FileService.createUpload(
    session,
    await UserService.actorOf(session),
    fileUuid: fileUuid,
    itemUuid: itemUuid,
    fileName: fileName,
    mimeType: mimeType,
    size: size,
    kind: kind ?? StoredFileKind.image,
  );

  Future<FileUrlView> completeUpload(Session session, UuidValue fileUuid) async =>
      FileService.completeUpload(session, await UserService.actorOf(session), fileUuid);

  /// Status and signed URL (15 min) of a file.
  Future<FileUrlView> getUrl(Session session, UuidValue fileUuid) async =>
      FileService.getUrl(session, await UserService.actorOf(session), fileUuid);

  Future<List<FileUrlView>> getUrls(Session session, List<UuidValue> fileUuids) async =>
      FileService.getUrls(session, await UserService.actorOf(session), fileUuids);
}
