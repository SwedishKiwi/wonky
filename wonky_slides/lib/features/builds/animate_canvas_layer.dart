import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' show KeyScope, InvocationSource;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../canvas/canvas_interactions.dart';
import '../canvas/canvas_tokens.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../motion/motion_stage.dart';
import '../selection/slide_elements.dart';
import 'animate_view.dart';
import 'build_labels.dart';
import 'build_order.dart';

/// Widget keys of the Animate canvas layer.
abstract final class AnimateCanvasKeys {
  static const preview = ValueKey<String>('slides.animate.previewStage');
  static const previewBar = ValueKey<String>('slides.animate.previewBar');
  static const stop = ValueKey<String>('slides.animate.previewStop');

  /// The build order badge of an element.
  static ValueKey<String> badge(String elementId) =>
      ValueKey<String>('slides.animate.badge.$elementId');

  /// The Magic Move match badge of an element.
  static ValueKey<String> match(String elementId) =>
      ValueKey<String>('slides.animate.match.$elementId');
}

/// The canvas side of the Animate tab (Slides 06 §5.5, §8.3):
///
/// - the **preview**: while one plays on the current slide the canvas is
///   read-only, SL-29's `SlidePlaybackStage` draws the player over the
///   slide and a floating bar offers *Stop* (Esc); any press stops it;
/// - **build order badges** at each animated element's top-left ("1",
///   "2–5", "0" for automatic) colored by kind; a click selects the build
///   in the Order list;
/// - **Magic Move match badges** (`link`, "Matches 'Title' on slide 4")
///   and, with View › *Show Magic Move matches*, the previous slide's
///   ghost outlines with connectors to their counterparts;
/// - the **motion path** of a selected `path` build: a dashed line from a
///   green start dot to a red end dot.
class AnimateCanvasLayer extends CanvasInteraction {
  AnimateCanvasLayer(super.c);

  AnimateView get _view => AnimateView.of(c.editor);
  DeckEditorController get _ed => c.editor;

  bool get _previewing {
    final p = AnimateView.maybeOf(_ed)?.preview;
    return p != null && p.active && p.slideId == _ed.currentSlideId;
  }

  @override
  bool get modal => _previewing;

  @override
  bool get active => _previewing;

  @override
  bool get hidesSelectionChrome => _previewing;

  @override
  bool down(CanvasPointer p) {
    if (!_previewing) return false;
    _view.preview.stop();
    return true;
  }

  @override
  List<KeyScope> get keyScopes =>
      _previewing ? const [KeyScope('slidesAnimatePreview')] : const [];

  @override
  SlideScene sceneFor(SlideScene scene) {
    if (!_previewing) return scene;
    // The preview stage draws the slide; the canvas keeps its background.
    return SlideScene(
      slideId: scene.slideId,
      width: scene.width,
      height: scene.height,
      background: scene.background,
      nodes: const [],
    );
  }

  // ----------------------------------------------------------------- paint

  @override
  void paint(Canvas canvas, CanvasTokens tokens) {
    final view = AnimateView.maybeOf(_ed);
    if (view == null || _previewing || _ed.editsMasters) return;
    if (view.showMatches) _paintMatches(canvas, view, tokens);
    _paintMotionPath(canvas, view, tokens);
  }

  void _paintMotionPath(Canvas canvas, AnimateView view, CanvasTokens t) {
    final builds = view.editedBuilds();
    if (builds.length != 1 || builds.single.effect != 'path') return;
    final b = builds.single;
    final e = c.elements?[b.elementId ?? ''];
    if (e == null) return;
    final opts = BuildOptions.decode(b.optionsJson).value;
    final spec = EffectCatalog.byId(b.kind, b.effect);
    final d = opts.param(spec, 'path');
    if (d is! String) return;
    final box = SlideElements.frameOf(e, c.scene).bounds;
    final center = Offset(box.x + box.width / 2, box.y + box.height / 2);
    final cmds = SvgPathParser.parse(d);
    if (cmds.isEmpty) return;
    final v = c.viewport;
    Offset pt(double x, double y) => v.toViewport(center + Offset(x, y));
    final path = ui.Path();
    Offset? start, end;
    for (final cmd in cmds) {
      switch (cmd) {
        case PMoveTo(:final x, :final y):
          final p = pt(x, y);
          path.moveTo(p.dx, p.dy);
          start ??= p;
          end = p;
        case PLineTo(:final x, :final y):
          final p = pt(x, y);
          path.lineTo(p.dx, p.dy);
          end = p;
        case PCubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x,
          :final y,
        ):
          final a = pt(x1, y1), bb = pt(x2, y2), p = pt(x, y);
          path.cubicTo(a.dx, a.dy, bb.dx, bb.dy, p.dx, p.dy);
          end = p;
        case PClose():
          path.close();
          end = start;
      }
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = t.selection;
    for (final m in path.computeMetrics()) {
      for (var s = 0.0; s < m.length; s += 10) {
        canvas.drawPath(m.extractPath(s, math.min(s + 6, m.length)), stroke);
      }
    }
    if (start != null) {
      canvas.drawCircle(start, 5, Paint()..color = const Color(0xFF16A34A));
    }
    if (end != null) {
      canvas.drawCircle(end, 5, Paint()..color = const Color(0xFFDC2626));
    }
  }

  void _paintMatches(Canvas canvas, AnimateView view, CanvasTokens t) {
    final m = _matches(view);
    if (m == null) return;
    final v = c.viewport;
    final ghost = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = t.selection.withValues(alpha: 0.3);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = t.selection.withValues(alpha: 0.6);
    for (final pair in m.pairs) {
      final a = v.rectToViewport(pair.from.frame);
      final b = v.rectToViewport(pair.to.frame);
      _dashedRect(canvas, a, ghost);
      canvas.drawLine(a.center, b.center, line);
      canvas.drawCircle(b.center, 2.5, Paint()..color = t.selection);
    }
  }

  static void _dashedRect(Canvas canvas, Rect r, Paint p) {
    final path = ui.Path()..addRect(r);
    for (final m in path.computeMetrics()) {
      for (var s = 0.0; s < m.length; s += 8) {
        canvas.drawPath(m.extractPath(s, math.min(s + 4, m.length)), p);
      }
    }
  }

  // ---------------------------------------------------------- Magic Move

  String _matchKey = '';
  MagicMoveMatches? _matchCache;
  String? _matchFrom;

  /// The matches of the current slide with the slide before it, when its
  /// transition is Magic Move (cached by both slides' revisions).
  MagicMoveMatches? _matches(AnimateView view) {
    final slideId = _ed.currentSlideId;
    if (slideId == null) return null;
    final model = view.model;
    final spec = TransitionSpec.effective(
      model.slide(slideId)?.transitionJson,
      model.deck?.defaultsJson,
    );
    if (spec.type != 'magicMove') return null;
    final prev = view.previousSlideOf(slideId);
    if (prev == null) return null;
    final key =
        '$prev|$slideId|${model.indexes.revision(prev)}|'
        '${model.indexes.revision(slideId)}|${spec.encode()}';
    if (key == _matchKey) return _matchCache;
    _matchKey = key;
    _matchFrom = prev;
    try {
      final a = MagicMoveSlide.fromDeck(
        model,
        prev,
        frame: view.timelineOf(prev, reduced: false).finalFrame,
        scene: c.renderer.scene(prev),
      );
      final b = MagicMoveSlide.fromDeck(
        model,
        slideId,
        frame: view.timelineOf(slideId, reduced: false).initial,
        scene: c.scene,
      );
      _matchCache = MagicMoveMatcher.match(
        a.elements,
        b.elements,
        options: spec.magicMove ?? const MagicMoveOptions(),
      );
    } on Object {
      _matchCache = null;
    }
    return _matchCache;
  }

  // -------------------------------------------------------------- widgets

  @override
  List<Widget> overlays(BuildContext context) {
    final view = AnimateView.maybeOf(_ed);
    if (view == null || _ed.editsMasters) return const [];
    if (_previewing) return _preview(context, view);
    return [
      if (view.badgesVisible) ..._badges(context, view),
      if (view.matchBadgesVisible) ..._matchBadges(context, view),
    ];
  }

  List<Widget> _preview(BuildContext context, AnimateView view) {
    final pb = view.preview.playback;
    if (pb == null) return const [];
    final v = c.viewport;
    final slide = c.renderer.slideSize;
    final o = v.origin;
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    return [
      Positioned(
        left: o.dx,
        top: o.dy,
        width: slide.width * v.scale,
        height: slide.height * v.scale,
        child: IgnorePointer(
          child: SlidePlaybackStage(
            key: AnimateCanvasKeys.preview,
            playback: pb,
            renderer: c.renderer,
            scale: v.scale,
            reducedMotion: view.previewReduced,
            semanticLabel: l.animatePreviewPlaying,
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 16,
        child: Center(
          child: CanvasChrome(
            child: DecoratedBox(
              key: AnimateCanvasKeys.previewBar,
              decoration: BoxDecoration(
                color: theme.colorScheme.popover,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.play,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l.animatePreviewPlaying,
                        style: theme.textTheme.small,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton.ghost(
                      key: AnimateCanvasKeys.stop,
                      size: ShadButtonSize.sm,
                      leading: const Icon(LucideIcons.square, size: 14),
                      onPressed: () => _ed.invokeCommand(
                        'slides.animate.stopPreview',
                        const {},
                        InvocationSource.ui,
                      ),
                      child: Text(l.animatePreviewStop),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _badges(BuildContext context, AnimateView view) {
    final slideId = _ed.currentSlideId;
    final els = c.elements;
    if (slideId == null || els == null) return const [];
    final order = view.orderOf(slideId);
    final tokens = SlidesTokens.of(context);
    final l = slidesL10n(context);
    final out = <Widget>[];
    for (final MapEntry(key: id, value: rows) in order.byElement.entries) {
      final e = els[id];
      if (e == null) continue;
      final r = c.viewport.rectToViewport(
        SlideElements.frameOf(e, c.scene).bounds,
      );
      final steps = <int>{
        for (final row in rows) ...(row.steps.isEmpty ? [row.step] : row.steps),
      }.toList()..sort();
      final label = _stepsLabel(steps);
      final color = tokens.buildKind(rows.first.build.kind.name);
      final selected = rows.any(
        (row) => view.selectedBuildIds.contains(row.id),
      );
      out.add(
        Positioned(
          left: r.left - 6,
          top: r.top - 10,
          child: CanvasChrome(
            child: _Chip(
              key: AnimateCanvasKeys.badge(id),
              color: color,
              selected: selected,
              tooltip: l.animateBadgeTooltip(
                BuildLabels.element(l, view.model.element(id)),
                label,
              ),
              onTap: () {
                view.selectBuilds([rows.first.id]);
                _ed.openInspector(InspectorTab.animate, animateTab: 'order');
              },
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  /// "1", "2–5", "1, 3" — compact step lists of a badge.
  static String _stepsLabel(List<int> steps) {
    if (steps.isEmpty) return '';
    final runs = <List<int>>[];
    for (final s in steps) {
      if (runs.isNotEmpty && runs.last.last == s - 1) {
        runs.last.add(s);
      } else {
        runs.add([s]);
      }
    }
    final parts = [for (final r in runs) BuildOrderRow.stepRangeLabel(r)];
    if (parts.length > 3) return '${parts.first}…${parts.last}';
    return parts.join(', ');
  }

  List<Widget> _matchBadges(BuildContext context, AnimateView view) {
    final m = _matches(view);
    final from = _matchFrom;
    if (m == null || from == null) return const [];
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final number = (_ed.order.entry(from)?.index ?? 0) + 1;
    final out = <Widget>[];
    for (final pair in m.pairs) {
      final r = c.viewport.rectToViewport(pair.to.frame);
      final name = BuildLabels.element(l, view.model.element(pair.from.id));
      out.add(
        Positioned(
          left: r.right - 10,
          top: r.top - 10,
          child: CanvasChrome(
            child: _Chip(
              key: AnimateCanvasKeys.match(pair.to.id),
              color: theme.colorScheme.primary,
              tooltip: l.animateMatchTooltip(name, number),
              onTap: () => _ed.invokeCommand(
                'slides.magicMove.toggleMatches',
                const {},
                InvocationSource.ui,
              ),
              child: const Icon(
                LucideIcons.link,
                size: 10,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }
}

/// A small colored chip on the canvas (badges).
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.color,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.selected = false,
  });

  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) => Text(tooltip),
      child: Semantics(
        button: true,
        label: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.foreground
                      : theme.colorScheme.background,
                  width: selected ? 2 : 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
