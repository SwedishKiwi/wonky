/// Built-in theme *Paper*: editorial, warm paper tone, elegant serif titles
/// (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../model/box_text_style.dart';
import '../../model/common.dart';
import '../../model/text_styles.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

/// *Paper*.
final BuiltInThemeDef paperTheme = BuiltInThemeDef(
  key: 'paper',
  name: 'Paper',
  defaultAppearance: SlideAppearance.light,
  light: const [
    '#FBF8F3',
    '#1C1917',
    '#F3EDE4',
    '#57534E',
    '#C2410C',
    '#4D7C0F',
    '#1E40AF',
    '#B45309',
    '#9D174D',
    '#0F766E',
    '#C2410C',
  ],
  dark: const [
    '#1A1714',
    '#F5F0E8',
    '#26211C',
    '#A8A29E',
    '#FB923C',
    '#A3E635',
    '#93C5FD',
    '#FCD34D',
    '#F9A8D4',
    '#5EEAD4',
    '#FDBA74',
  ],
  fonts: fonts(BundledFonts.ebGaramond, 400, BundledFonts.lato),
  textStyles: const {
    'title': ThemeTextStyle(size: 108, weight: 400, letterSpacing: -0.01),
    'heading': ThemeTextStyle(size: 72, weight: 400, letterSpacing: -0.01),
    'quote': ThemeTextStyle(weight: 400, italic: true),
    'bigNumber': ThemeTextStyle(weight: 400),
  },
  codeLight: 'solarized-light',
  codeDark: 'solarized-dark',
  decorations: {
    ...onLayouts(titledLayouts, [
      rule('hairline', const SuRect(120, 228, 1680, 2), 'theme:text1'),
    ]),
    'quote': const [
      ThemeDecoration(
        name: 'quoteMark',
        kind: 'text',
        rect: SuRect(150, 150, 240, 300),
        text: '“',
        textStyle: BoxTextStyle(
          insets: [0, 0, 0, 0],
          defaults: {
            'font': '@heading',
            'size': 360,
            'color': 'theme:accent1',
            'lineHeight': 1,
          },
        ),
      ),
    ],
  },
);
