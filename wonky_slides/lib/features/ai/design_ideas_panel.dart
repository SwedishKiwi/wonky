import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/ai.dart';
import 'package:wonky_slides_core/ops.dart' show SlidesPlanContext;
import 'package:wonky_slides_core/planner.dart' show SlidesPlanner;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../stage/slide_renderer.dart';
import '../thumbnails/slide_thumbnail.dart';
import '../uploads/slides_image_service.dart';
import 'ai_preview_dialog.dart' show copyDeck;
import 'slides_ai_controller.dart';

/// The panel id of *Design ideas* (Slides 11 §6.6).
const designIdeasPanelId = 'slides.panel.designIdeas';

/// Stable widget keys of the Design ideas panel.
abstract final class DesignIdeasKeys {
  static const panel = ValueKey<String>('slides.designIdeas.panel');
  static const refresh = ValueKey<String>('slides.designIdeas.refresh');
  static const more = ValueKey<String>('slides.designIdeas.more');
  static ValueKey<String> idea(String id) =>
      ValueKey<String>('slides.designIdeas.idea.$id');
}

/// The *Design ideas* side panel spec (Slides 11 §6.6; rail icon
/// `wand-sparkles`).
SidePanelSpec designIdeasPanelSpec(
  BuildContext context,
  ShellServices services,
  DeckEditorController editor,
) => SidePanelSpec(
  id: designIdeasPanelId,
  title: slidesL10n(context).aiDesignTitle,
  icon: LucideIcons.wandSparkles,
  builder: (context) =>
      DesignIdeasPanel(ideas: DesignIdeasController.of(editor)),
);

/// The ideas of the current slide (Slides 11 §6.6): the deterministic
/// [DesignIdeasEngine] candidates, each rendered as a thumbnail from a
/// copy of the deck with the idea applied, ranked by the AI when it is
/// available (reasons as tooltips). Computed for the current slide when it
/// changes and on *Refresh*; edits don't recompute (11 §6.6 *Refresh
/// after edits*). One per editor.
class DesignIdeasController extends ChangeNotifier {
  DesignIdeasController._(this.editor) {
    editor.addListener(_onEditor);
  }

  static final Expando<DesignIdeasController> _of = Expando('designIdeas');

  static DesignIdeasController of(DeckEditorController editor) =>
      _of[editor] ??= DesignIdeasController._(editor);

  static DesignIdeasController? maybeOf(DeckEditorController editor) =>
      _of[editor];

  final DeckEditorController editor;

  /// Ideas shown per page.
  static const pageSize = 8;

  String? _slideId;
  List<DesignIdea> _ideas = const [];
  final Map<String, SlideRenderer> _renderers = {};
  Map<String, SlidesAiDesignRankView> _ranks = const {};
  bool ranking = false;
  int shown = pageSize;
  int _request = 0;
  bool _disposed = false;

  /// The slide the ideas are for.
  String? get slideId => _slideId;

  /// The ideas, best first (AI order when ranked).
  List<DesignIdea> get ideas => _ideas;

  /// Whether the AI ranked the ideas.
  bool get ranked => _ranks.isNotEmpty;

  /// The AI's reason for idea [id].
  String? reasonOf(String id) => _ranks[id]?.reason;

  /// The idea [id] of the current slide.
  DesignIdea? idea(String id) => _ideas.where((i) => i.id == id).firstOrNull;

  void _onEditor() {
    if (editor.currentSlideId != _slideId) refresh();
  }

  /// Recomputes the ideas of the current slide (and asks the AI to rank
  /// them when it is available).
  void refresh() {
    _slideId = editor.currentSlideId;
    _clearRenderers();
    _ranks = const {};
    shown = pageSize;
    final id = _slideId;
    _ideas = id == null
        ? const []
        : DesignIdeasEngine.candidates(editor.model, id);
    _notify();
    unawaited(_rank());
  }

  /// Shows the next page.
  void more() {
    shown += pageSize;
    _notify();
  }

  Future<void> _rank() async {
    final id = _slideId;
    final ai = SlidesAiController.of(editor);
    if (id == null || _ideas.length < 2 || !ai.available) return;
    final request = ++_request;
    ranking = true;
    _notify();
    try {
      final r = await ai.api.rankDesigns(ai.itemUuid, id, [
        for (final i in _ideas) i.rankLine,
      ]);
      if (_disposed || request != _request || id != _slideId) return;
      _ranks = {
        for (final x in r)
          x.candidateId: SlidesAiDesignRankView(x.score, x.reason),
      };
      final order = {for (final (i, x) in r.indexed) x.candidateId: i};
      _ideas = [..._ideas]
        ..sort((a, b) {
          final x = order[a.id] ?? 1 << 20;
          final y = order[b.id] ?? 1 << 20;
          return x != y ? x.compareTo(y) : 0;
        });
    } on Object {
      // Unranked: the deterministic order stays (11 §6.6).
    } finally {
      if (request == _request) ranking = false;
      _notify();
    }
  }

  /// The renderer of [idea]'s preview: a copy of the deck with the idea
  /// applied (built on first use).
  SlideRenderer? rendererOf(DesignIdea idea) {
    final existing = _renderers[idea.id];
    if (existing != null) return existing;
    final m = copyDeck(editor.model);
    try {
      final plan = const SlidesPlanner().plan(
        idea.op,
        m,
        SlidesPlanContext(userId: 'preview', now: clock.now().toUtc()),
      );
      m.applyPlan(plan);
    } on Object {
      return null;
    }
    return _renderers[idea.id] = SlideRenderer(
      model: m,
      images: SlidesImageService.of(editor),
    );
  }

  void _clearRenderers() {
    for (final r in _renderers.values) {
      r.dispose();
    }
    _renderers.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// MCP `describeState` of the panel.
  Map<String, Object?> describeState() => {
    'slide_id': _slideId,
    'ranked': ranked,
    'ideas': [
      for (final i in _ideas.take(shown))
        {
          'id': i.id,
          'layout': i.layoutKey ?? i.name,
          'score': i.score,
          'reason': ?reasonOf(i.id),
        },
    ],
  };

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _of[editor] = null;
    editor.removeListener(_onEditor);
    _clearRenderers();
    super.dispose();
  }
}

/// The AI's verdict on one idea.
class SlidesAiDesignRankView {
  const SlidesAiDesignRankView(this.score, this.reason);
  final double score;
  final String? reason;
}

/// The panel body: 2 columns of thumbnails (1 below 300 px), best first,
/// each with its layout name; click (Enter) applies
/// `slides.ai.applyDesignIdea` (one undo step).
class DesignIdeasPanel extends StatefulWidget {
  const DesignIdeasPanel({super.key, required this.ideas});

  final DesignIdeasController ideas;

  @override
  State<DesignIdeasPanel> createState() => _DesignIdeasPanelState();
}

class _DesignIdeasPanelState extends State<DesignIdeasPanel> {
  DesignIdeasController get c => widget.ideas;

  @override
  void initState() {
    super.initState();
    if (c.slideId != c.editor.currentSlideId || c.ideas.isEmpty) c.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final services = c.editor.services;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final canApply = services.dispatcher
            .stateOf('slides.ai.applyDesignIdea')
            .enabled;
        if (c.slideId == null) {
          return WonkyEmptyState(
            key: DesignIdeasKeys.panel,
            illustration: EmptyIllustration.search,
            title: l.aiDesignNoSlide,
            size: 72,
          );
        }
        if (c.ideas.isEmpty) {
          return WonkyEmptyState(
            key: DesignIdeasKeys.panel,
            illustration: EmptyIllustration.search,
            title: l.aiDesignEmpty,
            size: 72,
          );
        }
        return LayoutBuilder(
          key: DesignIdeasKeys.panel,
          builder: (context, box) {
            final columns = box.maxWidth < 300 ? 1 : 2;
            final w = (box.maxWidth - 24 - (columns - 1) * 8) / columns;
            final shown = c.ideas.take(c.shown).toList();
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.ranking
                            ? l.aiDesignRanking
                            : c.ranked
                            ? l.aiDesignAiRanked
                            : l.aiDesignLayoutIdeas,
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                      ),
                    ),
                    ShadIconButton.ghost(
                      key: DesignIdeasKeys.refresh,
                      width: 28,
                      height: 28,
                      icon: Icon(
                        LucideIcons.refreshCw,
                        size: 14,
                        semanticLabel: l.aiDesignRefresh,
                      ),
                      onPressed: c.refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final idea in shown)
                      _IdeaCard(
                        key: DesignIdeasKeys.idea(idea.id),
                        idea: idea,
                        renderer: c.rendererOf(idea),
                        width: w,
                        reason: c.reasonOf(idea.id),
                        enabled: canApply,
                        label: l.aiDesignApply(idea.name),
                        onApply: () => unawaited(
                          services.dispatcher.invoke(
                            'slides.ai.applyDesignIdea',
                            args: {'candidateId': idea.id},
                            source: InvocationSource.ui,
                            context: context,
                          ),
                        ),
                      ),
                  ],
                ),
                if (c.ideas.length > c.shown)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ShadButton.outline(
                      key: DesignIdeasKeys.more,
                      size: ShadButtonSize.sm,
                      onPressed: c.more,
                      child: Text(l.aiDesignMore),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    super.key,
    required this.idea,
    required this.renderer,
    required this.width,
    required this.reason,
    required this.enabled,
    required this.label,
    required this.onApply,
  });

  final DesignIdea idea;
  final SlideRenderer? renderer;
  final double width;
  final String? reason;
  final bool enabled;
  final String label;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final r = renderer;
    final card = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onApply();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: enabled ? onApply : null,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: r == null
                      ? SizedBox(width: width, height: width * 9 / 16)
                      : SlideThumbnail(
                          renderer: r,
                          slideId: idea.slideId,
                          width: width - 2,
                        ),
                ),
                Text(
                  idea.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final why = reason;
    return why == null || why.isEmpty
        ? card
        : ShadTooltip(builder: (_) => Text(why), child: card);
  }
}
