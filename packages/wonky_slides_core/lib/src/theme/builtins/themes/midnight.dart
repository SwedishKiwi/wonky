/// Built-in theme *Midnight*: deep navy, electric accents, a soft radial glow
/// (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../color/color_ref.dart';
import '../../model/background.dart';
import '../../model/common.dart';
import '../../model/paint.dart';
import '../../model/text_styles.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

/// *Midnight*.
final BuiltInThemeDef midnightTheme = BuiltInThemeDef(
  key: 'midnight',
  name: 'Midnight',
  defaultAppearance: SlideAppearance.dark,
  // Light link: #0891B2 → #0E7490 (cyan-700) to reach 4.5:1 on bg1 (05 §11).
  light: const [
    '#F8FAFC',
    '#0F172A',
    '#E2E8F0',
    '#475569',
    '#0891B2',
    '#C026D3',
    '#65A30D',
    '#D97706',
    '#E11D48',
    '#7C3AED',
    '#0E7490',
  ],
  dark: const [
    '#070B1A',
    '#E2E8F0',
    '#11162B',
    '#94A3B8',
    '#22D3EE',
    '#E879F9',
    '#A3E635',
    '#FBBF24',
    '#FB7185',
    '#A78BFA',
    '#67E8F9',
  ],
  fonts: fonts(BundledFonts.lato, 700, BundledFonts.lato),
  textStyles: const {
    'title': ThemeTextStyle(letterSpacing: -0.04),
    'heading': ThemeTextStyle(letterSpacing: -0.03),
  },
  background: const SlideBackground(
    fill: SolidFill(ThemeColor('bg1')),
    overlay: GradientFill(
      kind: 'radial',
      centerX: 0,
      centerY: 0,
      radius: 0.9,
      stops: [
        GradientStop(0, ThemeColor('accent1', [AlphaModifier(0.12)])),
        GradientStop(1, ThemeColor('accent1', [AlphaModifier(0)])),
      ],
    ),
  ),
  codeLight: 'github-light',
  codeDark: 'one-dark',
  decorations: {
    'section': [
      ThemeDecoration(
        name: 'underline',
        rect: const SuRect(120, 612, 240, 6),
        fill: solid('theme:accent2'),
        effects: const {
          'v': 1,
          'glow': {'color': 'theme:accent2/alpha:0.6', 'radius': 16},
        },
      ),
    ],
  },
);
