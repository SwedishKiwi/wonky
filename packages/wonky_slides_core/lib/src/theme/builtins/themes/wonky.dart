/// Built-in theme *Wonky* (default): clean, modern product style (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../color/color_ref.dart';
import '../../model/common.dart';
import '../../model/paint.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

/// *Wonky*.
final BuiltInThemeDef wonkyTheme = BuiltInThemeDef(
  key: 'wonky',
  name: 'Wonky',
  defaultAppearance: SlideAppearance.light,
  light: const [
    '#FFFFFF',
    '#0F172A',
    '#F1F5F9',
    '#475569',
    '#6366F1',
    '#06B6D4',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#A855F7',
    '#4F46E5',
  ],
  dark: const [
    '#0B1020',
    '#F8FAFC',
    '#161C2E',
    '#94A3B8',
    '#818CF8',
    '#22D3EE',
    '#34D399',
    '#FBBF24',
    '#F87171',
    '#C084FC',
    '#A5B4FC',
  ],
  fonts: fonts(BundledFonts.openSans, 700, BundledFonts.openSans),
  codeLight: 'wonky-light',
  codeDark: 'wonky-dark',
  decorations: {
    'title': [
      const ThemeDecoration(
        name: 'blob',
        rect: SuRect(1340, 560, 760, 680),
        geometry: 'ellipse',
        fill: GradientFill(
          kind: 'linear',
          angle: 135,
          stops: [
            GradientStop(0, ThemeColor('accent1')),
            GradientStop(1, ThemeColor('accent6')),
          ],
        ),
        opacity: 0.2,
      ),
    ],
    'comparison': [
      ThemeDecoration(
        name: 'cardLeft',
        rect: const SuRect(96, 248, 864, 760),
        geometry: 'roundRect',
        adjust: const {'radius': 0.042},
        fill: solid('theme:bg2'),
      ),
      ThemeDecoration(
        name: 'cardRight',
        rect: const SuRect(960, 248, 864, 760),
        geometry: 'roundRect',
        adjust: const {'radius': 0.042},
        fill: solid('theme:bg2'),
      ),
    ],
  },
);
