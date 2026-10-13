import 'package:wonky_client/wonky_client.dart';

/// The `assistant` endpoint (suite 10 §2), behind an interface so widget
/// tests use [FakeAssistantApi] (`package:wonky_app/testing.dart`).
abstract class AssistantApi {
  Future<AssistantStatus> getStatus();
  Future<AssistantStatus> setQuality(AiQuality quality);

  /// Settings › AI providers: stores the user's own key (the server never
  /// returns it).
  Future<AssistantStatus> setProviderKey(AiProvider provider, String apiKey);
  Future<AssistantStatus> removeProviderKey();
  Stream<AssistantEvent> chat({
    required int? threadId,
    required UuidValue itemUuid,
    required String message,
    required AssistantContextHints hints,
  });
  Future<bool> stop({int? threadId, String? runId});
  Future<bool> confirm(String runId, String confirmationId, bool allow);
  Future<List<AssistantThreadView>> listThreads(UuidValue itemUuid);
  Future<AssistantThreadDetail> getThread(int threadId);
  Future<void> deleteThread(int threadId);
  Future<int> clearHistory();
  Future<void> revertChange(String changeId);
  Stream<InlineAiEvent> inline(InlineAiRequest request);
  Stream<ProofreadEvent> proofread(
    UuidValue itemUuid, {
    int? start,
    int? length,
  });
}

/// [AssistantApi] over the generated client.
class ServerAssistantApi implements AssistantApi {
  ServerAssistantApi(this.client);

  final Client client;

  EndpointAssistant get _a => client.assistant;

  @override
  Future<AssistantStatus> getStatus() => _a.getStatus();

  @override
  Future<AssistantStatus> setQuality(AiQuality quality) =>
      _a.setQuality(quality);

  @override
  Future<AssistantStatus> setProviderKey(AiProvider provider, String apiKey) =>
      _a.setProviderKey(provider, apiKey);

  @override
  Future<AssistantStatus> removeProviderKey() => _a.removeProviderKey();

  @override
  Stream<AssistantEvent> chat({
    required int? threadId,
    required UuidValue itemUuid,
    required String message,
    required AssistantContextHints hints,
  }) => _a.chat(threadId, itemUuid, message, hints);

  @override
  Future<bool> stop({int? threadId, String? runId}) => _a.stop(threadId, runId);

  @override
  Future<bool> confirm(String runId, String confirmationId, bool allow) =>
      _a.confirm(runId, confirmationId, allow);

  @override
  Future<List<AssistantThreadView>> listThreads(UuidValue itemUuid) =>
      _a.listThreads(itemUuid);

  @override
  Future<AssistantThreadDetail> getThread(int threadId) =>
      _a.getThread(threadId);

  @override
  Future<void> deleteThread(int threadId) => _a.deleteThread(threadId);

  @override
  Future<int> clearHistory() => _a.clearHistory();

  @override
  Future<void> revertChange(String changeId) => _a.revertChange(changeId);

  @override
  Stream<InlineAiEvent> inline(InlineAiRequest request) => _a.inline(request);

  @override
  Stream<ProofreadEvent> proofread(
    UuidValue itemUuid, {
    int? start,
    int? length,
  }) => _a.proofread(itemUuid, start, length);
}
