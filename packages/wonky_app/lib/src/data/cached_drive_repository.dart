import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../core/connectivity_service.dart';
import 'api.dart';
import 'drive_cache.dart';
import 'drive_repository.dart';

/// Wraps a remote [DriveRepository] with the offline cache and the pending
/// operation queue (suite 05 §4, 12 §3).
///
/// - Reads go to the server and refresh the cache; offline they are served
///   from the cache.
/// - Rename, move, star, pin, trash, restore, document creation and
///   spreadsheet registration made offline are applied to the cache
///   optimistically and queued; [replay] sends them in order once online.
///   Conflicts resolve server-side (last write wins); when an item no longer
///   exists [onConflict] is called (the shell shows a toast).
class CachedDriveRepository extends ChangeNotifier implements DriveRepository {
  CachedDriveRepository({
    required this.remote,
    required this.cache,
    required this.queue,
    required this.connectivity,
    required this.currentUser,
    UuidV7Generator? ids,
    this.onConflict,
  }) : _ids = ids ?? UuidV7Generator.instance {
    connectivity.addListener(_onConnectivity);
  }

  final DriveRepository remote;
  final DriveCache cache;
  final PendingDriveOpQueue queue;
  final ConnectivityService connectivity;
  final UserSummary? Function() currentUser;
  final UuidV7Generator _ids;
  final void Function(PendingDriveOp op, Object error)? onConflict;
  bool _replaying = false;

  /// Number of queued operations.
  int get pendingCount => queue.length;

  Future<void> init() async {
    await cache.load();
    await queue.load();
    if (connectivity.online) unawaited(replay());
  }

  void _onConnectivity() {
    if (connectivity.online) unawaited(replay());
  }

  Future<T> _read<T>(Future<T> Function() call, T? Function() fallback) async {
    try {
      final r = await call();
      connectivity.reportSuccess();
      return r;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      connectivity.reportFailure();
      final f = fallback();
      if (f == null) rethrow;
      return f;
    }
  }

  static String listKey(
    UuidValue? folderUuid,
    DriveListFilter f,
    DriveSort s,
  ) =>
      'folder:${folderUuid?.uuid ?? 'root'}:${f.view.name}:${f.owner.name}:'
      '${f.kinds?.map((k) => k.name).join(',') ?? '*'}:${s.field.name}:${s.descending}:${s.foldersFirst}';

  @override
  Future<DriveListPage> list({
    UuidValue? folderUuid,
    required DriveListFilter filter,
    required DriveSort sort,
    String? cursor,
    int limit = 100,
  }) {
    final key = listKey(folderUuid, filter, sort);
    return _read(
      () async {
        final page = await remote.list(
          folderUuid: folderUuid,
          filter: filter,
          sort: sort,
          cursor: cursor,
          limit: limit,
        );
        cache.putList(key, page.items, append: cursor != null);
        return page;
      },
      () {
        if (cursor != null) return DriveListPage(items: const []);
        var items = cache.list(key);
        if (items == null && filter.view == DriveView.offline) {
          items = [
            for (final i in cache.items)
              if (i.pinnedOffline) i,
          ];
        }
        return items == null ? null : DriveListPage(items: items);
      },
    );
  }

  @override
  Future<DriveItemView> get(UuidValue uuid) => _read(() async {
    final v = await remote.get(uuid);
    cache.put([v]);
    return v;
  }, () => cache.item(uuid));

  @override
  Future<List<DriveItemView>> path(UuidValue uuid) =>
      _read(() => remote.path(uuid), () {
        final out = <DriveItemView>[];
        var cur = cache.item(uuid)?.parentUuid;
        while (cur != null) {
          final p = cache.item(cur);
          if (p == null) break;
          out.insert(0, p);
          cur = p.parentUuid;
        }
        return out;
      });

  @override
  Future<DriveListPage> search(
    String query, {
    required DriveSearchFilters filters,
    String? cursor,
    int limit = 50,
  }) => _read(
    () async {
      final page = await remote.search(
        query,
        filters: filters,
        cursor: cursor,
        limit: limit,
      );
      cache.put(page.items);
      return page;
    },
    () {
      final q = query.toLowerCase();
      return DriveListPage(
        items: [
          for (final i in cache.items)
            if (i.trashedAt == null &&
                i.name.toLowerCase().contains(q) &&
                (filters.kinds == null || filters.kinds!.contains(i.kind)))
              i,
        ],
      );
    },
  );

  Future<T> _write<T>(
    String kind,
    Map<String, Object?> args,
    Future<T> Function() call,
    T Function() optimistic,
  ) async {
    if (!connectivity.online) return _queue(kind, args, optimistic);
    try {
      final r = await call();
      connectivity.reportSuccess();
      return r;
    } catch (e) {
      if (!isOfflineError(e)) rethrow;
      connectivity.reportFailure();
      return _queue(kind, args, optimistic);
    }
  }

  Future<T> _queue<T>(
    String kind,
    Map<String, Object?> args,
    T Function() optimistic,
  ) async {
    await queue.add(
      PendingDriveOp(
        id: _ids.nextString(),
        kind: kind,
        args: args,
        createdAt: clock.now(),
      ),
    );
    notifyListeners();
    return optimistic();
  }

  DriveItemView _cached(UuidValue uuid) =>
      cache.item(uuid) ??
      (throw const OfflineException('Item not available offline'));

  @override
  Future<DriveItemView> rename(UuidValue uuid, String name) => _write(
    'rename',
    {'uuid': uuid.uuid, 'name': name},
    () async => cache.put([await remote.rename(uuid, name)]).single,
    () {
      cache.update(
        uuid,
        (v) => v.copyWith(name: name, modifiedAt: clock.now()),
      );
      return _cached(uuid);
    },
  );

  @override
  Future<List<DriveItemView>> move(
    List<UuidValue> uuids,
    UuidValue? newParentUuid,
  ) => _write(
    'move',
    {
      'uuids': [for (final u in uuids) u.uuid],
      'newParentUuid': newParentUuid?.uuid,
    },
    () async => cache.put(await remote.move(uuids, newParentUuid)),
    () => [
      for (final u in uuids)
        if (cache.item(u) != null)
          (() {
            cache.update(u, (v) => v.copyWith(parentUuid: newParentUuid));
            return _cached(u);
          })(),
    ],
  );

  @override
  Future<DriveItemView> setStarred(UuidValue uuid, bool starred) => _write(
    'setStarred',
    {'uuid': uuid.uuid, 'starred': starred},
    () async => cache.put([await remote.setStarred(uuid, starred)]).single,
    () {
      cache.update(uuid, (v) => v.copyWith(starred: starred));
      return _cached(uuid);
    },
  );

  @override
  Future<DriveItemView> setPinnedOffline(UuidValue uuid, bool pinned) => _write(
    'setPinnedOffline',
    {'uuid': uuid.uuid, 'pinned': pinned},
    () async => cache.put([await remote.setPinnedOffline(uuid, pinned)]).single,
    () {
      cache.update(uuid, (v) => v.copyWith(pinnedOffline: pinned));
      return _cached(uuid);
    },
  );

  @override
  Future<void> trash(List<UuidValue> uuids) => _write(
    'trash',
    {
      'uuids': [for (final u in uuids) u.uuid],
    },
    () async {
      await remote.trash(uuids);
      for (final u in uuids) {
        cache.update(u, (v) => v.copyWith(trashedAt: clock.now()));
      }
    },
    () {
      for (final u in uuids) {
        cache.update(u, (v) => v.copyWith(trashedAt: clock.now()));
      }
    },
  );

  @override
  Future<void> restore(List<UuidValue> uuids) => _write(
    'restore',
    {
      'uuids': [for (final u in uuids) u.uuid],
    },
    () async {
      await remote.restore(uuids);
      for (final u in uuids) {
        cache.update(u, (v) => v.copyWith(trashedAt: null));
      }
    },
    () {
      for (final u in uuids) {
        cache.update(u, (v) => v.copyWith(trashedAt: null));
      }
    },
  );

  @override
  Future<DriveItemView> createDocument({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String? initialMarkdown,
    UuidValue? documentUuid,
    UuidValue? itemUuid,
  }) {
    final doc = documentUuid ?? _ids.next();
    final item = itemUuid ?? _ids.next();
    return _write(
      'createDocument',
      {
        'parentUuid': parentUuid?.uuid,
        'name': name,
        'templateUuid': templateUuid?.uuid,
        'initialMarkdown': initialMarkdown,
        'documentUuid': doc.uuid,
        'itemUuid': item.uuid,
      },
      () async {
        final v = await remote.createDocument(
          parentUuid: parentUuid,
          name: name,
          templateUuid: templateUuid,
          initialMarkdown: initialMarkdown,
          documentUuid: doc,
          itemUuid: item,
        );
        cache.insertIntoFolderLists(v);
        return v;
      },
      () =>
          _optimisticItem(item, DriveItemKind.document, name, parentUuid, doc),
    );
  }

  @override
  Future<DriveItemView> registerSpreadsheet({
    required UuidValue spaceUuid,
    UuidValue? parentUuid,
    required String name,
  }) => _write(
    'registerSpreadsheet',
    {'spaceUuid': spaceUuid.uuid, 'parentUuid': parentUuid?.uuid, 'name': name},
    () async {
      final v = await remote.registerSpreadsheet(
        spaceUuid: spaceUuid,
        parentUuid: parentUuid,
        name: name,
      );
      cache.insertIntoFolderLists(v);
      return v;
    },
    () => _optimisticItem(
      spaceUuid,
      DriveItemKind.spreadsheet,
      name,
      parentUuid,
      spaceUuid,
    ),
  );

  DriveItemView _optimisticItem(
    UuidValue uuid,
    DriveItemKind kind,
    String name,
    UuidValue? parent,
    UuidValue contentRef,
  ) {
    final me = currentUser();
    if (me == null) throw const OfflineException('Not signed in');
    final now = clock.now();
    final v = DriveItemView(
      uuid: uuid,
      kind: kind,
      name: name,
      contentRef: contentRef,
      parentUuid: parent,
      owner: me,
      role: AccessRole.owner,
      shared: false,
      sizeBytes: 0,
      createdAt: now,
      modifiedAt: now,
      starred: false,
      pinnedOffline: true,
      lastOpenedAt: now,
      editorsCanShare: true,
      nonEditorsCanExport: true,
      viewersSeeComments: false,
    );
    cache.insertIntoFolderLists(v);
    return v;
  }

  /// Sends queued operations in order. Stops at the first network failure.
  Future<void> replay() async {
    if (_replaying) return;
    _replaying = true;
    try {
      while (queue.ops.isNotEmpty && connectivity.online) {
        final op = queue.ops.first;
        try {
          await _send(op);
          await queue.removeFirst();
          notifyListeners();
        } catch (e) {
          if (isOfflineError(e)) {
            connectivity.reportFailure();
            break;
          }
          // Not retryable (item gone, no permission): drop and tell the user.
          await queue.removeFirst();
          notifyListeners();
          onConflict?.call(op, e);
        }
      }
    } finally {
      _replaying = false;
    }
  }

  Future<void> _send(PendingDriveOp op) async {
    final a = op.args;
    UuidValue u(String k) => UuidValue.fromString(a[k]! as String);
    UuidValue? uOpt(String k) =>
        a[k] == null ? null : UuidValue.fromString(a[k]! as String);
    List<UuidValue> us(String k) => [
      for (final s in a[k]! as List) UuidValue.fromString('$s'),
    ];
    switch (op.kind) {
      case 'rename':
        cache.put([await remote.rename(u('uuid'), a['name']! as String)]);
      case 'move':
        cache.put(await remote.move(us('uuids'), uOpt('newParentUuid')));
      case 'setStarred':
        cache.put([await remote.setStarred(u('uuid'), a['starred']! as bool)]);
      case 'setPinnedOffline':
        cache.put([
          await remote.setPinnedOffline(u('uuid'), a['pinned']! as bool),
        ]);
      case 'trash':
        await remote.trash(us('uuids'));
      case 'restore':
        await remote.restore(us('uuids'));
      case 'createDocument':
        cache.put([
          await remote.createDocument(
            parentUuid: uOpt('parentUuid'),
            name: a['name']! as String,
            templateUuid: uOpt('templateUuid'),
            initialMarkdown: a['initialMarkdown'] as String?,
            documentUuid: uOpt('documentUuid'),
            itemUuid: uOpt('itemUuid'),
          ),
        ]);
      case 'registerSpreadsheet':
        cache.put([
          await remote.registerSpreadsheet(
            spaceUuid: u('spaceUuid'),
            parentUuid: uOpt('parentUuid'),
            name: a['name']! as String,
          ),
        ]);
    }
  }

  // Online-only operations pass through (they fail fast offline).

  Future<T> _online<T>(Future<T> Function() f) async {
    try {
      final r = await f();
      connectivity.reportSuccess();
      return r;
    } catch (e) {
      if (isOfflineError(e)) connectivity.reportFailure();
      rethrow;
    }
  }

  @override
  Future<DriveItemView> createFolder({
    UuidValue? parentUuid,
    required String name,
  }) => _online(() async {
    final v = await remote.createFolder(parentUuid: parentUuid, name: name);
    cache.insertIntoFolderLists(v);
    return v;
  });

  @override
  Future<DriveItemView> createSpreadsheet({
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
  }) => _online(() async {
    final v = await remote.createSpreadsheet(
      parentUuid: parentUuid,
      name: name,
      templateUuid: templateUuid,
    );
    cache.insertIntoFolderLists(v);
    return v;
  });

  @override
  Future<DriveItemView> updateDescription(
    UuidValue uuid,
    String? description,
  ) => _online(
    () async =>
        cache.put([await remote.updateDescription(uuid, description)]).single,
  );

  @override
  Future<DriveItemView> copy(
    UuidValue uuid, {
    required String newName,
    UuidValue? parentUuid,
    bool copyComments = false,
    bool copySharing = false,
  }) => _online(() async {
    final v = await remote.copy(
      uuid,
      newName: newName,
      parentUuid: parentUuid,
      copyComments: copyComments,
      copySharing: copySharing,
    );
    cache.insertIntoFolderLists(v);
    return v;
  });

  @override
  Future<DriveItemView> markOpened(UuidValue uuid) => _read(() async {
    final v = await remote.markOpened(uuid);
    cache.put([v]);
    return v;
  }, () => cache.item(uuid));

  @override
  Future<DriveItemView> addShortcut(UuidValue uuid, UuidValue? parentUuid) =>
      _online(() => remote.addShortcut(uuid, parentUuid));

  @override
  Future<void> removeShortcut(UuidValue uuid) =>
      _online(() => remote.removeShortcut(uuid));

  @override
  Future<void> deletePermanently(List<UuidValue> uuids) => _online(() async {
    await remote.deletePermanently(uuids);
    for (final u in uuids) {
      cache.remove(u);
    }
  });

  @override
  Future<int> emptyTrash() => _online(() async {
    final n = await remote.emptyTrash();
    for (final i in [...cache.items]) {
      if (i.trashedAt != null) cache.remove(i.uuid);
    }
    return n;
  });

  @override
  Future<List<TemplateView>> listTemplates(DriveItemKind? kind) =>
      _read(() => remote.listTemplates(kind), () => const <TemplateView>[]);

  @override
  Future<StorageUsage> storageUsage() => _online(remote.storageUsage);

  @override
  Future<List<ActivityEventView>> activity(UuidValue uuid, {int limit = 50}) =>
      _read(
        () => remote.activity(uuid, limit: limit),
        () => const <ActivityEventView>[],
      );

  @override
  Stream<DriveChange> watch() => remote.watch().map((c) {
    final item = c.item;
    if (c.kind == DriveChangeKind.removed) {
      cache.remove(c.itemUuid);
    } else if (item != null) {
      cache.put([item]);
    }
    return c;
  });

  @override
  void dispose() {
    connectivity.removeListener(_onConnectivity);
    cache.dispose();
    super.dispose();
  }
}
