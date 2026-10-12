import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../common/errors.dart';
import '../common/models.dart';
import '../files/file_service.dart';
import '../users/user_service.dart';
import 'version_service.dart';

/// Version history shared by both apps (specs/07 §5). Editors+.
class VersionEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<List<ItemVersionView>> list(
    Session session,
    UuidValue itemUuid,
    bool namedOnly, {
    int? beforeId,
    int? limit,
  }) async => VersionService.list(
    session,
    await UserService.actorOf(session),
    itemUuid,
    namedOnly: namedOnly,
    beforeId: beforeId,
    limit: limit ?? 100,
  );

  /// Captures and names the current state.
  Future<ItemVersionView> nameCurrent(
    Session session,
    UuidValue itemUuid,
    String name,
  ) async => VersionService.nameCurrent(
    session,
    await UserService.actorOf(session),
    itemUuid,
    name,
  );

  /// Names a version; null removes the name.
  Future<ItemVersionView> rename(
    Session session,
    UuidValue itemUuid,
    int versionId,
    String? name,
  ) async => VersionService.rename(
    session,
    await UserService.actorOf(session),
    itemUuid,
    versionId,
    name,
  );

  /// Restores a version (a restore point is captured first).
  Future<VersionRestoreResult> restore(
    Session session,
    UuidValue itemUuid,
    int versionId,
  ) async => VersionService.restore(
    session,
    await UserService.actorOf(session),
    itemUuid,
    versionId,
  );

  /// Signed URL (15 min) of a Sheets snapshot (gzip NDJSON).
  Future<FileUrlView> getSnapshotUrl(
    Session session,
    UuidValue itemUuid,
    int versionId,
  ) async {
    final actor = await UserService.actorOf(session);
    final (_, version) = await VersionService.requireVersion(
      session,
      actor,
      itemUuid,
      versionId,
      min: Role.editor,
    );
    final fileId = version.snapshotFileId;
    if (fileId == null) throw Errors.invalid('This version has no snapshot.');
    return FileService.getUrl(session, actor, fileId);
  }
}
