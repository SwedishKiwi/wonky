import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// The Slides chrome tokens (Slides 04 §17 A-04-6, 03 §20): group colors
/// (light/dark variants of 04 §5.4), the navigator background, the
/// thumbnail rings and the canvas surround. Chrome follows the app theme;
/// slides themselves render in the deck's appearance (04 §16).
class SlidesTokens {
  const SlidesTokens._(this.dark, this._scheme);

  /// The tokens of [context]'s app theme.
  static SlidesTokens of(BuildContext context) {
    final theme = ShadTheme.of(context);
    return SlidesTokens._(
      theme.brightness == Brightness.dark,
      theme.colorScheme,
    );
  }

  final bool dark;
  final ShadColorScheme _scheme;

  /// `groupColor.<name>` (04 §5.4), light / dark.
  static const groupColors = <String, (int, int)>{
    'gray': (0xFF71717A, 0xFFA1A1AA),
    'red': (0xFFDC2626, 0xFFF87171),
    'orange': (0xFFEA580C, 0xFFFB923C),
    'amber': (0xFFD97706, 0xFFFBBF24),
    'green': (0xFF16A34A, 0xFF4ADE80),
    'teal': (0xFF0D9488, 0xFF2DD4BF),
    'blue': (0xFF2563EB, 0xFF60A5FA),
    'violet': (0xFF7C3AED, 0xFFA78BFA),
    'pink': (0xFFDB2777, 0xFFF472B6),
  };

  /// The color of group color [name] (null for none/unknown).
  Color? groupColor(String? name) {
    final c = groupColors[name];
    if (c == null) return null;
    return Color(dark ? c.$2 : c.$1);
  }

  /// Background of the slide navigator.
  Color get navigatorBackground => _scheme.card;

  /// Ring of the current slide's thumbnail (2 px).
  Color get thumbnailRing => _scheme.primary;

  /// Ring of selected (not current) thumbnails.
  Color get thumbnailSelection => _scheme.primary.withValues(alpha: 0.45);

  /// Around the slide on the canvas.
  Color get canvasSurround =>
      dark ? const Color(0xFF0B0B0D) : const Color(0xFFEDEDF0);
}
