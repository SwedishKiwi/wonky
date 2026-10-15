/// Auto-fit (02 §5.1, 03 §6.1): derived, never stored (P8). `shrink`
/// scales sizes and spacing in steps of 2.5 % (min 25 %) until the text
/// fits; `resize` grows the effective box height (the stored height is
/// the minimum); `none` lets text overflow.
library;

import 'dart:math' as math;

import '../scene/nodes/text_layout.dart';

/// Auto-fit modes of `textStyleJson.autofit`.
enum AutoFitMode {
  none,
  shrink,
  resize;

  /// The mode named [name], or [fallback].
  static AutoFitMode fromName(Object? name, {AutoFitMode fallback = none}) =>
      switch (name) {
        'none' => none,
        'shrink' => shrink,
        'resize' => resize,
        _ => fallback,
      };
}

/// The result of fitting a body into a box.
final class FittedText {
  /// Creates a result.
  const FittedText({
    required this.layout,
    required this.boxHeight,
    required this.contentHeight,
  });

  /// The layout (with `fitScale` and `overflows`).
  final TextLayoutResult layout;

  /// The effective box height (≥ the stored height for `resize`).
  final double boxHeight;

  /// The laid-out text height (su).
  final double contentHeight;

  /// The auto-fit scale (1 = none).
  double get scale => layout.fitScale;
}

/// The auto-fit algorithm with an injectable layout function.
abstract final class AutoFit {
  /// Scale step (2.5 %).
  static const step = 0.025;

  /// Minimum scale (25 %).
  static const minScale = 0.25;

  /// Number of steps from 100 % to 25 %.
  static const steps = 30;

  /// The scale of step [k] (0 = 100 %).
  static double scaleAt(int k) =>
      ((1 - k * step) * 1000).roundToDouble() / 1000;

  /// Fits a body: [layoutAt] lays it out at a scale; [available] is the
  /// text height available inside the box (box height minus insets) and
  /// [insetsY] the vertical insets.
  static FittedText fit({
    required TextLayoutResult Function(double scale) layoutAt,
    required AutoFitMode mode,
    required double available,
    required double insetsY,
  }) {
    final full = layoutAt(1);
    switch (mode) {
      case AutoFitMode.none:
        return FittedText(
          layout: _withOverflow(full, full.height > available + 0.5),
          boxHeight: available + insetsY,
          contentHeight: full.height,
        );
      case AutoFitMode.resize:
        return FittedText(
          layout: full,
          boxHeight: math.max(available, full.height) + insetsY,
          contentHeight: full.height,
        );
      case AutoFitMode.shrink:
        if (full.height <= available + 0.5) {
          return FittedText(
            layout: full,
            boxHeight: available + insetsY,
            contentHeight: full.height,
          );
        }
        // Binary search for the first step that fits (heights shrink with
        // the scale; line wrapping can make them non-strictly monotonic,
        // so the found step is verified).
        var lo = 1, hi = steps;
        TextLayoutResult? best;
        while (lo <= hi) {
          final mid = (lo + hi) ~/ 2;
          final r = layoutAt(scaleAt(mid));
          if (r.height <= available + 0.5) {
            best = r;
            hi = mid - 1;
          } else {
            lo = mid + 1;
          }
        }
        final result = best ?? _withOverflow(layoutAt(scaleAt(steps)), true);
        return FittedText(
          layout: result,
          boxHeight: available + insetsY,
          contentHeight: result.height,
        );
    }
  }

  static TextLayoutResult _withOverflow(TextLayoutResult r, bool overflows) =>
      overflows == r.overflows
      ? r
      : TextLayoutResult(
          width: r.width,
          height: r.height,
          lines: r.lines,
          fitScale: r.fitScale,
          overflows: overflows,
        );
}
