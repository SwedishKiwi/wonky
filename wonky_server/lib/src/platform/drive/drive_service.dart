import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_write_core/wonky_write_core.dart' show Delta, DeltaUtils;

import '../../sheets/spaces/space_copier.dart';
import '../../sheets/spaces/space_service.dart';
import '../../sheets/spaces/spreadsheet_factory.dart';
import '../../sheets/sync/sheets_sync_service.dart';
import '../../sheets/sync/sync_db.dart';
import '../../write/content/write_content.dart';
import '../../write/ot/document_bus.dart';
import '../../write/ot/document_store.dart';
import '../../write/themes/builtin_theme_ids.dart';
import '../activity/activity_service.dart';
import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../common/names.dart';
import '../common/roles.dart';
import '../common/time.dart';
import '../comments/comment_copier.dart';
import '../files/file_service.dart';
import '../sharing/access_service.dart';
import '../sharing/acl_events.dart';
import 'drive_events.dart';
import 'drive_views.dart';
import 'templates/builtin_templates.dart';
import '../cluster/cluster_bus.dart';

/// Wonky Drive (specs/05 §2).
abstract final class DriveService {
  /// Trashed items are deleted after this period (`drive.purgeTrash`).
  static const trashRetention = Duration(days: 30);

  /// Upper bound of candidates loaded for in-memory filtering and sorting.
  static const _maxCandidates = 5000;

  // ------------------------------------------------------------------ read

  static Future<DriveItemView> get(
    Session session,
    Actor actor,
    UuidValue uuid,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    return DriveViews.one(session, actor.userId, item, role: role);
  }

  /// Ancestors of [uuid] visible to the caller, root first.
  static Future<List<DriveItemView>> path(
    Session session,
    Actor actor,
    UuidValue uuid,
  ) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final ancestors = await AccessService.ancestors(session, item);
    final roles = await AccessService.rolesFor(
      session,
      actor.userId,
      ancestors,
    );
    final visible = <DriveItem>[];
    for (final a in ancestors) {
      if (roles[a.id!] == null) break;
      visible.add(a);
    }
    final views = await DriveViews.build(
      session,
      actor.userId,
      visible,
      roles: roles,
    );
    return views.reversed.toList();
  }

  static Future<DriveListPage> list(
    Session session,
    Actor actor, {
    UuidValue? folderUuid,
    required DriveListFilter filter,
    required DriveSort sort,
    String? cursor,
    int limit = 100,
  }) async {
    final me = actor.userId;
    var candidates = <DriveItem>[];
    Map<int, DriveItemUserState> states = {};

    Future<void> loadStates(
      Expression<dynamic> Function(DriveItemUserStateTable t) where,
    ) async {
      final rows = await DriveItemUserState.db.find(
        session,
        where: (t) => t.userId.equals(me) & where(t),
        limit: _maxCandidates,
      );
      states = {for (final s in rows) s.itemId: s};
      if (states.isEmpty) return;
      candidates = await DriveItem.db.find(
        session,
        where: (t) =>
            t.id.inSet(states.keys.toSet()) & t.trashedAt.equals(null),
      );
    }

    switch (filter.view) {
      case DriveView.folder:
        if (folderUuid == null) {
          candidates = await DriveItem.db.find(
            session,
            where: (t) =>
                t.ownerId.equals(me) &
                t.parentId.equals(null) &
                t.trashedAt.equals(null),
            limit: _maxCandidates,
          );
          final shortcuts = await DriveItemUserState.db.find(
            session,
            where: (t) => t.userId.equals(me) & t.shortcutParentId.equals(0),
          );
          if (shortcuts.isNotEmpty) {
            candidates.addAll(
              await DriveItem.db.find(
                session,
                where: (t) =>
                    t.id.inSet({for (final s in shortcuts) s.itemId}) &
                    t.trashedAt.equals(null),
              ),
            );
          }
        } else {
          final (folder, _) = await AccessService.require(
            session,
            actor,
            folderUuid,
            Role.viewer,
          );
          if (folder.kind != DriveItemKind.folder) {
            throw Errors.invalid('The item is not a folder.');
          }
          candidates = await DriveItem.db.find(
            session,
            where: (t) =>
                t.parentId.equals(folder.id!) & t.trashedAt.equals(null),
            limit: _maxCandidates,
          );
          final shortcuts = await DriveItemUserState.db.find(
            session,
            where: (t) =>
                t.userId.equals(me) & t.shortcutParentId.equals(folder.id!),
          );
          if (shortcuts.isNotEmpty) {
            candidates.addAll(
              await DriveItem.db.find(
                session,
                where: (t) =>
                    t.id.inSet({for (final s in shortcuts) s.itemId}) &
                    t.trashedAt.equals(null),
              ),
            );
          }
        }
      case DriveView.sharedWithMe:
        final grants = await DriveItemPermission.db.find(
          session,
          where: (t) => t.userId.equals(me) & t.inheritedFromId.equals(null),
          limit: _maxCandidates,
        );
        final linkStates = await DriveItemUserState.db.find(
          session,
          where: (t) => t.userId.equals(me) & t.viaLink.equals(true),
          limit: _maxCandidates,
        );
        final ids = {
          for (final g in grants) g.itemId,
          for (final s in linkStates) s.itemId,
        };
        if (ids.isNotEmpty) {
          candidates = await DriveItem.db.find(
            session,
            where: (t) =>
                t.id.inSet(ids) &
                t.ownerId.notEquals(me) &
                t.trashedAt.equals(null),
          );
        }
      case DriveView.starred:
        await loadStates((t) => t.starred.equals(true));
      case DriveView.recent:
        await loadStates((t) => t.lastOpenedAt.notEquals(null));
      case DriveView.offline:
        await loadStates((t) => t.pinnedOffline.equals(true));
      case DriveView.trash:
        final trashed = await DriveItem.db.find(
          session,
          where: (t) => t.ownerId.equals(me) & t.trashedAt.notEquals(null),
          limit: _maxCandidates,
        );
        final byId = {for (final i in trashed) i.id!: i};
        // Only the top of each trashed subtree.
        final parentIds = {for (final i in trashed) ?i.parentId};
        final parents = parentIds.isEmpty
            ? <DriveItem>[]
            : await DriveItem.db.find(
                session,
                where: (t) => t.id.inSet(parentIds),
              );
        final parentById = {for (final p in parents) p.id!: p};
        candidates = [
          for (final i in trashed)
            if (i.parentId == null ||
                byId[i.parentId] == null &&
                    parentById[i.parentId]?.trashedAt != i.trashedAt ||
                byId[i.parentId] != null &&
                    byId[i.parentId]!.trashedAt != i.trashedAt)
              i,
        ];
    }

    candidates = _applyFilters(candidates, filter.kinds, filter.owner, me);
    final roles = await AccessService.rolesFor(session, me, candidates);
    candidates = [
      for (final c in candidates)
        if (roles[c.id!] != null) c,
    ];
    if (states.isEmpty && candidates.isNotEmpty) {
      final rows = await DriveItemUserState.db.find(
        session,
        where: (t) =>
            t.userId.equals(me) &
            t.itemId.inSet({for (final c in candidates) c.id!}),
      );
      states = {for (final s in rows) s.itemId: s};
    }
    final effectiveSort = filter.view == DriveView.recent
        ? DriveSort(
            field: DriveSortField.lastOpenedByMe,
            descending: true,
            foldersFirst: false,
          )
        : sort;
    _sort(candidates, effectiveSort, states);
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final pageSize = limit.clamp(1, 500);
    final page = candidates.skip(offset).take(pageSize).toList();
    final views = await DriveViews.build(session, me, page, roles: roles);
    final next = offset + page.length;
    return DriveListPage(
      items: views,
      nextCursor: next < candidates.length ? '$next' : null,
    );
  }

  static List<DriveItem> _applyFilters(
    List<DriveItem> items,
    List<DriveItemKind>? kinds,
    DriveOwnerFilter owner,
    int me,
  ) {
    final seen = <int>{};
    return [
      for (final i in items)
        if (seen.add(i.id!) &&
            (kinds == null || kinds.isEmpty || kinds.contains(i.kind)) &&
            switch (owner) {
              DriveOwnerFilter.anyone => true,
              DriveOwnerFilter.me => i.ownerId == me,
              DriveOwnerFilter.notMe => i.ownerId != me,
            })
          i,
    ];
  }

  static void _sort(
    List<DriveItem> items,
    DriveSort sort,
    Map<int, DriveItemUserState> states,
  ) {
    int compare(DriveItem a, DriveItem b) {
      if (sort.foldersFirst) {
        final fa = a.kind == DriveItemKind.folder ? 0 : 1;
        final fb = b.kind == DriveItemKind.folder ? 0 : 1;
        if (fa != fb) return fa - fb;
      }
      int c;
      switch (sort.field) {
        case DriveSortField.name:
          c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case DriveSortField.modifiedAt:
          c = a.modifiedAt.compareTo(b.modifiedAt);
        case DriveSortField.createdAt:
          c = a.createdAt.compareTo(b.createdAt);
        case DriveSortField.size:
          c = a.sizeBytes.compareTo(b.sizeBytes);
        case DriveSortField.lastOpenedByMe:
          c = _cmpDate(states[a.id]?.lastOpenedAt, states[b.id]?.lastOpenedAt);
        case DriveSortField.lastModifiedByMe:
          c = _cmpDate(states[a.id]?.lastEditedAt, states[b.id]?.lastEditedAt);
      }
      if (sort.descending) c = -c;
      return c != 0 ? c : a.id!.compareTo(b.id!);
    }

    items.sort(compare);
  }

  static int _cmpDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  /// Full-text search over name, description and extracted content of the
  /// items the caller can access (Postgres `simple` text search with prefix
  /// matching, plus substring matching on names).
  static Future<DriveListPage> search(
    Session session,
    Actor actor,
    String query, {
    required DriveSearchFilters filters,
    String? cursor,
    int limit = 50,
  }) async {
    final terms = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(query.toLowerCase()).map((m) => m[0]!).take(8).toList();
    if (terms.isEmpty) return DriveListPage(items: const []);
    final tsQuery = terms.map((t) => '$t:*').join(' & ');
    final like =
        '%${query.trim().replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final pageSize = limit.clamp(1, 200);
    const doc =
        "to_tsvector('simple', coalesce(d.name, '') || ' ' || coalesce(d.description, '') || ' ' || coalesce(d.\"searchText\", ''))";
    final result = await session.db.unsafeQuery(
      '''
      SELECT d.id FROM drive_item d
      WHERE d."trashedAt" IS NULL AND (
        d."ownerId" = @me
        OR EXISTS (SELECT 1 FROM drive_item_permission p
                   WHERE p."itemId" = d.id AND p."userId" = @me
                   AND (p."expiresAt" IS NULL OR p."expiresAt" > now()))
        OR EXISTS (SELECT 1 FROM drive_item_user_state s
                   JOIN share_link l ON l."itemId" = s."itemId"
                   WHERE s."itemId" = d.id AND s."userId" = @me AND l.role IS NOT NULL)
      ) AND (
        $doc @@ to_tsquery('simple', @q) OR d.name ILIKE @like
      )
      ORDER BY ts_rank($doc, to_tsquery('simple', @q)) DESC, d."modifiedAt" DESC
      LIMIT @limit OFFSET @offset
      ''',
      parameters: QueryParameters.named({
        'me': actor.userId,
        'q': tsQuery,
        'like': like,
        'limit': _maxCandidates,
        'offset': 0,
      }),
    );
    final ids = [for (final row in result) row[0] as int];
    if (ids.isEmpty) return DriveListPage(items: const []);
    final items = await DriveItem.db.find(
      session,
      where: (t) => t.id.inSet(ids.toSet()),
    );
    final byId = {for (final i in items) i.id!: i};
    var ordered = [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
    ordered = _applyFilters(ordered, filters.kinds, filters.owner, actor.userId)
        .where(
          (i) =>
              (filters.modifiedAfter == null ||
                  i.modifiedAt.isAfter(filters.modifiedAfter!)) &&
              (filters.modifiedBefore == null ||
                  i.modifiedAt.isBefore(filters.modifiedBefore!)),
        )
        .toList();
    final roles = await AccessService.rolesFor(session, actor.userId, ordered);
    var views = await DriveViews.build(
      session,
      actor.userId,
      ordered,
      roles: roles,
    );
    if (filters.sharedOnly) {
      views = views
          .where((v) => v.shared || v.owner.id != actor.userId)
          .toList();
    }
    final page = views.skip(offset).take(pageSize).toList();
    final next = offset + page.length;
    return DriveListPage(
      items: page,
      nextCursor: next < views.length ? '$next' : null,
    );
  }

  // ---------------------------------------------------------------- create

  /// Resolves the parent folder for a new item. Null = the caller's root.
  static Future<DriveItem?> _parentFor(
    Session session,
    Actor actor,
    UuidValue? parentUuid, {
    Transaction? transaction,
  }) async {
    if (parentUuid == null) return null;
    final (parent, _) = await AccessService.require(
      session,
      actor,
      parentUuid,
      Role.editor,
      transaction: transaction,
    );
    if (parent.kind != DriveItemKind.folder) {
      throw Errors.invalid('Items can only be created in folders.');
    }
    if (parent.trashedAt != null) {
      throw Errors.invalid('The folder is in the trash.');
    }
    return parent;
  }

  static Future<DriveItem> _insertItem(
    Session session,
    Actor actor, {
    required DriveItemKind kind,
    required String name,
    DriveItem? parent,
    UuidValue? uuid,
    UuidValue? contentRef,
    String? description,
    Transaction? transaction,
  }) async {
    final now = nowUtc();
    final item = await DriveItem.db.insertRow(
      session,
      DriveItem(
        // Spreadsheet items share the UUID of their space (Sheets 02 §3.1),
        // so a spreadsheet created offline opens at `/s/<space>` before
        // `registerSpreadsheet` reached the server.
        uuid:
            uuid ??
            (kind == DriveItemKind.spreadsheet ? contentRef : null) ??
            const Uuid().v7obj(),
        kind: kind,
        name: normalizeItemName(name),
        ownerId: actor.userId,
        parentId: parent?.id,
        description: description,
        contentRef: contentRef,
        createdAt: now,
        createdById: actor.userId,
        modifiedAt: now,
        modifiedById: actor.userId,
      ),
      transaction: transaction,
    );
    await DriveItemUserState.db.insertRow(
      session,
      DriveItemUserState(
        itemId: item.id!,
        userId: actor.userId,
        lastOpenedAt: now,
        lastEditedAt: now,
      ),
      transaction: transaction,
    );
    if (parent != null) {
      await AccessService.rebuildInherited(
        session,
        item,
        transaction: transaction,
      );
    }
    return item;
  }

  static Future<void> _afterCreate(
    Session session,
    Actor actor,
    DriveItem item, {
    Map<String, Object?> summary = const {},
  }) async {
    await ActivityService.log(
      session,
      item.id!,
      actor,
      ActivityType.created,
      summary: summary,
    );
    await DriveEvents.notify(session, item, DriveChangeKind.created);
  }

  static Future<DriveItemView> createFolder(
    Session session,
    Actor actor, {
    UuidValue? parentUuid,
    required String name,
  }) async {
    final item = await session.db.transaction((tx) async {
      final parent = await _parentFor(
        session,
        actor,
        parentUuid,
        transaction: tx,
      );
      return _insertItem(
        session,
        actor,
        kind: DriveItemKind.folder,
        name: name,
        parent: parent,
        transaction: tx,
      );
    });
    await _afterCreate(session, actor, item);
    return DriveViews.one(session, actor.userId, item, role: Role.owner);
  }

  /// Creates a document. [documentUuid] and [itemUuid] may be generated by
  /// the client for offline creation; the call is idempotent on them.
  static Future<DriveItemView> createDocument(
    Session session,
    Actor actor, {
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String? initialMarkdown,
    UuidValue? documentUuid,
    UuidValue? itemUuid,
  }) async {
    if (documentUuid != null) {
      final existing = await DocumentStore.byUuid(session, documentUuid);
      if (existing != null) {
        final item = await DriveItem.db.findById(session, existing.itemId);
        if (item != null) return get(session, actor, item.uuid);
      }
    }
    if (itemUuid != null) {
      final existing = await AccessService.findItem(session, itemUuid);
      if (existing != null) return get(session, actor, itemUuid);
    }
    Delta? content;
    UuidValue? themeId;
    var pageSetup = '{}';
    String? frontMatter;
    String? language;
    var activitySummary = <String, Object?>{};
    if (templateUuid != null) {
      final builtin = BuiltinTemplates.byUuid(templateUuid);
      if (builtin != null) {
        if (builtin.kind != DriveItemKind.document) {
          throw Errors.invalid('This is not a document template.');
        }
        content = WriteContent.fromMarkdown(builtin.markdown!).delta;
        if (builtin.themeKey case final key?) {
          themeId = BuiltinThemeIds.forKey(key);
        }
        activitySummary = {'template': builtin.key};
      } else {
        final (tplItem, _) = await AccessService.require(
          session,
          actor,
          templateUuid,
          Role.viewer,
        );
        if (tplItem.kind != DriveItemKind.document) {
          throw Errors.invalid('This is not a document template.');
        }
        final tplDoc = await DocumentStore.requireByItem(session, tplItem.id!);
        content = DeltaUtils.stripOverlays(
          await DocumentStore.head(session, tplDoc),
        );
        themeId = tplDoc.themeId;
        pageSetup = tplDoc.pageSetupJson;
        frontMatter = tplDoc.frontMatter;
        language = tplDoc.language;
        activitySummary = {'template': tplItem.uuid.uuid};
      }
    } else if (initialMarkdown != null && initialMarkdown.isNotEmpty) {
      content = WriteContent.fromMarkdown(initialMarkdown).delta;
    }
    final docUuid = documentUuid ?? const Uuid().v7obj();
    final item = await session.db.transaction((tx) async {
      final parent = await _parentFor(
        session,
        actor,
        parentUuid,
        transaction: tx,
      );
      final item = await _insertItem(
        session,
        actor,
        kind: DriveItemKind.document,
        name: name,
        parent: parent,
        uuid: itemUuid,
        contentRef: docUuid,
        transaction: tx,
      );
      await DocumentStore.create(
        session,
        item: item,
        documentUuid: docUuid,
        actor: actor,
        initial: content,
        kind: DocumentOpKind.content,
        themeId: themeId,
        pageSetupJson: pageSetup,
        frontMatter: frontMatter,
        language: language,
        transaction: tx,
      );
      if (content != null) {
        await DriveItem.db.updateRow(
          session,
          item.copyWith(
            searchText: DocumentStore.searchText(content),
            sizeBytes: utf8.encode(DeltaUtils.text(content)).length,
          ),
          columns: (t) => [t.searchText, t.sizeBytes],
          transaction: tx,
        );
      }
      return item;
    });
    await _afterCreate(session, actor, item, summary: activitySummary);
    return DriveViews.one(session, actor.userId, item, role: Role.owner);
  }

  /// Registers a spreadsheet created locally in a reserved space
  /// (idempotent, works for queued offline creations).
  static Future<DriveItemView> registerSpreadsheet(
    Session session,
    Actor actor, {
    required UuidValue spaceUuid,
    UuidValue? parentUuid,
    required String name,
  }) async {
    final existing = await DriveItem.db.findFirstRow(
      session,
      where: (t) =>
          t.contentRef.equals(spaceUuid) &
          t.kind.equals(DriveItemKind.spreadsheet),
    );
    if (existing != null) return get(session, actor, existing.uuid);
    final reserved = await SpaceService.useReservation(
      session,
      actor,
      spaceUuid,
    );
    if (!reserved) {
      final role = await session.offlineSync.spaces.roleOf(
        user: actor.authUserId,
        space: spaceUuid,
      );
      if (role != OfflineSyncSpaceRole.readWrite) {
        throw Errors.forbidden('This space is not reserved for you.');
      }
    }
    final item = await session.db.transaction((tx) async {
      DriveItem? parent;
      try {
        parent = await _parentFor(session, actor, parentUuid, transaction: tx);
      } on WonkyException {
        // The folder was deleted or unshared while offline: use the root.
        parent = null;
      }
      final item = await _insertItem(
        session,
        actor,
        kind: DriveItemKind.spreadsheet,
        name: name,
        parent: parent,
        contentRef: spaceUuid,
        transaction: tx,
      );
      await SpaceService.touchSubscription(
        session,
        actor.userId,
        item,
        transaction: tx,
      );
      return item;
    });
    await _afterCreate(session, actor, item);
    // Change log rows that synced before the registration.
    await SheetsSyncService.afterRegistration(session, spaceUuid);
    return DriveViews.one(session, actor.userId, item, role: Role.owner);
  }

  /// Creates a spreadsheet server-side (online; MCP, templates, welcome).
  static Future<DriveItemView> createSpreadsheet(
    Session session,
    Actor actor, {
    UuidValue? parentUuid,
    required String name,
    UuidValue? templateUuid,
    String locale = 'en_US',
    String timeZone = 'UTC',
  }) async {
    final cleanName = normalizeItemName(name);
    BuiltinTemplate? builtin;
    DriveItem? templateItem;
    if (templateUuid != null) {
      builtin = BuiltinTemplates.byUuid(templateUuid);
      if (builtin == null) {
        final (tpl, _) = await AccessService.require(
          session,
          actor,
          templateUuid,
          Role.viewer,
        );
        templateItem = tpl;
      }
      if ((builtin?.kind ?? templateItem!.kind) != DriveItemKind.spreadsheet) {
        throw Errors.invalid('This is not a spreadsheet template.');
      }
    }
    // Validate the parent before creating a space.
    await _parentFor(session, actor, parentUuid);
    final UuidValue space;
    if (templateItem != null) {
      space = await session.offlineSync.spaces.createFor(actor.authUserId);
      await SpaceCopier.copy(
        session,
        fromSpace: templateItem.contentRef!,
        toSpace: space,
        authorUuid: actor.authUserId,
        title: cleanName,
      );
    } else {
      space = await session.offlineSync.spaces.createFor(actor.authUserId);
      await SpreadsheetFactory.write(
        session,
        spaceUuid: space,
        authorUuid: actor.authUserId,
        title: cleanName,
        locale: locale,
        timeZone: timeZone,
        sheets: builtin?.sheets ?? const [],
      );
    }
    final item = await session.db.transaction((tx) async {
      final parent = await _parentFor(
        session,
        actor,
        parentUuid,
        transaction: tx,
      );
      final item = await _insertItem(
        session,
        actor,
        kind: DriveItemKind.spreadsheet,
        name: cleanName,
        parent: parent,
        contentRef: space,
        transaction: tx,
      );
      await SpaceService.touchSubscription(
        session,
        actor.userId,
        item,
        transaction: tx,
      );
      return item;
    });
    await _afterCreate(
      session,
      actor,
      item,
      summary: {
        if (builtin != null) 'template': builtin.key,
        if (templateItem != null) 'template': templateItem.uuid.uuid,
      },
    );
    return DriveViews.one(session, actor.userId, item, role: Role.owner);
  }

  /// Creates a spreadsheet from [sheets] (imports).
  static Future<DriveItemView> createSpreadsheetFromSheets(
    Session session,
    Actor actor, {
    required String name,
    UuidValue? parentUuid,
    required List<TemplateSheet> sheets,
    Map<String, Object?> summary = const {},
  }) async {
    final cleanName = normalizeItemName(name);
    await _parentFor(session, actor, parentUuid);
    final space = await session.offlineSync.spaces.createFor(actor.authUserId);
    await SpreadsheetFactory.write(
      session,
      spaceUuid: space,
      authorUuid: actor.authUserId,
      title: cleanName,
      sheets: sheets,
    );
    final item = await session.db.transaction((tx) async {
      final parent = await _parentFor(
        session,
        actor,
        parentUuid,
        transaction: tx,
      );
      final item = await _insertItem(
        session,
        actor,
        kind: DriveItemKind.spreadsheet,
        name: cleanName,
        parent: parent,
        contentRef: space,
        transaction: tx,
      );
      await SpaceService.touchSubscription(
        session,
        actor.userId,
        item,
        transaction: tx,
      );
      return item;
    });
    await _afterCreate(session, actor, item, summary: summary);
    return DriveViews.one(session, actor.userId, item, role: Role.owner);
  }

  // ---------------------------------------------------------------- update

  static Future<DriveItemView> rename(
    Session session,
    Actor actor,
    UuidValue uuid,
    String name,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.editor,
    );
    final clean = normalizeItemName(name);
    if (clean == item.name) {
      return DriveViews.one(session, actor.userId, item, role: role);
    }
    final updated = await DriveItem.db.updateRow(
      session,
      item.copyWith(name: clean),
      columns: (t) => [t.name],
    );
    await ActivityService.log(
      session,
      item.id!,
      actor,
      ActivityType.renamed,
      summary: {'from': item.name, 'to': clean},
    );
    if (item.kind == DriveItemKind.document && item.contentRef != null) {
      await DocumentBus.metaChanged(
        session,
        item.contentRef!,
        DocMetaChanged(
          field: 'title',
          valueJson: jsonEncode(clean),
          authorId: actor.userId,
        ),
      );
    }
    if (item.kind == DriveItemKind.spreadsheet && item.contentRef != null) {
      await _mirrorTitleToSpreadsheet(session, actor, updated);
    }
    await DriveEvents.notify(session, updated, DriveChangeKind.updated);
    return DriveViews.one(session, actor.userId, updated, role: role);
  }

  /// Writes a drive rename into the synced Spreadsheet.title (best effort:
  /// needs write membership, which editors get on demand).
  static Future<void> _mirrorTitleToSpreadsheet(
    Session session,
    Actor actor,
    DriveItem item,
  ) async {
    try {
      final db = syncSessionOf(session);
      final sheet = await Spreadsheet.db.findById(db, item.contentRef!);
      if (sheet == null || sheet.title == item.name) return;
      await SpaceService.ensureWriter(
        session,
        actor,
        item,
        reason: SubscriptionReason.recent,
      );
      await db.offlineSyncDb.transactionForUser(
        actor.authUserId,
        (tx) => Spreadsheet.db.updateById(
          db,
          item.contentRef!,
          columnValues: (t) => [t.title(item.name)],
          transaction: tx,
        ),
        spaceId: item.contentRef!,
      );
    } on Exception catch (e) {
      session.log(
        'Could not mirror the title of ${item.uuid} to its spreadsheet: $e',
        level: LogLevel.warning,
      );
    }
  }

  static Future<DriveItemView> updateDescription(
    Session session,
    Actor actor,
    UuidValue uuid,
    String? description,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.editor,
    );
    final clean = description?.trim();
    if (clean != null && clean.length > 5000) {
      throw Errors.invalid('The description is too long.');
    }
    final updated = await DriveItem.db.updateRow(
      session,
      DriveItem(
        id: item.id,
        uuid: item.uuid,
        kind: item.kind,
        name: item.name,
        ownerId: item.ownerId,
        parentId: item.parentId,
        description: clean == null || clean.isEmpty ? null : clean,
        contentRef: item.contentRef,
        thumbnailFileId: item.thumbnailFileId,
        sizeBytes: item.sizeBytes,
        createdAt: item.createdAt,
        createdById: item.createdById,
        modifiedAt: item.modifiedAt,
        modifiedById: item.modifiedById,
        trashedAt: item.trashedAt,
        trashedById: item.trashedById,
        templateOf: item.templateOf,
        templateKey: item.templateKey,
        editorsCanShare: item.editorsCanShare,
        nonEditorsCanExport: item.nonEditorsCanExport,
        viewersSeeComments: item.viewersSeeComments,
        searchText: item.searchText,
      ),
      columns: (t) => [t.description],
    );
    await DriveEvents.notify(session, updated, DriveChangeKind.updated);
    return DriveViews.one(session, actor.userId, updated, role: role);
  }

  /// Moves items into [newParentUuid] (null = the caller's root, owners
  /// only). Requires Editor on the items and the target; cycles are refused.
  static Future<List<DriveItemView>> move(
    Session session,
    Actor actor,
    List<UuidValue> uuids,
    UuidValue? newParentUuid,
  ) async {
    DriveItem? target;
    if (newParentUuid != null) {
      final (t, _) = await AccessService.require(
        session,
        actor,
        newParentUuid,
        Role.editor,
      );
      if (t.kind != DriveItemKind.folder) {
        throw Errors.invalid('Items can only be moved into folders.');
      }
      if (t.trashedAt != null) {
        throw Errors.invalid('The folder is in the trash.');
      }
      target = t;
    }
    final moved = <DriveItem>[];
    for (final uuid in uuids.toSet()) {
      final (item, _) = await AccessService.require(
        session,
        actor,
        uuid,
        Role.editor,
      );
      if (target == null && item.ownerId != actor.userId) {
        throw Errors.forbidden(
          'Only the owner can move an item to My Drive. Add a shortcut instead.',
        );
      }
      if (target != null) {
        if (target.id == item.id) {
          throw WonkyException(
            code: WonkyErrorCode.cycle,
            message: 'A folder cannot be moved into itself.',
          );
        }
        final chain = await AccessService.ancestors(session, target);
        if (chain.any((a) => a.id == item.id)) {
          throw WonkyException(
            code: WonkyErrorCode.cycle,
            message: 'A folder cannot be moved into one of its subfolders.',
          );
        }
      }
      if (item.parentId == target?.id) continue;
      final before = await _subtreeUsers(session, item);
      final updated = await session.db.transaction((tx) async {
        final row = DriveItem.db.updateRow(
          session,
          _withParent(item, target?.id),
          columns: (t) => [t.parentId],
          transaction: tx,
        );
        final updated = await row;
        await AccessService.rebuildInherited(session, updated, transaction: tx);
        return updated;
      });
      await ActivityService.log(
        session,
        item.id!,
        actor,
        ActivityType.moved,
        summary: {'to': target?.uuid.uuid, 'toName': target?.name},
      );
      await AclEvents.changed(
        session,
        updated,
        affectedUsers: before,
        kind: DriveChangeKind.moved,
      );
      moved.add(updated);
    }
    return DriveViews.build(session, actor.userId, moved);
  }

  static Future<Set<int>> _subtreeUsers(Session session, DriveItem item) async {
    final users = <int>{};
    for (final node in await AccessService.subtree(session, item)) {
      users.addAll(await AccessService.interestedUsers(session, node));
    }
    return users;
  }

  static DriveItem _withParent(DriveItem item, int? parentId) => DriveItem(
    id: item.id,
    uuid: item.uuid,
    kind: item.kind,
    name: item.name,
    ownerId: item.ownerId,
    parentId: parentId,
    description: item.description,
    contentRef: item.contentRef,
    thumbnailFileId: item.thumbnailFileId,
    sizeBytes: item.sizeBytes,
    createdAt: item.createdAt,
    createdById: item.createdById,
    modifiedAt: item.modifiedAt,
    modifiedById: item.modifiedById,
    trashedAt: item.trashedAt,
    trashedById: item.trashedById,
    templateOf: item.templateOf,
    templateKey: item.templateKey,
    editorsCanShare: item.editorsCanShare,
    nonEditorsCanExport: item.nonEditorsCanExport,
    viewersSeeComments: item.viewersSeeComments,
    searchText: item.searchText,
  );

  /// Copies a document or spreadsheet ("Make a copy").
  static Future<DriveItemView> copy(
    Session session,
    Actor actor,
    UuidValue uuid, {
    required String newName,
    UuidValue? parentUuid,
    bool copyComments = false,
    bool copySharing = false,
  }) async {
    final (source, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    if (role < Role.editor && !source.nonEditorsCanExport) {
      throw Errors.forbidden('The owner has disabled copying for viewers.');
    }
    final DriveItemView copyView;
    switch (source.kind) {
      case DriveItemKind.folder:
        throw Errors.invalid('Folders cannot be copied.');
      case DriveItemKind.document:
        final sourceDoc = await DocumentStore.requireByItem(
          session,
          source.id!,
        );
        var content = await DocumentStore.head(session, sourceDoc);
        final threadMap = copyComments
            ? await CommentCopier.newThreadUuids(session, source)
            : <String, String>{};
        content = copyComments
            ? CommentCopier.rewriteAnchors(content, threadMap)
            : DeltaUtils.stripComments(content);
        final docUuid = const Uuid().v7obj();
        final item = await session.db.transaction((tx) async {
          final parent = await _parentFor(
            session,
            actor,
            parentUuid ?? await _defaultCopyParent(session, actor, source),
            transaction: tx,
          );
          final item = await _insertItem(
            session,
            actor,
            kind: DriveItemKind.document,
            name: newName,
            parent: parent,
            contentRef: docUuid,
            description: source.description,
            transaction: tx,
          );
          await DocumentStore.create(
            session,
            item: item,
            documentUuid: docUuid,
            actor: actor,
            initial: content,
            kind: DocumentOpKind.content,
            themeId: sourceDoc.themeId,
            pageSetupJson: sourceDoc.pageSetupJson,
            language: sourceDoc.language,
            frontMatter: sourceDoc.frontMatter,
            transaction: tx,
          );
          await DriveItem.db.updateRow(
            session,
            item.copyWith(
              searchText: source.searchText,
              sizeBytes: source.sizeBytes,
            ),
            columns: (t) => [t.searchText, t.sizeBytes],
            transaction: tx,
          );
          if (copyComments) {
            await CommentCopier.copyThreads(
              session,
              from: source,
              to: item,
              threadMap: threadMap,
              transaction: tx,
            );
          }
          return item;
        });
        copyView = await _finishCopy(session, actor, source, item, copySharing);
      case DriveItemKind.spreadsheet:
        final space = await session.offlineSync.spaces.createFor(
          actor.authUserId,
        );
        final idMap = await SpaceCopier.copy(
          session,
          fromSpace: source.contentRef!,
          toSpace: space,
          authorUuid: actor.authUserId,
          title: normalizeItemName(newName),
        );
        final item = await session.db.transaction((tx) async {
          final parent = await _parentFor(
            session,
            actor,
            parentUuid ?? await _defaultCopyParent(session, actor, source),
            transaction: tx,
          );
          final item = await _insertItem(
            session,
            actor,
            kind: DriveItemKind.spreadsheet,
            name: newName,
            parent: parent,
            contentRef: space,
            description: source.description,
            transaction: tx,
          );
          await SpaceService.touchSubscription(
            session,
            actor.userId,
            item,
            transaction: tx,
          );
          if (copyComments) {
            await CommentCopier.copyThreads(
              session,
              from: source,
              to: item,
              anchorIdMap: idMap,
              transaction: tx,
            );
          }
          return item;
        });
        copyView = await _finishCopy(session, actor, source, item, copySharing);
    }
    return copyView;
  }

  /// Creates a document with [content] (version copies, imports), taking
  /// theme and page setup from [source] when given.
  static Future<DriveItemView> createDocumentFromContent(
    Session session,
    Actor actor, {
    required String name,
    UuidValue? parentUuid,
    required Delta content,
    Document? source,
    String? frontMatter,
    Map<String, Object?> activitySummary = const {},
  }) async {
    final docUuid = const Uuid().v7obj();
    final item = await session.db.transaction((tx) async {
      final parent = await _parentFor(
        session,
        actor,
        parentUuid,
        transaction: tx,
      );
      final item = await _insertItem(
        session,
        actor,
        kind: DriveItemKind.document,
        name: name,
        parent: parent,
        contentRef: docUuid,
        transaction: tx,
      );
      await DocumentStore.create(
        session,
        item: item,
        documentUuid: docUuid,
        actor: actor,
        initial: content,
        kind: DocumentOpKind.imported,
        themeId: source?.themeId,
        pageSetupJson: source?.pageSetupJson ?? '{}',
        language: source?.language,
        frontMatter: frontMatter ?? source?.frontMatter,
        transaction: tx,
      );
      await DriveItem.db.updateRow(
        session,
        item.copyWith(
          searchText: DocumentStore.searchText(content),
          sizeBytes: utf8.encode(DeltaUtils.text(content)).length,
        ),
        columns: (t) => [t.searchText, t.sizeBytes],
        transaction: tx,
      );
      return item;
    });
    await _afterCreate(session, actor, item, summary: activitySummary);
    return DriveViews.one(session, actor.userId, item, role: Role.owner);
  }

  static Future<UuidValue?> _defaultCopyParent(
    Session session,
    Actor actor,
    DriveItem source,
  ) async {
    if (source.parentId == null) return null;
    final parent = await DriveItem.db.findById(session, source.parentId!);
    if (parent == null) return null;
    final role = await AccessService.effectiveRole(
      session,
      actor.userId,
      parent,
    );
    return role != null && role >= Role.editor ? parent.uuid : null;
  }

  static Future<DriveItemView> _finishCopy(
    Session session,
    Actor actor,
    DriveItem source,
    DriveItem copy,
    bool copySharing,
  ) async {
    if (copySharing) {
      final grants = await DriveItemPermission.db.find(
        session,
        where: (t) =>
            t.itemId.equals(source.id!) & t.inheritedFromId.equals(null),
      );
      final now = nowUtc();
      final rows = [
        for (final g in grants)
          if (g.userId != actor.userId)
            DriveItemPermission(
              itemId: copy.id!,
              userId: g.userId,
              invitedEmail: g.invitedEmail,
              role: g.role,
              grantedById: actor.userId,
              grantedAt: now,
              expiresAt: g.expiresAt,
            ),
        if (source.ownerId != actor.userId &&
            !grants.any((g) => g.userId == source.ownerId))
          DriveItemPermission(
            itemId: copy.id!,
            userId: source.ownerId,
            role: AccessRole.editor,
            grantedById: actor.userId,
            grantedAt: now,
          ),
      ];
      if (rows.isNotEmpty) {
        await DriveItemPermission.db.insert(session, rows);
      }
      await AclEvents.changed(session, copy);
    }
    await _afterCreate(
      session,
      actor,
      copy,
      summary: {'copiedFrom': source.uuid.uuid, 'copiedFromName': source.name},
    );
    return DriveViews.one(session, actor.userId, copy, role: Role.owner);
  }

  // ------------------------------------------------------------ user state

  static Future<DriveItemUserState> _state(
    Session session,
    int userId,
    DriveItem item,
  ) async {
    final existing = await DriveItemUserState.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(item.id!) & t.userId.equals(userId),
    );
    if (existing != null) return existing;
    try {
      return await DriveItemUserState.db.insertRow(
        session,
        DriveItemUserState(itemId: item.id!, userId: userId),
      );
    } on DatabaseException {
      return (await DriveItemUserState.db.findFirstRow(
        session,
        where: (t) => t.itemId.equals(item.id!) & t.userId.equals(userId),
      ))!;
    }
  }

  static Future<DriveItemView> setStarred(
    Session session,
    Actor actor,
    UuidValue uuid,
    bool starred,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final state = await _state(session, actor.userId, item);
    await DriveItemUserState.db.updateRow(
      session,
      state.copyWith(starred: starred),
      columns: (t) => [t.starred],
    );
    await ClusterBus.post(
      session,
      DriveEvents.channel(actor.userId),
      DriveChangeSignal(kind: DriveChangeKind.updated, itemUuid: item.uuid),
    );
    return DriveViews.one(session, actor.userId, item, role: role);
  }

  static Future<DriveItemView> setPinnedOffline(
    Session session,
    Actor actor,
    UuidValue uuid,
    bool pinned,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final state = await _state(session, actor.userId, item);
    await DriveItemUserState.db.updateRow(
      session,
      state.copyWith(pinnedOffline: pinned),
      columns: (t) => [t.pinnedOffline],
    );
    await SpaceService.setPinned(session, actor, item, pinned);
    await ClusterBus.post(
      session,
      DriveEvents.channel(actor.userId),
      DriveChangeSignal(kind: DriveChangeKind.updated, itemUuid: item.uuid),
    );
    return DriveViews.one(session, actor.userId, item, role: role);
  }

  /// Records that the caller opened [uuid]. A first open through link
  /// sharing adds the item to "Shared with me" (specs/06 §2.2).
  static Future<DriveItemView> markOpened(
    Session session,
    Actor actor,
    UuidValue uuid,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    await recordOpen(session, actor, item, role);
    return DriveViews.one(session, actor.userId, item, role: role);
  }

  static Future<void> recordOpen(
    Session session,
    Actor actor,
    DriveItem item,
    Role role,
  ) async {
    final state = await _state(session, actor.userId, item);
    var viaLink = state.viaLink;
    if (!viaLink && item.ownerId != actor.userId) {
      final grant = await DriveItemPermission.db.findFirstRow(
        session,
        where: (t) => t.itemId.equals(item.id!) & t.userId.equals(actor.userId),
      );
      viaLink = grant == null;
    }
    await DriveItemUserState.db.updateRow(
      session,
      state.copyWith(lastOpenedAt: nowUtc(), viaLink: viaLink),
      columns: (t) => [t.lastOpenedAt, t.viaLink],
    );
    // Activity dashboard view counts (specs/07 §6).
    await ActivityService.recordView(session, item.id!, actor.userId);
  }

  /// Records that the caller edited [item] (for "Last modified by me").
  static Future<void> recordEdit(
    Session session,
    int userId,
    DriveItem item,
  ) async {
    final state = await _state(session, userId, item);
    await DriveItemUserState.db.updateRow(
      session,
      state.copyWith(lastEditedAt: nowUtc()),
      columns: (t) => [t.lastEditedAt],
    );
  }

  /// "Add shortcut to My Drive": shows a shared item in [parentUuid] (null =
  /// the caller's root) without moving it.
  static Future<DriveItemView> addShortcut(
    Session session,
    Actor actor,
    UuidValue uuid,
    UuidValue? parentUuid,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    var parentId = 0;
    if (parentUuid != null) {
      final (parent, _) = await AccessService.require(
        session,
        actor,
        parentUuid,
        Role.editor,
      );
      if (parent.kind != DriveItemKind.folder) {
        throw Errors.invalid('Shortcuts can only be added to folders.');
      }
      parentId = parent.id!;
    }
    final state = await _state(session, actor.userId, item);
    await DriveItemUserState.db.updateRow(
      session,
      state.copyWith(shortcutParentId: parentId),
      columns: (t) => [t.shortcutParentId],
    );
    await ClusterBus.post(
      session,
      DriveEvents.channel(actor.userId),
      DriveChangeSignal(kind: DriveChangeKind.updated, itemUuid: item.uuid),
    );
    return DriveViews.one(session, actor.userId, item, role: role);
  }

  static Future<void> removeShortcut(
    Session session,
    Actor actor,
    UuidValue uuid,
  ) async {
    final item = await AccessService.findItem(session, uuid);
    if (item == null) throw Errors.notFound();
    await DriveItemUserState.db.updateWhere(
      session,
      columnValues: (t) => [t.shortcutParentId(null)],
      where: (t) => t.itemId.equals(item.id!) & t.userId.equals(actor.userId),
    );
    await ClusterBus.post(
      session,
      DriveEvents.channel(actor.userId),
      DriveChangeSignal(kind: DriveChangeKind.updated, itemUuid: item.uuid),
    );
  }

  // ------------------------------------------------------------------ trash

  static Future<void> trash(
    Session session,
    Actor actor,
    List<UuidValue> uuids,
  ) async {
    final now = nowUtc();
    for (final uuid in uuids.toSet()) {
      final (item, _) = await AccessService.require(
        session,
        actor,
        uuid,
        Role.editor,
      );
      if (item.trashedAt != null) continue;
      final nodes = await AccessService.subtree(session, item);
      final ids = {for (final n in nodes) n.id!};
      await DriveItem.db.updateWhere(
        session,
        columnValues: (t) => [t.trashedAt(now), t.trashedById(actor.userId)],
        where: (t) => t.id.inSet(ids) & t.trashedAt.equals(null),
      );
      await ActivityService.log(session, item.id!, actor, ActivityType.trashed);
      final updated = (await DriveItem.db.findById(session, item.id!))!;
      await AclEvents.changed(session, updated, kind: DriveChangeKind.trashed);
    }
  }

  static Future<void> restore(
    Session session,
    Actor actor,
    List<UuidValue> uuids,
  ) async {
    for (final uuid in uuids.toSet()) {
      final (item, _) = await AccessService.require(
        session,
        actor,
        uuid,
        Role.editor,
      );
      final trashedAt = item.trashedAt;
      if (trashedAt == null) continue;
      final nodes = await AccessService.subtree(session, item);
      final ids = {
        for (final n in nodes)
          if (n.trashedAt == trashedAt) n.id!,
      };
      // Restoring into a trashed or missing folder moves the item to the
      // owner's root.
      int? parentId = item.parentId;
      if (parentId != null) {
        final parent = await DriveItem.db.findById(session, parentId);
        if (parent == null || parent.trashedAt != null) parentId = null;
      }
      await DriveItem.db.updateWhere(
        session,
        columnValues: (t) => [t.trashedAt(null), t.trashedById(null)],
        where: (t) => t.id.inSet(ids),
      );
      if (parentId != item.parentId) {
        await DriveItem.db.updateWhere(
          session,
          columnValues: (t) => [t.parentId(null)],
          where: (t) => t.id.equals(item.id!),
        );
      }
      final updated = (await DriveItem.db.findById(session, item.id!))!;
      if (parentId != item.parentId) {
        await AccessService.rebuildInherited(session, updated);
      }
      await ActivityService.log(
        session,
        item.id!,
        actor,
        ActivityType.restored,
      );
      await AclEvents.changed(session, updated, kind: DriveChangeKind.restored);
    }
  }

  /// Deletes trashed items forever (owners only).
  static Future<void> deletePermanently(
    Session session,
    Actor actor,
    List<UuidValue> uuids,
  ) async {
    for (final uuid in uuids.toSet()) {
      final (item, role) = await AccessService.require(
        session,
        actor,
        uuid,
        Role.viewer,
      );
      if (role != Role.owner) {
        throw Errors.forbidden('Only the owner can delete an item forever.');
      }
      if (item.trashedAt == null) {
        throw Errors.invalid('Move the item to the trash first.');
      }
      await purge(session, item);
    }
  }

  static Future<int> emptyTrash(Session session, Actor actor) async {
    final page = await list(
      session,
      actor,
      filter: DriveListFilter(view: DriveView.trash),
      sort: DriveSort(),
      limit: 500,
    );
    var count = 0;
    for (final view in page.items) {
      final item = await AccessService.findItem(session, view.uuid);
      if (item == null || item.ownerId != actor.userId) continue;
      await purge(session, item);
      count++;
    }
    return count;
  }

  /// Physically deletes [item] and its subtree: documents (cascade),
  /// spreadsheet spaces, stored files.
  static Future<void> purge(Session session, DriveItem item) async {
    final nodes = await AccessService.subtree(session, item);
    final users = <int>{};
    for (final n in nodes) {
      users.addAll(await AccessService.interestedUsers(session, n));
    }
    final ids = {for (final n in nodes) n.id!};
    await FileService.deleteFilesOfItems(session, ids);
    for (final n in nodes.reversed) {
      if (n.kind == DriveItemKind.spreadsheet && n.contentRef != null) {
        await session.db.transaction(
          (tx) => OfflineSyncSpace.db.deleteWhere(
            session,
            where: (t) => t.uuidSpaceId.equals(n.contentRef!),
            transaction: tx,
          ),
        );
        await SpaceReservation.db.deleteWhere(
          session,
          where: (t) => t.spaceUuid.equals(n.contentRef!),
        );
      }
    }
    await DriveItem.db.deleteWhere(session, where: (t) => t.id.inSet(ids));
    for (final n in nodes) {
      final signal = DriveChangeSignal(
        kind: DriveChangeKind.removed,
        itemUuid: n.uuid,
      );
      for (final u in users) {
        await ClusterBus.post(session, DriveEvents.channel(u), signal);
      }
    }
  }

  /// Daily job: deletes items trashed longer than [trashRetention].
  static Future<int> purgeExpiredTrash(Session session, {DateTime? now}) async {
    final cutoff = (now ?? nowUtc()).subtract(trashRetention);
    final expired = await DriveItem.db.find(
      session,
      where: (t) => t.trashedAt < cutoff,
      limit: 1000,
    );
    final purged = <int>{};
    for (final item in expired) {
      if (purged.contains(item.id)) continue;
      final current = await DriveItem.db.findById(session, item.id!);
      if (current == null) continue;
      final nodes = await AccessService.subtree(session, current);
      await purge(session, current);
      purged.addAll(nodes.map((n) => n.id!));
    }
    return purged.length;
  }

  // ---------------------------------------------------------------- misc

  static Future<List<TemplateView>> listTemplates(
    Session session,
    Actor actor,
    DriveItemKind? kind,
  ) async {
    final result = <TemplateView>[
      for (final t in BuiltinTemplates.all)
        if (t.inGallery && (kind == null || t.kind == kind))
          TemplateView(
            uuid: t.uuid,
            key: t.key,
            kind: t.kind,
            name: t.name,
            description: t.description,
            category: t.category,
            builtin: true,
            previewText: t.previewText,
            themeKey: t.themeKey,
            previewStyle: t.previewStyle,
          ),
    ];
    final published = await DriveItem.db.find(
      session,
      where: (t) =>
          t.templateOf.notEquals(null) &
          t.trashedAt.equals(null) &
          (kind == null ? Constant.bool(true) : t.kind.equals(kind)),
      limit: 500,
    );
    final roles = await AccessService.rolesFor(
      session,
      actor.userId,
      published,
    );
    for (final item in published) {
      if (roles[item.id!] == null) continue;
      result.add(
        TemplateView(
          uuid: item.uuid,
          kind: item.kind,
          name: item.name,
          description: item.description ?? '',
          category: item.templateOf!,
          builtin: false,
          previewText: (item.searchText ?? '').length > 140
              ? '${item.searchText!.substring(0, 140)}…'
              : item.searchText ?? '',
          thumbnailFileId: item.thumbnailFileId,
        ),
      );
    }
    return result;
  }

  /// Publishes (or unpublishes with null) an owned item as a template.
  static Future<DriveItemView> setTemplate(
    Session session,
    Actor actor,
    UuidValue uuid,
    TemplateCategory? category,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.owner,
    );
    if (item.kind == DriveItemKind.folder) {
      throw Errors.invalid('Folders cannot be templates.');
    }
    await DriveItem.db.updateWhere(
      session,
      columnValues: (t) => [t.templateOf(category)],
      where: (t) => t.id.equals(item.id!),
    );
    final updated = (await DriveItem.db.findById(session, item.id!))!;
    await DriveEvents.notify(session, updated, DriveChangeKind.updated);
    return DriveViews.one(session, actor.userId, updated, role: role);
  }

  static Future<StorageUsage> storageUsage(Session session, Actor actor) async {
    final result = await session.db.unsafeQuery(
      r'''
      SELECT
        coalesce(sum("sizeBytes"), 0)::bigint,
        count(*) FILTER (WHERE kind = 'document'),
        count(*) FILTER (WHERE kind = 'spreadsheet'),
        count(*) FILTER (WHERE kind = 'folder')
      FROM drive_item WHERE "ownerId" = @me
      ''',
      parameters: QueryParameters.named({'me': actor.userId}),
    );
    final files = await session.db.unsafeQuery(
      r'''
      SELECT coalesce(sum("sizeBytes"), 0)::bigint, count(*)
      FROM stored_file WHERE "ownerId" = @me AND status = 'ready'
        AND kind NOT IN ('exportResult', 'importSource')
      ''',
      parameters: QueryParameters.named({'me': actor.userId}),
    );
    final row = result.first;
    final fileRow = files.first;
    return StorageUsage(
      bytesUsed: (row[0] as int) + (fileRow[0] as int),
      documents: row[1] as int,
      spreadsheets: row[2] as int,
      folders: row[3] as int,
      files: fileRow[1] as int,
    );
  }

  static Future<DriveItemView> setThumbnail(
    Session session,
    Actor actor,
    UuidValue uuid,
    UuidValue fileUuid,
  ) async {
    final (item, role) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.editor,
    );
    final file = await FileService.requireOwnReadyFile(
      session,
      actor,
      fileUuid,
      kind: StoredFileKind.thumbnail,
    );
    await FileService.attachToItem(session, file, item);
    final previous = item.thumbnailFileId;
    await DriveItem.db.updateWhere(
      session,
      columnValues: (t) => [t.thumbnailFileId(fileUuid)],
      where: (t) => t.id.equals(item.id!),
    );
    if (previous != null && previous != fileUuid) {
      await FileService.deleteFile(session, previous);
    }
    final updated = (await DriveItem.db.findById(session, item.id!))!;
    await DriveEvents.notify(session, updated, DriveChangeKind.updated);
    return DriveViews.one(session, actor.userId, updated, role: role);
  }

  static Future<List<ActivityEventView>> activity(
    Session session,
    Actor actor,
    UuidValue uuid, {
    int? beforeId,
    int limit = 50,
  }) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    return ActivityService.list(
      session,
      item.id!,
      beforeId: beforeId,
      limit: limit,
    );
  }

  /// Marks content as modified (throttled per item by the callers).
  static Future<void> touchModified(
    Session session,
    DriveItem item,
    int? userId, {
    String? searchText,
    int? sizeBytes,
  }) async {
    await DriveItem.db.updateWhere(
      session,
      columnValues: (t) => [
        t.modifiedAt(nowUtc()),
        t.modifiedById(userId),
        if (searchText != null) t.searchText(searchText),
        if (sizeBytes != null) t.sizeBytes(sizeBytes),
      ],
      where: (t) => t.id.equals(item.id!),
    );
    final updated = await DriveItem.db.findById(session, item.id!);
    if (updated != null) {
      await DriveEvents.notify(session, updated, DriveChangeKind.modified);
    }
  }

  /// Role of the caller as protocol enum (helper for endpoints).
  static AccessRole accessRole(Role role) => role.access;
}
