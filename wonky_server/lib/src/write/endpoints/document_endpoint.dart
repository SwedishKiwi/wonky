import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import '../ot/document_connection.dart';
import '../ot/document_service.dart';

/// Write documents: the OT editing stream and helpers (Write 03 §1).
class DocumentEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Opens an editing/viewing session. The first message is [DocInit] with
  /// the ops since [knownRevision] (0 = none) or a snapshot.
  Stream<DocServerMessage> connect(
    Session session,
    UuidValue documentUuid,
    int knownRevision,
    Stream<DocClientMessage> input,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* DocumentConnection.open(
      session,
      actor,
      documentUuid,
      knownRevision,
      input,
    );
  }

  Future<DocumentInfo> getInfo(Session session, UuidValue documentUuid) async =>
      DocumentService.getInfo(
        session,
        await UserService.actorOf(session),
        documentUuid,
      );

  /// Ops in [fromRevision]…[toRevision] (at most 1,000).
  Future<List<DocumentOpView>> getOps(
    Session session,
    UuidValue documentUuid,
    int fromRevision,
    int toRevision,
  ) async => DocumentService.getOps(
    session,
    await UserService.actorOf(session),
    documentUuid,
    fromRevision,
    toRevision,
  );

  /// Content at [revision] (head when null; older revisions need Editor+).
  Future<DocumentSnapshotView> getSnapshot(
    Session session,
    UuidValue documentUuid,
    int? revision,
  ) async => DocumentService.getSnapshot(
    session,
    await UserService.actorOf(session),
    documentUuid,
    revision,
  );

  /// LWW metadata change (themeId, pageSetup, language, frontMatter).
  Future<void> updateMeta(
    Session session,
    UuidValue documentUuid,
    DocumentMetaPatch patch,
    UuidValue clientOpId,
  ) async => DocumentService.updateMeta(
    session,
    await UserService.actorOf(session),
    documentUuid,
    patch,
    clientOpId,
  );
}
