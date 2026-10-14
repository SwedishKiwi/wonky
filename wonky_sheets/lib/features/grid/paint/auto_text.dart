import 'dart:math' as math;
import 'dart:ui';

import '../../../theme/sheets_tokens.dart';

/// The automatic text color of a cell (no explicit text color): the
/// theme's [GridPaintTokens.autoText] on the sheet background; on a fill
/// whose contrast with it is poor (a light fill in dark mode, a dark fill
/// in light mode), whichever of near-black / near-white reads better.
Color autoTextOn(GridPaintTokens tokens, Color? fill) {
  if (fill == null || fill.a < 0.35) return tokens.autoText;
  final bg = fill.a >= 1
      ? fill
      : Color.alphaBlend(fill, tokens.sheetBackground);
  if (contrastRatio(tokens.autoText, bg) >= 3) return tokens.autoText;
  const dark = Color(0xFF202124);
  const light = Color(0xFFE8EAED);
  return contrastRatio(dark, bg) >= contrastRatio(light, bg) ? dark : light;
}

/// WCAG contrast ratio of two opaque colors (1..21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
