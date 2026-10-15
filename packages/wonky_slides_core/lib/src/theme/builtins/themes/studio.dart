/// Built-in theme *Studio*: pitch-style bold color blocks and playful
/// display type (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../color/color_ref.dart';
import '../../layout/layout_library.dart';
import '../../model/background.dart';
import '../../model/common.dart';
import '../../model/paint.dart';
import '../../model/text_styles.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

PlaceholderDef _studioTweak(String owner, PlaceholderDef p) =>
    owner == 'section' ? p.copyWith(color: 'theme:bg1') : p;

/// *Studio*.
final BuiltInThemeDef studioTheme = BuiltInThemeDef(
  key: 'studio',
  name: 'Studio',
  defaultAppearance: SlideAppearance.light,
  // Light accent1: #FF5A36 → #F24B27 to reach 3:1 on bg1 (05 §11).
  light: const [
    '#FFF9F0',
    '#111827',
    '#FFE8CC',
    '#4B5563',
    '#F24B27',
    '#1D4ED8',
    '#FFC53D',
    '#0F766E',
    '#F9A8D4',
    '#111827',
    '#1D4ED8',
  ],
  dark: const [
    '#14110F',
    '#FFF7ED',
    '#2A2118',
    '#D6CFC4',
    '#FF7A59',
    '#6B8CFF',
    '#FFD166',
    '#2DD4BF',
    '#F9A8D4',
    '#FFF7ED',
    '#8FA8FF',
  ],
  fonts: fonts(BundledFonts.montserrat, 700, BundledFonts.lato),
  textStyles: const {
    'title': ThemeTextStyle(
      size: 128,
      weight: 800,
      lineHeight: 1.0,
      letterSpacing: -0.03,
    ),
    'heading': ThemeTextStyle(weight: 800, letterSpacing: -0.02),
    'bigNumber': ThemeTextStyle(size: 320),
  },
  codeLight: 'wonky-light',
  codeDark: 'one-dark',
  layoutBackgrounds: const {
    'section': SlideBackground(fill: SolidFill(ThemeColor('accent1'))),
  },
  placeholderTweak: _studioTweak,
  decorations: {
    'comparison': [
      for (final (name, x) in [('cardLeft', 96.0), ('cardRight', 960.0)])
        ThemeDecoration(
          name: name,
          rect: SuRect(x, 248, 864, 760),
          geometry: 'roundRect',
          adjust: const {'radius': 0.063},
          fill: solid('theme:bg2'),
        ),
    ],
  },
);
