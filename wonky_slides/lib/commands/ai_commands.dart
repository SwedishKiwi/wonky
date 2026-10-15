import 'dart:async';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/markdown.dart' show SlidesMarkdownCodec;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../features/ai/alt_text_dialog.dart';
import '../features/ai/design_ideas_panel.dart';
import '../features/ai/generate_deck_dialog.dart';
import '../features/ai/notes_dialog.dart';
import '../features/ai/rewrite_dialog.dart';
import '../features/ai/slides_ai_controller.dart';
import '../features/ai/ai_preview_dialog.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../features/layouts/layout_gallery.dart' show galleryLayouts;
import '../features/text_editing/text_editing_host.dart' show textEditingOf;
import '../features/undo/server_change_undo.dart';
import 'slides_command.dart';

/// The AI commands of Wonky Slides (Slides 11 §7; SL-43). Every model
/// call runs on the server (`slidesAi`); proposals are applied here as
/// ordinary edits (one `slides.rows` undo step "AI: …"), server builds and
/// applied previews as one `slides.serverChange` step. All are disabled
/// with the server's reason while AI isn't available (suite 10 §3).
///
/// - `slides.ai.generateDeck {source?, prompt?}` — *Generate presentation*
///   (outline, review, build; new deck or insert)
/// - `slides.ai.rewrite {mode, instruction?, language?, element?}`
/// - `slides.ai.suggestLayouts {slide?}` / `slides.panel.designIdeas`
/// - `slides.ai.applyDesignIdea {candidateId}`
/// - `slides.ai.speakerNotes {scope?, length?, style?, mode?}`
/// - `slides.ai.altText {elements?, all?}`
/// - `slides.ai.applyPreview {previewId?, selectedCallIds?}` /
///   `slides.ai.discardPreview {previewId?}`
/// - `slides.ai.setApplyMode {mode}`
/// - `slides.ai.insertAsSlide {markdown}` (the assistant's *Insert*)
List<Command<CommandArgs>> aiCommands(ShellServices s) {
  SlidesAiController ai(DeckEditorController ed) => SlidesAiController.of(ed);
  bool available(DeckEditorController ed) => ai(ed).available;
  String? unavailable(SlidesLocalizations l, DeckEditorController ed) =>
      ai(ed).unavailableReason ?? l.reasonAiUnavailable;

  return [
    SlidesCommand(
      'slides.ai.generateDeck',
      label: (l) => l.cmdAiGenerateDeck,
      icon: LucideIcons.sparkles,
      categoryOf: SlidesCategory.ai,
      requiredRole: Role.viewer,
      argsSchema: const JsonSchema.object(
        properties: {
          'source': JsonSchema.string(enumValues: ['prompt', 'outline']),
          'prompt': JsonSchema.string(
            description: 'Prefills the prompt (or the outline).',
          ),
        },
      ),
      enabled: (ed, a) => available(ed),
      reason: unavailable,
      run: (ctx, ed, a) async {
        final dc = ctx.dialogContext;
        if (dc == null) return const CommandResult.failed('No window');
        final c = ai(ed);
        final current = ed.currentSlideId;
        final r = await showGenerateDeckDialog(
          dc,
          services: s,
          api: c.api,
          itemUuid: ed.canEdit ? c.itemUuid : null,
          afterSlideId: ed.canEdit ? current : null,
          currentPosition: current == null
              ? null
              : ed.order.indexOf(current) + 1,
          prompt: a.string('prompt'),
          source: a.string('source') ?? 'prompt',
        );
        if (r == null) return const CommandResult.cancelled();
        final l = c.l10n;
        final build = r.build;
        if (r.target == GenerateTarget.newDeck) {
          s.toasts.show(l.aiGenerateCreated);
          unawaited(s.openPath('/p/${build.itemUuid.uuid}'));
          return ok({'itemUuid': build.itemUuid.uuid});
        }
        final change = build.changeId;
        if (change != null) {
          pushSlidesServerChangeStep(
            s,
            changeId: change,
            label: l.aiUndoLabel(l.aiGenerateUndo),
          );
        }
        s.toasts.show(l.aiGenerateDone(build.slideIds.length));
        // The new slides arrive by sync: open the first when it is there.
        _whenSlide(ed, build.slideIds.firstOrNull);
        return ok({'slideIds': build.slideIds, 'changeId': change});
      },
    ),
    SlidesCommand(
      'slides.ai.rewrite',
      label: (l) => l.cmdAiRewrite,
      icon: LucideIcons.wandSparkles,
      categoryOf: SlidesCategory.ai,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'mode': JsonSchema.string(
            enumValues: [
              'shorter',
              'longer',
              'clearer',
              'formal',
              'grammar',
              'punchier',
              'bullets',
              'paragraph',
              'translate',
              'custom',
            ],
          ),
          'instruction': JsonSchema.string(),
          'language': JsonSchema.string(description: 'translate: target'),
          'element': JsonSchema.string(description: 'Default: the selection'),
        },
      ),
      undoLabelOf: (l, a) => l.aiUndoLabel(_modeLabel(l, a.string('mode'))),
      enabled: (ed, a) =>
          available(ed) && ai(ed).textTarget(a.string('element')) != null,
      reason: (l, ed) => ai(ed).unavailableReason ?? l.reasonNoTextToRewrite,
      run: (ctx, ed, a) async {
        final c = ai(ed);
        final id = c.textTarget(a.string('element'));
        if (id == null) return CommandResult.failed(c.l10n.aiRewriteNoText);
        final dc = ctx.dialogContext;
        if (dc == null) return const CommandResult.failed('No window');
        // Pending typing first: the rewrite starts from the saved text.
        textEditingOf(ed).commit();
        final original = c.markdownOf(id) ?? '';
        final e = ed.model.element(id)!;
        final mode = a.string('mode') ?? 'shorter';
        final slide = e.slideId;
        final title = slide == null
            ? null
            : ed.model
                  .elementsOf(slide)
                  .where((x) => x.placeholderType == SlidePlaceholderType.title)
                  .map((x) => c.markdownOf(x.id))
                  .firstOrNull;
        final md = await showRewriteDialog(
          dc,
          api: c.api,
          itemUuid: c.itemUuid,
          title: _modeLabel(c.l10n, mode),
          currentMarkdown: () => c.markdownOf(id) ?? '',
          request: SlidesAiRewriteRequest(
            mode: mode,
            instruction: a.string('instruction'),
            language: a.string('language'),
            markdown: original,
            slideTitle: title,
            role: e.placeholderType?.name,
            capacityChars: c.capacityOf(id),
          ),
        );
        if (md == null) return const CommandResult.cancelled();
        final now = ed.model.element(id);
        if (now == null) return const CommandResult.failed('Deleted');
        textEditingOf(ed).end();
        final delta = SlidesMarkdownCodec.keepFormatting(
          now.text,
          SlidesAiController.deltaOf(md),
        );
        ed.apply(ctx, SetText(ElementText(id), delta));
        return ok({'element': id, 'markdown': md});
      },
    ),
    SlidesCommand(
      'slides.panel.designIdeas',
      label: (l) => l.cmdPanelDesignIdeas,
      icon: LucideIcons.wandSparkles,
      categoryOf: SlidesCategory.view,
      checked: (ed, a) => s.panels.isOpen(designIdeasPanelId),
      run: (ctx, ed, a) {
        s.panels.open(designIdeasPanelId);
        return ok();
      },
    ),
    SlidesCommand(
      'slides.ai.suggestLayouts',
      label: (l) => l.cmdAiSuggestLayouts,
      icon: LucideIcons.wandSparkles,
      categoryOf: SlidesCategory.ai,
      argsSchema: const JsonSchema.object(
        properties: {'slide': JsonSchema.string()},
      ),
      enabled: (ed, a) => ed.canEdit && ed.currentSlideId != null,
      reason: (l, ed) => ed.roleCanEdit ? l.reasonSelectSlides : null,
      run: (ctx, ed, a) {
        final slide = a.string('slide');
        if (slide != null && ed.model.slide(slide) != null) {
          ed.setCurrentSlide(slide);
        }
        s.panels.open(designIdeasPanelId);
        final ideas = DesignIdeasController.of(ed)..refresh();
        return ok(ideas.describeState());
      },
    ),
    SlidesCommand(
      'slides.ai.applyDesignIdea',
      label: (l) => l.cmdAiApplyDesignIdea,
      icon: LucideIcons.layoutTemplate,
      categoryOf: SlidesCategory.ai,
      mutates: true,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {'candidateId': JsonSchema.string()},
        required: ['candidateId'],
      ),
      undoLabelOf: (l, a) => l.aiDesignUndo,
      run: (ctx, ed, a) {
        final ideas = DesignIdeasController.of(ed);
        final idea = ideas.idea(a.requireString('candidateId'));
        if (idea == null || ed.model.slide(idea.slideId) == null) {
          return const CommandResult.failed('Unknown design idea');
        }
        ed.apply(ctx, idea.op);
        // The applied layout is now the slide's: new ideas.
        ideas.refresh();
        return ok({'slideId': idea.slideId, 'layoutId': idea.layoutId});
      },
    ),
    SlidesCommand(
      'slides.ai.speakerNotes',
      label: (l) => l.cmdAiSpeakerNotes,
      icon: LucideIcons.notebookPen,
      categoryOf: SlidesCategory.ai,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'scope': JsonSchema.string(
            enumValues: ['current', 'selected', 'all'],
          ),
          'length': JsonSchema.string(
            enumValues: ['brief', 'standard', 'detailed'],
          ),
          'style': JsonSchema.string(enumValues: ['script', 'bullets']),
          'mode': JsonSchema.string(
            enumValues: ['replace', 'append', 'fillEmpty'],
          ),
        },
      ),
      undoLabelOf: (l, a) => l.aiUndoLabel(l.aiNotesUndo),
      enabled: (ed, a) => available(ed) && ed.currentSlideId != null,
      reason: unavailable,
      run: (ctx, ed, a) async {
        final dc = ctx.dialogContext;
        if (dc == null) return const CommandResult.failed('No window');
        final scope = a.string('scope') ?? 'current';
        final d = await showNotesDialog(
          dc,
          ai: ai(ed),
          options: NotesOptions(
            scope: scope,
            length: a.string('length') ?? 'standard',
            style: a.string('style') ?? 'script',
            mode:
                a.string('mode') ?? (scope == 'all' ? 'fillEmpty' : 'replace'),
          ),
          review: a.values.containsKey('scope'),
        );
        if (d == null) return const CommandResult.cancelled();
        var written = 0;
        for (final n in d.notes) {
          final slide = ed.model.slide(n.slideId);
          if (slide == null) continue;
          final next = SlidesAiController.deltaOf(n.markdown, notes: true);
          final delta = d.mode == 'append' && slide.notes != null
              ? SlidesMarkdownCodec.concat(slide.notes, next)
              : next;
          ed.apply(ctx, SetText(NotesText(n.slideId), delta));
          written++;
        }
        if (written > 0 && !ed.notesVisible) ed.setNotesVisible(true);
        return ok({'slides': written});
      },
    ),
    SlidesCommand(
      'slides.ai.altText',
      label: (l) => l.cmdAiAltText,
      icon: LucideIcons.captions,
      categoryOf: SlidesCategory.ai,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'elements': JsonSchema.array(JsonSchema.string()),
          'all': JsonSchema.boolean(
            description: 'Every object missing alt text.',
          ),
        },
      ),
      undoLabelOf: (l, a) => l.aiUndoLabel(l.aiAltUndo),
      enabled: (ed, a) =>
          available(ed) &&
          (a.boolean('all') == true ||
              (a.values['elements'] is List
                      ? a.strings('elements')
                      : ed.selectedElementIds)
                  .isNotEmpty),
      reason: (l, ed) => ai(ed).unavailableReason ?? l.reasonSelectObject,
      run: (ctx, ed, a) async {
        final dc = ctx.dialogContext;
        if (dc == null) return const CommandResult.failed('No window');
        final ids = a.boolean('all') == true
            ? const <String>[]
            : a.values['elements'] is List
            ? a.strings('elements')
            : ed.selectedElementIds;
        final r = await showAltTextGenerateDialog(
          dc,
          ai: ai(ed),
          elementIds: ids,
        );
        if (r == null || r.isEmpty) return const CommandResult.cancelled();
        for (final e in r.entries) {
          if (ed.model.element(e.key) == null) continue;
          ed.apply(
            ctx,
            SetElementProps(
              [e.key],
              altText: Patch(e.value),
              decorative: false,
            ),
          );
        }
        return ok({'elements': r.keys.toList()});
      },
    ),
    SlidesCommand(
      'slides.ai.applyPreview',
      label: (l) => l.cmdAiApplyPreview,
      icon: LucideIcons.gitCompareArrows,
      categoryOf: SlidesCategory.ai,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'previewId': JsonSchema.string(),
          'selectedCallIds': JsonSchema.array(JsonSchema.string()),
        },
      ),
      enabled: (ed, a) =>
          (a.string('previewId') ?? ai(ed).pendingPreview) != null,
      reason: (l, ed) => l.reasonNoPreview,
      run: (ctx, ed, a) async {
        final c = ai(ed);
        final id = a.string('previewId') ?? c.pendingPreview;
        if (id == null) return const CommandResult.failed('No preview');
        final calls = a.values['selectedCallIds'] is List
            ? a.strings('selectedCallIds')
            : null;
        if (calls != null || ctx.source.isAgent) {
          // Direct (MCP, tests): no dialog.
          final r = await c.api.applyPreview(id, calls);
          c.recordOutcome(id, AiPreviewApplied(r));
          return ok({'changeId': r.changeId, 'applied': r.appliedCalls});
        }
        final outcome = await c.openPreview(id, context: ctx.dialogContext);
        return outcome == null
            ? const CommandResult.cancelled()
            : ok({
                'outcome': outcome is AiPreviewApplied
                    ? 'applied'
                    : 'discarded',
              });
      },
    ),
    SlidesCommand(
      'slides.ai.discardPreview',
      label: (l) => l.cmdAiDiscardPreview,
      icon: LucideIcons.x,
      categoryOf: SlidesCategory.ai,
      argsSchema: const JsonSchema.object(
        properties: {'previewId': JsonSchema.string()},
      ),
      enabled: (ed, a) =>
          (a.string('previewId') ?? ai(ed).pendingPreview) != null,
      reason: (l, ed) => l.reasonNoPreview,
      run: (ctx, ed, a) async {
        final c = ai(ed);
        final id = a.string('previewId') ?? c.pendingPreview;
        if (id == null) return const CommandResult.failed('No preview');
        try {
          await c.api.discardPreview(id);
        } on Object {
          // Expired previews are gone anyway.
        }
        c.recordOutcome(id, const AiPreviewDiscarded());
        return ok();
      },
    ),
    SlidesCommand(
      'slides.ai.setApplyMode',
      label: (l) => l.cmdAiSetApplyMode,
      categoryOf: SlidesCategory.ai,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'mode': JsonSchema.string(enumValues: ['edit', 'suggest']),
        },
        required: ['mode'],
      ),
      checked: (ed, a) =>
          ai(ed).chat?.applyMode.name == (a.string('mode') ?? 'edit'),
      enabled: (ed, a) => ai(ed).chat != null,
      reason: unavailable,
      run: (ctx, ed, a) {
        final chat = ai(ed).chat;
        if (chat == null) return const CommandResult.failed('No assistant');
        chat.setApplyMode(
          a.requireString('mode') == 'suggest'
              ? AiApplyMode.suggest
              : AiApplyMode.edit,
        );
        return ok();
      },
    ),
    SlidesCommand(
      'slides.ai.insertAsSlide',
      label: (l) => l.aiQuickNewDeck,
      categoryOf: SlidesCategory.ai,
      mutates: true,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {'markdown': JsonSchema.string()},
        required: ['markdown'],
      ),
      undoLabelOf: (l, a) => l.aiUndoLabel(l.aiGenerateNewSlide),
      run: (ctx, ed, a) {
        final md = a.requireString('markdown').trim();
        if (md.isEmpty) return const CommandResult.failed('Empty');
        final lines = md.split('\n');
        var title = lines.first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        var body = lines.skip(1).join('\n').trim();
        if (!lines.first.startsWith('#') && lines.length == 1) {
          body = title;
          title = '';
        }
        final layout = galleryLayouts(
          ed,
        ).where((x) => x.key == 'titleBody').firstOrNull;
        final plan = ed.apply(
          ctx,
          AddSlides(layoutId: layout?.id, afterSlideId: ed.currentSlideId),
        );
        final id = (plan.result['slideIds'] as List?)?.cast<String>().first;
        if (id == null) return const CommandResult.failed('No slide');
        for (final e in ed.model.elementsOf(id)) {
          final text = switch (e.placeholderType) {
            SlidePlaceholderType.title => title,
            SlidePlaceholderType.body => body,
            _ => null,
          };
          if (text == null || text.isEmpty) continue;
          ed.apply(
            ctx,
            SetText(ElementText(e.id), SlidesAiController.deltaOf(text)),
          );
        }
        ed.setCurrentSlide(id);
        return ok({'slideId': id});
      },
    ),
  ];
}

/// The label of a rewrite [mode] (menus, dialog title, undo label).
String _modeLabel(SlidesLocalizations l, String? mode) => switch (mode) {
  'longer' => l.rewriteLonger,
  'clearer' => l.rewriteClearer,
  'formal' => l.rewriteFormal,
  'grammar' => l.rewriteGrammar,
  'punchier' => l.rewritePunchier,
  'bullets' => l.rewriteBullets,
  'paragraph' => l.rewriteParagraph,
  'custom' => l.rewriteCustom,
  'translate' => l.aiRewriteTitle,
  _ => l.rewriteShorter,
};

/// Goes to [slideId] once it arrived by sync (server builds), within 10 s.
void _whenSlide(DeckEditorController ed, String? slideId) {
  if (slideId == null) return;
  if (ed.model.slide(slideId) != null) {
    ed.setCurrentSlide(slideId);
    return;
  }
  var tries = 0;
  Timer.periodic(const Duration(milliseconds: 250), (t) {
    tries++;
    if (ed.model.slide(slideId) != null) {
      t.cancel();
      ed.setCurrentSlide(slideId);
    } else if (tries > 40) {
      t.cancel();
    }
  });
}
