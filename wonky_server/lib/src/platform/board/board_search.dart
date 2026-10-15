import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../common/time.dart';
import 'board_access.dart';

/// Full-text search and the board list query (specs/16 §4.4, §6.4). The
/// search document is computed in the query; there is no stored tsvector
/// column or index, so the schema stays identical to `definition.sql`.
abstract final class BoardSearch {
  static const document =
      "(setweight(to_tsvector('english', p.title), 'A') || "
      "setweight(to_tsvector('english', p.body), 'B'))";

  /// Votes of users who are not blocked right now (specs/16 §11).
  static const activeVoter =
      'NOT EXISTS (SELECT 1 FROM board_user_profile b '
      'WHERE b."userId" = v."userId" AND b."blockedAt" IS NOT NULL '
      'AND (b."blockedUntil" IS NULL OR b."blockedUntil" > @now))';

  /// An OR query over the words of [text] for `websearch_to_tsquery`
  /// (similar posts: any shared term counts, ranking does the rest).
  static String orQuery(String text) {
    final words = <String>{};
    for (final m in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(text)) {
      final w = m[0]!.toLowerCase();
      if (w.length < 2 || w == 'or') continue;
      words.add(w);
      if (words.length >= 40) break;
    }
    return words.join(' or ');
  }

  /// Ids of visible posts in [statuses] that match [text] best (OR over its
  /// words), best first.
  static Future<List<int>> similarIds(
    Session session,
    String text, {
    BoardPostKind? kind,
    int limit = 10,
    int? excludeId,
    List<BoardPostStatus> statuses = const [
      BoardPostStatus.open,
      BoardPostStatus.planned,
      BoardPostStatus.done,
    ],
  }) async {
    final q = orQuery(text);
    if (q.isEmpty) return const [];
    final rows = await session.db.unsafeQuery(
      '''
      SELECT p.id FROM board_post p,
        websearch_to_tsquery('english', @q) query
      WHERE p.moderation = 'visible' AND p."deletedAt" IS NULL
        AND p.status IN (${_names(statuses)})
        ${kind == null ? '' : 'AND p.kind = @kind'}
        ${excludeId == null ? '' : 'AND p.id <> @exclude'}
        AND $document @@ query
      ORDER BY ts_rank_cd($document, query) DESC, p.score DESC, p.id DESC
      LIMIT @limit
      ''',
      parameters: QueryParameters.named({
        'q': q,
        'kind': ?kind?.name,
        'exclude': ?excludeId,
        'limit': limit,
      }),
    );
    return [for (final r in rows) r[0] as int];
  }

  static Future<List<BoardPost>> similarPosts(
    Session session,
    String text, {
    BoardPostKind? kind,
    int limit = 10,
    int? excludeId,
  }) async {
    final ids = await similarIds(
      session,
      text,
      kind: kind,
      limit: limit,
      excludeId: excludeId,
    );
    return byIds(session, ids);
  }

  /// Posts by [ids], in that order.
  static Future<List<BoardPost>> byIds(Session session, List<int> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await BoardPost.db.find(
      session,
      where: (t) => t.id.inSet(ids.toSet()),
    );
    final byId = {for (final p in rows) p.id!: p};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  static String _names(Iterable<Enum> values) =>
      values.map((v) => "'${v.name}'").join(', ');

  /// One page of the board list (specs/16 §4.4): ids in order and the
  /// total.
  static Future<(List<int>, int)> list(
    Session session,
    BoardCaller c,
    BoardListQuery query, {
    required int offset,
    required int limit,
  }) async {
    final statuses = query.statuses.isEmpty
        ? const [BoardPostStatus.open, BoardPostStatus.planned]
        : query.statuses;
    final text = query.query?.trim() ?? '';
    final where = <String>[
      'p."deletedAt" IS NULL',
      'p.status IN (${_names(statuses)})',
      // The caller's own checking/held posts show in Mine.
      if (query.mine && c.signedIn)
        '(p.moderation = \'visible\' OR (p."authorId" = @me '
            'AND p.moderation IN (\'checking\', \'held\')))'
      else
        "p.moderation = 'visible'",
      if (query.kind != null) 'p.kind = @kind',
      if (query.areas.isNotEmpty) 'p.area IN (${_names(query.areas)})',
      if (query.sizes.isNotEmpty) 'p.size IN (${_names(query.sizes)})',
      if (query.mine)
        c.signedIn
            ? '(p."authorId" = @me OR EXISTS (SELECT 1 FROM board_vote mv '
                  'WHERE mv."postId" = p.id AND mv."userId" = @me))'
            : 'FALSE',
      if (text.isNotEmpty) "$document @@ websearch_to_tsquery('english', @q)",
    ];
    final now = nowUtc();
    final params = <String, Object?>{
      if (query.mine && c.signedIn) 'me': c.userId,
      'kind': ?query.kind?.name,
      if (text.isNotEmpty) 'q': text,
    };
    final whereSql = where.join(' AND ');
    final countRows = await session.db.unsafeQuery(
      'SELECT count(*) FROM board_post p WHERE $whereSql',
      parameters: QueryParameters.named(params),
    );
    final total = countRows.first[0] as int;
    const trending =
        '(SELECT COALESCE(SUM(v.value), 0) FROM board_vote v '
        'WHERE v."postId" = p.id AND v."createdAt" > @since '
        'AND $activeVoter)';
    final rank = text.isEmpty
        ? null
        : "ts_rank_cd($document, websearch_to_tsquery('english', @q))";
    final order = switch (query.sort) {
      BoardSort.trending => [
        ?rank,
        '$trending DESC',
        'p.score DESC',
        'p.id DESC',
      ],
      BoardSort.top => ['p.score DESC', 'p.id DESC'],
      BoardSort.newest => ['p."createdAt" DESC', 'p.id DESC'],
      BoardSort.discussed => [
        'p."commentCount" DESC',
        'p.score DESC',
        'p.id DESC',
      ],
    }.map((o) => o == rank ? '$o DESC' : o).join(', ');
    final rows = await session.db.unsafeQuery(
      'SELECT p.id FROM board_post p WHERE $whereSql '
      'ORDER BY $order LIMIT @limit OFFSET @offset',
      parameters: QueryParameters.named({
        ...params,
        if (query.sort == BoardSort.trending) ...{
          'since': now.subtract(const Duration(days: 14)),
          'now': now,
        },
        'limit': limit,
        'offset': offset,
      }),
    );
    return ([for (final r in rows) r[0] as int], total);
  }
}
