import 'package:wonky_slides_core/icons.dart';
import 'package:wonky_slides_core/scene.dart';

/// Draws `icon` elements (02 §6.6) with the Lucide icon fonts the app ships
/// through `shad` (`lucide_icons_flutter`): the name → code point map of
/// the core ([LucideGlyphs]) and the font family of the icon's stroke width
/// (`Lucide200` … `Lucide600`). Emoji use the platform's color emoji font.
///
/// The weighted families are never referenced by a `const IconData`, so a
/// release build's icon-font tree shaking keeps every glyph of them.
class LucideIconSource implements SlideIconSource {
  const LucideIconSource({this.emojiFamily});

  /// The default source of the app's renderers.
  static const instance = LucideIconSource();

  @override
  IconGlyph? lucide(String name, double strokeWidth) {
    final glyph = LucideGlyphs.glyph(name);
    if (glyph == null) return null;
    return IconGlyph(LucideGlyphs.assetFamilyFor(strokeWidth), glyph);
  }

  @override
  final String? emojiFamily;
}
