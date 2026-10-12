import 'package:serverpod/serverpod.dart';

import '../../write/ai/inline_ai_service.dart';
import '../../write/ai/proofread_service.dart';
import '../common/models.dart';
import '../users/user_service.dart';
import 'ai_usage_service.dart';
import 'assistant_service.dart';

/// The AI assistant (suite 10 §2, Write 09 §5). Model calls happen here on
/// the server; the API key never reaches clients.
class AssistantEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Whether the assistant can be used, the quality setting and today's
  /// usage.
  Future<AssistantStatus> getStatus(Session session) async {
    final actor = await UserService.actorOf(session);
    return AiUsageService.status(session, actor.userId);
  }

  /// Settings › AI › Quality.
  Future<AssistantStatus> setQuality(Session session, AiQuality quality) async {
    final actor = await UserService.actorOf(session);
    await AiUsageService.setQuality(session, actor.userId, quality);
    return AiUsageService.status(session, actor.userId);
  }

  /// Sends a message ([threadId] null = new thread on [itemUuid]) and
  /// streams the run: `started` (thread + run id), text deltas, progress
  /// notes, tool activity, confirmations, usage, then `done`.
  Stream<AssistantEvent> chat(
    Session session,
    int? threadId,
    UuidValue itemUuid,
    String message,
    AssistantContextHints hints,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* await AssistantService.chat(
      session,
      actor,
      threadId: threadId,
      itemUuid: itemUuid,
      message: message,
      hints: hints,
    );
  }

  /// Stops a run ([runId]) or every run of [threadId].
  Future<bool> stop(Session session, int? threadId, String? runId) async {
    final actor = await UserService.actorOf(session);
    return AssistantService.stop(
      actor.userId,
      runId: runId,
      threadId: threadId,
    );
  }

  /// Answers a destructive-change confirmation (Allow / Deny).
  Future<bool> confirm(
    Session session,
    String runId,
    String confirmationId,
    bool allow,
  ) async {
    final actor = await UserService.actorOf(session);
    return AssistantService.confirm(
      actor.userId,
      runId,
      confirmationId,
      allow: allow,
    );
  }

  /// Threads of the user on [itemUuid], newest first.
  Future<List<AssistantThreadView>> listThreads(
    Session session,
    UuidValue itemUuid,
  ) async => AssistantService.listThreads(
    session,
    await UserService.actorOf(session),
    itemUuid,
  );

  Future<AssistantThreadDetail> getThread(Session session, int threadId) async =>
      AssistantService.getThread(
        session,
        await UserService.actorOf(session),
        threadId,
      );

  Future<void> deleteThread(Session session, int threadId) async =>
      AssistantService.deleteThread(
        session,
        await UserService.actorOf(session),
        threadId,
      );

  /// Deletes every conversation of the user; returns how many.
  Future<int> clearHistory(Session session) async =>
      AssistantService.clearHistory(session, await UserService.actorOf(session));

  /// Reverts an assistant change by its `change_id` (panel Undo fallback).
  Future<void> revertChange(Session session, String changeId) async {
    await AssistantService.revertChange(
      session,
      await UserService.actorOf(session),
      changeId,
    );
  }

  /// Inline AI: rewrite a selection, continue writing, explain, summarize,
  /// generate an outline (Write 09 §5.3–5.5).
  Stream<InlineAiEvent> inline(Session session, InlineAiRequest request) async* {
    final actor = await UserService.actorOf(session);
    yield* await InlineAiService.run(session, actor, request);
  }

  /// Proofreads the document (or a range): streams validated issues per
  /// section.
  Stream<ProofreadEvent> proofread(
    Session session,
    UuidValue itemUuid,
    int? start,
    int? length,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* await ProofreadService.run(
      session,
      actor,
      itemUuid,
      start: start,
      length: length,
    );
  }
}
