/// Built-in theme *Mono*: minimal grayscale with a single blue highlight
/// (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../color/color_ref.dart';
import '../../model/common.dart';
import '../../model/text_styles.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

/// *Mono*.
final BuiltInThemeDef monoTheme = BuiltInThemeDef(
  key: 'mono',
  name: 'Mono',
  defaultAppearance: SlideAppearance.light,
  light: const [
    '#FFFFFF',
    '#111111',
    '#F2F2F2',
    '#6B6B6B',
    '#111111',
    '#4D4D4D',
    '#8C8C8C',
    '#BFBFBF',
    '#2563EB',
    '#DC2626',
    '#2563EB',
  ],
  dark: const [
    '#111111',
    '#F5F5F5',
    '#1C1C1C',
    '#A3A3A3',
    '#F5F5F5',
    '#C7C7C7',
    '#8C8C8C',
    '#5C5C5C',
    '#60A5FA',
    '#F87171',
    '#60A5FA',
  ],
  fonts: fonts(
    BundledFonts.sourceSans3,
    600,
    BundledFonts.sourceSans3,
    mono: BundledFonts.robotoMono,
  ),
  textStyles: const {
    'title': ThemeTextStyle(weight: 600),
    'heading': ThemeTextStyle(weight: 600),
    'bigNumber': ThemeTextStyle(color: ThemeColor('accent5')),
  },
  codeLight: 'monochrome-light',
  codeDark: 'monochrome-dark',
);
