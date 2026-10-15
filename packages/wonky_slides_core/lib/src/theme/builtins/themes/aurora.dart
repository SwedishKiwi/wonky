/// Built-in theme *Aurora*: gradient backgrounds, glassy cards, vivid accents
/// (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../color/color_ref.dart';
import '../../model/background.dart';
import '../../model/common.dart';
import '../../model/paint.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

/// *Aurora*.
final BuiltInThemeDef auroraTheme = BuiltInThemeDef(
  key: 'aurora',
  name: 'Aurora',
  defaultAppearance: SlideAppearance.dark,
  light: const [
    '#F5F3FF',
    '#1E1B4B',
    '#FFFFFFB3',
    '#4C4F6B',
    '#DB2777',
    '#2563EB',
    '#059669',
    '#D97706',
    '#7C3AED',
    '#DC2626',
    '#2563EB',
  ],
  dark: const [
    '#120F33',
    '#F8FAFC',
    '#FFFFFF14',
    '#CBD5E1',
    '#F472B6',
    '#60A5FA',
    '#34D399',
    '#FBBF24',
    '#A78BFA',
    '#F87171',
    '#93C5FD',
  ],
  fonts: fonts(BundledFonts.nunito, 700, BundledFonts.openSans),
  background: const SlideBackground(
    fill: GradientFill(
      kind: 'linear',
      angle: 135,
      stops: [
        GradientStop(0, HexColor(0xFFF5F3FF)),
        GradientStop(1, HexColor(0xFFFDF2F8)),
      ],
    ),
    fillDark: GradientFill(
      kind: 'linear',
      angle: 135,
      stops: [
        GradientStop(0, HexColor(0xFF120F33)),
        GradientStop(1, HexColor(0xFF2A1F6B)),
      ],
    ),
  ),
  codeLight: 'wonky-light',
  codeDark: 'dracula',
  decorations: {
    'master': [
      ThemeDecoration(
        name: 'orbA',
        rect: const SuRect(1380, -180, 720, 720),
        geometry: 'ellipse',
        fill: solid('theme:accent1/alpha:0.3'),
        effects: const {'v': 1, 'blur': 120},
      ),
      ThemeDecoration(
        name: 'orbB',
        rect: const SuRect(-240, 640, 640, 640),
        geometry: 'ellipse',
        fill: solid('theme:accent2/alpha:0.25'),
        effects: const {'v': 1, 'blur': 120},
      ),
    ],
    'comparison': [
      for (final (name, x) in [('cardLeft', 96.0), ('cardRight', 960.0)])
        ThemeDecoration(
          name: name,
          rect: SuRect(x, 248, 864, 760),
          geometry: 'roundRect',
          adjust: const {'radius': 0.042},
          fill: solid('theme:bg2'),
          effects: const {'v': 1, 'blur': 24},
        ),
    ],
  },
);
