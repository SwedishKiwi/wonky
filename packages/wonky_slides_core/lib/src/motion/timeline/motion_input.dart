/// What the timeline compiler needs for one slide (06 §9.4): the slide,
/// its builds, the effective transition, and the animated elements'
/// geometry (frames, text, part boxes, chart shape, code states).
library;

import 'dart:math' as math;

import '../../model/api/deck_model.dart';
import '../../model/api/deck_reader.dart';
import '../../model/api/kinds.dart';
import '../../model/api/records.dart';
import '../../model/resolve/slide_resolver.dart';
import '../../scene/nodes/scene_nodes.dart';
import '../../theme/model/common.dart' show SuRect;
import '../builds/parts.dart';
import '../builds/transition_spec.dart';

/// One code state of a code element, for code builds (07 §6).
final class MotionCodeState {
  /// Creates a state.
  const MotionCodeState({this.length = 0, this.highlightSteps = 0, this.mode});

  /// Characters of the state's source.
  final int length;

  /// How the state is reached (`transitionJson.mode`: type, morph,
  /// instant), or null = type.
  final String? mode;

  /// The `mode` of a `CodeState.transitionJson`, or null.
  static String? modeOf(String? transitionJson) {
    if (transitionJson == null) return null;
    final m = RegExp(
      r'"mode"\s*:\s*"(type|morph|instant)"',
    ).firstMatch(transitionJson);
    return m?.group(1);
  }

  /// Number of highlight steps (`CodeState.highlight`, 07 §4.1).
  final int highlightSteps;

  /// Counts the `|`-separated steps of a highlight expression.
  static int stepsOf(String? highlight) {
    if (highlight == null) return 0;
    return highlight.split('|').where((s) => s.trim().isNotEmpty).length;
  }
}

/// An element as the timeline sees it.
final class MotionElement {
  /// Creates an element.
  const MotionElement({
    required this.id,
    required this.kind,
    required this.frame,
    this.rotation = 0,
    this.opacity = 1,
    this.text,
    this.partBoxes,
    this.chart,
    this.codeStates = const [],
    this.hidden = false,
  });

  final String id;
  final ElementKind kind;

  /// Effective frame (su, unrotated box; derived frames of auto-sized
  /// text included).
  final SuRect frame;

  /// Degrees clockwise.
  final double rotation;

  /// Authored opacity (0..1).
  final double opacity;

  /// Text for text deliveries and typewriter (text boxes, shapes).
  final MotionText? text;

  /// Element-local box of a character range (from the text layout), or
  /// null: part transforms then use the element's center.
  final SuRect? Function(int start, int end)? partBoxes;

  /// Chart data shape for chart deliveries, or null.
  final ChartShape? chart;

  /// Code states in order (code elements).
  final List<MotionCodeState> codeStates;

  /// Not drawn (`SlideElement.hidden`).
  final bool hidden;

  /// The element's center (su).
  ({double x, double y}) get center =>
      (x: frame.x + frame.width / 2, y: frame.y + frame.height / 2);
}

/// Compile options (06 §13, §4.4).
final class CompileOptions {
  /// Creates options.
  const CompileOptions({
    this.reducedMotion = false,
    this.ignoreAutoBuilds = false,
  });

  /// Applies the reduced-motion replacements (06 §13).
  final bool reducedMotion;

  /// Keeps onClick steps even when the transition's `advance.autoBuilds`
  /// is on (the editor's Order tab shows the authored clicks).
  final bool ignoreAutoBuilds;
}

/// Resolves a color string (`#RRGGBB`, `theme:<key>`) to ARGB.
typedef MotionColorResolver = int? Function(String color);

/// The compiler's input for one slide (06 §9.4).
final class SlideMotionInput {
  /// Creates the input. Without [elements] the compiler can't validate
  /// element references or center transforms: use [SlideMotionInput.fromDeck]
  /// wherever the deck is at hand.
  const SlideMotionInput({
    required this.slide,
    this.builds = const [],
    this.elements,
    this.transition = TransitionSpec.none,
    this.slideWidth = 1920,
    this.slideHeight = 1080,
    this.options = const CompileOptions(),
    this.resolveColor,
  });

  /// The input of [slideId] of [deck]: builds, the effective transition
  /// (06 §7.1), and every top-level element of the slide resolved through
  /// [resolved] (or a `SlideResolver` when [deck] is a `DeckModel`), with
  /// derived frames and text part boxes from [scene] when given.
  /// [chartShapeOf] supplies chart data shapes (08); without it chart
  /// deliveries read the snapshot's `series`/`domain` when present.
  factory SlideMotionInput.fromDeck(
    DeckReader deck,
    String slideId, {
    ResolvedSlide? resolved,
    SlideScene? scene,
    CompileOptions options = const CompileOptions(),
    ChartShape? Function(SlideElementRec element)? chartShapeOf,
  }) {
    final slide = deck.slide(slideId);
    if (slide == null) {
      throw ArgumentError.value(slideId, 'slideId', 'No such slide');
    }
    final rs =
        resolved ??
        (deck is DeckModel ? SlideResolver(deck).resolve(slideId) : null);
    final elements = <String, MotionElement>{};
    final textNodes = <String, TextNode>{};
    if (scene != null) {
      for (final n in scene.nodes) {
        _collectText(n, textNodes);
      }
    }
    void add(
      SlideElementRec rec,
      SuRect? frame,
      double rotation,
      double opacity,
    ) {
      final f = scene?.frames[rec.id] ?? frame ?? const SuRect(0, 0, 0, 0);
      final tn = textNodes[rec.id];
      ChartShape? chart;
      if (rec.kind == ElementKind.chart) {
        chart =
            chartShapeOf?.call(rec) ??
            ChartShape.tryParse(deck.chartLinkOf(rec.id)?.dataSnapshotJson) ??
            ChartShape.tryParse(rec.dataJson);
      }
      elements[rec.id] = MotionElement(
        id: rec.id,
        kind: rec.kind,
        frame: f,
        rotation: rotation,
        opacity: opacity,
        hidden: rec.hidden,
        text: rec.kind.hasText ? MotionText.fromDelta(rec.text) : null,
        partBoxes: tn == null ? null : (s, e) => _partBox(tn, s, e),
        chart: chart,
        codeStates: rec.kind == ElementKind.code
            ? [
                for (final s in deck.codeStatesOf(rec.id))
                  MotionCodeState(
                    length: s.code.length,
                    highlightSteps: MotionCodeState.stepsOf(s.highlight),
                    mode: MotionCodeState.modeOf(s.transitionJson),
                  ),
              ]
            : const [],
      );
    }

    if (rs != null) {
      for (final e in rs.elements) {
        add(e.record, e.frame, e.rotation, e.opacity);
      }
    } else {
      for (final rec in deck.elementsOf(slideId)) {
        add(rec, rec.frame, rec.rotation ?? 0, rec.opacity ?? 1);
      }
    }
    final themeColor = rs?.theme;
    return SlideMotionInput(
      slide: slide,
      builds: deck.buildsOf(slideId),
      elements: elements,
      transition: TransitionSpec.effective(
        slide.transitionJson,
        deck.deck?.defaultsJson,
      ),
      slideWidth: deck.deck?.width ?? 1920,
      slideHeight: deck.deck?.height ?? 1080,
      options: options,
      resolveColor: themeColor == null
          ? null
          : (c) => themeColor.colorString(c, fallback: 0),
    );
  }

  final SlideRec slide;

  /// The slide's builds in order.
  final List<SlideBuildRec> builds;

  /// Top-level elements of the slide by id; null = unknown (no reference
  /// checks, transforms about the origin).
  final Map<String, MotionElement>? elements;

  /// The effective transition into the slide (advance, auto builds).
  final TransitionSpec transition;
  final double slideWidth, slideHeight;
  final CompileOptions options;

  /// Color resolution for `colorChange`/`highlight`/`dimColor`; null =
  /// hex colors only.
  final MotionColorResolver? resolveColor;
}

void _collectText(SceneNode n, Map<String, TextNode> out) {
  if (n is TextNode && n.elementId != null && n.partId == null) {
    out.putIfAbsent(n.elementId!, () => n);
  }
  if (n is GroupNode) {
    for (final c in n.children) {
      _collectText(c, out);
    }
  }
}

SuRect? _partBox(TextNode n, int start, int end) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final line in n.layout.lines) {
    if (line.end <= start || line.start >= end) continue;
    for (final r in line.runs) {
      final rs = r.start, re = r.start + r.text.length;
      if (re <= start || rs >= end) continue;
      final x0 = n.originX + line.left + r.x;
      minX = math.min(minX, x0);
      maxX = math.max(maxX, x0 + r.width);
      minY = math.min(minY, n.originY + line.top);
      maxY = math.max(maxY, n.originY + line.top + line.height);
    }
  }
  if (!minX.isFinite) return null;
  return SuRect(minX, minY, maxX - minX, maxY - minY);
}
