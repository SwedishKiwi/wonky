import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import '../versions/write_history_service.dart';

/// Write version history (Write 08 §4.3). Editors+.
class WriteHistoryEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<WriteVersionDocument> getVersionDocument(
    Session session,
    UuidValue documentUuid,
    int revision,
  ) async => WriteHistoryService.getVersionDocument(
    session,
    await UserService.actorOf(session),
    documentUuid,
    revision,
  );

  Future<WriteDiffView> diff(
    Session session,
    UuidValue documentUuid,
    int fromRevision,
    int toRevision,
  ) async => WriteHistoryService.diff(
    session,
    await UserService.actorOf(session),
    documentUuid,
    fromRevision,
    toRevision,
  );

  Future<ItemVersionView> createRestorePoint(
    Session session,
    UuidValue documentUuid,
  ) async => WriteHistoryService.createRestorePoint(
    session,
    await UserService.actorOf(session),
    documentUuid,
  );

  Future<VersionRestoreResult> restore(
    Session session,
    UuidValue documentUuid,
    int versionId,
  ) async => WriteHistoryService.restore(
    session,
    await UserService.actorOf(session),
    documentUuid,
    versionId,
  );

  Future<DriveItemView> copyVersion(
    Session session,
    UuidValue documentUuid,
    int versionId,
    String name,
    UuidValue? parentUuid,
  ) async => WriteHistoryService.copyVersion(
    session,
    await UserService.actorOf(session),
    documentUuid,
    versionId,
    name,
    parentUuid: parentUuid,
  );
}
