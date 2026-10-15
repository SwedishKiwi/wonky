import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../drive/drive_views.dart';

/// `drive.listByStorage` (Drive 03 §6.4): the caller's owned items (incl.
/// trashed, excl. folders and uploads in progress) sorted by counted size
/// (`sizeBytes + attachmentBytes`) descending, then id descending. The
/// cursor is the last row's `<countedBytes>:<id>` (keyset paging).
abstract final class StorageListing {
  static const defaultLimit = 50;
  static const maxLimit = 200;

  static Future<DriveListPage> list(
    Session session,
    Actor actor,
    StorageListFilter filter, {
    String? cursor,
    int limit = defaultLimit,
  }) async {
    final n = limit <= 0 ? defaultLimit : (limit > maxLimit ? maxLimit : limit);
    final params = <String, Object?>{'me': actor.userId, 'limit': n + 1};
    final where = <String>[
      'd."ownerId" = @me',
      "d.kind <> 'folder'",
      '''(d."uploadState" IS NULL OR d."uploadState" = 'ready')''',
    ];
    final kinds = filter.kinds;
    if (kinds != null) {
      final names = {
        for (final k in kinds)
          if (k != DriveItemKind.folder) k.name,
      };
      if (names.isEmpty) return DriveListPage(items: const []);
      where.add('d.kind IN (${names.map((k) => "'$k'").join(', ')})');
    }
    if (filter.trashedOnly) where.add('d."trashedAt" IS NOT NULL');
    if (filter.minCountedBytes case final min?) {
      where.add('d."sizeBytes" + d."attachmentBytes" >= @min');
      params['min'] = min;
    }
    if (filter.notOpenedSince case final since?) {
      where.add('(s."lastOpenedAt" IS NULL OR s."lastOpenedAt" < @since)');
      params['since'] = since.toUtc();
    }
    if (cursor != null && cursor.isNotEmpty) {
      final parts = cursor.split(':');
      final counted = parts.length == 2 ? int.tryParse(parts[0]) : null;
      final id = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (counted == null || id == null) {
        throw Errors.invalid('The cursor is invalid.');
      }
      where.add('(d."sizeBytes" + d."attachmentBytes", d.id) < (@cc, @cid)');
      params['cc'] = counted;
      params['cid'] = id;
    }
    final rows = await session.db.unsafeQuery(
      '''
      SELECT d.id, d."sizeBytes" + d."attachmentBytes" AS counted
      FROM drive_item d
      LEFT JOIN drive_item_user_state s
        ON s."itemId" = d.id AND s."userId" = @me
      WHERE ${where.join(' AND ')}
      ORDER BY counted DESC, d.id DESC
      LIMIT @limit
      ''',
      parameters: QueryParameters.named(params),
    );
    final page = rows.take(n).toList();
    final ids = [for (final r in page) r[0] as int];
    final byId = {
      for (final i in await DriveItem.db.find(
        session,
        where: (t) => t.id.inSet(ids.toSet()),
      ))
        i.id!: i,
    };
    final items = [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
    final views = await DriveViews.build(
      session,
      actor.userId,
      items,
      roles: {for (final i in items) i.id!: Role.owner},
    );
    final last = page.isEmpty ? null : page.last;
    return DriveListPage(
      items: views,
      nextCursor: rows.length > n && last != null
          ? '${last[1]}:${last[0]}'
          : null,
    );
  }
}
