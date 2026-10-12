import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../activity/activity_service.dart';
import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../sharing/access_service.dart';
import '../users/user_service.dart';

/// What a [VersionProvider] stored for a captured version.
class CapturedVersion {
  const CapturedVersion({
    required this.storageKind,
    this.revision,
    this.snapshotFileId,
    this.sizeBytes = 0,
  });

  final VersionStorage storageKind;
  final int? revision;
  final UuidValue? snapshotFileId;
  final int sizeBytes;
}

/// Result of a provider restore.
class RestoredVersion {
  const RestoredVersion({this.revision, this.changeId});
  final int? revision;
  final UuidValue? changeId;
}

/// Per-app version support (specs/07 §5): capture, restore, discard.
abstract interface class VersionProvider {
  DriveItemKind get kind;

  /// Captures the current state of [item].
  Future<CapturedVersion> capture(Session session, DriveItem item);

  /// Applies [version] to [item] as a normal forward edit by [actor].
  Future<RestoredVersion> restore(
    Session session,
    Actor actor,
    DriveItem item,
    ItemVersion version,
  );

  /// Called when a version is deleted by thinning (free storage).
  Future<void> discard(Session session, ItemVersion version);

  /// Called after a version row was inserted (indexes, snapshots).
  Future<void> afterCapture(
    Session session,
    DriveItem item,
    ItemVersion version,
  );
}

/// The version framework shared by both apps (specs/07 §5).
abstract final class VersionService {
  /// Auto version after this much inactivity following edits.
  static const idleBeforeCapture = Duration(minutes: 5);

  /// At most one auto version per this period of continuous editing.
  static const maxContinuous = Duration(minutes: 30);

  static final Map<DriveItemKind, VersionProvider> _providers = {};

  static void register(VersionProvider provider) =>
      _providers[provider.kind] = provider;

  static VersionProvider providerFor(DriveItem item) {
    final provider = _providers[item.kind];
    if (provider == null) {
      throw Errors.invalid('This item has no version history.');
    }
    return provider;
  }

  /// Records an edit for the capture policy.
  static Future<void> recordEdit(
    Session session,
    DriveItem item,
    int userId, {
    int? revision,
  }) async {
    final now = nowUtc();
    final state = await ItemVersionState.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(item.id!),
    );
    if (state == null) {
      try {
        await ItemVersionState.db.insertRow(
          session,
          ItemVersionState(
            itemId: item.id!,
            lastEditAt: now,
            dirtySince: now,
            editorsSinceLastVersion: [userId],
            lastRevision: revision,
          ),
        );
        return;
      } on DatabaseException {
        // Concurrent insert: fall through to update.
      }
    }
    final current =
        state ??
        await ItemVersionState.db.findFirstRow(
          session,
          where: (t) => t.itemId.equals(item.id!),
        );
    if (current == null) return;
    final editors = {...current.editorsSinceLastVersion, userId}.toList();
    await ItemVersionState.db.updateRow(
      session,
      current.copyWith(
        lastEditAt: now,
        dirtySince: current.dirtySince ?? now,
        editorsSinceLastVersion: editors,
        lastRevision: revision ?? current.lastRevision,
      ),
    );
  }

  /// Captures a version of [item] now.
  static Future<ItemVersion> capture(
    Session session,
    DriveItem item, {
    required VersionKind kind,
    String? name,
    int? createdById,
  }) async {
    final provider = providerFor(item);
    final captured = await provider.capture(session, item);
    final state = await ItemVersionState.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(item.id!),
    );
    final now = nowUtc();
    final version = await ItemVersion.db.insertRow(
      session,
      ItemVersion(
        itemId: item.id!,
        kind: kind,
        name: name,
        createdAt: now,
        createdById: createdById,
        authors: state?.editorsSinceLastVersion ?? const [],
        storageKind: captured.storageKind,
        revision: captured.revision,
        snapshotFileId: captured.snapshotFileId,
        sizeBytes: captured.sizeBytes,
      ),
    );
    if (state != null) {
      await ItemVersionState.db.updateRow(
        session,
        ItemVersionState(
          id: state.id,
          itemId: state.itemId,
          lastEditAt: state.lastEditAt,
          dirtySince: null,
          lastVersionAt: now,
          editorsSinceLastVersion: const [],
          lastRevision: state.lastRevision,
        ),
      );
    } else {
      await ItemVersionState.db.insertRow(
        session,
        ItemVersionState(
          itemId: item.id!,
          lastEditAt: now,
          lastVersionAt: now,
          editorsSinceLastVersion: const [],
        ),
      );
    }
    await provider.afterCapture(session, item, version);
    return version;
  }

  // ---------------------------------------------------------------- views

  static Future<List<ItemVersionView>> viewsOf(
    Session session,
    DriveItem item,
    List<ItemVersion> versions,
  ) async {
    final users = await UserService.summaries(session, [
      for (final v in versions) ...v.authors,
    ]);
    return [
      for (final v in versions)
        ItemVersionView(
          id: v.id!,
          itemUuid: item.uuid,
          kind: v.kind,
          name: v.name,
          createdAt: v.createdAt,
          authors: [
            for (final a in v.authors)
              if (users[a] != null) users[a]!,
          ],
          storageKind: v.storageKind,
          revision: v.revision,
          sizeBytes: v.sizeBytes,
        ),
    ];
  }

  static Future<(DriveItem, ItemVersion)> requireVersion(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    int versionId, {
    Role min = Role.editor,
  }) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      itemUuid,
      min,
    );
    final version = await ItemVersion.db.findById(session, versionId);
    if (version == null || version.itemId != item.id) {
      throw Errors.notFound('Version');
    }
    return (item, version);
  }

  static Future<List<ItemVersionView>> list(
    Session session,
    Actor actor,
    UuidValue itemUuid, {
    bool namedOnly = false,
    int? beforeId,
    int limit = 100,
  }) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.editor,
    );
    final versions = await ItemVersion.db.find(
      session,
      where: (t) =>
          t.itemId.equals(item.id!) &
          (namedOnly ? t.kind.equals(VersionKind.named) : Constant.bool(true)) &
          (beforeId == null ? Constant.bool(true) : t.id < beforeId),
      orderBy: (t) => t.id.desc(),
      limit: limit.clamp(1, 500),
    );
    return viewsOf(session, item, versions);
  }

  static Future<ItemVersionView> nameCurrent(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    String name,
  ) async {
    final (item, _) = await AccessService.require(
      session,
      actor,
      itemUuid,
      Role.editor,
    );
    final version = await capture(
      session,
      item,
      kind: VersionKind.named,
      name: _cleanName(name),
      createdById: actor.userId,
    );
    return (await viewsOf(session, item, [version])).single;
  }

  static String _cleanName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Errors.invalid('The name cannot be empty.');
    return trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed;
  }

  /// Names a version (or removes the name with null, making it auto again).
  static Future<ItemVersionView> rename(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    int versionId,
    String? name,
  ) async {
    final (item, version) = await requireVersion(
      session,
      actor,
      itemUuid,
      versionId,
    );
    final clean = name == null || name.trim().isEmpty ? null : _cleanName(name);
    final updated = await ItemVersion.db.updateRow(
      session,
      ItemVersion(
        id: version.id,
        itemId: version.itemId,
        kind: clean == null
            ? (version.kind == VersionKind.named
                  ? VersionKind.auto
                  : version.kind)
            : VersionKind.named,
        name: clean,
        createdAt: version.createdAt,
        createdById: version.createdById,
        authors: version.authors,
        storageKind: version.storageKind,
        revision: version.revision,
        snapshotFileId: version.snapshotFileId,
        sizeBytes: version.sizeBytes,
      ),
    );
    return (await viewsOf(session, item, [updated])).single;
  }

  /// Restores [versionId]: captures a restore point, then applies the
  /// version as a forward edit (specs/07 §5).
  static Future<VersionRestoreResult> restore(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    int versionId,
  ) async {
    final (item, version) = await requireVersion(
      session,
      actor,
      itemUuid,
      versionId,
    );
    final label = version.name ?? version.createdAt.toIso8601String();
    final restorePoint = await capture(
      session,
      item,
      kind: VersionKind.restorePoint,
      name: 'Before restoring "$label"',
      createdById: actor.userId,
    );
    final restored = await providerFor(item).restore(
      session,
      actor,
      item,
      version,
    );
    await ActivityService.log(
      session,
      item.id!,
      actor,
      ActivityType.restoredVersion,
      summary: {'versionId': version.id, 'name': version.name},
    );
    return VersionRestoreResult(
      restorePoint: (await viewsOf(session, item, [restorePoint])).single,
      revision: restored.revision,
      changeId: restored.changeId,
    );
  }

  // ---------------------------------------------------------------- jobs

  /// Capture policy job (every minute): an auto version after
  /// [idleBeforeCapture] of inactivity following edits, and at most every
  /// [maxContinuous] during continuous editing.
  static Future<int> captureDue(Session session, {DateTime? now}) async {
    final at = now ?? nowUtc();
    final due = await ItemVersionState.db.find(
      session,
      where: (t) =>
          t.dirtySince.notEquals(null) &
          ((t.lastEditAt <= at.subtract(idleBeforeCapture)) |
              (t.dirtySince <= at.subtract(maxContinuous))),
      limit: 200,
    );
    var captured = 0;
    for (final state in due) {
      final item = await DriveItem.db.findById(session, state.itemId);
      if (item == null || !_providers.containsKey(item.kind)) continue;
      try {
        await capture(session, item, kind: VersionKind.auto);
        captured++;
      } on Exception catch (e, st) {
        session.log(
          'Version capture of ${item.uuid} failed: $e',
          level: LogLevel.error,
          stackTrace: st,
        );
      }
    }
    return captured;
  }

  /// Nightly thinning of auto versions and restore points: keep everything
  /// for 7 days, then one per hour up to 30 days, then one per day. Named
  /// versions are never thinned.
  static Future<int> thin(Session session, {DateTime? now}) async {
    final at = now ?? nowUtc();
    final candidates = await ItemVersion.db.find(
      session,
      where: (t) =>
          t.kind.notEquals(VersionKind.named) &
          (t.createdAt < at.subtract(const Duration(days: 7))),
      orderBy: (t) => t.createdAt.desc(),
    );
    final keep = <String>{};
    final remove = <ItemVersion>[];
    for (final v in candidates) {
      final age = at.difference(v.createdAt);
      final bucket = age > const Duration(days: 30)
          ? '${v.itemId}|d|${v.createdAt.year}-${v.createdAt.month}-${v.createdAt.day}'
          : '${v.itemId}|h|${v.createdAt.year}-${v.createdAt.month}-${v.createdAt.day}-${v.createdAt.hour}';
      if (keep.add(bucket)) continue; // newest of the bucket is kept
      remove.add(v);
    }
    for (final v in remove) {
      final item = await DriveItem.db.findById(session, v.itemId);
      if (item != null && _providers[item.kind] != null) {
        await _providers[item.kind]!.discard(session, v);
      }
      await ItemVersion.db.deleteRow(session, v);
    }
    return remove.length;
  }
}
