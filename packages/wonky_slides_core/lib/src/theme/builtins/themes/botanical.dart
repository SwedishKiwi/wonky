/// Built-in theme *Botanical*: natural greens and clay, soft serif display
/// (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../model/common.dart';
import '../../model/text_styles.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

/// *Botanical*.
final BuiltInThemeDef botanicalTheme = BuiltInThemeDef(
  key: 'botanical',
  name: 'Botanical',
  defaultAppearance: SlideAppearance.light,
  light: const [
    '#F4F1E8',
    '#22302A',
    '#E7E2D3',
    '#5B6B61',
    '#2F6B4F',
    '#D97757',
    '#E8B04B',
    '#7A9E9F',
    '#8C5E8C',
    '#3B5BA5',
    '#2F6B4F',
  ],
  dark: const [
    '#18201B',
    '#EEF0E6',
    '#222C25',
    '#A7B3A9',
    '#6FBF95',
    '#F0997B',
    '#F2C76B',
    '#9CC3C4',
    '#C49AC4',
    '#8EA7E0',
    '#6FBF95',
  ],
  fonts: fonts(BundledFonts.ebGaramond, 600, BundledFonts.nunito),
  textStyles: const {
    'title': ThemeTextStyle(letterSpacing: -0.01),
    'heading': ThemeTextStyle(letterSpacing: -0.01),
  },
  codeLight: 'solarized-light',
  codeDark: 'solarized-dark',
  decorations: {
    ...onLayouts(
      ['title', 'section'],
      [
        ThemeDecoration(
          name: 'blobA',
          rect: const SuRect(1300, -160, 820, 700),
          geometry: 'ellipse',
          fill: solid('theme:bg2'),
        ),
        ThemeDecoration(
          name: 'blobB',
          rect: const SuRect(-200, 760, 620, 480),
          geometry: 'ellipse',
          fill: solid('theme:bg2'),
        ),
      ],
    ),
    ...onLayouts(titledLayouts, [
      rule('clayRule', const SuRect(120, 232, 160, 6), 'theme:accent2'),
    ]),
  },
);
