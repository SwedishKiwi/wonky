import 'package:wonky_app/wonky_app.dart' show Api;
import 'package:wonky_client/wonky_client.dart';

import '../sync/sync_transport.dart';

/// The server calls a Write document session needs (Write 03 §1, Write 08
/// §4.3), behind an interface so tests can run against an in-process fake.
abstract interface class WriteDocumentApi {
  /// The drive item (name, role, `contentRef` = document uuid).
  Future<DriveItemView> getItem(UuidValue itemUuid);

  /// The sync transport of [documentUuid].
  DocumentSyncTransport transport(UuidValue documentUuid);

  /// `document.updateMeta` (LWW; idempotent on [clientOpId]).
  Future<void> updateMeta(
    UuidValue documentUuid,
    String field,
    String valueJson,
    UuidValue clientOpId,
  );

  /// `writeHistory.getVersionDocument`.
  Future<WriteVersionDocument> getVersionDocument(
    UuidValue documentUuid,
    int revision,
  );

  /// `writeHistory.diff` (per-author attribution).
  Future<WriteDiffView> diff(
    UuidValue documentUuid,
    int fromRevision,
    int toRevision,
  );

  /// `writeHistory.copyVersion`.
  Future<DriveItemView> copyVersion(
    UuidValue documentUuid,
    int versionId,
    String name, {
    UuidValue? parentUuid,
  });
}

/// [WriteDocumentApi] over the generated client.
class ServerWriteDocumentApi implements WriteDocumentApi {
  ServerWriteDocumentApi(Client client) : _api = Api(client);

  final Api _api;

  Client get client => _api.client;

  @override
  Future<DriveItemView> getItem(UuidValue itemUuid) =>
      _api.guard((c) => c.drive.get(itemUuid));

  @override
  DocumentSyncTransport transport(UuidValue documentUuid) =>
      ServerDocumentSyncTransport(client, documentUuid);

  @override
  Future<void> updateMeta(
    UuidValue documentUuid,
    String field,
    String valueJson,
    UuidValue clientOpId,
  ) => _api.guard(
    (c) => c.document.updateMeta(
      documentUuid,
      DocumentMetaPatch(field: field, valueJson: valueJson),
      clientOpId,
    ),
  );

  @override
  Future<WriteVersionDocument> getVersionDocument(
    UuidValue documentUuid,
    int revision,
  ) => _api.guard(
    (c) => c.writeHistory.getVersionDocument(documentUuid, revision),
  );

  @override
  Future<WriteDiffView> diff(
    UuidValue documentUuid,
    int fromRevision,
    int toRevision,
  ) => _api.guard(
    (c) => c.writeHistory.diff(documentUuid, fromRevision, toRevision),
  );

  @override
  Future<DriveItemView> copyVersion(
    UuidValue documentUuid,
    int versionId,
    String name, {
    UuidValue? parentUuid,
  }) => _api.guard(
    (c) =>
        c.writeHistory.copyVersion(documentUuid, versionId, name, parentUuid),
  );
}
