import 'dart:typed_data';

import 'package:wonky_client/wonky_client.dart';

import 'api.dart';

/// Uploads to the files service (suite 12 §1.1): idempotent on the
/// client-supplied file uuid.
abstract class FileRepository {
  /// Uploads [bytes] and returns the ready file view.
  Future<FileUrlView> upload({
    required UuidValue fileUuid,
    UuidValue? itemUuid,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    StoredFileKind kind = StoredFileKind.image,
  });

  Future<FileUrlView> getUrl(UuidValue fileUuid);
}

class ServerFileRepository implements FileRepository {
  ServerFileRepository(this.api);

  final Api api;

  @override
  Future<FileUrlView> upload({
    required UuidValue fileUuid,
    UuidValue? itemUuid,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    StoredFileKind kind = StoredFileKind.image,
  }) async {
    final ticket = await api.guard(
      (c) => c.file.createUpload(fileUuid, itemUuid, fileName, mimeType, bytes.length, kind: kind),
    );
    if (ticket.status != StoredFileStatus.ready && ticket.uploadDescription != null) {
      final uploader = FileUploader(ticket.uploadDescription!);
      await uploader.uploadByteData(ByteData.sublistView(bytes));
    }
    return api.guard((c) => c.file.completeUpload(fileUuid));
  }

  @override
  Future<FileUrlView> getUrl(UuidValue fileUuid) =>
      api.guard((c) => c.file.getUrl(fileUuid));
}
