import 'package:wonky_client/wonky_client.dart';

import 'api.dart';

/// Drive operations (suite 05 §2). Implemented by [ServerDriveRepository]
/// (the `drive` endpoint), wrapped by `CachedDriveRepository` for offline
/// browsing and queued operations, and faked by `FakeDriveRepository`.
abstract class DriveRepository {
  Future<DriveListPage> list({
    UuidValue? folderUuid,
    required DriveListFilter filter,
    required DriveSort sort,
    String? cursor,
    int limit = 100,
  });

  Future<DriveItemView> get(UuidValue uuid);

  /// Ancestors visible to the user, root first (excluding [uuid]).
  Future<List<DriveItemView>> path(UuidValue uuid);

  Future<DriveListPage> search(
    String query, {
    required DriveSearchFilters filters,
    String? cursor,
    int limit = 50,
  });

  Future<DriveItemView> createFolder({
    UuidValue? parentUuid,
    required String name,
  });

  Future<DriveItemView> createDocument({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String? initialMarkdown,
    UuidValue? documentUuid,
    UuidValue? itemUuid,
  });

  Future<DriveItemView> createSpreadsheet({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
  });

  Future<DriveItemView> registerSpreadsheet({
    required UuidValue spaceUuid,
    UuidValue? parentUuid,
    required String name,
  });

  Future<DriveItemView> rename(UuidValue uuid, String name);

  Future<DriveItemView> updateDescription(UuidValue uuid, String? description);

  Future<List<DriveItemView>> move(
    List<UuidValue> uuids,
    UuidValue? newParentUuid,
  );

  Future<DriveItemView> copy(
    UuidValue uuid, {
    required String newName,
    UuidValue? parentUuid,
    bool copyComments = false,
    bool copySharing = false,
  });

  Future<DriveItemView> setStarred(UuidValue uuid, bool starred);

  Future<DriveItemView> setPinnedOffline(UuidValue uuid, bool pinned);

  /// Records that the user opened the item (Recent view, link access).
  Future<DriveItemView> markOpened(UuidValue uuid);

  Future<DriveItemView> addShortcut(UuidValue uuid, UuidValue? parentUuid);

  Future<void> removeShortcut(UuidValue uuid);

  Future<void> trash(List<UuidValue> uuids);

  Future<void> restore(List<UuidValue> uuids);

  Future<void> deletePermanently(List<UuidValue> uuids);

  /// Returns the number of purged items.
  Future<int> emptyTrash();

  Future<List<TemplateView>> listTemplates(DriveItemKind? kind);

  Future<StorageUsage> storageUsage();

  /// The activity feed of [uuid], newest first; [beforeId] pages back.
  Future<List<ActivityEventView>> activity(
    UuidValue uuid, {
    int? beforeId,
    int limit = 50,
  });

  /// Live changes of items visible to the user.
  Stream<DriveChange> watch();
}

/// [DriveRepository] backed by the server's `drive` endpoint.
class ServerDriveRepository implements DriveRepository {
  ServerDriveRepository(this.api);

  final Api api;

  @override
  Future<DriveListPage> list({
    UuidValue? folderUuid,
    required DriveListFilter filter,
    required DriveSort sort,
    String? cursor,
    int limit = 100,
  }) => api.guard((c) => c.drive.list(folderUuid, filter, sort, cursor, limit));

  @override
  Future<DriveItemView> get(UuidValue uuid) =>
      api.guard((c) => c.drive.get(uuid));

  @override
  Future<List<DriveItemView>> path(UuidValue uuid) =>
      api.guard((c) => c.drive.path(uuid));

  @override
  Future<DriveListPage> search(
    String query, {
    required DriveSearchFilters filters,
    String? cursor,
    int limit = 50,
  }) => api.guard((c) => c.drive.search(query, filters, cursor, limit));

  @override
  Future<DriveItemView> createFolder({
    UuidValue? parentUuid,
    required String name,
  }) => api.guard((c) => c.drive.createFolder(parentUuid, name));

  @override
  Future<DriveItemView> createDocument({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String? initialMarkdown,
    UuidValue? documentUuid,
    UuidValue? itemUuid,
  }) => api.guard(
    (c) => c.drive.createDocument(
      parentUuid,
      name,
      templateUuid,
      initialMarkdown,
      documentUuid: documentUuid,
      itemUuid: itemUuid,
    ),
  );

  @override
  Future<DriveItemView> createSpreadsheet({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
  }) => api.guard(
    (c) => c.drive.createSpreadsheet(parentUuid, name, templateUuid),
  );

  @override
  Future<DriveItemView> registerSpreadsheet({
    required UuidValue spaceUuid,
    UuidValue? parentUuid,
    required String name,
  }) => api.guard(
    (c) => c.drive.registerSpreadsheet(spaceUuid, parentUuid, name),
  );

  @override
  Future<DriveItemView> rename(UuidValue uuid, String name) =>
      api.guard((c) => c.drive.rename(uuid, name));

  @override
  Future<DriveItemView> updateDescription(
    UuidValue uuid,
    String? description,
  ) => api.guard((c) => c.drive.updateDescription(uuid, description));

  @override
  Future<List<DriveItemView>> move(
    List<UuidValue> uuids,
    UuidValue? newParentUuid,
  ) => api.guard((c) => c.drive.move(uuids, newParentUuid));

  @override
  Future<DriveItemView> copy(
    UuidValue uuid, {
    required String newName,
    UuidValue? parentUuid,
    bool copyComments = false,
    bool copySharing = false,
  }) => api.guard(
    (c) => c.drive.copy(uuid, newName, parentUuid, copyComments, copySharing),
  );

  @override
  Future<DriveItemView> setStarred(UuidValue uuid, bool starred) =>
      api.guard((c) => c.drive.setStarred(uuid, starred));

  @override
  Future<DriveItemView> setPinnedOffline(UuidValue uuid, bool pinned) =>
      api.guard((c) => c.drive.setPinnedOffline(uuid, pinned));

  @override
  Future<DriveItemView> markOpened(UuidValue uuid) =>
      api.guard((c) => c.drive.markOpened(uuid));

  @override
  Future<DriveItemView> addShortcut(UuidValue uuid, UuidValue? parentUuid) =>
      api.guard((c) => c.drive.addShortcut(uuid, parentUuid));

  @override
  Future<void> removeShortcut(UuidValue uuid) =>
      api.guard((c) => c.drive.removeShortcut(uuid));

  @override
  Future<void> trash(List<UuidValue> uuids) =>
      api.guard((c) => c.drive.trash(uuids));

  @override
  Future<void> restore(List<UuidValue> uuids) =>
      api.guard((c) => c.drive.restore(uuids));

  @override
  Future<void> deletePermanently(List<UuidValue> uuids) =>
      api.guard((c) => c.drive.deletePermanently(uuids));

  @override
  Future<int> emptyTrash() => api.guard((c) => c.drive.emptyTrash());

  @override
  Future<List<TemplateView>> listTemplates(DriveItemKind? kind) =>
      api.guard((c) => c.drive.listTemplates(kind));

  @override
  Future<StorageUsage> storageUsage() =>
      api.guard((c) => c.drive.storageUsage());

  @override
  Future<List<ActivityEventView>> activity(
    UuidValue uuid, {
    int? beforeId,
    int limit = 50,
  }) => api.guard((c) => c.drive.activity(uuid, beforeId, limit));

  @override
  Stream<DriveChange> watch() => api.client.drive.watch();
}
