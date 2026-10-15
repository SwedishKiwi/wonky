import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../sharing/access_service.dart';

/// `DriveItem.kindMask` of folders (suite 05 §3.2, Drive 02 §1.1): the bit
/// set (`1 << DriveItemKind.index`) of the kinds a folder contains
/// recursively, ignoring trashed items and files that are not `ready`.
/// Maintained in the transaction of every create, register, move, trash,
/// restore, delete and upload completion; [recomputeAll] (nightly) repairs
/// drift. The mask ignores per-user access.
abstract final class KindMasks {
  /// The bit of [kind].
  static int bit(DriveItemKind kind) => 1 << kind.index;

  /// Whether [mask] has [kind].
  static bool has(int mask, DriveItemKind kind) => mask & bit(kind) != 0;

  /// Whether [item] contributes to its ancestors' masks.
  static bool counts(DriveItem item) =>
      item.trashedAt == null &&
      (item.uploadState == null || item.uploadState == FileUploadState.ready);

  /// SQL: the contribution of a `drive_item` row aliased `c`.
  static String get _contribution {
    final cases = [
      for (final k in DriveItemKind.values)
        k == DriveItemKind.folder
            ? "WHEN '${k.name}' THEN c.\"kindMask\" | ${bit(k)}"
            : "WHEN '${k.name}' THEN ${bit(k)}",
    ].join(' ');
    return 'CASE c.kind $cases ELSE 0 END';
  }

  static const _live =
      'c."trashedAt" IS NULL AND '
      '(c."uploadState" IS NULL OR c."uploadState" = \'ready\')';

  /// The mask of folder [folderId] computed from its live children.
  static Future<int> compute(
    Session session,
    int folderId, {
    Transaction? transaction,
  }) async {
    final rows = await session.db.unsafeQuery(
      'SELECT coalesce(bit_or($_contribution), 0)::bigint '
      'FROM drive_item c WHERE c."parentId" = @id AND $_live',
      parameters: QueryParameters.named({'id': folderId}),
      transaction: transaction,
    );
    return rows.first[0] as int;
  }

  /// Recomputes the masks of folder [folderId] and its ancestors, nearest
  /// first, stopping at the first folder whose mask is unchanged (its
  /// ancestors can't change then). Null is a no-op (the root).
  static Future<void> refreshChain(
    Session session,
    int? folderId, {
    Transaction? transaction,
  }) async {
    final seen = <int>{};
    var id = folderId;
    while (id != null && seen.add(id)) {
      final rows = await session.db.unsafeQuery(
        'SELECT "kindMask", "parentId", kind FROM drive_item WHERE id = @id',
        parameters: QueryParameters.named({'id': id}),
        transaction: transaction,
      );
      if (rows.isEmpty || rows.first[2] != DriveItemKind.folder.name) return;
      final stored = rows.first[0] as int;
      final parentId = rows.first[1] as int?;
      final mask = await compute(session, id, transaction: transaction);
      if (mask == stored) return;
      await _set(session, id, mask, transaction: transaction);
      id = parentId;
    }
  }

  /// Recomputes every folder of [root]'s subtree bottom-up (restores), then
  /// the chain above [root].
  static Future<void> refreshSubtree(
    Session session,
    DriveItem root, {
    Transaction? transaction,
  }) async {
    final nodes = await AccessService.subtree(
      session,
      root,
      transaction: transaction,
    );
    for (final node in nodes.reversed) {
      if (node.kind != DriveItemKind.folder) continue;
      final mask = await compute(session, node.id!, transaction: transaction);
      if (mask != node.kindMask) {
        await _set(session, node.id!, mask, transaction: transaction);
      }
    }
    await refreshChain(session, root.parentId, transaction: transaction);
  }

  static Future<void> _set(
    Session session,
    int id,
    int mask, {
    Transaction? transaction,
  }) => session.db.unsafeExecute(
    'UPDATE drive_item SET "kindMask" = @m WHERE id = @id',
    parameters: QueryParameters.named({'m': mask, 'id': id}),
    transaction: transaction,
  );

  /// The masks of every folder computed from scratch: each live item adds
  /// its bit to every ancestor reachable through live folders. Folders
  /// that are missing from the result have mask 0.
  static Future<Map<int, int>> computeAll(
    Session session, {
    Transaction? transaction,
  }) async {
    final bits = [
      for (final k in DriveItemKind.values) "WHEN '${k.name}' THEN ${bit(k)}",
    ].join(' ');
    final rows = await session.db.unsafeQuery(
      '''
      WITH RECURSIVE live AS (
        SELECT c.id, c."parentId", (CASE c.kind $bits ELSE 0 END)::bigint AS b
        FROM drive_item c WHERE $_live
      ), up(folder, b, depth) AS (
        SELECT l."parentId", l.b, 1 FROM live l WHERE l."parentId" IS NOT NULL
        UNION ALL
        SELECT p."parentId", up.b, up.depth + 1
        FROM up JOIN live p ON p.id = up.folder
        WHERE p."parentId" IS NOT NULL AND up.depth < 256
      )
      SELECT folder, bit_or(b)::bigint FROM up GROUP BY folder
      ''',
      transaction: transaction,
    );
    return {for (final r in rows) r[0] as int: r[1] as int};
  }

  /// Nightly job: recomputes every live folder's mask and fixes the ones
  /// that drifted. Returns how many were fixed.
  static Future<int> recomputeAll(Session session) async {
    final computed = await computeAll(session);
    final folders = await session.db.unsafeQuery(
      'SELECT id, "kindMask" FROM drive_item c '
      "WHERE c.kind = 'folder' AND $_live",
    );
    var fixed = 0;
    for (final row in folders) {
      final id = row[0] as int;
      final want = computed[id] ?? 0;
      if (row[1] as int != want) {
        await _set(session, id, want);
        fixed++;
      }
    }
    return fixed;
  }
}
