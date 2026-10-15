import 'package:wonky_app/fonts.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';
import 'package:wonky_slides_core/charts.dart';

/// Chart text of Wonky Slides (08 §3.5): charts restyled to the deck use the
/// deck's fonts, which the [AssetFontRegistry] registers on demand under their
/// family names. One shared [FlutterTextMeasurer] lays out and paints every
/// chart (layout and paint must agree on metrics); a family that is not
/// registered yet measures and draws with the chart default until it loads
/// (the renderer then clears [measurer] and its layouts).
abstract final class SlidesChartText {
  /// The font registry deck fonts are registered with.
  static AssetFontRegistry fonts = AssetFontRegistry.instance;

  /// The measurer of every chart layout and paint.
  static final FlutterTextMeasurer measurer = FlutterTextMeasurer(
    familyOf: familyOf,
  );

  /// The Flutter family chart text of [family] is drawn with.
  static String familyOf(String? family) =>
      family != null && family.isNotEmpty && fonts.isLoaded(family)
      ? family
      : chartDefaultFamily(family);

  /// A chart layout over [measurer] (the stage's chart source).
  static SlideChartLayout layout() => SlideChartLayout(measurer: measurer);

  /// The font families the text of [scene] asks for (preloading).
  static Set<String> familiesOf(ChartScene scene) {
    final out = <String>{};
    void walk(List<ScenePrimitive> list) {
      for (final p in list) {
        switch (p) {
          case SText(:final style):
            final f = style.family;
            if (f != null && f.isNotEmpty) out.add(f);
          case SGroup(:final children):
            walk(children);
          case SClip(:final children):
            walk(children);
          default:
            break;
        }
      }
    }

    walk(scene.primitives);
    return out;
  }
}
