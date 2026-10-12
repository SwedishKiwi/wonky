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

  Future<DriveItemView> createFolder({UuidValue? parentUuid, required String name});

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

  Future<List<DriveItemView>> move(List<UuidValue> uuids, UuidValue? newParentUuid);

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

  Future<List<ActivityEventView>> activity(UuidValue uuid, {int limit = 50});

  /// Live changes of items visible to the user.
  Stream<DriveChange> watch();
}

/// [DriveRepository] backed by the server's `drive` endpoint.
class ServerDriveRepository implements DriveRepository {
  ServerDriveRepository(this.api);

  final Api api;
  static const _e = 'drive';

  @override
  Future<DriveListPage> list({
    UuidValue? folderUuid,
    required DriveListFilter filter,
    required DriveSort sort,
    String? cursor,
    int limit = 100,
  }) => api.call<DriveListPage>(_e, 'list', {
    'folderUuid': folderUuid,
    'filter': filter,
    'sort': sort,
    'cursor': cursor,
    'limit': limit,
  });

  @override
  Future<DriveItemView> get(UuidValue uuid) =>
      api.call<DriveItemView>(_e, 'get', {'uuid': uuid});

  @override
  Future<List<DriveItemView>> path(UuidValue uuid) =>
      api.call<List<DriveItemView>>(_e, 'path', {'uuid': uuid});

  @override
  Future<DriveListPage> search(
    String query, {
    required DriveSearchFilters filters,
    String? cursor,
    int limit = 50,
  }) => api.call<DriveListPage>(_e, 'search', {
    'query': query,
    'filters': filters,
    'cursor': cursor,
    'limit': limit,
  });

  @override
  Future<DriveItemView> createFolder({UuidValue? parentUuid, required String name}) =>
      api.call<DriveItemView>(_e, 'createFolder', {'parentUuid': parentUuid, 'name': name});

  @override
  Future<DriveItemView> createDocument({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String? initialMarkdown,
    UuidValue? documentUuid,
    UuidValue? itemUuid,
  }) => api.call<DriveItemView>(_e, 'createDocument', {
    'parentUuid': parentUuid,
    'name': name,
    'templateUuid': templateUuid,
    'initialMarkdown': initialMarkdown,
    'documentUuid': documentUuid,
    'itemUuid': itemUuid,
  });

  @override
  Future<DriveItemView> createSpreadsheet({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
  }) => api.call<DriveItemView>(_e, 'createSpreadsheet', {
    'parentUuid': parentUuid,
    'name': name,
    'templateUuid': templateUuid,
  });

  @override
  Future<DriveItemView> registerSpreadsheet({
    required UuidValue spaceUuid,
    UuidValue? parentUuid,
    required String name,
  }) => api.call<DriveItemView>(_e, 'registerSpreadsheet', {
    'spaceUuid': spaceUuid,
    'parentUuid': parentUuid,
    'name': name,
  });

  @override
  Future<DriveItemView> rename(UuidValue uuid, String name) =>
      api.call<DriveItemView>(_e, 'rename', {'uuid': uuid, 'name': name});

  @override
  Future<DriveItemView> updateDescription(UuidValue uuid, String? description) =>
      api.call<DriveItemView>(_e, 'updateDescription', {
        'uuid': uuid,
        'description': description,
      });

  @override
  Future<List<DriveItemView>> move(List<UuidValue> uuids, UuidValue? newParentUuid) =>
      api.call<List<DriveItemView>>(_e, 'move', {
        'uuids': uuids,
        'newParentUuid': newParentUuid,
      });

  @override
  Future<DriveItemView> copy(
    UuidValue uuid, {
    required String newName,
    UuidValue? parentUuid,
    bool copyComments = false,
    bool copySharing = false,
  }) => api.call<DriveItemView>(_e, 'copy', {
    'uuid': uuid,
    'newName': newName,
    'parentUuid': parentUuid,
    'copyComments': copyComments,
    'copySharing': copySharing,
  });

  @override
  Future<DriveItemView> setStarred(UuidValue uuid, bool starred) =>
      api.call<DriveItemView>(_e, 'setStarred', {'uuid': uuid, 'starred': starred});

  @override
  Future<DriveItemView> setPinnedOffline(UuidValue uuid, bool pinned) =>
      api.call<DriveItemView>(_e, 'setPinnedOffline', {'uuid': uuid, 'pinned': pinned});

  @override
  Future<DriveItemView> markOpened(UuidValue uuid) =>
      api.call<DriveItemView>(_e, 'markOpened', {'uuid': uuid});

  @override
  Future<DriveItemView> addShortcut(UuidValue uuid, UuidValue? parentUuid) =>
      api.call<DriveItemView>(_e, 'addShortcut', {'uuid': uuid, 'parentUuid': parentUuid});

  @override
  Future<void> removeShortcut(UuidValue uuid) =>
      api.call<void>(_e, 'removeShortcut', {'uuid': uuid});

  @override
  Future<void> trash(List<UuidValue> uuids) => api.call<void>(_e, 'trash', {'uuids': uuids});

  @override
  Future<void> restore(List<UuidValue> uuids) =>
      api.call<void>(_e, 'restore', {'uuids': uuids});

  @override
  Future<void> deletePermanently(List<UuidValue> uuids) =>
      api.call<void>(_e, 'deletePermanently', {'uuids': uuids});

  @override
  Future<int> emptyTrash() => api.call<int>(_e, 'emptyTrash');

  @override
  Future<List<TemplateView>> listTemplates(DriveItemKind? kind) =>
      api.call<List<TemplateView>>(_e, 'listTemplates', {'kind': kind});

  @override
  Future<StorageUsage> storageUsage() => api.call<StorageUsage>(_e, 'storageUsage');

  @override
  Future<List<ActivityEventView>> activity(UuidValue uuid, {int limit = 50}) =>
      api.call<List<ActivityEventView>>(_e, 'activity', {'uuid': uuid, 'limit': limit});

  @override
  Stream<DriveChange> watch() => api.stream<DriveChange>(_e, 'watch');
}
