import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../users/user_service.dart';
import 'drive_events.dart';
import 'drive_service.dart';
import 'import_service.dart';

/// Wonky Drive (specs/05 §2).
class DriveEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Children of a folder (null = My Drive root) or a virtual view.
  Future<DriveListPage> list(
    Session session,
    UuidValue? folderUuid,
    DriveListFilter filter,
    DriveSort sort,
    String? cursor,
    int limit,
  ) async => DriveService.list(
    session,
    await UserService.actorOf(session),
    folderUuid: folderUuid,
    filter: filter,
    sort: sort,
    cursor: cursor,
    limit: limit,
  );

  Future<DriveItemView> get(Session session, UuidValue uuid) async =>
      DriveService.get(session, await UserService.actorOf(session), uuid);

  /// Breadcrumb ancestors visible to the caller, root first.
  Future<List<DriveItemView>> path(Session session, UuidValue uuid) async =>
      DriveService.path(session, await UserService.actorOf(session), uuid);

  Future<DriveListPage> search(
    Session session,
    String query,
    DriveSearchFilters filters,
    String? cursor,
    int limit,
  ) async => DriveService.search(
    session,
    await UserService.actorOf(session),
    query,
    filters: filters,
    cursor: cursor,
    limit: limit,
  );

  Future<DriveItemView> createFolder(
    Session session,
    UuidValue? parentUuid,
    String name,
  ) async => DriveService.createFolder(
    session,
    await UserService.actorOf(session),
    parentUuid: parentUuid,
    name: name,
  );

  /// Creates a document; idempotent on the client-generated [documentUuid]
  /// and [itemUuid] (offline creation).
  Future<DriveItemView> createDocument(
    Session session,
    UuidValue? parentUuid,
    String name,
    UuidValue? templateUuid,
    String? initialMarkdown, {
    UuidValue? documentUuid,
    UuidValue? itemUuid,
  }) async => DriveService.createDocument(
    session,
    await UserService.actorOf(session),
    parentUuid: parentUuid,
    name: name,
    templateUuid: templateUuid,
    initialMarkdown: initialMarkdown,
    documentUuid: documentUuid,
    itemUuid: itemUuid,
  );

  /// Registers a spreadsheet created locally in a reserved space
  /// (idempotent).
  Future<DriveItemView> registerSpreadsheet(
    Session session,
    UuidValue spaceUuid,
    UuidValue? parentUuid,
    String name,
  ) async => DriveService.registerSpreadsheet(
    session,
    await UserService.actorOf(session),
    spaceUuid: spaceUuid,
    parentUuid: parentUuid,
    name: name,
  );

  /// Creates a spreadsheet server-side (space + rows).
  Future<DriveItemView> createSpreadsheet(
    Session session,
    UuidValue? parentUuid,
    String name,
    UuidValue? templateUuid, {
    String? locale,
    String? timeZone,
  }) async => DriveService.createSpreadsheet(
    session,
    await UserService.actorOf(session),
    parentUuid: parentUuid,
    name: name,
    templateUuid: templateUuid,
    locale: locale,
    timeZone: timeZone,
  );

  Future<DriveItemView> rename(
    Session session,
    UuidValue uuid,
    String name,
  ) async => DriveService.rename(
    session,
    await UserService.actorOf(session),
    uuid,
    name,
  );

  Future<DriveItemView> updateDescription(
    Session session,
    UuidValue uuid,
    String? description,
  ) async => DriveService.updateDescription(
    session,
    await UserService.actorOf(session),
    uuid,
    description,
  );

  /// Moves items into [newParentUuid] (null = My Drive root, owners only).
  Future<List<DriveItemView>> move(
    Session session,
    List<UuidValue> uuids,
    UuidValue? newParentUuid,
  ) async => DriveService.move(
    session,
    await UserService.actorOf(session),
    uuids,
    newParentUuid,
  );

  Future<DriveItemView> copy(
    Session session,
    UuidValue uuid,
    String newName,
    UuidValue? parentUuid,
    bool copyComments,
    bool copySharing,
  ) async => DriveService.copy(
    session,
    await UserService.actorOf(session),
    uuid,
    newName: newName,
    parentUuid: parentUuid,
    copyComments: copyComments,
    copySharing: copySharing,
  );

  Future<DriveItemView> setStarred(
    Session session,
    UuidValue uuid,
    bool starred,
  ) async => DriveService.setStarred(
    session,
    await UserService.actorOf(session),
    uuid,
    starred,
  );

  Future<DriveItemView> setPinnedOffline(
    Session session,
    UuidValue uuid,
    bool pinned,
  ) async => DriveService.setPinnedOffline(
    session,
    await UserService.actorOf(session),
    uuid,
    pinned,
  );

  /// Records that the caller opened the item (Recent; link visits appear in
  /// Shared with me).
  Future<DriveItemView> markOpened(Session session, UuidValue uuid) async =>
      DriveService.markOpened(
        session,
        await UserService.actorOf(session),
        uuid,
      );

  /// "Add shortcut to My Drive" ([parentUuid] null = root).
  Future<DriveItemView> addShortcut(
    Session session,
    UuidValue uuid,
    UuidValue? parentUuid,
  ) async => DriveService.addShortcut(
    session,
    await UserService.actorOf(session),
    uuid,
    parentUuid,
  );

  Future<void> removeShortcut(Session session, UuidValue uuid) async =>
      DriveService.removeShortcut(
        session,
        await UserService.actorOf(session),
        uuid,
      );

  Future<void> trash(Session session, List<UuidValue> uuids) async =>
      DriveService.trash(session, await UserService.actorOf(session), uuids);

  Future<void> restore(Session session, List<UuidValue> uuids) async =>
      DriveService.restore(session, await UserService.actorOf(session), uuids);

  Future<void> deletePermanently(
    Session session,
    List<UuidValue> uuids,
  ) async => DriveService.deletePermanently(
    session,
    await UserService.actorOf(session),
    uuids,
  );

  /// Deletes all owned items in the trash; returns how many.
  Future<int> emptyTrash(Session session) async =>
      DriveService.emptyTrash(session, await UserService.actorOf(session));

  /// Live changes of items visible to the caller.
  Stream<DriveChange> watch(Session session) async* {
    final actor = await UserService.actorOf(session);
    yield* DriveEvents.watch(session, actor);
  }

  /// Template gallery ([kind] null = all kinds).
  Future<List<TemplateView>> listTemplates(
    Session session,
    DriveItemKind? kind,
  ) async => DriveService.listTemplates(
    session,
    await UserService.actorOf(session),
    kind,
  );

  /// Publishes an owned item as a template ([category] null = unpublish).
  Future<DriveItemView> setTemplate(
    Session session,
    UuidValue uuid,
    TemplateCategory? category,
  ) async => DriveService.setTemplate(
    session,
    await UserService.actorOf(session),
    uuid,
    category,
  );

  /// Imports an uploaded file (`file.createUpload` with kind importSource)
  /// as a new item.
  Future<ImportReportView> import(
    Session session,
    UuidValue uploadId,
    DriveItemKind kind,
    DriveImportOptions options,
  ) async => ImportService.import(
    session,
    await UserService.actorOf(session),
    uploadId,
    kind,
    options,
  );

  Future<StorageUsage> storageUsage(Session session) async =>
      DriveService.storageUsage(session, await UserService.actorOf(session));

  /// Sets a client-rendered thumbnail (uploaded with kind thumbnail).
  Future<DriveItemView> setThumbnail(
    Session session,
    UuidValue uuid,
    UuidValue uploadedFileUuid,
  ) async => DriveService.setThumbnail(
    session,
    await UserService.actorOf(session),
    uuid,
    uploadedFileUuid,
  );

  /// The activity feed of an item, newest first.
  Future<List<ActivityEventView>> activity(
    Session session,
    UuidValue uuid,
    int? beforeId,
    int limit,
  ) async => DriveService.activity(
    session,
    await UserService.actorOf(session),
    uuid,
    beforeId: beforeId,
    limit: limit,
  );
}
