import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart' show InvalidRangeException;

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../sheet_editor/sheets_document_controller.dart';
import '../model/memory_workbook_session.dart' show WorkbookSessionBase;
import '../data_tools/cleanup_suggestions.dart' show CleanupKind;
import '../data_tools/cleanup_suggestions_panel.dart' show cleanupSuggestionsOf;
import 'agent_highlight_layer.dart';
import 'ai_cells.dart';
import 'external_agent_writes.dart';
import 'ai_cell_popover.dart';
import 'ai_preview_dialog.dart';
import 'fill_with_ai_dialog.dart';
import 'server_change_undo.dart';
import 'sheets_a1.dart';
import 'sheets_ai_api.dart';
import 'sheets_assistant_adapter.dart';

/// What the AI cell popover shows (formula bar ✨, Explain formula).
enum AiPopoverKind { suggest, explain }

/// State of the AI cell popover anchored at a cell (Sheets 12 §6.4–6.5).
class AiPopoverState {
  AiPopoverState({
    required this.kind,
    required this.sheetId,
    required this.row,
    required this.col,
    required this.cellA1,
  });

  final AiPopoverKind kind;
  final String sheetId;
  final int row;
  final int col;

  /// Qualified A1 of the cell (`Sheet1!B4`).
  final String cellA1;

  String prompt = '';
  bool loading = false;
  SheetsFormulaSuggestion? suggestion;
  String? error;

  /// Explain: the formula and the streamed explanation.
  String formula = '';
  final StringBuffer _markdown = StringBuffer();
  String get markdown => _markdown.toString();

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'cell': cellA1,
    'loading': loading,
    if (kind == AiPopoverKind.suggest) 'prompt': prompt,
    if (suggestion != null)
      'suggestion': {
        'formula': suggestion!.localizedFormula,
        'explanation': suggestion!.explanation,
        'preview_value': suggestion!.previewValue,
        'error_message': suggestion!.errorMessage,
      },
    if (kind == AiPopoverKind.explain) 'explanation': markdown,
    'error': ?error,
  };
}

/// The AI features of one open spreadsheet (Sheets 12 §6, suite 10): the
/// assistant adapter, the agent presence highlight, the ✨ formula
/// suggestion and Explain popover, Fill with AI, the Suggest-mode preview,
/// Analyze and chart descriptions. One per editor
/// ([SheetEditorController.extension]).
class SheetsAiController extends ChangeNotifier {
  SheetsAiController._(this.editor) {
    adapter = SheetsAssistantAdapter(this);
    editor.layers.add(highlights);
    final session = editor.session;
    if (session is WorkbookSessionBase) {
      session.externalData.attach(aiCells, served: const {'AI'});
    }
    externalWrites = ExternalAgentWrites(
      editor,
      highlights,
      labels: AgentLabels(
        mcp: l10n.aiAgentMcp,
        of: l10n.aiAgentOf,
        aiOf: l10n.aiAgentAiOf,
        someone: l10n.someone,
      ),
    );
    final hooks = editor.gridHooks.overlays;
    hooks.value = [...hooks.value, _overlayBuilder];
    editor.onDispose(dispose);
  }

  /// The controller of [editor] (created on first use).
  static SheetsAiController of(SheetEditorController editor) =>
      editor.extension<SheetsAiController>(
        SheetsAiController,
        () => SheetsAiController._(editor),
      );

  /// The controller of the open spreadsheet of [ctx], or null.
  static SheetsAiController? ofContext(CommandContext ctx) {
    final doc = ctx.document;
    final ed = doc is SheetsDocumentController ? doc.editor : null;
    return ed == null ? null : of(ed);
  }

  /// The controller of the open spreadsheet of [services], or null.
  static SheetsAiController? ofServices(ShellServices services) {
    final doc = services.activeDocument.value;
    final ed = doc is SheetsDocumentController ? doc.editor : null;
    return ed == null ? null : of(ed);
  }

  final SheetEditorController editor;
  late final SheetsAssistantAdapter adapter;

  /// The agent presence highlight layer.
  final AgentHighlightLayer highlights = AgentHighlightLayer();

  /// Flashes headless agent writes of other clients (12 §1.4).
  late final ExternalAgentWrites externalWrites;

  /// `=AI()` cells (12 §6.8).
  late final AiCellsProvider aiCells = AiCellsProvider(
    api: () => api,
    itemUuid: itemUuid,
  );

  /// The AI cell popover (null = closed).
  final ValueNotifier<AiPopoverState?> popover = ValueNotifier(null);

  bool _disposed = false;

  ShellServices get services => editor.services;
  SheetsLocalizations get l10n => sheetsL10nOf(services);
  UuidValue get itemUuid => editor.session.itemUuid;

  /// The Sheets AI endpoints.
  SheetsAiApi get api => SheetsAiApis.of(services);

  ShellAssistant? get assistant => ShellAssistant.of(services);

  /// Whether AI UI is shown at all (installed, not switched off on the
  /// server or by the user).
  bool get shown => services.prefs.aiEnabled && (assistant?.available ?? false);

  /// Whether AI requests can be sent now.
  bool get available =>
      services.prefs.aiEnabled && (assistant?.usable ?? false);

  /// Why AI can't be used now (null when [available]).
  String? get unavailableReason {
    if (available) return null;
    if (!services.prefs.aiEnabled) return l10n.aiTurnedOff;
    final s = assistant?.status.value;
    final la = services.l10n;
    if (s != null && la != null) return assistantStatusMessage(la, s);
    return s?.message ?? l10n.aiUnavailable;
  }

  /// The panel controller of this spreadsheet.
  AssistantController? get chat => assistant?.controllerFor(adapter);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------- show

  /// Flashes [a1] (qualified or on the active sheet) with [label];
  /// [select] also activates its sheet, selects and reveals it.
  bool reveal(
    String a1, {
    String? label,
    bool select = true,
    Color color = AgentHighlightLayer.agentColor,
    Duration duration = const Duration(seconds: 5),
  }) {
    final ResolvedRangeLike r;
    try {
      final rr = editor.model.parseA1(a1, contextSheetId: editor.activeSheetId);
      r = (sheetId: rr.sheetId, rect: rr.rect);
    } on InvalidRangeException {
      return false;
    }
    if (select && !editor.goTo(a1)) return false;
    highlights.flash(
      AgentHighlight(
        sheetId: r.sheetId,
        rect: r.rect,
        label: label ?? l10n.aiAgentLabel,
        color: color,
      ),
      duration: duration,
    );
    return true;
  }

  /// Selects the chart/pivot/rule [objectId] when a command can.
  Future<void> showObject(String objectId) async {
    for (final id in ['sheets.object.select', 'sheets.pivot.openEditor']) {
      if (services.registry.byId(id) == null) continue;
      final args = id == 'sheets.object.select'
          ? {'objectId': objectId}
          : {'pivotId': objectId};
      try {
        final r = await services.dispatcher.invoke(
          id,
          args: args,
          source: InvocationSource.ui,
          context: services.navigatorContext,
        );
        if (r.isOk) return;
      } on Object {
        // Try the next.
      }
    }
  }

  // --------------------------------------------------------------- popover

  late final Widget Function(BuildContext) _overlayBuilder = _overlay;

  Widget _overlay(BuildContext context) => AiCellPopoverHost(ai: this);

  /// Opens the ✨ formula suggestion popover at [cell] (default: the
  /// active cell). With [prompt], asks right away.
  Future<SheetsFormulaSuggestion?> openSuggest({
    String? cell,
    String? prompt,
  }) async {
    final state = _popoverAt(AiPopoverKind.suggest, cell);
    if (state == null) return null;
    popover.value = state;
    if (prompt != null && prompt.trim().isNotEmpty) {
      state.prompt = prompt.trim();
      await runSuggest();
    }
    return state.suggestion;
  }

  AiPopoverState? _popoverAt(AiPopoverKind kind, String? cell) {
    var sheetId = editor.activeSheetId;
    var row = editor.selection.resolved.activeRow;
    var col = editor.selection.resolved.activeCol;
    if (cell != null) {
      final rr = editor.model.parseA1(cell, contextSheetId: sheetId);
      sheetId = rr.sheetId;
      row = rr.rect.top;
      col = rr.rect.left;
      if (sheetId != editor.activeSheetId) editor.activateSheet(sheetId);
      editor.selection.selectCell(row, col);
    }
    editor.revealCell(row, col);
    return AiPopoverState(
      kind: kind,
      sheetId: sheetId,
      row: row,
      col: col,
      cellA1: qualifiedA1(
        editor.sheetName(sheetId),
        rectA1(GridRect(row, col, row, col)),
      ),
    );
  }

  /// Asks for a formula for the popover's prompt.
  Future<void> runSuggest() async {
    final s = popover.value;
    if (s == null || s.kind != AiPopoverKind.suggest) return;
    if (s.prompt.trim().isEmpty || s.loading) return;
    s
      ..loading = true
      ..error = null
      ..suggestion = null;
    _popoverChanged();
    try {
      s.suggestion = await api.suggestFormula(itemUuid, s.cellA1, s.prompt);
    } on Object catch (e) {
      s.error = errorMessage(e);
    }
    s.loading = false;
    _popoverChanged();
    unawaited(assistant?.refreshStatus());
  }

  void _popoverChanged() {
    final s = popover.value;
    popover.value = null;
    popover.value = s;
  }

  /// Inserts the suggested formula into its cell (one undo step).
  Future<bool> insertSuggestion() async {
    final s = popover.value;
    final f = s?.suggestion;
    if (s == null || f == null || f.formula.isEmpty) return false;
    final r = await services.dispatcher.invoke(
      'sheets.cell.setInput',
      args: {'a1': s.cellA1, 'input': f.localizedFormula},
      source: InvocationSource.ai,
      context: services.navigatorContext,
    );
    if (!r.isOk) return false;
    closePopover();
    editor.gridFocus.requestFocus();
    return true;
  }

  void closePopover() {
    final s = popover.value;
    if (s == null) return;
    popover.value = null;
    _explain?.cancel();
    _explain = null;
  }

  StreamSubscription<InlineAiEvent>? _explain;

  /// Explains the formula of [cell] (default: the active cell) in the
  /// popover, streaming. Returns false when the cell has no formula.
  bool explain({String? cell}) {
    final state = _popoverAt(AiPopoverKind.explain, cell);
    if (state == null) return false;
    final display = editor.cells.displayAt(state.sheetId, state.row, state.col);
    if (display?.isFormula != true) return false;
    state
      ..formula = editor.editableText(
        state.row,
        state.col,
        sheetId: state.sheetId,
      )
      ..loading = true;
    _explain?.cancel();
    popover.value = state;
    _explain = api
        .explainFormula(itemUuid, state.cellA1)
        .listen(
          (e) {
            switch (e.type) {
              case InlineAiEventType.textDelta:
                state._markdown.write(e.text ?? '');
              case InlineAiEventType.done:
                final md = e.markdown;
                if (md != null && md.isNotEmpty) {
                  state._markdown
                    ..clear()
                    ..write(md);
                }
                state.loading = false;
              case InlineAiEventType.refusal:
                state
                  ..loading = false
                  ..error = e.error ?? AssistantController.refusalText;
              case InlineAiEventType.error:
                state
                  ..loading = false
                  ..error = e.error;
            }
            if (identical(popover.value, state)) _popoverChanged();
          },
          onError: (Object e) {
            state
              ..loading = false
              ..error = errorMessage(e);
            if (identical(popover.value, state)) _popoverChanged();
          },
          onDone: () {
            state.loading = false;
            if (identical(popover.value, state)) _popoverChanged();
            unawaited(assistant?.refreshStatus());
          },
          cancelOnError: true,
        );
    return true;
  }

  /// Hands the explanation to the assistant panel as a result card.
  void explanationToPanel() {
    final s = popover.value;
    final c = chat;
    if (s == null || c == null) return;
    final r = c.addResult(l10n.aiExplainResultTitle(s.cellA1));
    r
      ..markdown = '`${s.formula}`\n\n${s.markdown}'
      ..status = AssistantReplyStatus.done;
    c.refresh();
    closePopover();
    services.panels.open(ShellPanels.assistant);
  }

  // ------------------------------------------------------------- fill

  /// Fill with AI for a one-column [range] (default: the active range):
  /// shows the proposals dialog; Apply writes them as one undo step.
  Future<SheetsAiApplyResult?> fill({
    String? range,
    String? instructions,
    BuildContext? context,
  }) async {
    final target = range ?? editor.selectionA1.first;
    final ctx = context ?? services.navigatorContext;
    if (ctx == null || !ctx.mounted) return null;
    final result = await showFillWithAiDialog(
      ctx,
      ai: this,
      range: target,
      instructions: instructions,
    );
    if (result == null || result.changeId == null) return result;
    _pushServerStep(result.changeId!.uuid, result.label);
    reveal(target, select: false, label: l10n.aiAgentLabel);
    return result;
  }

  void _pushServerStep(String changeId, String label) {
    pushServerChangeStep(
      services,
      changeId: changeId,
      label: label.isEmpty ? l10n.aiUndoDefault : label,
    );
  }

  // ------------------------------------------------------------- preview

  final Map<String, String> _previewOutcome = {};

  /// `applied` / `discarded` once the preview [previewId] was handled.
  String? previewOutcome(String previewId) => _previewOutcome[previewId];

  /// Shows the AI changes preview [previewId] (Suggest mode, 12 §6.3).
  /// Returns the apply result (null: discarded or closed).
  Future<SheetsAiApplyResult?> openPreview(
    String previewId, {
    BuildContext? context,
  }) async {
    final ctx = context ?? services.navigatorContext;
    if (ctx == null || !ctx.mounted) return null;
    final outcome = await showAiPreviewDialog(
      ctx,
      ai: this,
      previewId: previewId,
    );
    switch (outcome) {
      case AiPreviewApplied(:final result):
        _previewOutcome[previewId] = 'applied';
        if (result.changeId != null) {
          _pushServerStep(result.changeId!.uuid, result.label);
        }
        if (result.skipped > 0) {
          services.toasts.show(l10n.aiPreviewSkipped(result.skipped));
        }
        _notify();
        chat?.refresh();
        return result;
      case AiPreviewDiscarded():
        _previewOutcome[previewId] = 'discarded';
        _notify();
        chat?.refresh();
        return null;
      case null:
        return null;
    }
  }

  /// Applies the preview without the dialog (`sheets.ai.applyPreview`).
  Future<SheetsAiApplyResult> applyPreview(
    String previewId, {
    List<String>? callIds,
  }) async {
    final result = await api.applyPreview(previewId, callIds);
    _previewOutcome[previewId] = 'applied';
    if (result.changeId != null) {
      _pushServerStep(result.changeId!.uuid, result.label);
    }
    _notify();
    chat?.refresh();
    return result;
  }

  /// Discards the preview (`sheets.ai.discardPreview`).
  Future<void> discardPreview(String previewId) async {
    await api.discardPreview(previewId);
    _previewOutcome[previewId] = 'discarded';
    _notify();
    chat?.refresh();
  }

  // ------------------------------------------------------------- analyze

  /// *Analyze with AI*: opens the assistant with prompt chips for [range]
  /// (default: the selection when it is more than a cell).
  Future<List<String>> analyze({String? range}) async {
    services.panels.open(ShellPanels.assistant);
    final r = range ?? _selectionOrNull();
    List<String> chips;
    try {
      chips = await api.analyzeChips(itemUuid, r);
    } on Object {
      chips = const [];
    }
    adapter.setAnalyzeChips(chips);
    return chips;
  }

  String? _selectionOrNull() {
    final sel = editor.selection.resolved;
    if (sel.isSingleCell) return null;
    return editor.selectionA1.first;
  }

  // ------------------------------------------------------ cleanup (P2)

  /// *Clean up data with AI* (12 §6.9): the deterministic cleanup checks
  /// (07 §12.3) of the sheet are handed to the assistant, which groups and
  /// explains them and proposes fixes in Suggest mode (the AI changes
  /// preview applies the checked ones as one undo step). Returns the
  /// prompt, or null when the assistant can't be used.
  Future<String?> cleanupWithAi({String? range}) async {
    final chat = this.chat;
    final sheet = editor.activeSheet;
    if (chat == null || !available || sheet == null) return null;
    final found = cleanupSuggestionsOf(editor);
    final lines = [
      for (final f in found.take(20))
        '- ${f.kind.name}: ${f.count} '
            '${f.kind == CleanupKind.duplicates || f.kind == CleanupKind.emptyRows ? 'rows' : 'cells'} '
            'in ${qualifiedA1(sheet.name, rectA1(f.range))}'
            '${f.preview.isEmpty ? '' : ', e.g. ${f.preview.take(2).map((p) => '"${p.$1}" → "${p.$2}"').join(', ')}'}',
    ];
    final prompt = l10n.aiCleanupPrompt(
      range == null
          ? l10n.aiCleanupScopeSheet(sheet.name)
          : l10n.aiCleanupScopeRange(range),
      lines.isEmpty ? l10n.aiCleanupNothing : lines.join('\n'),
    );
    services.panels.open(ShellPanels.assistant);
    if (chat.applyMode != AiApplyMode.suggest) {
      chat.setApplyMode(AiApplyMode.suggest);
    }
    unawaited(chat.send(prompt));
    return prompt;
  }

  /// *Refresh AI cells* (12 §6.8): recomputes every `=AI()` call.
  void refreshAiCells() => aiCells.refreshAll();

  // ------------------------------------------------------- chart alt text

  /// An alt-text proposal for chart [objectId] (12 §6.10).
  Future<String> describeChart(String objectId) =>
      api.describeChart(itemUuid, objectId);

  // ------------------------------------------------------------ runs

  final Map<String, String> _runSteps = {};

  /// An Edit-mode assistant run committed [changeId]: one undo step.
  void runCommitted(String runId, String changeId, String summary) {
    if (_runSteps.containsKey(runId)) return;
    final label = l10n.aiUndoLabel(
      summary.trim().isEmpty ? l10n.aiUndoDefault : summary.trim(),
    );
    _runSteps[runId] = pushServerChangeStep(
      services,
      changeId: changeId,
      label: label,
    );
  }

  /// Undoes the run's step when it is the latest one; otherwise reverts
  /// [changeId] on the server directly. False when neither is possible.
  Future<bool> undoRun(String runId, {String? changeId}) async {
    final step = _runSteps[runId];
    final key = services.undo.activeDocumentStack;
    if (step != null && key != null) {
      final steps = services.undo.undoStepsOf(key);
      if (steps.isNotEmpty && steps.last.id == step) {
        await services.undo.undo();
        return true;
      }
    }
    if (changeId == null) return false;
    try {
      await api.revertChange(UuidValue.fromString(changeId));
      return true;
    } on Object catch (e) {
      services.toasts.error(l10n.toastCommandFailed, description: '$e');
      return false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _explain?.cancel();
    final hooks = editor.gridHooks.overlays;
    hooks.value = [
      for (final o in hooks.value)
        if (o != _overlayBuilder) o,
    ];
    externalWrites.dispose();
    final session = editor.session;
    if (session is WorkbookSessionBase &&
        identical(session.externalData.target, aiCells)) {
      session.externalData.attach(null);
    }
    aiCells.dispose();
    editor.layers.remove(highlights);
    highlights.dispose();
    assistant?.release(adapter);
    adapter.dispose();
    popover.dispose();
    super.dispose();
  }
}

/// A range by sheet id and rectangle.
typedef ResolvedRangeLike = ({String sheetId, GridRect rect});
