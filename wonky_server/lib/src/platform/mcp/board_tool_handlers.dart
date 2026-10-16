import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show BoardTools, McpToolDefinition;

import '../board/board_access.dart';
import '../board/board_service.dart';
import '../common/models.dart';
import 'tool_executor.dart';
import 'tool_support.dart';

/// Headless `board.*` tools (specs/16 §14) over [BoardService], as the
/// token's user.
abstract final class BoardToolHandlers {
  static List<RegisteredMcpTool> get all => [
    _t(BoardTools.listPosts, listPosts),
    _t(BoardTools.getPost, getPost),
    _t(BoardTools.listTasks, listTasks),
    _t(BoardTools.getTask, getTask),
    _t(BoardTools.createPost, createPost),
    _t(BoardTools.vote, vote),
    _t(BoardTools.comment, comment),
    _t(BoardTools.claimTask, claimTask),
    _t(BoardTools.releaseTask, releaseTask),
  ];

  static RegisteredMcpTool _t(McpToolDefinition d, ToolHandler h) =>
      RegisteredMcpTool(d, (ctx, a) async {
        await BoardAccess.useActor(ctx.session, ctx.actor);
        return h(ctx, a);
      });

  static List<T> _enums<T extends Enum>(List<T> values, List<Object?>? raw) => [
    for (final v in raw ?? const [])
      for (final e in values)
        if (e.name == v) e,
  ];

  static Map<String, Object?> _item(BoardPostListItem p) => {
    'number': p.number,
    'kind': p.kind.name,
    'title': p.title,
    'status': p.status.name,
    'area': p.area?.name,
    'size': p.size?.name,
    'score': p.score,
    'votes': p.voteCount,
    'comments': p.commentCount,
    'my_vote': p.myVote,
    'author': p.author?.displayName,
    'task': p.task == null ? null : 'T-${p.task!.number}',
    'created_at': p.createdAt.toIso8601String(),
  };

  static Map<String, Object?> _task(BoardTaskView t, {bool full = false}) => {
    'number': t.number,
    'id': 'T-${t.number}',
    'title': t.title,
    'status': t.status.name,
    'area': t.area.name,
    'size': t.size.name,
    'claimed_by': t.claimedBy?.displayName,
    'claim_expires_at': t.claimExpiresAt?.toIso8601String(),
    'pull_request': t.pullRequestUrl,
    'posts': [for (final p in t.posts) _item(p)],
    // The prompt only reaches the claimant and admins (empty otherwise).
    if (full && t.prompt.isNotEmpty) 'prompt': t.prompt,
    if (t.claimCode != null) ...{
      'claim_code': t.claimCode,
      'pr_description_lines':
          'Wonky-Task: T-${t.number}\nWonky-Claim: ${t.claimCode}',
    },
  };

  static Future<ToolResult> listPosts(ToolContext ctx, ToolArgs a) async {
    final kind = a.string('kind');
    final page = await BoardService.list(
      ctx.session,
      BoardListQuery(
        kind: kind == null ? null : BoardPostKind.fromJson(kind),
        statuses: _enums(BoardPostStatus.values, a.list('status')),
        areas: _enums(BoardArea.values, a.list('area')),
        sizes: const [],
        sort: BoardSort.values.firstWhere(
          (s) => s.name == a.string('sort'),
          orElse: () => BoardSort.trending,
        ),
        query: a.string('query'),
        mine: false,
        cursor: a.string('cursor'),
        limit: a.integer('limit') ?? 30,
      ),
    );
    return ToolResult({
      'posts': [for (final p in page.items) _item(p)],
      'total': page.total,
      'next_cursor': page.nextCursor,
    });
  }

  static Future<ToolResult> getPost(ToolContext ctx, ToolArgs a) async {
    final n = _number(a, 'number');
    final p = await BoardService.getPost(ctx.session, n);
    final comments = await BoardService.listComments(
      ctx.session,
      postNumber: n,
    );
    return ToolResult({
      'number': p.number,
      'kind': p.kind.name,
      'title': p.title,
      'body': p.body,
      'status': p.status.name,
      'moderation': p.moderation.name,
      'area': p.area?.name,
      'size': p.size?.name,
      'score': p.score,
      'my_vote': p.myVote,
      'author': p.author?.displayName,
      'details': p.contextJson,
      'has_screenshot': p.hasScreenshot,
      'task': p.task == null ? null : 'T-${p.task!.number}',
      'duplicate_of': p.duplicateOfNumber,
      'created_at': p.createdAt.toIso8601String(),
      'comments': [
        for (final c in comments)
          if (!c.deleted && c.systemEvent == null)
            {
              'author': c.author?.displayName,
              'body': c.body,
              'created_at': c.createdAt.toIso8601String(),
            },
      ],
    });
  }

  static Future<ToolResult> listTasks(ToolContext ctx, ToolArgs a) async {
    final page = await BoardService.listTasks(
      ctx.session,
      _enums(BoardTaskStatus.values, a.list('status')),
      null,
      50,
    );
    return ToolResult({
      'tasks': [for (final t in page.items) _task(t)],
    });
  }

  static Future<ToolResult> getTask(ToolContext ctx, ToolArgs a) async =>
      ToolResult(
        _task(
          await BoardService.getTask(ctx.session, _number(a, 'number')),
          full: true,
        ),
      );

  static Future<ToolResult> createPost(ToolContext ctx, ToolArgs a) async {
    final p = await BoardService.createPost(
      ctx.session,
      BoardPostDraft(
        kind: BoardPostKind.fromJson(a.requireString('kind')),
        title: a.requireString('title'),
        body: a.requireString('body'),
        appHint: a.string('app') ?? 'drive',
      ),
    );
    return ToolResult({
      'number': p.number,
      'moderation': p.moderation.name,
      'status': p.status.name,
    });
  }

  static Future<ToolResult> vote(ToolContext ctx, ToolArgs a) async {
    final r = await BoardService.vote(
      ctx.session,
      _number(a, 'number'),
      a.integer('value') ??
          (throw McpToolException(
            McpErrorCode.invalidArgs,
            '"value" is required',
          )),
    );
    return ToolResult({
      'number': r.number,
      'score': r.score,
      'my_vote': r.myVote,
    });
  }

  /// Comments on a post; tasks have no discussion (specs/16 §4.6).
  static Future<ToolResult> comment(ToolContext ctx, ToolArgs a) async {
    final c = await BoardService.addComment(
      ctx.session,
      uuid: const Uuid().v7obj(),
      postNumber: _number(a, 'post_number'),
      body: a.requireString('body'),
    );
    return ToolResult({
      'uuid': c.uuid.uuid,
      'moderation': c.moderation.name,
    });
  }

  static Future<ToolResult> claimTask(ToolContext ctx, ToolArgs a) async =>
      ToolResult(
        _task(await BoardService.claimTask(ctx.session, _number(a, 'number'))),
      );

  static Future<ToolResult> releaseTask(ToolContext ctx, ToolArgs a) async =>
      ToolResult(
        _task(
          await BoardService.releaseTask(ctx.session, _number(a, 'number')),
        ),
      );

  static int _number(ToolArgs a, String key) =>
      a.integer(key) ??
      (throw McpToolException(McpErrorCode.invalidArgs, '"$key" is required'));
}
