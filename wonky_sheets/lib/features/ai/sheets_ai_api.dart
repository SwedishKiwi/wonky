import 'package:wonky_client/wonky_client.dart';

/// The Sheets AI endpoints (`sheetsAi`, Sheets 12 §6.3–6.10) and the undo of
/// server-side changes (`sheets.revertChange` / `reapplyChange`), behind an
/// interface so widget tests use a fake.
abstract class SheetsAiApi {
  /// Formula from natural language for [cell] (A1 with sheet).
  Future<SheetsFormulaSuggestion> suggestFormula(
    UuidValue itemUuid,
    String cell,
    String prompt,
  );

  /// Streams a plain-language explanation of the formula in [cell].
  Stream<InlineAiEvent> explainFormula(UuidValue itemUuid, String cell);

  /// Fill with AI proposals for the empty cells of a column [range].
  Future<SheetsFillProposal> fillRange(
    UuidValue itemUuid,
    String range,
    String? instructions,
  );

  /// Writes accepted fill proposals as one server change.
  Future<SheetsAiApplyResult> applyFill(
    UuidValue itemUuid,
    String range,
    List<SheetsFillRow> rows,
  );

  /// Prompt chips of *Analyze with AI* / Explore (deterministic).
  Future<List<String>> analyzeChips(UuidValue itemUuid, String? range);

  /// An alt-text proposal for a chart.
  Future<String> describeChart(UuidValue itemUuid, String chartId);

  /// The AI changes preview of a Suggest-mode run.
  Future<SheetsAiPreview> getPreview(String previewId);

  /// Applies the selected calls (null = all) as one server change.
  Future<SheetsAiApplyResult> applyPreview(
    String previewId,
    List<String>? callIds,
  );

  Future<void> discardPreview(String previewId);

  /// Undo of a server change (`sheets.serverChange`).
  Future<RevertResult> revertChange(UuidValue changeId);

  /// Redo of a reverted server change.
  Future<RevertResult> reapplyChange(UuidValue changeId);
}

/// [SheetsAiApi] over the generated client.
class ServerSheetsAiApi implements SheetsAiApi {
  ServerSheetsAiApi(this.client);

  final Client client;

  EndpointSheetsAi get _ai => client.sheetsAi;

  @override
  Future<SheetsFormulaSuggestion> suggestFormula(
    UuidValue itemUuid,
    String cell,
    String prompt,
  ) => _ai.suggestFormula(itemUuid, cell, prompt);

  @override
  Stream<InlineAiEvent> explainFormula(UuidValue itemUuid, String cell) =>
      _ai.explainFormula(itemUuid, cell);

  @override
  Future<SheetsFillProposal> fillRange(
    UuidValue itemUuid,
    String range,
    String? instructions,
  ) => _ai.fillRange(itemUuid, range, instructions);

  @override
  Future<SheetsAiApplyResult> applyFill(
    UuidValue itemUuid,
    String range,
    List<SheetsFillRow> rows,
  ) => _ai.applyFill(itemUuid, range, rows);

  @override
  Future<List<String>> analyzeChips(UuidValue itemUuid, String? range) =>
      _ai.analyzeChips(itemUuid, range);

  @override
  Future<String> describeChart(UuidValue itemUuid, String chartId) =>
      _ai.describeChart(itemUuid, chartId);

  @override
  Future<SheetsAiPreview> getPreview(String previewId) =>
      _ai.getPreview(previewId);

  @override
  Future<SheetsAiApplyResult> applyPreview(
    String previewId,
    List<String>? callIds,
  ) => _ai.applyPreview(previewId, callIds);

  @override
  Future<void> discardPreview(String previewId) =>
      _ai.discardPreview(previewId);

  @override
  Future<RevertResult> revertChange(UuidValue changeId) =>
      client.sheets.revertChange(changeId);

  @override
  Future<RevertResult> reapplyChange(UuidValue changeId) =>
      client.sheets.reapplyChange(changeId);
}

/// Used when there is no client (widget tests without a fake): every call
/// fails with "AI isn't configured".
class UnavailableSheetsAiApi implements SheetsAiApi {
  const UnavailableSheetsAiApi();

  static WonkyException get _error => WonkyException(
    code: WonkyErrorCode.unavailable,
    message: "AI isn't configured on this server.",
  );

  @override
  Future<SheetsFormulaSuggestion> suggestFormula(
    UuidValue itemUuid,
    String cell,
    String prompt,
  ) async => throw _error;

  @override
  Stream<InlineAiEvent> explainFormula(UuidValue itemUuid, String cell) =>
      Stream.error(_error);

  @override
  Future<SheetsFillProposal> fillRange(
    UuidValue itemUuid,
    String range,
    String? instructions,
  ) async => throw _error;

  @override
  Future<SheetsAiApplyResult> applyFill(
    UuidValue itemUuid,
    String range,
    List<SheetsFillRow> rows,
  ) async => throw _error;

  @override
  Future<List<String>> analyzeChips(UuidValue itemUuid, String? range) async =>
      const [];

  @override
  Future<String> describeChart(UuidValue itemUuid, String chartId) async =>
      throw _error;

  @override
  Future<SheetsAiPreview> getPreview(String previewId) async => throw _error;

  @override
  Future<SheetsAiApplyResult> applyPreview(
    String previewId,
    List<String>? callIds,
  ) async => throw _error;

  @override
  Future<void> discardPreview(String previewId) async {}

  @override
  Future<RevertResult> revertChange(UuidValue changeId) async => throw _error;

  @override
  Future<RevertResult> reapplyChange(UuidValue changeId) async => throw _error;
}
