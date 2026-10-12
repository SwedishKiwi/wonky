import 'dart:async';

import 'package:wonky_client/wonky_client.dart';

/// The server side of one document's sync session (Write 03 §1): the
/// `document.connect` stream plus the non-streaming helpers the client needs
/// for gap fills and resyncs.
///
/// [ServerDocumentSyncTransport] talks to the real server; tests use an
/// in-process fake server.
abstract interface class DocumentSyncTransport {
  /// Opens `document.connect(documentUuid, knownRevision, input)`.
  Stream<DocServerMessage> connect(
    int knownRevision,
    Stream<DocClientMessage> input,
  );

  /// `document.getOps` (at most 1,000 ops per call).
  Future<List<DocumentOpView>> getOps(int fromRevision, int toRevision);

  /// `document.getSnapshot` at head.
  Future<DocumentSnapshotView> getSnapshot();
}

/// [DocumentSyncTransport] over the generated client.
class ServerDocumentSyncTransport implements DocumentSyncTransport {
  ServerDocumentSyncTransport(this.client, this.documentUuid);

  final Client client;
  final UuidValue documentUuid;

  @override
  Stream<DocServerMessage> connect(
    int knownRevision,
    Stream<DocClientMessage> input,
  ) => client.document.connect(documentUuid, knownRevision, input);

  @override
  Future<List<DocumentOpView>> getOps(int fromRevision, int toRevision) =>
      client.document.getOps(documentUuid, fromRevision, toRevision);

  @override
  Future<DocumentSnapshotView> getSnapshot() =>
      client.document.getSnapshot(documentUuid, null);
}
