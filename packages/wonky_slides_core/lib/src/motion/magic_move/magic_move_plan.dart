/// The Magic Move plan (06 §8.4–§8.6, §9.5): matched pairs with their
/// precomputed interpolation descriptors (geometry, colors, resampled
/// outlines, aligned glyph runs, code token pairs, chart cameras), the
/// unmatched elements, the draw order, and frame evaluation.
///
/// **Frame contract (for the renderer, SL-29).** [MagicMovePlan.frameAt]
/// returns a [MagicMoveFrame] with one `SlideFrame` per slide —
/// [MagicMoveFrame.outgoing] for the outgoing slide's scene and
/// [MagicMoveFrame.incoming] for the incoming one — whose element states
/// are ordinary `ElementVisualState`s (slide-space transforms
/// pre-multiplied before the element's own transform, opacity multipliers,
/// color overrides, text part states), plus [MagicMoveFrame.layers] (what
/// to paint, back to front) and per-pair descriptors
/// ([MagicMoveFrame.pairs]) for what a frame state can't say (morphed
/// outlines, code token glyphs, image crops). A renderer that draws both
/// scenes with these frames in layer order shows the whole morph; the
/// descriptors refine it:
///
/// - `replace`: only the incoming element is drawn, its box stretched onto
///   the interpolated geometry, colors blended (`colors`), chart camera
///   interpolated (`chart.camera`).
/// - `path`: as `replace`, but the renderer draws [MorphPairState.path]
///   (in the incoming element's local space) instead of its outline.
/// - `crossfade`: both are drawn on the interpolated geometry (text kinds
///   rigidly, never stretched), the outgoing fading out while the incoming
///   fades in; [MorphPairState.code] / `chartMorph` / `crop` let a renderer
///   morph the content instead (code tokens, chart scenes, image crops).
/// - `glyphs`: both text elements are placed rigidly on the interpolated
///   center/rotation; the outgoing element's matched glyph runs move as
///   text parts (transform + color) to their new place, its unmatched
///   ranges fade out in the first half; the incoming element hides its
///   matched ranges and fades in its new ranges in the second half.
///
/// Elements of the outgoing slide that the frame doesn't mention keep the
/// state of the outgoing slide's final frame (hidden by builds stays
/// hidden); likewise the incoming slide's initial frame. Group children
/// have their own states (06 §8.3: matched recursively), so renderers apply
/// nested element states too.
library;

import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:wonky_code/wonky_code.dart'
    show CachedCodeTokenizer, TokenMorphPlan, CodeToken;

import '../../model/api/kinds.dart';
import '../../scene/nodes/scene_nodes.dart' show ScenePath;
import '../builds/transition_spec.dart';
import '../easing/motion_easing.dart';
import '../timeline/slide_frame.dart';
import 'chart_camera.dart';
import 'magic_move_matcher.dart';
import 'magic_move_slide.dart';
import 'morph_geometry.dart';
import 'path_morph.dart';
import 'text_morph.dart';

double _r(double v) => (v * 1e6).roundToDouble() / 1e6;

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// How a matched pair morphs.
enum MorphMode {
  /// Same content: the incoming element is drawn on the interpolated
  /// geometry (colors and the 3D camera interpolate).
  replace,

  /// Different shape outlines: as [replace] with the morphed outline.
  path,

  /// Different content: both are drawn, crossfading.
  crossfade,

  /// Text with glyph runs (word/character matching, or identical text).
  glyphs,

  /// Element groups: both group nodes are drawn; their children morph as
  /// pairs of their own.
  group,
}

/// Which slide a layer or state belongs to.
enum MagicMoveSide {
  /// The outgoing slide (A).
  from,

  /// The incoming slide (B).
  to,
}

/// One paint layer of a Magic Move frame: a slide's background (no
/// [elementId]) or a top-level node (element or layout/master decoration).
final class MagicMoveLayer {
  /// Creates a layer.
  const MagicMoveLayer(this.side, [this.elementId]);

  final MagicMoveSide side;

  /// The element (or decoration) id; null = the slide's background.
  final String? elementId;

  /// Whether this is a background layer.
  bool get isBackground => elementId == null;

  /// Canonical JSON (`"from:bg"`, `"to:<id>"`).
  String toJson() => '${side.name}:${elementId ?? 'bg'}';

  @override
  String toString() => toJson();
}

/// A matched pair with its precomputed descriptors (06 §9.5 `MorphPair`).
final class MorphPair {
  MorphPair._({
    required this.match,
    required this.mode,
    required this.index,
    required this.logSize,
    required this.rotationDelta,
    required this.fromAuthored,
    required this.toAuthored,
    this.path,
    this.text,
    this.code,
    this.fromCamera,
    this.toCamera,
    this.chartMorph = false,
    this.textCrossfade = false,
  });

  final MagicMoveMatch match;
  final MorphMode mode;

  /// Reading-order index (stagger, 06 §8.6).
  final int index;

  /// Size in log space (same aspect ratio).
  final bool logSize;

  /// Rotation from the outgoing to the incoming element (degrees).
  final double rotationDelta;

  /// The authored boxes (what the frame transforms map from).
  final MorphGeometry fromAuthored, toAuthored;

  /// Outline morph ([MorphMode.path]).
  final PathMorph? path;

  /// Glyph runs ([MorphMode.glyphs]).
  final TextMorph? text;

  /// Token morph between the displayed code states (code pairs).
  final TokenMorphPlan? code;

  /// 3D cameras (chart pairs with a camera on either side).
  final ChartCameraView? fromCamera, toCamera;

  /// Same chart source with different data: a renderer with a chart scene
  /// morph (`ChartSceneMorph`, 08 §9.4) morphs instead of crossfading.
  final bool chartMorph;

  /// Object-level text crossfade over the middle 60 % (06 §8.4).
  final bool textCrossfade;

  MagicMoveElement get from => match.from;
  MagicMoveElement get to => match.to;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'from': from.id,
    'to': to.id,
    'pass': match.pass.name,
    'mode': mode.name,
    'index': index,
    if (logSize) 'logSize': true,
    if (rotationDelta != 0) 'rotation': _r(rotationDelta),
    if (path != null) 'path': path!.toJson(),
    if (text != null) 'text': text!.toJson(),
    if (code != null)
      'code': {
        'matched': code!.matched.length,
        'removed': code!.removed.length,
        'added': code!.added.length,
      },
    if (fromCamera != null) 'fromCamera': fromCamera!.toJson(),
    if (toCamera != null) 'toCamera': toCamera!.toJson(),
    if (chartMorph) 'chartMorph': true,
  };
}

/// Per-pair values of one frame (beyond the element states).
final class MorphPairState {
  /// Creates a state.
  const MorphPairState({
    required this.fromId,
    required this.toId,
    required this.mode,
    required this.progress,
    required this.contentMix,
    required this.geometry,
    this.path,
    this.camera,
    this.codeProgress,
    this.crop,
  });

  final String fromId, toId;
  final MorphMode mode;

  /// Eased progress of the pair (0..1, stagger applied).
  final double progress;

  /// 0 = the outgoing content, 1 = the incoming (crossfade).
  final double contentMix;

  /// The interpolated geometry (slide space).
  final MorphGeometry geometry;

  /// [MorphMode.path]: the outline in the incoming element's local space.
  final ScenePath? path;

  /// The interpolated 3D chart camera, or null.
  final ChartCameraView? camera;

  /// Linear progress of the code token morph (`plan.frameAt(codeProgress ×
  /// plan.totalDurationMs)`), or null.
  final double? codeProgress;

  /// Interpolated image crop `{x, y, w, h}`, or null.
  final Map<String, double>? crop;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'from': fromId,
    'to': toId,
    'mode': mode.name,
    'progress': _r(progress),
    if (contentMix != 1 || mode == MorphMode.crossfade)
      'contentMix': _r(contentMix),
    'geometry': geometry.toJson(),
    if (path != null) 'pathPoints': path!.commands.length,
    if (camera != null) 'camera': camera!.toJson(),
    if (codeProgress != null) 'codeProgress': _r(codeProgress!),
    if (crop != null)
      'crop': {for (final e in crop!.entries) e.key: _r(e.value)},
  };
}

/// One frame of a Magic Move (see the library comment for the contract).
final class MagicMoveFrame {
  /// Creates a frame.
  const MagicMoveFrame({
    required this.progress,
    required this.outgoing,
    required this.incoming,
    required this.layers,
    this.pairs = const {},
  });

  /// Eased overall progress (0..1).
  final double progress;

  /// States for the outgoing slide's scene.
  final SlideFrame outgoing;

  /// States for the incoming slide's scene (its `background.opacity` is the
  /// background crossfade).
  final SlideFrame incoming;

  /// Paint order, back to front.
  final List<MagicMoveLayer> layers;

  /// Pair descriptors by incoming element id.
  final Map<String, MorphPairState> pairs;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'progress': _r(progress),
    'outgoing': outgoing.toJson(),
    'incoming': incoming.toJson(),
    'layers': [for (final l in layers) l.toJson()],
    'pairs': {
      for (final k in pairs.keys.toList()..sort()) k: pairs[k]!.toJson(),
    },
  };
}

/// Fraction of the duration that unmatched elements take to fade before or
/// after the morph (`fadeUnmatched: before | after`).
const double _fadePhase = 0.35;

/// The compiled Magic Move between two slides (06 §9.5 `TransitionPlan`
/// for `magicMove`).
final class MagicMovePlan {
  MagicMovePlan._(
    this._carriers, {
    required this.from,
    required this.to,
    required this.matches,
    required this.pairs,
    required this.options,
    required this.morphMs,
    required this.durationMs,
    required this.curve,
    required this.layers,
    required this.sameBackground,
    required this.sameChrome,
    required this.cameraLerp,
  });

  /// The outgoing and incoming slides.
  final MagicMoveSlide from, to;

  /// The matcher's result.
  final MagicMoveMatches matches;

  /// Every matched pair (groups and their children, depth first).
  final List<MorphPair> pairs;
  final MagicMoveOptions options;

  /// Length of one pair's morph (ms).
  final int morphMs;

  /// Total length (ms): the morph plus the stagger of the last pair.
  final int durationMs;

  /// The transition's easing.
  final MotionEasing curve;

  /// Paint order, back to front.
  final List<MagicMoveLayer> layers;

  /// Both slides have the same background (no crossfade).
  final bool sameBackground;

  /// Both slides have the same layout/master decorations (they stay).
  final bool sameChrome;
  final ChartCameraLerp cameraLerp;

  /// Unmatched group children → the group pair they ride with.
  final Map<String, (MorphPair, MagicMoveSide)> _carriers;

  /// Whether any element matched (else the transition plays as a fade,
  /// 06 §8.5).
  bool get hasMatches => matches.pairs.isNotEmpty;

  /// Ids of every unmatched outgoing element (any depth).
  List<String> get outgoingIds => [
    for (final e in matches.outgoing) e.id,
    for (final p in pairs) ...[for (final e in p.match.children.outgoing) e.id],
  ];

  /// Ids of every unmatched incoming element (any depth).
  List<String> get incomingIds => [
    for (final e in matches.incoming) e.id,
    for (final p in pairs) ...[for (final e in p.match.children.incoming) e.id],
  ];

  /// Compiles the Magic Move from [from] (the outgoing slide in its final
  /// frame) to [to] (the incoming slide in its initial frame) with the
  /// transition [spec] (`magicMove` options, duration, easing; default: the
  /// catalog's Magic Move).
  /// [reverse]: playing the incoming slide's transition backwards (06 §6):
  /// `fadeUnmatched: before` and `after` swap.
  static MagicMovePlan compile(
    MagicMoveSlide from,
    MagicMoveSlide to, {
    TransitionSpec? spec,
    bool reverse = false,
    ChartCameraLerp cameraLerp = ChartCameraView.lerp,
  }) {
    spec ??= TransitionSpec.of('magicMove');
    var options = spec.magicMove ?? const MagicMoveOptions();
    if (reverse && options.fadeUnmatched != 'together') {
      options = MagicMoveOptions(
        textMatching: options.textMatching,
        matchByContent: options.matchByContent,
        fadeUnmatched: options.fadeUnmatched == 'before' ? 'after' : 'before',
        rotation: options.rotation,
        stagger: options.stagger,
      );
    }
    final matches = MagicMoveMatcher.match(
      from.elements,
      to.elements,
      options: options,
    );
    final bound = spec.curve.bind(spec.durationMs);
    final morphMs = bound.durationMs;

    // Pairs (depth first) in reading order of the incoming elements.
    final flat = matches.allPairs.toList();
    final order = [...flat]
      ..sort((x, y) {
        final gx = x.to.geometry.frame, gy = y.to.geometry.frame;
        final c = gx.y.compareTo(gy.y);
        if (c != 0) return c;
        final cx = gx.x.compareTo(gy.x);
        return cx != 0 ? cx : x.to.z.compareTo(y.to.z);
      });
    final index = {for (var i = 0; i < order.length; i++) order[i].to.id: i};
    final pairs = [for (final m in flat) _pair(m, index[m.to.id]!, options)];
    final stagger = options.stagger;
    final durationMs = pairs.isEmpty
        ? morphMs
        : morphMs + stagger * (pairs.length - 1);

    final carriers = <String, (MorphPair, MagicMoveSide)>{};
    for (final p in pairs) {
      for (final e in p.match.children.outgoing) {
        carriers[e.id] = (p, MagicMoveSide.from);
      }
      for (final e in p.match.children.incoming) {
        carriers[e.id] = (p, MagicMoveSide.to);
      }
    }
    final sameBackground = from.backgroundKey == to.backgroundKey;
    final sameChrome = from.chromeKey == to.chromeKey;
    final layers = _layers(
      from,
      to,
      matches,
      {for (final p in pairs) p.to.id: p},
      sameBackground,
      sameChrome,
    );
    return MagicMovePlan._(
      carriers,
      from: from,
      to: to,
      matches: matches,
      pairs: pairs,
      options: options,
      morphMs: morphMs,
      durationMs: durationMs,
      curve: bound.easing,
      layers: layers,
      sameBackground: sameBackground,
      sameChrome: sameChrome,
      cameraLerp: cameraLerp,
    );
  }

  static MorphPair _pair(MagicMoveMatch m, int index, MagicMoveOptions o) {
    final a = m.from, b = m.to;
    final fromAuthored = MorphGeometry.of(a.frame, a.rotation);
    final toAuthored = MorphGeometry.of(b.frame, b.rotation);
    final ga = a.geometry, gb = b.geometry;
    final rotationDelta = o.rotation == 'literal'
        ? (b.literalRotation ?? b.rotation) - (a.literalRotation ?? a.rotation)
        : MorphGeometry.shortestDelta(ga.rotation, gb.rotation);
    final logSize = MorphGeometry.sameAspect(ga, gb);
    final sameKind = a.kind == b.kind;
    final sameContent =
        sameKind && a.contentKey != null && a.contentKey == b.contentKey;

    MorphMode mode;
    PathMorph? path;
    TextMorph? text;
    var textCrossfade = false;
    if (a.kind == ElementKind.group && b.kind == ElementKind.group) {
      mode = MorphMode.group;
    } else if (sameKind &&
        a.kind == ElementKind.text &&
        a.text != null &&
        b.text != null &&
        (o.textMatching != 'object' || a.text!.plain == b.text!.plain)) {
      text = TextMorph.build(
        a.text!,
        b.text!,
        a.text!.plain == b.text!.plain ? 'character' : o.textMatching,
      );
      mode = text == null ? MorphMode.crossfade : MorphMode.glyphs;
      textCrossfade = text == null;
    } else if (sameKind &&
        a.kind == ElementKind.shape &&
        a.geometryKey != b.geometryKey &&
        _sameButGeometry(a, b)) {
      final oa = a.outline, ob = b.outline;
      path = oa == null || ob == null
          ? null
          : PathMorph.build(
              oa,
              a.frame.width,
              a.frame.height,
              ob,
              b.frame.width,
              b.frame.height,
            );
      mode = path == null ? MorphMode.crossfade : MorphMode.path;
    } else if (sameContent &&
        (a.kind != ElementKind.shape || a.geometryKey == b.geometryKey)) {
      mode = MorphMode.replace;
    } else {
      mode = MorphMode.crossfade;
      textCrossfade = a.kind == ElementKind.text && sameKind;
    }

    TokenMorphPlan? code;
    final ca = a.code, cb = b.code;
    if (ca != null && cb != null) {
      final tk = CachedCodeTokenizer.shared;
      List<CodeToken> tokens(String code, String lang) =>
          lang.isEmpty || !tk.supports(lang)
          ? const []
          : tk.tokenize(code, lang);
      code = TokenMorphPlan.build(
        ca.code,
        cb.code,
        fromTokens: tokens(ca.code, ca.language),
        toTokens: tokens(cb.code, cb.language),
        fromLayout: ca.layout,
        toLayout: cb.layout,
      );
    }
    final camA = a.chart?.camera, camB = b.chart?.camera;
    final chartMorph =
        a.chart != null &&
        b.chart != null &&
        a.chart!.source == b.chart!.source &&
        a.chart!.dataHash != b.chart!.dataHash;
    return MorphPair._(
      match: m,
      mode: mode,
      index: index,
      logSize: logSize,
      rotationDelta: rotationDelta,
      fromAuthored: fromAuthored,
      toAuthored: toAuthored,
      path: path,
      text: text,
      code: code,
      fromCamera: camA ?? camB,
      toCamera: camB ?? camA,
      chartMorph: chartMorph,
      textCrossfade: textCrossfade,
    );
  }

  /// Shapes whose content keys are equal (only the outline differs).
  static bool _sameButGeometry(MagicMoveElement a, MagicMoveElement b) =>
      a.contentKey != null && a.contentKey == b.contentKey;

  /// Paint order (06 §8.4): backgrounds, decorations, then the incoming
  /// slide's order for matched and incoming elements; outgoing elements at
  /// their outgoing rank next to their nearest matched neighbor.
  static List<MagicMoveLayer> _layers(
    MagicMoveSlide from,
    MagicMoveSlide to,
    MagicMoveMatches matches,
    Map<String, MorphPair> byTo,
    bool sameBackground,
    bool sameChrome,
  ) {
    const f = MagicMoveSide.from, t = MagicMoveSide.to;
    final out = <MagicMoveLayer>[
      if (!sameBackground) const MagicMoveLayer(f),
      const MagicMoveLayer(t),
      if (!sameChrome)
        for (final id in from.chrome) MagicMoveLayer(f, id),
      for (final id in to.chrome) MagicMoveLayer(t, id),
    ];
    final matchedA = <String, String>{
      for (final p in matches.pairs) p.from.id: p.to.id,
    };
    final before = <String, List<String>>{}, after = <String, List<String>>{};
    final bottom = <String>[];
    final outgoing = {for (final e in matches.outgoing) e.id};
    final aList = from.elements;
    for (var i = 0; i < aList.length; i++) {
      final id = aList[i].id;
      if (!outgoing.contains(id)) continue;
      String? anchor;
      for (var k = i - 1; k >= 0 && anchor == null; k--) {
        anchor = matchedA[aList[k].id];
      }
      if (anchor != null) {
        (after[anchor] ??= []).add(id);
        continue;
      }
      for (var k = i + 1; k < aList.length && anchor == null; k++) {
        anchor = matchedA[aList[k].id];
      }
      if (anchor != null) {
        (before[anchor] ??= []).add(id);
      } else {
        bottom.add(id);
      }
    }
    for (final id in bottom) {
      out.add(MagicMoveLayer(f, id));
    }
    for (final e in to.elements) {
      for (final id in before[e.id] ?? const <String>[]) {
        out.add(MagicMoveLayer(f, id));
      }
      final p = byTo[e.id];
      if (p != null &&
          p.mode != MorphMode.replace &&
          p.mode != MorphMode.path) {
        out.add(MagicMoveLayer(f, p.from.id));
      }
      out.add(MagicMoveLayer(t, e.id));
      for (final id in after[e.id] ?? const <String>[]) {
        out.add(MagicMoveLayer(f, id));
      }
    }
    return out;
  }

  double _ease(double t) => curve.transform(_clamp01(t));

  double _window(int ms, num start, num length) =>
      _ease(_linear(ms, start, length));

  static double _linear(int ms, num start, num length) =>
      length <= 0 ? (ms >= start ? 1 : 0) : _clamp01((ms - start) / length);

  /// The frame at [ms] since the transition started (clamped to
  /// `[0, durationMs]`).
  MagicMoveFrame frameAt(int ms) {
    final t = ms < 0 ? 0 : (ms > durationMs ? durationMs : ms);
    final fade = options.fadeUnmatched;
    final last = pairs.isEmpty ? 0 : options.stagger * (pairs.length - 1);
    final morphLen = fade == 'together'
        ? morphMs
        : (morphMs * (1 - _fadePhase)).round();
    final morphStart = fade == 'before' ? morphMs - morphLen : 0;
    final (outStart, outLen) = switch (fade) {
      'before' => (0, morphMs - morphLen),
      'after' => (0, morphLen + last),
      _ => (0, durationMs),
    };
    final (inStart, inLen) = switch (fade) {
      'before' => (morphStart, durationMs - morphStart),
      'after' => (morphLen + last, durationMs - morphLen - last),
      _ => (0, durationMs),
    };
    final fOut = _window(t, outStart, outLen);
    final fIn = _window(t, inStart, inLen);
    final global = _window(t, 0, durationMs);

    final outStates = Map<String, ElementVisualState>.of(from.frame.elements);
    final inStates = Map<String, ElementVisualState>.of(to.frame.elements);
    final pairStates = <String, MorphPairState>{};
    final geometryOf = <String, MorphGeometry>{};

    for (final p in pairs) {
      final lin = _linear(t, morphStart + options.stagger * p.index, morphLen);
      final st = _pairFrame(p, _ease(lin), lin, outStates, inStates);
      pairStates[p.to.id] = st;
      geometryOf[p.to.id] = st.geometry;
    }

    // Unmatched elements: fade in place (group children ride with their
    // group's morph).
    Matrix4? carrier(String id) {
      final c = _carriers[id];
      if (c == null) return null;
      final (p, side) = c;
      final g = geometryOf[p.to.id]!;
      return g.stretchFrom(
        side == MagicMoveSide.from ? p.fromAuthored : p.toAuthored,
      );
    }

    for (final e in matches.outgoing) {
      outStates[e.id] = _faded(e.state, 1 - fOut, null);
    }
    for (final e in matches.incoming) {
      inStates[e.id] = _faded(e.state, fIn, null);
    }
    for (final p in pairs) {
      for (final e in p.match.children.outgoing) {
        outStates[e.id] = _faded(e.state, 1 - fOut, carrier(e.id));
      }
      for (final e in p.match.children.incoming) {
        inStates[e.id] = _faded(e.state, fIn, carrier(e.id));
      }
    }

    // Decorations and backgrounds.
    for (final id in from.chrome) {
      outStates[id] = sameChrome
          ? ElementVisualState(visible: false)
          : ElementVisualState(opacity: 1 - global);
    }
    if (!sameChrome) {
      for (final id in to.chrome) {
        inStates[id] = ElementVisualState(opacity: global);
      }
    }
    return MagicMoveFrame(
      progress: global,
      outgoing: SlideFrame(Map.unmodifiable(outStates)),
      incoming: SlideFrame(
        Map.unmodifiable(inStates),
        BackgroundState(opacity: sameBackground ? 1 : global),
      ),
      layers: layers,
      pairs: Map.unmodifiable(pairStates),
    );
  }

  /// Writes the states of pair [p] at eased progress [e] ([linear]: before
  /// the easing).
  MorphPairState _pairFrame(
    MorphPair p,
    double e,
    double linear,
    Map<String, ElementVisualState> outStates,
    Map<String, ElementVisualState> inStates,
  ) {
    final a = p.from, b = p.to;
    final g = MorphGeometry.lerp(
      a.geometry,
      b.geometry,
      e,
      logSize: p.logSize,
      rotationDelta: p.rotationDelta,
    );
    final shown = a.shownOpacity + (b.shownOpacity - a.shownOpacity) * e;
    double rel(MagicMoveElement x) =>
        x.opacity <= 1e-9 ? shown : shown / x.opacity;
    final camera = p.fromCamera == null
        ? null
        : cameraLerp(p.fromCamera!, p.toCamera!, e);
    ChartRevealState? chart(ElementVisualState s) {
      if (camera == null) return s.chart;
      final c = s.chart;
      return ChartRevealState(
        backgroundOpacity: c?.backgroundOpacity ?? 1,
        parts: c?.parts ?? const [],
        highlight: c?.highlight,
        highlightMix: c?.highlightMix ?? 0,
        camera: camera.toJson(),
        cameraMix: 1,
      );
    }

    final colors = <String, ColorOverride>{};
    void color(String key, int? x, int? y) {
      if (x != null && y != null && x != y) {
        colors[key] = ColorOverride(from: x, to: y, mix: e);
      }
    }

    var contentMix = 1.0;
    ScenePath? path;
    switch (p.mode) {
      case MorphMode.replace || MorphMode.path:
        outStates[a.id] = ElementVisualState(visible: false);
        color('fill', a.fillColor, b.fillColor);
        color('stroke', a.strokeColor, b.strokeColor);
        inStates[b.id] = _copy(
          b.state,
          transform: g.stretchFrom(p.toAuthored),
          opacity: rel(b),
          colors: {...b.state.colors, ...colors},
          chart: chart(b.state),
        );
        if (p.path != null) {
          path = p.path!.pathAt(e, b.frame.width, b.frame.height);
        }
      case MorphMode.crossfade:
        contentMix = p.textCrossfade ? _clamp01((e - 0.2) / 0.6) : e;
        final rigid = a.kind == ElementKind.text && b.kind == ElementKind.text;
        outStates[a.id] = _copy(
          a.state,
          transform: rigid
              ? g.rigidFrom(p.fromAuthored)
              : g.stretchFrom(p.fromAuthored),
          opacity: rel(a) * (1 - contentMix),
          chart: chart(a.state),
        );
        inStates[b.id] = _copy(
          b.state,
          transform: rigid
              ? g.rigidFrom(p.toAuthored)
              : g.stretchFrom(p.toAuthored),
          opacity: rel(b) * contentMix,
          chart: chart(b.state),
        );
      case MorphMode.glyphs:
        contentMix = e;
        final tm = p.text!;
        final fa = p.fromAuthored, fb = p.toAuthored;
        final fadeOut = 1 - _clamp01(e / 0.5);
        final fadeIn = _clamp01((e - 0.5) / 0.5);
        final aParts = <TextPartState>[
          for (final r in tm.runs)
            TextPartState(
              start: r.fromStart,
              end: r.fromEnd,
              transform: _runMatrix(r, fa, fb, e),
              color: r.fromColor == r.toColor
                  ? null
                  : ColorOverride(from: r.fromColor, to: r.toColor, mix: e),
            ),
          for (final s in tm.removed)
            TextPartState(start: s.start, end: s.end, opacity: fadeOut),
        ]..sort((x, y) => x.start.compareTo(y.start));
        final bParts = <TextPartState>[
          for (final r in tm.runs)
            TextPartState(start: r.toStart, end: r.toEnd, visible: false),
          for (final s in tm.added)
            TextPartState(start: s.start, end: s.end, opacity: fadeIn),
        ]..sort((x, y) => x.start.compareTo(y.start));
        outStates[a.id] = _copy(
          a.state,
          transform: g.rigidFrom(fa),
          opacity: rel(a),
          parts: TextPartStates(parts: aParts, backgroundOpacity: 1 - e),
        );
        inStates[b.id] = _copy(
          b.state,
          transform: g.rigidFrom(fb),
          opacity: rel(b),
          parts: TextPartStates(parts: bParts, backgroundOpacity: e),
        );
      case MorphMode.group:
        break;
    }
    Map<String, double>? crop;
    final ca = a.image?.crop, cb = b.image?.crop;
    if (a.image != null &&
        b.image != null &&
        a.image!.src == b.image!.src &&
        (ca != null || cb != null)) {
      double v(Map<String, Object?>? c, String k, double d) {
        // Image elements store the crop as insets `{l, t, r, b}` (02 §6.4).
        if (c != null &&
            !c.containsKey(k) &&
            const ['l', 't', 'r', 'b'].any(c.containsKey)) {
          double n(String key) {
            final x = c[key];
            return x is num ? x.toDouble() : 0;
          }

          return switch (k) {
            'x' => n('l'),
            'y' => n('t'),
            'w' => 1 - n('l') - n('r'),
            _ => 1 - n('t') - n('b'),
          };
        }
        final x = c?[k];
        return x is num ? x.toDouble() : d;
      }

      crop = {
        for (final (k, d) in const [
          ('x', 0.0),
          ('y', 0.0),
          ('w', 1.0),
          ('h', 1.0),
        ])
          k: v(ca, k, d) + (v(cb, k, d) - v(ca, k, d)) * e,
      };
    }
    return MorphPairState(
      fromId: a.id,
      toId: b.id,
      mode: p.mode,
      progress: e,
      contentMix: contentMix,
      geometry: g,
      path: path,
      camera: camera,
      codeProgress: p.code == null ? null : linear,
      crop: crop,
    );
  }

  /// The element-local transform of glyph run [r] of the outgoing element
  /// (placed rigidly on the interpolated center/rotation, 06 §8.4).
  static Matrix4 _runMatrix(
    TextMorphRun r,
    MorphGeometry fa,
    MorphGeometry fb,
    double e,
  ) {
    final ax = r.fromBox.x - fa.width / 2, ay = r.fromBox.y - fa.height / 2;
    final bx = r.toBox.x - fb.width / 2, by = r.toBox.y - fb.height / 2;
    final rx = ax + (bx - ax) * e, ry = ay + (by - ay) * e;
    final s = 1 + (r.scale - 1) * e;
    return Matrix4.identity()
      ..translateByDouble(fa.width / 2 + rx, fa.height / 2 + ry, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-r.fromBox.x, -r.fromBox.y, 0, 1);
  }

  static ElementVisualState _faded(
    ElementVisualState s,
    double factor,
    Matrix4? carrier,
  ) => _copy(
    s,
    opacity: s.opacity * factor,
    transform: carrier == null
        ? s.transform
        : (carrier.clone()..multiply(s.transform)),
  );

  /// [s] with fields replaced.
  static ElementVisualState _copy(
    ElementVisualState s, {
    double? opacity,
    Matrix4? transform,
    Map<String, ColorOverride>? colors,
    TextPartStates? parts,
    ChartRevealState? chart,
  }) => ElementVisualState(
    visible: s.visible,
    opacity: opacity ?? s.opacity,
    transform: transform ?? s.transform,
    blurSigma: s.blurSigma,
    drawProgress: s.drawProgress,
    drawReverse: s.drawReverse,
    fillOpacity: s.fillOpacity,
    codeStateIndex: s.codeStateIndex,
    codeHighlightStep: s.codeHighlightStep,
    clip: s.clip,
    dissolve: s.dissolve,
    colors: colors ?? s.colors,
    highlights: s.highlights,
    parts: parts ?? s.parts,
    chart: chart ?? s.chart,
    code: s.code,
  );

  /// Canonical JSON of the plan.
  Map<String, Object?> toJson() => {
    'from': from.slideId,
    'to': to.slideId,
    'durationMs': durationMs,
    'morphMs': morphMs,
    'options': options.toJson(),
    'pairs': [for (final p in pairs) p.toJson()],
    'outgoing': outgoingIds,
    'incoming': incomingIds,
    'layers': [for (final l in layers) l.toJson()],
    if (!sameBackground) 'backgroundCrossfade': true,
    if (!sameChrome) 'chromeCrossfade': true,
  };
}
