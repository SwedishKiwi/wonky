/// Shared pieces of the built-in theme definitions (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../color/color_ref.dart';
import '../../model/common.dart';
import '../../model/paint.dart';
import '../../model/theme_fonts.dart';
import '../builtin_theme_def.dart';

/// Theme fonts with JetBrains Mono for code unless [mono] says otherwise.
ThemeFonts fonts(
  String heading,
  int headingWeight,
  String body, {
  String mono = BundledFonts.jetBrainsMono,
}) => ThemeFonts(
  heading: ThemeFont(heading, headingWeight),
  body: ThemeFont(body, 400),
  mono: ThemeFont(mono, 400),
);

/// Layouts with a title at the top (title as #3 of 05 §4).
const List<String> titledLayouts = [
  'titleBody',
  'titleOnly',
  'twoColumns',
  'comparison',
  'code',
  'chart',
  'agenda',
];

/// A solid fill of a color ref string.
SlideFill solid(String ref) => SolidFill(ColorRef.parse(ref));

/// A rule (thin rectangle) decoration.
ThemeDecoration rule(String name, SuRect rect, String color) =>
    ThemeDecoration(name: name, rect: rect, fill: solid(color));

/// Decorations repeated on several layouts.
Map<String, List<ThemeDecoration>> onLayouts(
  Iterable<String> layouts,
  List<ThemeDecoration> decorations,
) => {for (final l in layouts) l: decorations};
