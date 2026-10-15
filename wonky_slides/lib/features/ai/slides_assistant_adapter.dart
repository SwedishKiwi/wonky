import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart';

import 'slides_ai_controller.dart';

/// Specializes the shared assistant panel for a presentation (Slides 11
/// §6.2–§6.3, suite 10 §3.1): the current slide and selection chips and
/// `slides*` context hints, Show (go to the slide, select the element),
/// one undo step per Edit-mode run (`slides.serverChange`), the
/// Suggest-mode preview (*Review changes*), Slides quick prompts and texts.
class SlidesAssistantAdapter extends ChangeNotifier
    implements
        AssistantDocumentAdapter,
        AssistantRunHooks,
        AssistantPanelTexts {
  SlidesAssistantAdapter(this.ai) {
    ai.editor.addListener(_onEditor);
    ai.addListener(notifyListeners);
  }

  final SlidesAiController ai;

  static const chipSlide = 'slide';
  static const chipSelection = 'selection';

  String _chipKey = '';

  void _onEditor() {
    final key = [for (final c in chips) c.label].join('|');
    if (key == _chipKey) return;
    _chipKey = key;
    notifyListeners();
  }

  @override
  UuidValue get itemUuid => ai.itemUuid;

  @override
  Role get role {
    final ed = ai.editor;
    final r = ed.role;
    return r < ed.itemRole ? r : ed.itemRole;
  }

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

  // --------------------------------------------------------------- context

  int? _position(String? slideId) {
    if (slideId == null) return null;
    final i = ai.model.slides.indexWhere((s) => s.id == slideId);
    return i < 0 ? null : i + 1;
  }

  @override
  List<AssistantContextChip> get chips {
    final ed = ai.editor;
    final l = ai.l10n;
    final pos = _position(ed.currentSlideId);
    final selected = ed.selectedElementIds;
    return [
      if (pos != null)
        AssistantContextChip(
          id: chipSlide,
          label: l.aiChipSlide(pos),
          icon: LucideIcons.presentation,
        ),
      if (selected.isNotEmpty)
        AssistantContextChip(
          id: chipSelection,
          label: l.aiChipObjects(selected.length),
          icon: LucideIcons.squareDashedMousePointer,
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
    final slide = chips.contains(chipSlide) ? ed.currentSlideId : null;
    return AssistantContextHints(
      applyMode: applyMode,
      includeComments: includeComments,
      localTime:
          '${now.toIso8601String().substring(0, 16).replaceAll('T', ' ')} '
          '${now.timeZoneName}',
      slidesCurrentSlide: slide,
      slidesSelectedSlides: slide == null
          ? null
          : ed.selectedSlideIds.isEmpty
          ? [slide]
          : ed.selectedSlideIds.toList(),
      slidesSelectedElements: chips.contains(chipSelection)
          ? ed.selectedElementIds
          : null,
    );
  }

  @override
  List<AssistantQuickPrompt> get quickPrompts {
    final l = ai.l10n;
    final canEdit = role >= Role.editor;
    // The prompts are instructions for the model and stay in English.
    return [
      AssistantQuickPrompt(
        label: l.aiQuickSummarize,
        prompt:
            'Summarize this presentation in a few bullets: its main message, '
            'its structure and anything that seems missing.',
        icon: LucideIcons.listCollapse,
      ),
      if (canEdit) ...[
        AssistantQuickPrompt(
          label: l.aiQuickImproveSlide,
          prompt:
              'Improve the current slide: make the title clear and the text '
              'short and scannable, keeping its meaning. Explain what you '
              'changed.',
          icon: LucideIcons.wandSparkles,
        ),
        AssistantQuickPrompt(
          label: l.aiQuickNotes,
          prompt:
              'Write speaker notes for the slides that have none: 3–5 '
              'sentences each that say what the slide does not.',
          icon: LucideIcons.notebookPen,
        ),
        AssistantQuickPrompt(
          label: l.aiQuickAgenda,
          prompt:
              'Add an agenda slide after the title slide that lists the '
              'sections (groups) or main topics of this presentation.',
          icon: LucideIcons.listOrdered,
        ),
        AssistantQuickPrompt(
          label: l.aiQuickConsistency,
          prompt:
              'Check the slide titles and wording for consistency (tense, '
              'capitalization, terminology) and fix what is inconsistent.',
          icon: LucideIcons.spellCheck,
        ),
      ],
    ];
  }

  // ------------------------------------------------------------------ show

  /// Show: `range` is the slide, `objectId` the element (the server's
  /// `SlidesAssistantTarget.annotate`).
  @override
  void show(AssistantActivity activity) =>
      ai.show(slideId: activity.range, elementId: activity.objectId);

  // ------------------------------------------------------------------ runs

  final Map<String, String> _runChange = {};

  @override
  void toolFinished(AssistantActivity activity) {}

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
    ai.previewReady(previewId);
    // Shown at the end of the turn (11 §6.3), when this deck is open.
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
            key: const ValueKey<String>('slides.ai.reviewChanges'),
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

  // --------------------------------------------------------------- results

  /// Inserts the reply as a new slide after the current one
  /// (`slides.ai.insertAsSlide`): its first line becomes the title.
  @override
  Future<bool> insertMarkdown(String markdown, {bool atTop = false}) async {
    final r = await ai.services.dispatcher.invoke(
      'slides.ai.insertAsSlide',
      args: {'markdown': markdown},
      source: InvocationSource.ai,
      context: ai.services.navigatorContext,
    );
    return r.isOk;
  }

  @override
  void dispose() {
    ai.editor.removeListener(_onEditor);
    ai.removeListener(notifyListeners);
    super.dispose();
  }
}
