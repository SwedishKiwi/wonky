import 'package:wonky_slides_core/motion.dart';

/// The performance budgets of the player (Slides 06 §14).
///
/// - **Blur**: at most [maxBlurred] simultaneously blurred elements or
///   text parts, σ ≤ [maxBlurSigma] su; beyond that, blur effects play as
///   their fade ([limitBlur]).
/// - **Frame budget**: [FrameBudget] counts consecutive animation frames
///   that missed the budget; after [FrameBudget.missesToDegrade] the rest
///   of the running step or transition plays as a crossfade of snapshots.
abstract final class MotionBudget {
  /// Simultaneously blurred elements/parts.
  static const int maxBlurred = 4;

  /// Largest blur sigma (su).
  static const double maxBlurSigma = 40;

  /// [frame] with blur dropped from every element and text part past the
  /// first [maxBlurred] (in element id order — deterministic) and sigmas
  /// capped; [frame] itself when nothing changes.
  static SlideFrame limitBlur(SlideFrame frame) {
    var blurred = 0;
    var over = false;
    for (final s in frame.elements.values) {
      if (s.blurSigma > maxBlurSigma) over = true;
      if (s.blurSigma > 0) blurred++;
      for (final p in s.parts?.parts ?? const <TextPartState>[]) {
        if (p.blurSigma > maxBlurSigma) over = true;
        if (p.blurSigma > 0) blurred++;
      }
    }
    if (blurred <= maxBlurred && !over) return frame;
    var left = maxBlurred;
    double take(double sigma) {
      if (sigma <= 0) return 0;
      if (left <= 0) return 0;
      left--;
      return sigma > maxBlurSigma ? maxBlurSigma : sigma;
    }

    final ids = frame.elements.keys.toList()..sort();
    final out = <String, ElementVisualState>{};
    for (final id in ids) {
      final s = frame.elements[id]!;
      final blur = take(s.blurSigma);
      final parts = s.parts;
      TextPartStates? newParts = parts;
      if (parts != null && parts.parts.any((p) => p.blurSigma > 0)) {
        newParts = TextPartStates(
          parts: [
            for (final p in parts.parts)
              p.blurSigma <= 0 ? p : _partWithBlur(p, take(p.blurSigma)),
          ],
          backgroundOpacity: parts.backgroundOpacity,
        );
      }
      out[id] = blur == s.blurSigma && identical(newParts, parts)
          ? s
          : withBlur(s, blur, parts: newParts);
    }
    return SlideFrame(out, frame.background);
  }

  static TextPartState _partWithBlur(TextPartState p, double blur) =>
      TextPartState(
        start: p.start,
        end: p.end,
        visible: p.visible,
        opacity: p.opacity,
        transform: p.transform,
        clip: p.clip,
        blurSigma: blur,
        revealEnd: p.revealEnd,
        caret: p.caret,
        dim: p.dim,
        dimColor: p.dimColor,
        color: p.color,
      );

  /// [s] with [opacity].
  static ElementVisualState withOpacity(ElementVisualState s, double opacity) =>
      _copy(s, opacity: opacity);

  /// [s] with [blur] (and [parts]).
  static ElementVisualState withBlur(
    ElementVisualState s,
    double blur, {
    TextPartStates? parts,
  }) => _copy(s, blur: blur, parts: parts);

  static ElementVisualState _copy(
    ElementVisualState s, {
    double? opacity,
    double? blur,
    TextPartStates? parts,
  }) => ElementVisualState(
    visible: s.visible,
    opacity: opacity ?? s.opacity,
    transform: s.transform,
    blurSigma: blur ?? s.blurSigma,
    drawProgress: s.drawProgress,
    drawReverse: s.drawReverse,
    fillOpacity: s.fillOpacity,
    codeStateIndex: s.codeStateIndex,
    codeHighlightStep: s.codeHighlightStep,
    clip: s.clip,
    dissolve: s.dissolve,
    colors: s.colors,
    highlights: s.highlights,
    parts: parts ?? s.parts,
    chart: s.chart,
    code: s.code,
  );
}

/// Counts animation frames that missed the frame budget (06 §14: 10 in a
/// row → degrade). Frame intervals come from the caller's clock: an
/// interval over [budgetMs] means the previous frame took too long (a
/// dropped vsync); gaps over [pauseMs] are pauses (a hidden tab), not
/// jank.
class FrameBudget {
  FrameBudget({this.budgetMs = 24, this.pauseMs = 250});

  /// Consecutive misses that degrade the running animation.
  static const int missesToDegrade = 10;

  /// Interval that counts as a miss (16.7 ms per frame at 60 Hz plus
  /// slack: the frame's own budget is 12–14 ms).
  final int budgetMs;
  final int pauseMs;

  int? _last;
  int _misses = 0;

  /// Consecutive misses so far.
  int get misses => _misses;

  /// Records an animation frame at [now]; true when the animation should
  /// degrade.
  bool frame(int now) {
    final last = _last;
    _last = now;
    if (last == null) return false;
    final dt = now - last;
    if (dt > budgetMs && dt < pauseMs) {
      _misses++;
    } else {
      _misses = 0;
    }
    return _misses >= missesToDegrade;
  }

  /// Starts counting afresh (a new step or transition).
  void reset() {
    _last = null;
    _misses = 0;
  }
}
