import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart'
    show ChangesTools, CommentsTools, McpToolDefinition, Role, VersionsTools;
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../write/mcp/headless_editor.dart';
import '../../write/ot/document_store.dart';
import '../comments/comment_service.dart';
import '../common/models.dart';
import '../versions/version_service.dart';
import 'tool_executor.dart';
import 'tool_support.dart';

/// Headless `comments.*`, `versions.*` and `changes.*` tools (suite 09 §4,
/// Write 08 §8).
abstract final class CollabToolHandlers {
  static List<RegisteredMcpTool> get all => [
    _t(CommentsTools.list, listComments),
    _t(CommentsTools.create, createComment),
    _t(CommentsTools.reply, reply),
    _t(CommentsTools.resolve, resolve),
    _t(CommentsTools.reopen, reopen),
    _t(CommentsTools.delete, deleteComment),
    _t(VersionsTools.list, listVersions),
    _t(VersionsTools.nameCurrent, nameCurrent),
    _t(VersionsTools.get, getVersion),
    _t(VersionsTools.restore, restoreVersion),
    _t(ChangesTools.revert, revert),
  ];

  static RegisteredMcpTool _t(McpToolDefinition d, ToolHandler h) =>
      RegisteredMcpTool(d, h);

  // ------------------------------------------------------------- comments

  static Map<String, Object?> threadJson(
    CommentThreadView t, {
    CommentAnchor? anchor,
  }) => {
    'thread_uuid': t.uuid.uuid,
    'status': t.status.name,
    'anchor_kind': t.anchorKind.name,
    'anchor': anchor == null
        ? null
        : {
            'start': anchor.start,
            'length': anchor.length,
            'quote': anchor.quote,
          },
    'quoted_text': t.quotedText,
    'suggestion_id': ?t.suggestionId,
    'created_by': t.createdBy?.displayName,
    'created_at': t.createdAt.toIso8601String(),
    'resolved_by': t.resolvedBy?.displayName,
    'assignee': t.assignee?.displayName,
    'comments': [
      for (final c in t.comments)
        if (!c.deleted && c.systemEvent == null)
          {
            'comment_id': c.id,
            'author': c.author?.displayName,
            'author_kind': c.authorKind.name,
            'body': c.body,
            'created_at': c.createdAt.toIso8601String(),
            if (c.editedAt != null) 'edited_at': c.editedAt!.toIso8601String(),
          },
    ],
    'events': [
      for (final c in t.comments)
        if (c.systemEvent != null)
          {
            'event': c.systemEvent!.toJson(),
            'by': c.author?.displayName,
            'at': c.createdAt.toIso8601String(),
          },
    ],
  };

  static Future<ToolResult> listComments(ToolContext ctx, ToolArgs a) async {
    final target = await HeadlessDocumentEditor.resolve(
      ctx.session,
      ctx.actor,
      a.requireUuid('uuid'),
    );
    final filter = switch (a.string('status')) {
      'resolved' => CommentFilter.resolved,
      'all' => CommentFilter.all,
      _ => CommentFilter.open,
    };
    final threads = await CommentService.listThreads(
      ctx.session,
      ctx.actor,
      target.item.uuid,
      filter: filter,
    );
    final state = await HeadlessDocumentEditor.head(
      ctx.session,
      target.document,
    );
    final anchors = CommentAnchors.anchors(state.content);
    return ToolResult({
      'document_uuid': target.item.uuid.uuid,
      'revision': state.revision,
      'threads': [
        for (final t in threads) threadJson(t, anchor: anchors[t.uuid.uuid]),
      ],
    }, text: '${threads.length} thread(s)');
  }

  static final _mention = RegExp(r'@([^\s@<>()]+@[^\s@<>(),;]+\.[A-Za-z]{2,})');

  static Future<List<int>> _mentions(Session session, String body) async {
    final emails = {
      for (final m in _mention.allMatches(body)) m.group(1)!.toLowerCase(),
    };
    if (emails.isEmpty) return const [];
    final profiles = await UserProfile.db.find(
      session,
      where: (t) => t.email.inSet(emails),
    );
    return [for (final p in profiles) p.id!];
  }

  static Future<ToolResult> createComment(ToolContext ctx, ToolArgs a) async {
    final target = await HeadlessDocumentEditor.resolve(
      ctx.session,
      ctx.actor,
      a.requireUuid('uuid'),
      min: Role.commenter,
    );
    final body = a.requireString('body');
    final anchor = a.object('anchor');
    final threadUuid = const Uuid().v7obj();
    final mentions = await _mentions(ctx.session, body);
    if (anchor == null || anchor['document'] == true) {
      final t = await CommentService.createThread(
        ctx.session,
        ctx.actor,
        threadUuid: threadUuid,
        itemUuid: target.item.uuid,
        anchorKind: CommentAnchorKind.document,
        anchorJson: '{"v":1}',
        body: body,
        mentions: mentions,
      );
      return ToolResult({
        'thread_uuid': t.uuid.uuid,
        'change_id': null,
        'thread': threadJson(t),
      }, text: 'Comment added to the document');
    }
    // Resolve the anchor against the head first (errors before creating).
    final state = await HeadlessDocumentEditor.head(
      ctx.session,
      target.document,
    );
    final range = _anchorRange(state.content, anchor);
    final quote = WonkyDocument(
      state.content,
    ).text.substring(range.start, range.end).replaceAll('\n', ' ');
    final thread = await CommentService.createThread(
      ctx.session,
      ctx.actor,
      threadUuid: threadUuid,
      itemUuid: target.item.uuid,
      anchorKind: CommentAnchorKind.textRange,
      anchorJson: '{"v":1}',
      quotedText: quote,
      body: body,
      mentions: mentions,
    );
    final r = await HeadlessDocumentEditor.mutate(
      ctx,
      documentUuid: target.document.uuid,
      toolName: 'comments.create',
      options: const MutationOptions(),
      overlayOnly: true,
      defaultLabel: 'Comment',
      build: (head, edits) {
        // Re-resolve against the current head (concurrent edits).
        final now = _anchorRange(head, anchor);
        final change = CommentAnchors.addAnchor(
          threadUuid.uuid,
          now.start,
          now.length,
        );
        final n = const WonkyDeltaNormalizer().normalizeChange(head, change);
        return EditResult(
          change: n.change,
          document: n.document,
          appliedRange: now,
          summary: 'Comment added',
        );
      },
    );
    return ToolResult({
      'thread_uuid': thread.uuid.uuid,
      'change_id': r['change_id'],
      'revision': r['revision'],
      'anchor': r['applied_range'],
      'thread': threadJson(thread),
    }, text: 'Comment added on "$quote"');
  }

  static ResolvedRange _anchorRange(Delta doc, Map<String, dynamic> anchor) {
    final resolver = AddressResolver(doc);
    final ResolvedRange range;
    if (anchor['quote'] is String) {
      range = resolver.resolveQuote(
        anchor['quote'] as String,
        (anchor['occurrence'] as num?)?.toInt(),
      );
    } else if (anchor['start'] is num && anchor['length'] is num) {
      range = resolver.checkRange(
        (anchor['start'] as num).toInt(),
        (anchor['length'] as num).toInt(),
      );
    } else {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'anchor needs {quote, occurrence?}, {start, length} or '
        '{document: true}.',
      );
    }
    if (range.length == 0) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'A comment needs at least one character to anchor to.',
      );
    }
    return range;
  }

  static Future<ToolResult> reply(ToolContext ctx, ToolArgs a) async {
    final body = a.requireString('body');
    final t = await CommentService.reply(
      ctx.session,
      ctx.actor,
      a.requireUuid('thread_uuid'),
      body: body,
      mentions: await _mentions(ctx.session, body),
    );
    return ToolResult({'thread': threadJson(t)}, text: 'Reply added');
  }

  static Future<ToolResult> resolve(ToolContext ctx, ToolArgs a) async {
    final t = await CommentService.resolve(
      ctx.session,
      ctx.actor,
      a.requireUuid('thread_uuid'),
    );
    return ToolResult({'thread': threadJson(t)}, text: 'Thread resolved');
  }

  static Future<ToolResult> reopen(ToolContext ctx, ToolArgs a) async {
    final t = await CommentService.reopen(
      ctx.session,
      ctx.actor,
      a.requireUuid('thread_uuid'),
    );
    return ToolResult({'thread': threadJson(t)}, text: 'Thread reopened');
  }

  static Future<ToolResult> deleteComment(ToolContext ctx, ToolArgs a) async {
    final commentId = a.integer('comment_id');
    final threadUuid = a.uuid('thread_uuid');
    if (commentId != null) {
      await CommentService.delete(ctx.session, ctx.actor, commentId);
      return ToolResult({'ok': true}, text: 'Comment deleted');
    }
    if (threadUuid == null) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'Pass comment_id or thread_uuid.',
      );
    }
    final thread = await CommentThread.db.findFirstRow(
      ctx.session,
      where: (t) => t.uuid.equals(threadUuid),
    );
    await CommentService.deleteThread(ctx.session, ctx.actor, threadUuid);
    String? changeId;
    if (thread != null && thread.anchorKind == CommentAnchorKind.textRange) {
      final doc = await DocumentStore.byItem(ctx.session, thread.itemId);
      if (doc != null) {
        final r = await HeadlessDocumentEditor.mutate(
          ctx,
          documentUuid: doc.uuid,
          toolName: 'comments.delete',
          options: const MutationOptions(),
          overlayOnly: true,
          defaultLabel: 'Delete comment',
          build: (head, edits) {
            final change = CommentAnchors.removeAnchor(head, threadUuid.uuid);
            final n = const WonkyDeltaNormalizer().normalizeChange(
              head,
              change,
            );
            return EditResult(change: n.change, document: n.document);
          },
        );
        changeId = r['change_id'] as String?;
      }
    }
    return ToolResult({
      'ok': true,
      'change_id': changeId,
    }, text: 'Thread deleted');
  }

  // ------------------------------------------------------------- versions

  static Map<String, Object?> versionJson(ItemVersionView v) => {
    'version_id': v.id,
    'kind': v.kind.name,
    'name': v.name,
    'created_at': v.createdAt.toIso8601String(),
    'authors': [for (final u in v.authors) u.displayName],
    'revision': v.revision,
  };

  static Future<ToolResult> listVersions(ToolContext ctx, ToolArgs a) async {
    final target = await HeadlessDocumentEditor.resolve(
      ctx.session,
      ctx.actor,
      a.requireUuid('uuid'),
    );
    final versions = await VersionService.list(
      ctx.session,
      ctx.actor,
      target.item.uuid,
      namedOnly: a.boolean('named_only') ?? false,
    );
    return ToolResult({
      'document_uuid': target.item.uuid.uuid,
      'versions': [for (final v in versions) versionJson(v)],
    }, text: '${versions.length} version(s)');
  }

  static Future<ToolResult> nameCurrent(ToolContext ctx, ToolArgs a) async {
    final target = await HeadlessDocumentEditor.resolve(
      ctx.session,
      ctx.actor,
      a.requireUuid('uuid'),
    );
    final v = await VersionService.nameCurrent(
      ctx.session,
      ctx.actor,
      target.item.uuid,
      a.requireString('name'),
    );
    return ToolResult({
      'version': versionJson(v),
    }, text: 'Saved version "${v.name}"');
  }

  static Future<ToolResult> getVersion(ToolContext ctx, ToolArgs a) async {
    final target = await HeadlessDocumentEditor.resolve(
      ctx.session,
      ctx.actor,
      a.requireUuid('uuid'),
    );
    final (_, version) = await VersionService.requireVersion(
      ctx.session,
      ctx.actor,
      target.item.uuid,
      a.integer('version_id')!,
    );
    final revision = version.revision;
    if (revision == null) {
      throw McpToolException(
        McpErrorCode.unsupported,
        'This version has no document revision.',
      );
    }
    final content = await DocumentStore.contentAt(
      ctx.session,
      target.document,
      revision,
    );
    final format = a.string('format') ?? 'markdown';
    final read = const DocumentReader().read(
      content,
      format: switch (format) {
        'text' => ReadFormat.text,
        'delta' => ReadFormat.delta,
        _ => ReadFormat.markdown,
      },
      maxChars: 200000,
    );
    return ToolResult(
      {
        'document_uuid': target.item.uuid.uuid,
        'version_id': version.id,
        'revision': revision,
        'format': format == 'values' ? 'markdown' : format,
        'content': read.content,
        'truncated': read.truncated,
      },
      text: read.content is String
          ? read.content as String
          : jsonEncode(read.content),
    );
  }

  static Future<ToolResult> restoreVersion(ToolContext ctx, ToolArgs a) async {
    final target = await HeadlessDocumentEditor.resolve(
      ctx.session,
      ctx.actor,
      a.requireUuid('uuid'),
      min: Role.editor,
    );
    final r = await VersionService.restore(
      ctx.session,
      ctx.actor,
      target.item.uuid,
      a.integer('version_id')!,
    );
    String? changeId;
    if (r.revision != null) {
      final op = await DocumentOp.db.findFirstRow(
        ctx.session,
        where: (t) =>
            t.documentId.equals(target.document.id!) &
            t.revision.equals(r.revision!),
      );
      if (op != null) {
        changeId = op.clientOpId.uuid;
        await HeadlessDocumentEditor.recordChange(
          ctx.session,
          HeadlessChange(
            changeId: op.clientOpId,
            kind: 'content',
            itemId: target.item.id!,
            documentId: target.document.id,
            revision: op.revision,
            inverseJson: op.inverseJson,
            userId: ctx.actor.userId,
            actorKind: ctx.actor.kind,
            label: 'Restore version',
            toolName: 'versions.restore',
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    }
    return ToolResult({
      'document_uuid': target.item.uuid.uuid,
      'revision': r.revision,
      'restore_point': versionJson(r.restorePoint),
      'change_id': changeId,
    }, text: 'Restored the version (restore point saved)');
  }

  // -------------------------------------------------------------- changes

  static Future<ToolResult> revert(ToolContext ctx, ToolArgs a) async {
    final r = await HeadlessDocumentEditor.revert(
      ctx,
      a.requireString('change_id'),
    );
    return ToolResult(r, text: '${r['summary']}');
  }
}
