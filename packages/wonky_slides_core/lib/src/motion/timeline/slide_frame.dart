/// Frames of a slide's timeline (06 §9.2–§9.3): the visual state of every
/// animated element at one timeline position. Consumed by the stage
/// (`SlideStage`, SL-29), present mode (SL-19), the PDF renderer (SL-20 /
/// SL-33) and thumbnails. Pure data with a canonical JSON form (the
/// determinism tests compare it between client, server and PDF).
///
/// Coordinates: `transform` is a slide-space matrix (su) that renderers
/// pre-multiply before the element's own transform (the stage and the PDF
/// painter already do); part transforms are in the element's local space
/// (the space of its text node). Clips and reveals are descriptive: the
/// renderer builds the geometry in the element's unrotated box.
library;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

double _r(double v) => (v * 1e6).roundToDouble() / 1e6;

List<double> _m(Matrix4 m) => [for (final v in m.storage) _r(v)];

bool _isIdentity(Matrix4 m) {
  final s = m.storage;
  for (var i = 0; i < 16; i++) {
    if (s[i] != (i % 5 == 0 ? 1.0 : 0.0)) return false;
  }
  return true;
}

/// A clip of a wipe or iris (06 §3.1): what part of the element's box is
/// visible.
final class ClipSpec {
  /// Creates a clip.
  const ClipSpec({
    required this.kind,
    required this.progress,
    this.direction = 'left',
    this.shape = 'circle',
    this.originX = 0.5,
    this.originY = 0.5,
    this.softness = 0,
  });

  /// `wipe` or `iris`.
  final String kind;

  /// 0 = nothing visible, 1 = everything.
  final double progress;

  /// Wipe: the side the reveal starts from (`left` = visible from the left
  /// edge to `progress × width`; diagonals sweep a band from that corner).
  final String direction;

  /// Iris: `circle` (radius = progress × distance from the origin to the
  /// farthest corner), `rect`, `diamond`.
  final String shape;

  /// Iris origin as a fraction of the box.
  final double originX, originY;

  /// Feathered edge as a fraction of the element (0 = hard).
  final double softness;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'kind': kind,
    'progress': _r(progress),
    if (kind == 'wipe') 'direction': direction,
    if (kind == 'iris') 'shape': shape,
    if (kind == 'iris') 'origin': [_r(originX), _r(originY)],
    if (softness != 0) 'softness': _r(softness),
  };
}

/// Dissolve state: [amount] of the element visible through seeded noise
/// cells of [cell] su.
final class DissolveState {
  /// Creates the state.
  const DissolveState(this.amount, this.seed, this.cell);

  /// 0 = hidden, 1 = fully visible.
  final double amount;

  /// Noise seed (`hash(buildId, part)`).
  final int seed;

  /// Cell size (su).
  final double cell;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'amount': _r(amount),
    'seed': seed,
    'cell': _r(cell),
  };
}

/// A color override of `colorChange` (06 §3.3): the renderer blends from
/// [from] (null = the authored color) to [to] by [mix] in OKLab.
final class ColorOverride {
  /// Creates an override.
  const ColorOverride({required this.to, this.from, this.mix = 1});

  /// ARGB, or null = the authored color.
  final int? from;

  /// ARGB.
  final int to;

  /// 0..1.
  final double mix;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {'from': from, 'to': to, 'mix': _r(mix)};
}

/// A text highlight sweep of the `highlight` effect.
final class TextHighlightState {
  /// Creates a highlight.
  const TextHighlightState({
    required this.start,
    required this.end,
    required this.color,
    required this.style,
    required this.progress,
  });

  /// Character range `[start, end)` in the body's plain text.
  final int start, end;

  /// ARGB.
  final int color;

  /// marker | underline | box.
  final String style;

  /// Sweep progress left to right (0..1).
  final double progress;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'range': [start, end],
    'color': color,
    'style': style,
    'progress': _r(progress),
  };
}

/// The state of one text part (paragraph, word or character run) of a
/// build delivered in parts, or of a typewriter reveal.
final class TextPartState {
  /// Creates a part state.
  TextPartState({
    required this.start,
    required this.end,
    this.visible = true,
    this.opacity = 1,
    Matrix4? transform,
    this.clip,
    this.blurSigma = 0,
    this.revealEnd,
    this.caret = false,
    this.dim = 1,
    this.dimColor,
    this.color,
  }) : transform = transform ?? Matrix4.identity();

  /// Character range `[start, end)` in the body's plain text.
  final int start, end;
  final bool visible;

  /// 0..1 (multiplied with the element's opacity).
  final double opacity;

  /// Element-local transform of the part's glyphs.
  final Matrix4 transform;
  final ClipSpec? clip;
  final double blurSigma;

  /// Typewriter: characters before this offset are shown (null = all).
  final int? revealEnd;

  /// Typewriter caret at [revealEnd].
  final bool caret;

  /// After-build dimming: opacity multiplier (1 = not dimmed).
  final double dim;

  /// After-build dim color (ARGB), or null.
  final int? dimColor;

  /// Text color morph of the part's glyphs (Magic Move glyph runs, 06
  /// §8.4: the renderer blends in OKLab), or null = the laid-out colors.
  final ColorOverride? color;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'range': [start, end],
    if (!visible) 'visible': false,
    if (opacity != 1) 'opacity': _r(opacity),
    if (!_isIdentity(transform)) 'transform': _m(transform),
    if (clip != null) 'clip': clip!.toJson(),
    if (blurSigma != 0) 'blur': _r(blurSigma),
    if (revealEnd != null) 'revealEnd': revealEnd,
    if (caret) 'caret': true,
    if (dim != 1) 'dim': _r(dim),
    if (dimColor != null) 'dimColor': dimColor,
    if (color != null) 'color': color!.toJson(),
  };
}

/// Per-part states of a text element (06 §9.2 `PartStates`).
final class TextPartStates {
  /// Creates the states.
  const TextPartStates({required this.parts, this.backgroundOpacity = 1});

  /// Parts with their states (characters outside every part are drawn
  /// normally).
  final List<TextPartState> parts;

  /// Opacity of the element's non-text drawing (box fill, stroke): it
  /// arrives with the first part.
  final double backgroundOpacity;

  /// The state of the part containing character [offset], or null.
  TextPartState? partAt(int offset) {
    for (final p in parts) {
      if (offset >= p.start && offset < p.end) return p;
    }
    return null;
  }

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'parts': [for (final p in parts) p.toJson()],
    if (backgroundOpacity != 1) 'background': _r(backgroundOpacity),
  };
}

/// A chart part of a delivery (06 §2.3, 08 §9.1).
final class ChartPartKey {
  /// Creates a key.
  const ChartPartKey(this.role, {this.series, this.index});

  /// `series`, `category`, `point`, `labels` or `all`.
  final String role;

  /// Series key (series and point parts).
  final String? series;

  /// Category / point index (0-based).
  final int? index;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'role': role,
    'series': ?series,
    'index': ?index,
  };

  @override
  bool operator ==(Object other) =>
      other is ChartPartKey &&
      other.role == role &&
      other.series == series &&
      other.index == index;

  @override
  int get hashCode => Object.hash(role, series, index);
}

/// The state of one chart part: [grow] for `chartGrow` (bars grow, lines
/// draw on, wedges sweep), [opacity] for fade-based effects.
final class ChartPartState {
  /// Creates a state.
  const ChartPartState(this.key, {this.grow = 1, this.opacity = 1});

  final ChartPartKey key;

  /// 0..1 growth.
  final double grow;

  /// 0..1.
  final double opacity;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'key': key.toJson(),
    if (grow != 1) 'grow': _r(grow),
    if (opacity != 1) 'opacity': _r(opacity),
  };
}

/// Chart reveal, highlight and 3D camera (06 §9.2, 08 §9). Parts absent
/// from [parts] are fully shown.
final class ChartRevealState {
  /// Creates the state.
  const ChartRevealState({
    this.backgroundOpacity = 1,
    this.parts = const [],
    this.highlight,
    this.highlightMix = 0,
    this.azimuthDelta = 0,
    this.elevationDelta = 0,
    this.camera,
    this.fromCamera,
    this.cameraMix = 0,
  });

  /// Axes, gridlines, legend and titles.
  final double backgroundOpacity;
  final List<ChartPartState> parts;

  /// `chartHighlight.target` (`{series: key}` or `{point: [key, i]}`) and
  /// `dimOthers`, or null.
  final Map<String, Object?>? highlight;

  /// 0 = no highlight, 1 = full highlight.
  final double highlightMix;

  /// `chartOrbit` offsets (degrees) on top of the camera.
  final double azimuthDelta, elevationDelta;

  /// `chartCamera` target `{azimuth, elevation, perspective}` (null keys =
  /// keep), blended by [cameraMix].
  final Map<String, Object?>? camera;

  /// The camera blended from (an earlier `chartCamera` target), or null =
  /// the authored camera.
  final Map<String, Object?>? fromCamera;
  final double cameraMix;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    if (backgroundOpacity != 1) 'background': _r(backgroundOpacity),
    if (parts.isNotEmpty) 'parts': [for (final p in parts) p.toJson()],
    if (highlight != null) 'highlight': highlight,
    if (highlight != null) 'highlightMix': _r(highlightMix),
    if (azimuthDelta != 0) 'azimuthDelta': _r(azimuthDelta),
    if (elevationDelta != 0) 'elevationDelta': _r(elevationDelta),
    if (camera != null) 'camera': camera,
    if (fromCamera != null) 'fromCamera': fromCamera,
    if (camera != null) 'cameraMix': _r(cameraMix),
  };
}

/// What a code element shows (07 §4–§6): state [stateIndex] (0-based in
/// state order), reached from [fromStateIndex] by [mode] with [mix]; the
/// highlight step likewise; [typing] is the type-in progress of `codeType`
/// (from empty) or a `type` state change.
final class CodeViewState {
  /// Creates the state.
  const CodeViewState({
    required this.stateIndex,
    this.fromStateIndex,
    this.mix = 1,
    this.mode = 'instant',
    this.highlightStep,
    this.fromHighlightStep,
    this.highlightMix = 1,
    this.typing,
  });

  final int stateIndex;

  /// The state before a running change (−1 = empty, for `codeType`).
  final int? fromStateIndex;

  /// 0..1 progress of the change.
  final double mix;

  /// type | morph | instant | crossfade.
  final String mode;

  /// 0-based highlight step, or null (no highlight).
  final int? highlightStep;
  final int? fromHighlightStep;
  final double highlightMix;

  /// Type-in progress 0..1 (null = not typing).
  final double? typing;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'state': stateIndex,
    if (fromStateIndex != null) 'from': fromStateIndex,
    if (mix != 1) 'mix': _r(mix),
    if (fromStateIndex != null) 'mode': mode,
    'step': ?highlightStep,
    if (fromHighlightStep != null) 'fromStep': fromHighlightStep,
    if (highlightMix != 1) 'stepMix': _r(highlightMix),
    if (typing != null) 'typing': _r(typing!),
  };
}

/// The visual state of one element in a frame (06 §9.2). Absent from a
/// [SlideFrame] = the edit state (unanimated).
final class ElementVisualState {
  /// Creates a state.
  ElementVisualState({
    this.visible = true,
    this.opacity = 1,
    Matrix4? transform,
    this.blurSigma = 0,
    this.drawProgress = 1,
    this.drawReverse = false,
    this.fillOpacity = 1,
    int? codeStateIndex,
    int? codeHighlightStep,
    this.clip,
    this.dissolve,
    this.colors = const {},
    this.highlights = const [],
    this.parts,
    this.chart,
    this.code,
  }) : transform = transform ?? Matrix4.identity(),
       codeStateIndex = codeStateIndex ?? code?.stateIndex,
       codeHighlightStep = codeHighlightStep ?? code?.highlightStep;

  /// The edit state.
  static final edit = ElementVisualState();

  final bool visible;

  /// Multiplied with the element's own opacity: 0..1 for builds; Magic
  /// Move (SL-25) may go above 1 so that the product interpolates between
  /// two elements' opacities — renderers clamp the product to 0..1.
  final double opacity;

  /// 4×4 slide-space transform (su, incl. perspective), pre-multiplied
  /// before the element's own transform.
  final Matrix4 transform;

  /// su.
  final double blurSigma;

  /// Line drawing 0..1 (1 = complete).
  final double drawProgress;

  /// Draws the stroke from its end (`lineDraw` backward).
  final bool drawReverse;

  /// Fill opacity while a line draws on (`lineDraw.fillDelay`).
  final double fillOpacity;

  /// Code element: state index shown (07), or null = the edit choice.
  final int? codeStateIndex;

  /// Code element: highlight step, or null.
  final int? codeHighlightStep;

  /// Wipe / iris clip, or null.
  final ClipSpec? clip;

  /// Dissolve, or null.
  final DissolveState? dissolve;

  /// Color overrides by property (`fill`, `stroke`, `text`).
  final Map<String, ColorOverride> colors;

  /// Highlight sweeps of the `highlight` effect.
  final List<TextHighlightState> highlights;

  /// Text parts (delivery, typewriter), or null.
  final TextPartStates? parts;

  /// Chart reveal / highlight / camera, or null.
  final ChartRevealState? chart;

  /// Code view, or null.
  final CodeViewState? code;

  /// Whether this is the edit state.
  bool get isEdit =>
      visible &&
      opacity == 1 &&
      _isIdentity(transform) &&
      blurSigma == 0 &&
      drawProgress == 1 &&
      fillOpacity == 1 &&
      clip == null &&
      dissolve == null &&
      colors.isEmpty &&
      highlights.isEmpty &&
      parts == null &&
      chart == null &&
      code == null &&
      codeStateIndex == null &&
      codeHighlightStep == null;

  /// Canonical JSON (sorted keys, numbers rounded to 1e-6).
  Map<String, Object?> toJson() => {
    if (!visible) 'visible': false,
    if (opacity != 1) 'opacity': _r(opacity),
    if (!_isIdentity(transform)) 'transform': _m(transform),
    if (blurSigma != 0) 'blur': _r(blurSigma),
    if (drawProgress != 1) 'draw': _r(drawProgress),
    if (drawReverse) 'drawReverse': true,
    if (fillOpacity != 1) 'fillOpacity': _r(fillOpacity),
    if (clip != null) 'clip': clip!.toJson(),
    if (dissolve != null) 'dissolve': dissolve!.toJson(),
    if (colors.isNotEmpty)
      'colors': {
        for (final k in colors.keys.toList()..sort()) k: colors[k]!.toJson(),
      },
    if (highlights.isNotEmpty)
      'highlights': [for (final h in highlights) h.toJson()],
    if (parts != null) 'parts': parts!.toJson(),
    if (chart != null) 'chart': chart!.toJson(),
    if (code != null) 'code': code!.toJson(),
    if (code == null && codeStateIndex != null) 'codeState': codeStateIndex,
    if (code == null && codeHighlightStep != null)
      'codeStep': codeHighlightStep,
  };
}

/// Slide background state (Magic Move crossfades, SL-25); the builds of
/// one slide never change it.
final class BackgroundState {
  /// Creates the state.
  const BackgroundState({this.opacity = 1});

  /// Unchanged.
  static const authored = BackgroundState();

  /// 0..1.
  final double opacity;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {'opacity': _r(opacity)};
}

/// One frame of a slide: element states (absent = edit state).
final class SlideFrame {
  /// Creates a frame.
  const SlideFrame([
    this.elements = const {},
    this.background = BackgroundState.authored,
  ]);

  /// The edit frame: everything visible, authored state.
  static const edit = SlideFrame();

  /// Element id → state.
  final Map<String, ElementVisualState> elements;
  final BackgroundState background;

  /// The state of [elementId] (the edit state when absent).
  ElementVisualState stateOf(String elementId) =>
      elements[elementId] ?? ElementVisualState.edit;

  /// Whether every element is in its edit state.
  bool get isEdit => elements.values.every((s) => s.isEdit);

  /// Canonical JSON: element ids sorted, edit states omitted; a changed
  /// background (Magic Move crossfade) under `@background`.
  Map<String, Object?> toJson() {
    final ids = elements.keys.toList()..sort();
    return {
      if (background.opacity != 1) '@background': background.toJson(),
      for (final id in ids)
        if (!elements[id]!.isEdit) id: elements[id]!.toJson(),
    };
  }
}
