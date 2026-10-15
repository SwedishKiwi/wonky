import 'dart:math' as math;

import 'package:flutter/material.dart' show Scrollbar;
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../config/menus/context_menu_specs.dart';
import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../canvas/canvas_interactions.dart';
import '../canvas/slide_canvas.dart';
import '../canvas/slide_canvas_controller.dart';
import '../find/find_overlay.dart';
import '../toolbar/command_ui.dart';
import '../text_editing/text_editing_host.dart' show typeToEdit;
import 'deck_editor_controller.dart';
import 'navigator_shell.dart' show OpenContextMenu;
import 'slide_labels.dart';
import 'slide_preview.dart';

/// The canvas region of the Normal view (04 §2): the current slide on the
/// canvas surround, fitted (or at a fixed zoom with scrolling), inside the
/// `slidesCanvas` key scope. Until SL-12 replaces the body with the real
/// canvas (SL-10's `SlideStage`, selection, transforms), the slide is a
/// static [SlidePreview]; right-click opens `context.slide`. An empty deck
/// shows *New slide* and *Choose a layout* (04 §5.11).
class CanvasRegion extends StatefulWidget {
  const CanvasRegion({
    super.key,
    required this.services,
    required this.editor,
    required this.onContextMenu,
  });

  final ShellServices services;
  final DeckEditorController editor;
  final OpenContextMenu onContextMenu;

  @override
  State<CanvasRegion> createState() => _CanvasRegionState();
}

class _CanvasRegionState extends State<CanvasRegion> {
  final _h = ScrollController();
  final _v = ScrollController();

  DeckEditorController get ed => widget.editor;

  @override
  void dispose() {
    _h.dispose();
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SlidesTokens.of(context);
    // The `slidesCanvas` key scope; typing a character with one text box
    // selected starts editing it first (03 §3.4, SL-13). The find bar,
    // the find panel and the paste options chip float above it, outside
    // the scope (SL-18).
    final canvas = Focus(
      focusNode: ed.canvasFocus,
      onKeyEvent: (node, event) {
        // Element modes first (`slidesCrop`, `slidesTable`, 03 §1.2).
        final canvas = SlideCanvasController.of(ed);
        if (canvas != null) {
          for (final i in CanvasInteractions.of(canvas)) {
            for (final scope in i.keyScopes) {
              final r = widget.services.keymap.handle(
                event,
                scope,
                context: context,
              );
              if (r == KeyEventResult.handled) return r;
            }
          }
        }
        if (typeToEdit(ed, event)) return KeyEventResult.handled;
        return widget.services.keymap.handle(
          event,
          SlidesKeyScopes.canvas,
          context: context,
        );
      },
      child: ColoredBox(
        key: const ValueKey<String>('slides.canvas'),
        color: tokens.canvasSurround,
        child: ListenableBuilder(
          listenable: ed,
          builder: (context, _) =>
              LayoutBuilder(builder: (context, c) => _content(context, c)),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(child: canvas),
        Positioned.fill(child: DeckCanvasOverlays(editor: ed)),
      ],
    );
  }

  Widget _content(BuildContext context, BoxConstraints c) {
    final entry = ed.currentEntry;
    if (entry == null) return _empty(context);
    // The real canvas (SL-12) once the screen attached its controller.
    final canvas = SlideCanvasController.of(ed);
    if (canvas != null) {
      return SlideCanvas(
        editor: ed,
        controller: canvas,
        onContextMenu: widget.onContextMenu,
      );
    }
    final slide = ed.resolver.resolve(entry.id);
    if (slide == null) return const SizedBox.shrink();
    final l = slidesL10n(context);
    final b = slide.bounds;
    // Fit: the slide with a 32 px margin (03 §2.2).
    const margin = 32.0;
    final fit = math.max(
      0.01,
      math.min(
        (c.maxWidth - margin * 2) / b.width,
        (c.maxHeight - margin * 2) / b.height,
      ),
    );
    ed.reportFitScale(fit);
    final scale = ed.zoom;
    final title = SlideLabels.title(ed.model, entry.id);
    final page = Container(
      width: b.width * scale,
      height: b.height * scale,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0x33000000),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SlidePreview(
        key: ValueKey<String>('slides.canvas.slide.${entry.id}'),
        slide: slide,
        showPrompts: !ed.viewMode,
        semanticLabel: l.canvasSlideSemantics(
          entry.index + 1,
          title.isEmpty ? l.slideUntitled : title,
        ),
      ),
    );
    final body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ed.canvasFocus.requestFocus();
        ed.clearElementSelection();
      },
      onSecondaryTapUp: (d) {
        ed.canvasFocus.requestFocus();
        widget.onContextMenu(
          ed.selectedElementIds.isEmpty
              ? SlidesContextMenuIds.slide
              : SlidesContextMenuIds.element,
          d.globalPosition,
        );
      },
      child: SizedBox(
        width: math.max(c.maxWidth, b.width * scale + margin * 2),
        height: math.max(c.maxHeight, b.height * scale + margin * 2),
        child: Center(child: page),
      ),
    );
    if (ed.zoomFit || scale <= fit) return body;
    return Scrollbar(
      controller: _v,
      child: SingleChildScrollView(
        controller: _v,
        child: Scrollbar(
          controller: _h,
          child: SingleChildScrollView(
            controller: _h,
            scrollDirection: Axis.horizontal,
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l = slidesL10n(context);
    final ui = SlidesCommandUi(context, widget.services);
    Widget action(String id, String label, {bool primary = false}) {
      final st = ui.state(id);
      final onPressed = st.enabled
          ? () => ui.run(id, const {}, InvocationSource.ui)
          : null;
      final b = primary
          ? ShadButton(
              enabled: st.enabled,
              onPressed: onPressed,
              child: Text(label),
            )
          : ShadButton.outline(
              enabled: st.enabled,
              onPressed: onPressed,
              child: Text(label),
            );
      final reason = st.disabledReason;
      return st.enabled || reason == null
          ? b
          : ShadTooltip(builder: (_) => Text(reason), child: b);
    }

    return Center(
      child: SingleChildScrollView(
        child: WonkyEmptyState(
          key: const ValueKey<String>('slides.canvas.empty'),
          illustration: EmptyIllustration.documents,
          title: l.canvasEmptyTitle,
          description: l.canvasEmptyBody,
          actions: [
            action('slides.slide.new', l.cmdSlideNew, primary: true),
            action('slides.slide.applyLayout', l.canvasChooseLayout),
          ],
        ),
      ),
    );
  }
}
