/// `backgroundJson` (Slides 05 §2.6): the same shape for `DeckTheme`,
/// `SlideMaster`, `SlideLayout` and `Slide` (null column = inherit).
library;

import '../color/color_ref.dart';
import '../json/json_util.dart';
import 'common.dart';
import 'paint.dart';

/// A background: a fill, an optional explicit dark fill and an optional
/// overlay drawn above.
final class SlideBackground {
  /// Creates a background.
  const SlideBackground({required this.fill, this.fillDark, this.overlay});

  /// A solid theme `bg1` background.
  static const SlideBackground themeDefault = SlideBackground(
    fill: SolidFill(ThemeColor('bg1')),
  );

  /// The fill (theme refs follow the appearance).
  final SlideFill fill;

  /// Optional explicit fill used in the dark appearance.
  final SlideFill? fillDark;

  /// Optional fill drawn above (vignette, texture).
  final SlideFill? overlay;

  /// The fill for [appearance].
  SlideFill fillFor(SlideAppearance appearance) =>
      appearance == SlideAppearance.dark && fillDark != null ? fillDark! : fill;

  /// JSON form.
  JsonMap toJson() => {
    'v': 1,
    'fill': fill.toJson(),
    'fillDark': fillDark?.toJson(),
    'overlay': overlay?.toJson(),
  };

  /// Parses a background. Errors → `null`.
  static SlideBackground? fromJson(
    Object? json,
    IssueSink sink, {
    String path = 'backgroundJson',
  }) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'v', 'fill', 'fillDark', 'overlay'},
    );
    if (r == null) return null;
    r.version(required: true);
    final fill = SlideFill.fromJson(r.map['fill'], r.at('fill'), sink);
    final dark = r.has('fillDark')
        ? SlideFill.fromJson(r.map['fillDark'], r.at('fillDark'), sink)
        : null;
    final overlay = r.has('overlay')
        ? SlideFill.fromJson(r.map['overlay'], r.at('overlay'), sink)
        : null;
    if (fill == null ||
        (r.has('fillDark') && dark == null) ||
        (r.has('overlay') && overlay == null)) {
      return null;
    }
    return SlideBackground(fill: fill, fillDark: dark, overlay: overlay);
  }

  @override
  bool operator ==(Object other) =>
      other is SlideBackground && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}
