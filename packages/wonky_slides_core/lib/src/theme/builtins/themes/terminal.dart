/// Built-in theme *Terminal*: developer talks, GitHub-like palette, mono
/// headings, code-first layouts (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../model/box_text_style.dart';
import '../../model/common.dart';
import '../../model/text_styles.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

/// *Terminal*.
final BuiltInThemeDef terminalTheme = BuiltInThemeDef(
  key: 'terminal',
  name: 'Terminal',
  defaultAppearance: SlideAppearance.dark,
  light: const [
    '#FFFFFF',
    '#1F2328',
    '#F6F8FA',
    '#59636E',
    '#1A7F37',
    '#0969DA',
    '#8250DF',
    '#BC4C00',
    '#CF222E',
    '#9A6700',
    '#0969DA',
  ],
  dark: const [
    '#0D1117',
    '#E6EDF3',
    '#161B22',
    '#8B949E',
    '#3FB950',
    '#58A6FF',
    '#BC8CFF',
    '#F0883E',
    '#FF7B72',
    '#D29922',
    '#58A6FF',
  ],
  fonts: fonts(BundledFonts.jetBrainsMono, 700, BundledFonts.sourceSans3),
  textStyles: const {
    'title': ThemeTextStyle(size: 80, letterSpacing: 0),
    'heading': ThemeTextStyle(size: 56, letterSpacing: 0),
    'bigNumber': ThemeTextStyle(size: 240),
    'quote': ThemeTextStyle(size: 60),
  },
  codeLight: 'github-light',
  codeDark: 'github-dark',
  codeChrome: 'window',
  decorations: {
    'section': [
      const ThemeDecoration(
        name: 'prompt',
        kind: 'text',
        rect: SuRect(120, 260, 240, 64),
        text: '›_',
        textStyle: BoxTextStyle(
          insets: [0, 0, 0, 0],
          anchor: 'bottom',
          defaults: {
            'font': '@mono',
            'size': 48,
            'weight': 700,
            'color': 'theme:accent1',
          },
        ),
      ),
    ],
  },
);
