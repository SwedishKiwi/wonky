import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show McpScope, Role;
import 'package:wonky_write_core/wonky_write_core.dart'
    show BlockType, Delta, DeltaUtils, WonkyDocument;

import '../../write/ai/write_context_builder.dart';
import '../../write/ai/write_prompts.dart';
import '../../write/mcp/headless_editor.dart';
import '../common/actor.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../mcp/tool_executor.dart';
import '../mcp/tool_support.dart';
import '../mcp/wonky_mcp_server.dart';
import 'ai_config.dart';
import 'ai_models.dart';
import 'ai_usage_service.dart';
import 'anthropic/anthropic_client.dart';
import 'assistant_tools.dart';

/// A running assistant loop (for `stop` and destructive confirmations).
class AssistantRun {
  AssistantRun(this.runId, this.userId, this.threadId);

  final String runId;
  final int userId;
  final int threadId;
  final AiCancelToken cancel = AiCancelToken();
  final Map<String, Completer<bool>> confirmations = {};
}

/// One tool chip of the panel (persisted in `toolCallsJson`).
class AssistantToolActivity {
  AssistantToolActivity({
    required this.toolUseId,
    required this.toolName,
    required this.summary,
    this.error = false,
    this.changeId,
    this.rangeStart,
    this.rangeLength,
    this.revision,
  });

  final String toolUseId;
  final String toolName;
  String summary;
  bool error;
  String? changeId;
  int? rangeStart;
  int? rangeLength;
  int? revision;

  Map<String, Object?> toJson() => {
    'toolUseId': toolUseId,
    'toolName': toolName,
    'summary': summary,
    if (error) 'error': true,
    'changeId': ?changeId,
    'rangeStart': ?rangeStart,
    'rangeLength': ?rangeLength,
    'revision': ?revision,
  };
}

/// The assistant agent loop (suite 10 §2): builds the request (tools →
/// frozen system prompt → document snapshot → conversation, caching in
/// that order), streams the answer, executes tool calls through the MCP
/// [ToolExecutor] (in parallel, results in one user message), and loops
/// until the model ends its turn. Every op of a run carries the run id as
/// `groupId` and the requesting app session as `onBehalfOfSessionId`, so
/// the run is one undo step "AI: …" on that client (Write 09 §5.2).
abstract final class AssistantService {
  static final Map<String, AssistantRun> _runs = {};

  /// Runs of [userId] (tests).
  static Iterable<AssistantRun> runsOf(int userId) =>
      _runs.values.where((r) => r.userId == userId);

  /// Destructive guard (Write 09 §5.8).
  static const guardChars = 2000;
  static const guardFraction = 0.3;

  /// How long a confirmation waits for the user.
  static Duration confirmationTimeout = const Duration(minutes: 10);

  /// Tool results are capped at this many characters.
  static const maxToolResultChars = 50000;

  static const refusalText = "The assistant can't help with that request.";

  // ------------------------------------------------------------------ chat

  /// Sends [message] in [threadId] (null = a new thread on [itemUuid]) and
  /// streams the run. Checks run before the stream starts (availability,
  /// budget, concurrency, access).
  static Future<Stream<AssistantEvent>> chat(
    Session session,
    Actor actor, {
    required int? threadId,
    required UuidValue itemUuid,
    required String message,
    required AssistantContextHints hints,
    ToolExecutor? executor,
    Future<Session> Function()? runSession,
  }) async {
    final text = message.trim();
    if (text.isEmpty) throw Errors.invalid('The message is empty.');
    if (text.length > 20000) throw Errors.tooLarge('The message is too long.');
    await AiUsageService.requireAvailable(session, actor.userId);
    final target = await HeadlessDocumentEditor.resolve(
      session,
      actor,
      itemUuid,
    );
    AssistantThread thread;
    if (threadId != null) {
      final t = await AssistantThread.db.findById(session, threadId);
      if (t == null || t.userId != actor.userId) {
        throw Errors.notFound('Conversation');
      }
      if (t.itemId != target.item.id) {
        throw Errors.invalid('The conversation belongs to another file.');
      }
      thread = t;
    } else {
      thread = await AssistantThread.db.insertRow(
        session,
        AssistantThread(
          userId: actor.userId,
          itemId: target.item.id,
          title: _title(text),
          createdAt: nowUtc(),
          updatedAt: nowUtc(),
        ),
      );
    }
    final busyRun = _runs.values.where((r) => r.threadId == thread.id);
    if (busyRun.isNotEmpty) {
      throw Errors.busy('The assistant is still answering in this chat.');
    }
    final release = AiUsageService.acquire(actor.userId);
    final run = AssistantRun(
      const Uuid().v7(),
      actor.userId,
      thread.id!,
    );
    _runs[run.runId] = run;
    final out = StreamController<AssistantEvent>();
    out.onCancel = run.cancel.cancel;
    final quality = await AiUsageService.quality(session, actor.userId);
    Future<void> body() async {
      final s = runSession == null
          ? await session.serverpod.createSession(enableLogging: false)
          : await runSession();
      try {
        await _Loop(
          session: s,
          actor: actor,
          ar: run,
          thread: thread,
          target: target,
          message: text,
          hints: hints,
          quality: quality,
          executor: executor ?? WonkyMcpServer.executor,
          emit: (e) {
            if (!out.isClosed) out.add(e);
          },
        ).execute();
      } finally {
        if (runSession == null) await s.close();
      }
    }

    unawaited(
      body()
          .catchError((Object e, StackTrace st) {
            session.serverpod.logVerbose('Assistant run failed: $e\n$st');
            if (!out.isClosed) {
              out.add(
                AssistantEvent(
                  type: AssistantEventType.error,
                  threadId: run.threadId,
                  runId: run.runId,
                  error: 'Something went wrong. Please try again.',
                  errorCode: 'internal',
                ),
              );
            }
          })
          .whenComplete(() {
            release();
            _runs.remove(run.runId);
            for (final c in run.confirmations.values) {
              if (!c.isCompleted) c.complete(false);
            }
            if (!out.isClosed) unawaited(out.close());
          }),
    );
    return out.stream;
  }

  static String _title(String message) {
    final line = message.split('\n').first.trim();
    return line.length <= 60 ? line : '${line.substring(0, 57)}…';
  }

  /// Stops the user's run [runId], or every run in [threadId].
  static bool stop(int userId, {String? runId, int? threadId}) {
    var stopped = false;
    for (final r in _runs.values.toList()) {
      if (r.userId != userId) continue;
      if (runId != null && r.runId != runId) continue;
      if (threadId != null && r.threadId != threadId) continue;
      r.cancel.cancel();
      for (final c in r.confirmations.values) {
        if (!c.isCompleted) c.complete(false);
      }
      stopped = true;
    }
    return stopped;
  }

  /// Answers a destructive-change confirmation.
  static bool confirm(
    int userId,
    String runId,
    String confirmationId, {
    required bool allow,
  }) {
    final r = _runs[runId];
    if (r == null || r.userId != userId) return false;
    final c = r.confirmations[confirmationId];
    if (c == null || c.isCompleted) return false;
    c.complete(allow);
    return true;
  }

  // --------------------------------------------------------------- threads

  static AssistantThreadView _view(AssistantThread t, UuidValue? itemUuid) =>
      AssistantThreadView(
        id: t.id!,
        itemUuid: itemUuid,
        title: t.title,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
      );

  /// Threads of the user on [itemUuid], newest first.
  static Future<List<AssistantThreadView>> listThreads(
    Session session,
    Actor actor,
    UuidValue itemUuid,
  ) async {
    final target = await HeadlessDocumentEditor.resolve(
      session,
      actor,
      itemUuid,
    );
    final rows = await AssistantThread.db.find(
      session,
      where: (t) =>
          t.userId.equals(actor.userId) & t.itemId.equals(target.item.id),
      orderBy: (t) => t.updatedAt.desc(),
      limit: 100,
    );
    return [for (final r in rows) _view(r, target.item.uuid)];
  }

  static Future<AssistantThread> _own(
    Session session,
    Actor actor,
    int threadId,
  ) async {
    final t = await AssistantThread.db.findById(session, threadId);
    if (t == null || t.userId != actor.userId) {
      throw Errors.notFound('Conversation');
    }
    return t;
  }

  /// A thread with its visible messages.
  static Future<AssistantThreadDetail> getThread(
    Session session,
    Actor actor,
    int threadId,
  ) async {
    final t = await _own(session, actor, threadId);
    final item = t.itemId == null
        ? null
        : await DriveItem.db.findById(session, t.itemId!);
    final rows = await AssistantMessage.db.find(
      session,
      where: (m) => m.threadId.equals(threadId) & m.visible.equals(true),
      orderBy: (m) => m.id,
    );
    return AssistantThreadDetail(
      thread: _view(t, item?.uuid),
      messages: [
        for (final m in rows)
          AssistantMessageView(
            id: m.id!,
            role: m.role,
            displayText: m.displayText,
            toolCallsJson: m.toolCallsJson,
            runId: m.runId,
            stopReason: m.stopReason,
            createdAt: m.createdAt,
          ),
      ],
    );
  }

  static Future<void> deleteThread(
    Session session,
    Actor actor,
    int threadId,
  ) async {
    final t = await _own(session, actor, threadId);
    stop(actor.userId, threadId: threadId);
    await AssistantThread.db.deleteRow(session, t);
  }

  /// Settings › AI › Clear history: deletes every thread of the user.
  static Future<int> clearHistory(Session session, Actor actor) async {
    stop(actor.userId);
    final rows = await AssistantThread.db.deleteWhere(
      session,
      where: (t) => t.userId.equals(actor.userId),
    );
    return rows.length;
  }

  /// Reverts an assistant change (panel Undo when the client's undo step
  /// is gone): `changes.revert` as the assistant.
  static Future<Map<String, Object?>> revertChange(
    Session session,
    Actor actor,
    String changeId,
  ) => HeadlessDocumentEditor.revert(
    ToolContext(
      session: session,
      actor: actor.copyWith(kind: ActorKind.ai),
      scopes: {McpScope.writeRead, McpScope.writeEdit},
    ),
    changeId,
  );

  /// The destructive guard of [doc]: refuses a change that deletes more
  /// than [guardChars] characters or [guardFraction] of the document.
  static McpToolException? guardViolation(Delta head, Delta change) {
    var deleted = 0;
    var pos = 0;
    final ranges = <(int, int)>[];
    for (final op in change.toList()) {
      final len = op.length ?? 0;
      if (op.isDelete) {
        deleted += len;
        ranges.add((pos, len));
        pos += len;
      } else if (op.isRetain) {
        pos += len;
      }
    }
    final docLen = DeltaUtils.documentLength(head);
    if (deleted == 0) return null;
    if (deleted <= guardChars &&
        (docLen < 400 || deleted <= docLen * guardFraction)) {
      return null;
    }
    final doc = WonkyDocument(head);
    final headings = <String>{};
    for (final r in ranges) {
      for (final line in doc.linesInRange(r.$1, r.$2)) {
        if (line.format.type == BlockType.heading) {
          headings.add(line.text.trim());
        }
      }
    }
    final paragraphs = ranges.fold<int>(
      0,
      (n, r) => n + doc.linesInRange(r.$1, r.$2).length,
    );
    final pct = (deleted * 100 / (docLen == 0 ? 1 : docLen)).round();
    final what = headings.isEmpty
        ? '$paragraphs paragraph${paragraphs == 1 ? '' : 's'}'
        : '$paragraphs paragraph${paragraphs == 1 ? '' : 's'} '
              '(${headings.take(3).join(', ')}${headings.length > 3 ? '…' : ''})';
    return McpToolException(
      'needs_confirmation',
      'This change deletes $deleted characters ($pct% of the document). '
          'The user must confirm it.',
      details: {
        'deleted_chars': deleted,
        'percent': pct,
        'summary': 'The assistant wants to delete $what',
        'headings': headings.toList(),
      },
    );
  }

  /// A short "what the tool is doing" label for the panel chip.
  static String startLabel(String tool) => switch (tool) {
    'write.get_document' => 'Reading the document',
    'write.get_outline' => 'Reading the outline',
    'write.get_stats' => 'Counting words',
    'write.search' => 'Searching the document',
    'write.get_page_setup' => 'Reading the page setup',
    'write.insert_markdown' => 'Adding text',
    'write.replace_text' => 'Replacing text',
    'write.replace_range' => 'Rewriting text',
    'write.delete_range' => 'Deleting text',
    'write.apply_format' => 'Formatting text',
    'write.set_block_type' => 'Changing block types',
    'write.insert_table' => 'Inserting a table',
    'write.update_table' => 'Editing a table',
    'write.list_suggestions' => 'Reading suggestions',
    'write.suggest_edit' => 'Suggesting an edit',
    'write.accept_suggestion' => 'Accepting suggestions',
    'write.reject_suggestion' => 'Rejecting suggestions',
    'comments.list' => 'Reading comments',
    'comments.create' => 'Adding a comment',
    'comments.reply' => 'Replying to a comment',
    'versions.list' => 'Reading the version history',
    'versions.get' => 'Reading a version',
    'write.list_themes' => 'Looking at themes',
    'write.apply_theme' => 'Applying a theme',
    'write.update_page_setup' => 'Changing the page setup',
    _ => 'Working',
  };
}

/// One run of the loop.
class _Loop {
  _Loop({
    required this.session,
    required this.actor,
    required this.ar,
    required this.thread,
    required this.target,
    required this.message,
    required this.hints,
    required this.quality,
    required this.executor,
    required this.emit,
  });

  final Session session;
  final Actor actor;
  final AssistantRun ar;
  AssistantThread thread;
  final WriteTarget target;
  final String message;
  final AssistantContextHints hints;
  final AiQuality quality;
  final ToolExecutor executor;
  final void Function(AssistantEvent) emit;

  final List<Map<String, Object?>> _messages = [];
  final StringBuffer _answer = StringBuffer();
  int? _lastAssistantId;

  AssistantEvent _ev(AssistantEventType type, {String? text}) => AssistantEvent(
    type: type,
    threadId: ar.threadId,
    runId: ar.runId,
    text: text,
  );

  Future<void> execute() async {
    final client = AiConfig.client;
    if (client == null) {
      emit(
        _ev(AssistantEventType.error)
          ..error = AiUsageService.notConfiguredMessage
          ..errorCode = AiUsageService.notConfigured,
      );
      return;
    }
    final role = target.role;
    final applyMode = role < Role.editor
        ? AiApplyMode.suggest
        : hints.applyMode;
    final toolset = AssistantToolset.write(
      executor,
      canDecideSuggestions: role >= Role.editor,
    );
    final runner = AssistantToolRunner(
      executor: executor,
      toolset: toolset,
      itemUuid: target.item.uuid,
      itemId: target.item.id!,
    );

    await _loadHistory();
    final userMessageId = await _appendUserTurn(applyMode);
    emit(_ev(AssistantEventType.started)..messageId = userMessageId);

    final tier = AiTier.chat(quality);
    final system = [
      {
        'type': 'text',
        'text': WritePrompts.assistant,
        'cache_control': {'type': 'ephemeral'},
      },
    ];
    final config = AiConfig.current;
    var stoppedEarly = true;
    for (var round = 0; round < config.maxToolRounds; round++) {
      if (ar.cancel.isCancelled) break;
      try {
        await AiUsageService.requireBudget(session, actor.userId);
      } on WonkyException catch (e) {
        emit(
          _ev(AssistantEventType.error)
            ..error = e.message
            ..errorCode = 'budget',
        );
        stoppedEarly = false;
        break;
      }
      final request = AnthropicRequest(
        model: tier.model,
        effort: tier.effort,
        system: system,
        tools: toolset.apiTools,
        messages: List.of(_messages),
        userId: 'u${actor.userId}',
        feature: 'chat',
      );
      AnthropicMessage msg;
      final progress = <int, StringBuffer>{};
      try {
        msg = await client.send(
          request,
          cancel: ar.cancel,
          onText: (t) {
            _answer.write(t);
            emit(_ev(AssistantEventType.textDelta, text: t));
          },
          onThinking: (i, t) {
            // Progress notes (display "updates"): the whole note so far.
            final note = (progress[i] ??= StringBuffer())..write(t);
            final text = note.toString().trim();
            if (text.isNotEmpty) {
              emit(_ev(AssistantEventType.progress, text: text));
            }
          },
        );
      } on AiCancelledException {
        break;
      } on AnthropicApiException catch (e) {
        emit(
          _ev(AssistantEventType.error)
            ..error = AssistantErrors.message(e)
            ..errorCode = AssistantErrors.code(e),
        );
        stoppedEarly = false;
        break;
      }
      await AiUsageService.record(
        session,
        userId: actor.userId,
        model: msg.model ?? tier.model,
        feature: 'chat',
        usage: msg.usage,
      );
      emit(
        _ev(AssistantEventType.usage)
          ..inputTokens = msg.usage.inputTokens
          ..outputTokens = msg.usage.outputTokens
          ..cacheReadTokens = msg.usage.cacheReadTokens,
      );

      // Always check stop_reason before using the content.
      final stop = msg.stopReason;
      if (stop == 'refusal') {
        await _persistAssistant(
          const [],
          AssistantService.refusalText,
          stop: 'refusal',
          replay: false,
        );
        emit(
          _ev(AssistantEventType.refusal, text: AssistantService.refusalText),
        );
        stoppedEarly = false;
        break;
      }
      final content = msg.replayContent;
      final toolUses = [
        for (final b in content)
          if (b['type'] == 'tool_use') b,
      ];
      final assistantId = await _persistAssistant(
        content,
        msg.text,
        stop: stop,
        replay: content.isNotEmpty,
      );
      if (content.isNotEmpty) {
        _messages.add({'role': 'assistant', 'content': content});
      }

      if (stop == 'pause_turn') continue;
      if (toolUses.isNotEmpty) {
        if (stop == 'max_tokens' || stop == 'model_context_window_exceeded') {
          // A cut-off tool call is never executed; answer it so the
          // history stays valid, then offer "Continue".
          await _appendToolResults([
            for (final t in toolUses)
              _toolResult(
                '${t['id']}',
                jsonEncode({
                  'code': 'truncated',
                  'message':
                      'The output was cut off before this call was complete; '
                      'it was not executed.',
                }),
                isError: true,
              ),
          ]);
          emit(_ev(AssistantEventType.maxTokens));
          stoppedEarly = false;
          break;
        }
        final activities = <AssistantToolActivity>[];
        final results = await Future.wait([
          for (final t in toolUses)
            _execute(
              runner,
              t,
              msg.invalidToolInputs,
              applyMode,
              activities,
            ),
        ]);
        await _setToolCalls(assistantId, activities);
        await _appendToolResults(results);
        if (ar.cancel.isCancelled) break;
        continue;
      }
      if (stop == 'max_tokens' || stop == 'model_context_window_exceeded') {
        emit(_ev(AssistantEventType.maxTokens));
      }
      stoppedEarly = false;
      break;
    }
    if (stoppedEarly && !ar.cancel.isCancelled) {
      emit(
        _ev(AssistantEventType.error)
          ..error =
              'The assistant stopped after ${config.maxToolRounds} steps. '
              'Send a message to let it continue.'
          ..errorCode = 'max_rounds',
      );
    }
    thread = thread.copyWith(updatedAt: nowUtc());
    await AssistantThread.db.updateRow(session, thread);
    emit(
      _ev(AssistantEventType.done, text: _answer.toString())
        ..messageId = _lastAssistantId
        ..errorCode = ar.cancel.isCancelled ? 'stopped' : null,
    );
  }

  Future<void> _loadHistory() async {
    final rows = await AssistantMessage.db.find(
      session,
      where: (m) => m.threadId.equals(ar.threadId) & m.replay.equals(true),
      orderBy: (m) => m.id,
    );
    for (final m in rows) {
      final content = jsonDecode(m.contentJson ?? '[]');
      if (content is! List || content.isEmpty) continue;
      _messages.add({'role': m.role, 'content': content});
    }
  }

  /// Appends the user's turn: the frozen document snapshot (first turn,
  /// cached) or a "document updated" element, then the message with the
  /// volatile context at its end.
  Future<int> _appendUserTurn(AiApplyMode applyMode) async {
    final ctx = await WriteContextBuilder.load(session, target);
    final selection = WriteContextBuilder.selection(
      ctx,
      start: hints.selectionStart,
      length: hints.selectionLength,
      text: hints.selectionText,
    );
    final blocks = <Map<String, Object?>>[];
    final first = _messages.isEmpty;
    if (first) {
      blocks.add({
        'type': 'text',
        'text': WriteContextBuilder.snapshot(
          ctx,
          focusOffset: selection?.start ?? hints.selectionStart,
        ),
        'cache_control': {'type': 'ephemeral'},
      });
    } else if (thread.contextRevision != ctx.revision) {
      final update = WriteContextBuilder.update(
        previousMarkdown: thread.contextMarkdown,
        previousRevision: thread.contextRevision,
        now: ctx,
      );
      if (update != null) blocks.add({'type': 'text', 'text': update});
    }
    String? comments;
    if (hints.includeComments) {
      final out = await executor.call(
        ToolContext(
          session: session,
          actor: actor.copyWith(kind: ActorKind.ai),
          scopes: {McpScope.writeRead},
        ),
        'comments.list',
        {'uuid': target.item.uuid.uuid, 'status': 'open'},
      );
      comments = out.result?.text;
    }
    final caret = hints.selectionStart;
    blocks.add({
      'type': 'text',
      'text':
          '$message\n\n${WriteContextBuilder.volatile(
            c: ctx,
            applyMode: applyMode,
            role: target.role.name,
            selection: selection,
            caretHeadingPath: hints.caretHeadingPath ?? (caret == null ? null : WriteContextBuilder.headingPath(ctx, caret)),
            localTime: hints.localTime,
            comments: comments,
          )}',
    });
    thread = thread.copyWith(
      contextRevision: ctx.revision,
      contextMarkdown: ctx.markdown,
      updatedAt: nowUtc(),
    );
    await AssistantThread.db.updateRow(session, thread);
    final row = await AssistantMessage.db.insertRow(
      session,
      AssistantMessage(
        threadId: ar.threadId,
        role: 'user',
        contentJson: jsonEncode(blocks),
        displayText: message,
        runId: ar.runId,
        createdAt: nowUtc(),
      ),
    );
    _messages.add({'role': 'user', 'content': blocks});
    return row.id!;
  }

  Future<int> _persistAssistant(
    List<Map<String, Object?>> content,
    String text, {
    String? stop,
    required bool replay,
  }) async {
    final row = await AssistantMessage.db.insertRow(
      session,
      AssistantMessage(
        threadId: ar.threadId,
        role: 'assistant',
        contentJson: jsonEncode(content),
        displayText: text,
        visible: text.trim().isNotEmpty || stop == 'refusal',
        replay: replay,
        runId: ar.runId,
        stopReason: stop,
        createdAt: nowUtc(),
      ),
    );
    if (row.visible) _lastAssistantId = row.id;
    return row.id!;
  }

  Future<void> _setToolCalls(
    int messageId,
    List<AssistantToolActivity> a,
  ) async {
    if (a.isEmpty) return;
    final row = await AssistantMessage.db.findById(session, messageId);
    if (row == null) return;
    await AssistantMessage.db.updateRow(
      session,
      row.copyWith(
        toolCallsJson: jsonEncode([for (final x in a) x.toJson()]),
        visible: true,
      ),
    );
    _lastAssistantId = row.id;
  }

  Future<void> _appendToolResults(List<Map<String, Object?>> results) async {
    await AssistantMessage.db.insertRow(
      session,
      AssistantMessage(
        threadId: ar.threadId,
        role: 'user',
        contentJson: jsonEncode(results),
        displayText: '',
        visible: false,
        runId: ar.runId,
        createdAt: nowUtc(),
      ),
    );
    _messages.add({'role': 'user', 'content': results});
  }

  static Map<String, Object?> _toolResult(
    String id,
    String content, {
    bool isError = false,
  }) => {
    'type': 'tool_result',
    'tool_use_id': id,
    'content': content,
    if (isError) 'is_error': true,
  };

  ToolContext _toolContext({bool guarded = true}) => ToolContext(
    session: session,
    actor: actor.copyWith(kind: ActorKind.ai),
    scopes: {McpScope.writeRead, McpScope.writeEdit},
    clientName: 'Assistant',
    groupId: ar.runId,
    onBehalfOfSessionId: hints.documentSessionId,
    changeGuard: guarded
        ? (head, change, _) {
            final v = AssistantService.guardViolation(head, change);
            if (v != null) throw v;
          }
        : null,
  );

  Future<Map<String, Object?>> _execute(
    AssistantToolRunner runner,
    Map<String, Object?> block,
    Map<String, String> invalidInputs,
    AiApplyMode applyMode,
    List<AssistantToolActivity> activities,
  ) async {
    final id = '${block['id']}';
    final apiName = '${block['name']}';
    final tool = runner.toolset.byApiName(apiName);
    final mcpName = tool?.name ?? apiName;
    final activity = AssistantToolActivity(
      toolUseId: id,
      toolName: mcpName,
      summary: AssistantService.startLabel(mcpName),
    );
    activities.add(activity);
    emit(
      _ev(AssistantEventType.toolStarted)
        ..toolUseId = id
        ..toolName = mcpName
        ..toolSummary = activity.summary,
    );
    Map<String, Object?> finish(String content, {required bool error}) {
      activity.error = error;
      emit(
        _ev(AssistantEventType.toolFinished)
          ..toolUseId = id
          ..toolName = mcpName
          ..toolSummary = activity.summary
          ..toolError = error
          ..changeId = activity.changeId
          ..rangeStart = activity.rangeStart
          ..rangeLength = activity.rangeLength
          ..revision = activity.revision,
      );
      return _toolResult(id, content, isError: error);
    }

    final raw = invalidInputs[id];
    if (raw != null) {
      activity.summary = 'Invalid tool call';
      return finish(jsonEncode({'INVALID_JSON': raw}), error: true);
    }
    final input = (block['input'] as Map?)?.cast<String, Object?>() ?? {};
    var outcome = await runner.run(
      _toolContext(),
      apiName,
      input,
      applyMode: applyMode,
    );
    if (outcome.error?.code == 'needs_confirmation') {
      final details = outcome.error!.details;
      final summary = details is Map
          ? '${details['summary'] ?? outcome.error!.message}'
          : outcome.error!.message;
      final confirmationId = const Uuid().v4();
      final completer = Completer<bool>();
      ar.confirmations[confirmationId] = completer;
      emit(
        _ev(AssistantEventType.confirmationRequired)
          ..toolUseId = id
          ..toolName = mcpName
          ..toolSummary = summary
          ..confirmationId = confirmationId,
      );
      final allow = await completer.future.timeout(
        AssistantService.confirmationTimeout,
        onTimeout: () => false,
      );
      ar.confirmations.remove(confirmationId);
      if (!allow) {
        activity.summary = 'Deletion denied';
        return finish(
          jsonEncode({
            'code': 'denied_by_user',
            'message':
                'The user denied this change. Do not try to make it in '
                'another way; ask the user what they want instead.',
          }),
          error: true,
        );
      }
      outcome = await runner.run(
        _toolContext(guarded: false),
        apiName,
        input,
        applyMode: applyMode,
      );
    }
    final err = outcome.error;
    if (err != null) {
      activity.summary = '${activity.summary} failed';
      return finish(jsonEncode(err.toJson()), error: true);
    }
    final r = outcome.result!;
    final structured = r.structured;
    if (structured is Map) {
      final s = structured['summary'];
      if (s is String && s.isNotEmpty) activity.summary = s;
      final change = structured['change_id'];
      if (change is String) activity.changeId = change;
      final rev = structured['revision'];
      if (rev is int) activity.revision = rev;
      final range = structured['applied_range'];
      if (range is Map) {
        activity.rangeStart = (range['start'] as num?)?.toInt();
        activity.rangeLength = (range['length'] as num?)?.toInt();
      }
    }
    var text = mcpName == 'write.get_document'
        ? r.text
        : jsonEncode(_jsonSafe(structured ?? r.text));
    if (text.length > AssistantService.maxToolResultChars) {
      text =
          '${text.substring(0, AssistantService.maxToolResultChars)}\n'
          '[truncated: the result was longer than '
          '${AssistantService.maxToolResultChars} characters]';
    }
    return finish(text, error: false);
  }

  static Object? _jsonSafe(Object? v) => switch (v) {
    null || String() || num() || bool() => v,
    Map() => <String, Object?>{
      for (final e in v.entries) '${e.key}': _jsonSafe(e.value),
    },
    Iterable() => [for (final e in v) _jsonSafe(e)],
    UuidValue() => v.uuid,
    DateTime() => v.toUtc().toIso8601String(),
    _ => '$v',
  };
}

/// User-facing messages for API failures.
abstract final class AssistantErrors {
  static String message(AnthropicApiException e) {
    if (e.isAuth) {
      return "AI isn't configured correctly on this server (the API key was "
          'rejected).';
    }
    if (e.isRateLimit || e.isOverloaded) {
      return 'The AI service is busy right now. Try again in a moment.';
    }
    if (e.type == 'timeout') return 'The AI service took too long to answer.';
    if (e.statusCode == 0) {
      return 'The connection to the AI service was interrupted. Try again.';
    }
    if (e.statusCode == 413) return 'The request is too large for the model.';
    return 'The AI service returned an error. Try again.';
  }

  static String code(AnthropicApiException e) {
    if (e.isAuth) return 'auth';
    if (e.isRateLimit) return 'rate_limited';
    if (e.isOverloaded) return 'overloaded';
    if (e.type == 'timeout') return 'timeout';
    if (e.statusCode == 0) return 'connection';
    return 'api_error';
  }
}
