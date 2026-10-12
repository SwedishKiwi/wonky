import 'package:serverpod/serverpod.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/versions/version_service.dart';
import '../ot/document_store.dart';
import '../ot/ot_service.dart';

/// Write versions (Write 08 §4.1): a version is an op-log revision with a
/// snapshot at that revision, so op-log pruning never breaks
/// materialization.
class WriteVersionProvider implements VersionProvider {
  const WriteVersionProvider();

  @override
  DriveItemKind get kind => DriveItemKind.document;

  @override
  Future<CapturedVersion> capture(Session session, DriveItem item) async {
    final doc = await DocumentStore.requireByItem(session, item.id!);
    final content = await DocumentStore.head(session, doc);
    await DocumentStore.writeSnapshot(session, doc, doc.headRevision, content);
    final size = DocumentStore.encodeContent(content, compress: false).length;
    return CapturedVersion(
      storageKind: VersionStorage.writeRevision,
      revision: doc.headRevision,
      sizeBytes: size,
    );
  }

  @override
  Future<RestoredVersion> restore(
    Session session,
    Actor actor,
    DriveItem item,
    ItemVersion version,
  ) async {
    final doc = await DocumentStore.requireByItem(session, item.id!);
    final revision = version.revision;
    if (revision == null) throw Errors.invalid('The version has no revision.');
    final target = DeltaUtils.stripOverlays(
      await DocumentStore.contentAt(session, doc, revision),
    );
    final committed = await OtService.submitServerChange(
      session,
      actor: actor,
      document: doc,
      item: item,
      kind: DocumentOpKind.restore,
      // R = strip(C).diff(strip(V)) keeps anchors on surviving text.
      build: (head) => DeltaUtils.stripOverlays(head).diff(target),
    );
    return RestoredVersion(revision: committed.revision);
  }

  @override
  Future<void> discard(Session session, ItemVersion version) async {
    // Snapshots are shared with the op log and pruned with it.
  }

  @override
  Future<void> afterCapture(
    Session session,
    DriveItem item,
    ItemVersion version,
  ) async {}
}
