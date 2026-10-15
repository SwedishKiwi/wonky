/// Built-in theme *Classic*: corporate navy, serif headings, restrained
/// (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../layout/layout_library.dart';
import '../../model/common.dart';
import '../../model/text_styles.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

PlaceholderDef _classicTweak(String owner, PlaceholderDef p) =>
    owner == 'title' || owner == 'section' ? p.copyWith(color: 'theme:bg1') : p;

/// *Classic*.
final BuiltInThemeDef classicTheme = BuiltInThemeDef(
  key: 'classic',
  name: 'Classic',
  defaultAppearance: SlideAppearance.light,
  light: const [
    '#FFFFFF',
    '#1F2A37',
    '#F2F5F9',
    '#4B5563',
    '#1F3A5F',
    '#2E6DA4',
    '#D9822B',
    '#5B8C5A',
    '#8E5572',
    '#C9A227',
    '#2E6DA4',
  ],
  dark: const [
    '#0F1A2A',
    '#F1F5F9',
    '#18263A',
    '#A9B4C2',
    '#7FA7D9',
    '#5FA8E8',
    '#F2A65A',
    '#8FC18E',
    '#C48BB0',
    '#E6C65C',
    '#8EC1F0',
  ],
  fonts: fonts(BundledFonts.merriweather, 700, BundledFonts.sourceSans3),
  textStyles: const {
    'title': ThemeTextStyle(size: 88, letterSpacing: 0, lineHeight: 1.15),
    'heading': ThemeTextStyle(size: 60, letterSpacing: 0),
  },
  codeLight: 'github-light',
  codeDark: 'github-dark',
  placeholderTweak: _classicTweak,
  decorations: {
    'master': [
      rule(
        'footerRule',
        const SuRect(120, 976, 1680, 2),
        'theme:text2/alpha:0.4',
      ),
    ],
    'title': [rule('band', const SuRect(0, 320, 1920, 480), 'theme:accent1')],
    'section': [rule('band', const SuRect(0, 300, 1920, 460), 'theme:accent1')],
  },
);
