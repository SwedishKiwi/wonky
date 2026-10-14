import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../../mcp/ui_sheets_tools.dart';
import 'sheets_a1.dart';
import 'sheets_ai_controller.dart';

/// Specializes the shared assistant panel for a spreadsheet (Sheets 12 §6,
/// suite 10 §3): selection and sheet chips, the `sheets*` context hints,
/// Show (activate the sheet, select and flash the range) and one undo step
/// per Edit-mode run (`sheets.serverChange`), the Suggest-mode preview
/// (Review changes), Sheets quick prompts and inserting results as cells.
class SheetsAssistantAdapter extends ChangeNotifier
    implements
        AssistantDocumentAdapter,
        AssistantRunHooks,
        AssistantPanelTexts,
        AssistantWindowTools {
  SheetsAssistantAdapter(this.ai) {
    ai.editor.selection.addListener(_onSelection);
    ai.editor.addListener(_onSelection);
    ai.addListener(notifyListeners);
  }

  final SheetsAiController ai;

  /// Selections larger than this are sent as A1 only (the server profiles
  /// them).
  static const chipSelection = 'selection';
  static const chipSheet = 'sheet';

  String _chipKey = '';
  List<String> _analyzeChips = const [];

  void _onSelection() {
    final key = [for (final c in chips) c.label].join('|');
    if (key == _chipKey) return;
    _chipKey = key;
    notifyListeners();
  }

  @override
  UuidValue get itemUuid => ai.itemUuid;

  // --------------------------------------------------------------- texts

  @override
  String get emptyTitle => ai.l10n.aiAssistantEmptyTitle;

  @override
  String privacyNotice(String? provider) => provider == null
      ? ai.l10n.aiAssistantPrivacyNotice
      : ai.l10n.aiAssistantPrivacyNoticeProvider(provider);

  @override
  String get modeEditHint => ai.l10n.aiAssistantModeEditHint;

  @override
  String get modeEditUnavailable => ai.l10n.aiAssistantModeEditUnavailable;

  @override
  String get modeSuggestHint => ai.l10n.aiAssistantModeSuggestHint;

  @override
  Role get role {
    final ed = ai.editor;
    final r = ed.session.role.value;
    return r < ed.itemRole ? r : ed.itemRole;
  }

  @override
  List<AssistantContextChip> get chips {
    final ed = ai.editor;
    final l = ai.l10n;
    final sheet = ed.activeSheet;
    if (sheet == null) return const [];
    final sel = ed.selection.resolved;
    return [
      if (!sel.isSingleCell)
        AssistantContextChip(
          id: chipSelection,
          label: sel.ranges.length == 1
              ? ed.selectionA1.single
              : l.aiChipRanges(ed.selectionA1.first, sel.ranges.length - 1),
          icon: LucideIcons.squareDashedMousePointer,
        ),
      AssistantContextChip(
        id: chipSheet,
        label: l.aiChipSheet(sheet.name),
        icon: LucideIcons.sheet,
      ),
    ];
  }

  @override
  AssistantContextHints hints({
    required AiApplyMode applyMode,
    required Set<String> chips,
    bool includeComments = false,
  }) {
    final ed = ai.editor;
    final now = DateTime.now();
    final sel = ed.selection.resolved;
    return AssistantContextHints(
      applyMode: applyMode,
      includeComments: includeComments,
      localTime:
          '${now.toIso8601String().substring(0, 16).replaceAll('T', ' ')} '
          '${now.timeZoneName}',
      sheetsActiveSheet: chips.contains(chipSheet)
          ? ed.activeSheet?.name
          : null,
      sheetsSelection: chips.contains(chipSelection) && !sel.isSingleCell
          ? ed.selectionA1
          : null,
      sheetsActiveCell: ed.activeCellA1,
      sheetsVisibleRange: ed.visibleRangeA1,
      uiTools: windowTools,
    );
  }

  // -------------------------------------------------------- window tools

  /// `ui.sheets.*` tools the assistant runs in this window (Sheets 12
  /// §6.2): read the live selection, select and point at cells.
  static const windowTools = [
    'ui.sheets.get_selection',
    'ui.sheets.select_range',
    'ui.sheets.highlight_range',
  ];

  @override
  Future<UiToolResult> runWindowTool(String tool, Map<String, Object?> args) {
    final handler = windowTools.contains(tool)
        ? UiSheetsToolHandlers.all(ai.services)[tool]
        : null;
    if (handler == null) {
      throw UiToolException(
        'unsupported',
        'The assistant cannot run $tool in this window.',
      );
    }
    return handler(
      UiToolContext(
        services: ai.services,
        boundaryKey: GlobalKey(),
        events: UiEventLog(),
        agentName: ai.l10n.aiAgentLabel,
      ),
      args,
    );
  }

  /// Chips of *Analyze with AI* (`sheetsAi.analyzeChips`), shown first.
  void setAnalyzeChips(List<String> chips) {
    _analyzeChips = chips;
    notifyListeners();
  }

  @override
  List<AssistantQuickPrompt> get quickPrompts {
    final l = ai.l10n;
    final canEdit = role >= Role.editor;
    // The prompts are instructions for the model and stay in English.
    return [
      for (final c in _analyzeChips)
        AssistantQuickPrompt(
          label: c,
          prompt: c,
          icon: LucideIcons.chartNoAxesColumn,
        ),
      if (_analyzeChips.isEmpty)
        AssistantQuickPrompt(
          label: l.aiQuickAnalyze,
          prompt:
              'Analyze the data in the selected range (or the active sheet): '
              'summarize it, point out trends and anomalies, and suggest '
              'charts or pivot tables that would help.',
          icon: LucideIcons.chartNoAxesColumn,
        ),
      if (canEdit) ...[
        AssistantQuickPrompt(
          label: l.aiQuickChart,
          prompt:
              'Build a chart of the selected data (or the main table of the '
              'active sheet) that shows its most important trend.',
          icon: LucideIcons.chartLine,
        ),
        AssistantQuickPrompt(
          label: l.aiQuickClean,
          prompt:
              'Clean the data in the selected range (or the main table of the '
              'active sheet): trim whitespace, fix inconsistent '
              'capitalization and formats, and flag duplicates. Explain what '
              'you changed.',
          icon: LucideIcons.brushCleaning,
        ),
        AssistantQuickPrompt(
          label: l.aiQuickFormula,
          prompt:
              'Write a formula for the active cell that fits the surrounding '
              'data, and explain it.',
          icon: LucideIcons.squareFunction,
        ),
      ],
    ];
  }

  @override
  void show(AssistantActivity activity) {
    final range = activity.range;
    if (range != null && ai.reveal(range)) {
      ai.editor.gridFocus.requestFocus();
      return;
    }
    final object = activity.objectId;
    if (object != null) unawaited(ai.showObject(object));
  }

  // ---------------------------------------------------------------- runs

  final Map<String, String> _runChange = {};

  @override
  void toolFinished(AssistantActivity activity) {
    final range = activity.range;
    if (!activity.changed || range == null) return;
    ai.reveal(range, select: false);
  }

  @override
  void runCommitted(
    AssistantReplyEntry reply,
    String changeId,
    String summary,
  ) {
    final runId = reply.runId;
    if (runId == null) return;
    _runChange[runId] = changeId;
    ai.runCommitted(runId, changeId, summary);
  }

  @override
  Future<bool> undoRun(String runId) =>
      ai.undoRun(runId, changeId: _runChange[runId]);

  /// The undo step is labelled when the run commits.
  @override
  void runFinished(String runId, String summary) {}

  @override
  void previewReady(AssistantReplyEntry reply, String previewId) {
    // Shown at the end of the turn (12 §6.3), when this file is open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ai.services.activeDocument.value?.itemUuid != itemUuid) return;
      if (ai.previewOutcome(previewId) != null) return;
      unawaited(ai.openPreview(previewId));
    });
  }

  @override
  Widget? replyFooter(BuildContext context, AssistantReplyEntry reply) {
    final id = reply.previewId;
    if (id == null) return null;
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        final l = ai.l10n;
        final outcome = ai.previewOutcome(id);
        final theme = ShadTheme.of(context);
        if (outcome != null) {
          return Row(
            children: [
              Icon(
                outcome == 'applied' ? LucideIcons.check : LucideIcons.x,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  outcome == 'applied'
                      ? l.aiPreviewAppliedNote
                      : l.aiPreviewDiscardedNote,
                  style: theme.textTheme.muted,
                ),
              ),
            ],
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: const ValueKey<String>('sheets.ai.reviewChanges'),
            size: ShadButtonSize.sm,
            enabled: !reply.streaming,
            leading: const Icon(LucideIcons.gitCompareArrows, size: 13),
            onPressed: () => unawaited(ai.openPreview(id, context: context)),
            child: Flexible(
              child: Text(l.aiPreviewReview, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- results

  /// Inserts the reply's first Markdown table (or its text) at the active
  /// cell as one undo step (`sheets.ai.insertResult`).
  @override
  Future<bool> insertMarkdown(String markdown, {bool atTop = false}) async {
    final r = await ai.services.dispatcher.invoke(
      'sheets.ai.insertResult',
      args: {'markdown': markdown},
      source: InvocationSource.ai,
      context: ai.services.navigatorContext,
    );
    return r.isOk;
  }

  @override
  void dispose() {
    ai.editor.selection.removeListener(_onSelection);
    ai.editor.removeListener(_onSelection);
    ai.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Parses the first Markdown table of [markdown] into rows of cell texts
/// (header first); without a table, the non-empty lines as one column.
List<List<String>> markdownToRows(String markdown) {
  final lines = markdown.split('\n');
  final table = <List<String>>[];
  var inTable = false;
  for (final raw in lines) {
    final line = raw.trim();
    final isRow = line.startsWith('|') && line.endsWith('|') && line.length > 1;
    if (!isRow) {
      if (inTable) break;
      continue;
    }
    inTable = true;
    final cells = line
        .substring(1, line.length - 1)
        .split('|')
        .map((c) => c.trim())
        .toList();
    final separator = cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
    if (separator) continue;
    table.add([for (final c in cells) _stripInline(c)]);
  }
  if (table.isNotEmpty) return table;
  return [
    for (final raw in lines)
      if (raw.trim().isNotEmpty) [_stripInline(raw.trim())],
  ];
}

String _stripInline(String s) => s
    .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'^[-*] '), (m) => '');
