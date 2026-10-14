import 'dart:async';

import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets/features/ai/sheets_ai_api.dart';

/// An in-memory [SheetsAiApi]: scripted answers, recorded calls.
class FakeSheetsAiApi implements SheetsAiApi {
  final List<(String cell, String prompt)> suggestCalls = [];
  SheetsFormulaSuggestion Function(String cell, String prompt)? onSuggest;

  List<InlineAiEvent> explainScript = [
    InlineAiEvent(type: InlineAiEventType.textDelta, text: 'Adds '),
    InlineAiEvent(type: InlineAiEventType.done, markdown: 'Adds the values.'),
  ];

  SheetsFillProposal? fillProposal;
  final List<(String range, String? instructions)> fillCalls = [];
  final List<List<SheetsFillRow>> applied = [];

  List<String> chips = const ['Summarize this table', 'Find anomalies'];
  final Map<String, SheetsAiPreview> previews = {};
  final List<(String, List<String>?)> appliedPreviews = [];
  final List<String> discarded = [];
  final List<String> reverted = [];
  final List<String> reapplied = [];
  int _change = 0;

  String _nextChange() =>
      '01923456-789a-7bcd-8ef0-${(++_change).toString().padLeft(12, '0')}';

  @override
  Future<SheetsFormulaSuggestion> suggestFormula(
    UuidValue itemUuid,
    String cell,
    String prompt,
  ) async {
    suggestCalls.add((cell, prompt));
    return onSuggest?.call(cell, prompt) ??
        SheetsFormulaSuggestion(
          formula: '=SUM(A1:A3)',
          localizedFormula: '=SUM(A1:A3)',
          explanation: 'Adds A1 to A3.',
          references: ['A1:A3'],
          previewValue: '6',
          previewType: 'number',
        );
  }

  @override
  Stream<InlineAiEvent> explainFormula(UuidValue itemUuid, String cell) =>
      Stream.fromIterable(explainScript);

  @override
  Future<SheetsFillProposal> fillRange(
    UuidValue itemUuid,
    String range,
    String? instructions,
  ) async {
    fillCalls.add((range, instructions));
    return fillProposal ??
        SheetsFillProposal(
          range: range,
          examples: 1,
          rows: [
            SheetsFillRow(
              cell: 'Sheet1!B2',
              row: 2,
              inputs: 'A "Name"=Bob',
              value: 'bob@x.com',
              confidence: 'high',
            ),
            SheetsFillRow(
              cell: 'Sheet1!B3',
              row: 3,
              inputs: 'A "Name"=Eve',
              value: 'eve?',
              confidence: 'low',
            ),
          ],
        );
  }

  @override
  Future<SheetsAiApplyResult> applyFill(
    UuidValue itemUuid,
    String range,
    List<SheetsFillRow> rows,
  ) async {
    applied.add(rows);
    return SheetsAiApplyResult(
      changeId: UuidValue.fromString(_nextChange()),
      label: 'AI: Fill $range',
      cellsAffected: rows.length,
      skipped: 0,
    );
  }

  @override
  Future<List<String>> analyzeChips(UuidValue itemUuid, String? range) async =>
      chips;

  @override
  Future<String> describeChart(UuidValue itemUuid, String chartId) async =>
      'Column chart of revenue by region.';

  @override
  Future<SheetsAiPreview> getPreview(String previewId) async =>
      previews[previewId] ?? (throw StateError('Preview not found'));

  @override
  Future<SheetsAiApplyResult> applyPreview(
    String previewId,
    List<String>? callIds,
  ) async {
    appliedPreviews.add((previewId, callIds));
    return SheetsAiApplyResult(
      changeId: UuidValue.fromString(_nextChange()),
      label: 'AI: Suggested changes',
      cellsAffected: 3,
      skipped: 0,
    );
  }

  @override
  Future<void> discardPreview(String previewId) async =>
      discarded.add(previewId);

  /// `AI()` batches: (requests, refresh).
  final List<(List<SheetsAiCellRequest>, bool)> aiCellCalls = [];

  /// The answer of an `AI()` prompt (default: the prompt upper-cased).
  String? Function(SheetsAiCellRequest r) aiCellValue = (r) =>
      r.prompt.toUpperCase();

  @override
  Future<List<SheetsAiCellResult>> evaluateAiCells(
    UuidValue itemUuid,
    List<SheetsAiCellRequest> requests, {
    bool refresh = false,
  }) async {
    aiCellCalls.add((requests, refresh));
    return [
      for (final r in requests)
        SheetsAiCellResult(id: r.id, value: aiCellValue(r), cached: false),
    ];
  }

  @override
  Future<RevertResult> revertChange(UuidValue changeId) async {
    reverted.add(changeId.uuid);
    return RevertResult(
      changeId: UuidValue.fromString(_nextChange()),
      revertedCells: 1,
      skipped: [],
    );
  }

  @override
  Future<RevertResult> reapplyChange(UuidValue changeId) async {
    reapplied.add(changeId.uuid);
    return RevertResult(
      changeId: UuidValue.fromString(_nextChange()),
      revertedCells: 1,
      skipped: [],
    );
  }
}

/// A preview with two calls.
SheetsAiPreview twoCallPreview(String id, UuidValue item) => SheetsAiPreview(
  previewId: id,
  itemUuid: item,
  expiresAt: DateTime.utc(2030),
  calls: [
    SheetsAiPreviewCall(
      callId: 'c1',
      toolName: 'sheets.set_values',
      label: 'Wrote 2 cells',
      ranges: ['Sheet1!A1:A2'],
      cellsAffected: 2,
      cells: [
        SheetsAiPreviewCell(cell: 'Sheet1!A1', before: null, after: 'Region'),
        SheetsAiPreviewCell(cell: 'Sheet1!A2', before: 'x', after: 'North'),
      ],
    ),
    SheetsAiPreviewCall(
      callId: 'c2',
      toolName: 'sheets.add_sheet',
      label: 'Added sheet "Dashboard"',
      ranges: [],
      cellsAffected: 0,
      structural: 'Add sheet "Dashboard"',
      cells: [],
    ),
  ],
);
