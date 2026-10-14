import 'dart:async';

import 'package:wonky_client/wonky_client.dart';

import 'assistant_api.dart';

/// An in-memory [AssistantApi] for widget tests: scripted chat events per
/// message, recorded calls, threads kept in memory.
class FakeAssistantApi implements AssistantApi {
  FakeAssistantApi({AssistantStatus? status})
    : status =
          status ??
          AssistantStatus(
            available: true,
            quality: AiQuality.best,
            tokensUsedToday: 0,
            dailyTokenBudget: 1000000,
          );

  AssistantStatus status;

  /// Events of the next chats, in order (one list per message). A chat
  /// without a script answers "OK".
  final List<List<AssistantEvent>> chatScripts = [];

  /// When set, chats stay open until [releaseChat] (Stop / streaming tests).
  bool holdChats = false;
  StreamController<AssistantEvent>? _held;

  /// Inline scripts (one per request).
  final List<List<InlineAiEvent>> inlineScripts = [];
  final List<List<ProofreadEvent>> proofreadScripts = [];

  final List<String> sent = [];
  final List<AssistantContextHints> sentHints = [];
  final List<InlineAiRequest> inlineRequests = [];
  final List<String> reverted = [];
  final List<(String, bool)> confirmations = [];
  int stops = 0;

  final Map<int, AssistantThreadDetail> threads = {};
  int _nextThread = 1;

  @override
  Future<AssistantStatus> getStatus() async => status;

  @override
  Future<AssistantStatus> setQuality(AiQuality quality) async {
    status = status.copyWith(quality: quality);
    return status;
  }

  /// Keys saved through [setProviderKey] (provider, key), in order.
  final List<(AiProvider, String)> savedKeys = [];

  @override
  Future<AssistantStatus> setProviderKey(
    AiProvider provider,
    String apiKey,
  ) async {
    savedKeys.add((provider, apiKey));
    final k = apiKey.trim();
    status = status.copyWith(
      available: true,
      reason: null,
      message: null,
      provider: provider,
      keySource: 'user',
      userKey: AiProviderKeyView(
        provider: provider,
        last4: k.length <= 4 ? k : k.substring(k.length - 4),
        updatedAt: DateTime.utc(2026),
      ),
    );
    return status;
  }

  @override
  Future<AssistantStatus> removeProviderKey() async {
    status = AssistantStatus(
      available: false,
      reason: 'notConfigured',
      quality: status.quality,
      tokensUsedToday: status.tokensUsedToday,
      dailyTokenBudget: status.dailyTokenBudget,
      userKeysAllowed: status.userKeysAllowed,
    );
    return status;
  }

  @override
  Stream<AssistantEvent> chat({
    required int? threadId,
    required UuidValue itemUuid,
    required String message,
    required AssistantContextHints hints,
  }) {
    sent.add(message);
    sentHints.add(hints);
    final id = threadId ?? _nextThread++;
    threads.putIfAbsent(
      id,
      () => AssistantThreadDetail(
        thread: AssistantThreadView(
          id: id,
          itemUuid: itemUuid,
          title: message,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        messages: [],
      ),
    );
    final script = chatScripts.isEmpty
        ? [
            AssistantEvent(type: AssistantEventType.textDelta, text: 'OK'),
            AssistantEvent(type: AssistantEventType.done, text: 'OK'),
          ]
        : chatScripts.removeAt(0);
    final events = [
      AssistantEvent(
        type: AssistantEventType.started,
        threadId: id,
        runId: 'run-$id-${sent.length}',
      ),
      for (final e in script)
        e.copyWith(threadId: id, runId: e.runId ?? 'run-$id-${sent.length}'),
    ];
    if (!holdChats) return Stream.fromIterable(events);
    final c = StreamController<AssistantEvent>();
    _held = c;
    for (final e in events.where((e) => e.type != AssistantEventType.done)) {
      c.add(e);
    }
    return c.stream;
  }

  /// Ends a held chat with `done` ([stopped]: as after Stop).
  Future<void> releaseChat({bool stopped = false}) async {
    final c = _held;
    if (c == null) return;
    _held = null;
    c.add(
      AssistantEvent(
        type: AssistantEventType.done,
        errorCode: stopped ? 'stopped' : null,
      ),
    );
    await c.close();
  }

  @override
  Future<bool> stop({int? threadId, String? runId}) async {
    stops++;
    await releaseChat(stopped: true);
    return true;
  }

  @override
  Future<bool> confirm(String runId, String confirmationId, bool allow) async {
    confirmations.add((confirmationId, allow));
    return true;
  }

  /// Answers of `uiToolCall` events, in order.
  final List<UiBridgeResponse> uiResults = [];

  @override
  Future<bool> uiToolResult(String runId, UiBridgeResponse response) async {
    uiResults.add(response);
    return true;
  }

  @override
  Future<List<AssistantThreadView>> listThreads(UuidValue itemUuid) async => [
    for (final t in threads.values) t.thread,
  ];

  @override
  Future<AssistantThreadDetail> getThread(int threadId) async =>
      threads[threadId] ??
      (throw WonkyException(
        code: WonkyErrorCode.notFound,
        message: 'Conversation not found.',
      ));

  @override
  Future<void> deleteThread(int threadId) async => threads.remove(threadId);

  @override
  Future<int> clearHistory() async {
    final n = threads.length;
    threads.clear();
    return n;
  }

  @override
  Future<void> revertChange(String changeId) async => reverted.add(changeId);

  @override
  Stream<InlineAiEvent> inline(InlineAiRequest request) {
    inlineRequests.add(request);
    final script = inlineScripts.isEmpty
        ? [InlineAiEvent(type: InlineAiEventType.done, markdown: 'OK')]
        : inlineScripts.removeAt(0);
    return Stream.fromIterable(script);
  }

  @override
  Stream<ProofreadEvent> proofread(
    UuidValue itemUuid, {
    int? start,
    int? length,
  }) => Stream.fromIterable(
    proofreadScripts.isEmpty
        ? [ProofreadEvent(type: 'done')]
        : proofreadScripts.removeAt(0),
  );
}
