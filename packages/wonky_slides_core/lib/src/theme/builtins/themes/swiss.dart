/// Built-in theme *Swiss*: international style, huge left-aligned titles, a
/// red bar, no rounded corners (05 §6).
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../../model/common.dart';
import '../../model/object_style_defaults.dart';
import '../../model/object_styles.dart';
import '../../model/text_styles.dart';
import '../builtin_theme_def.dart';
import 'common.dart';

/// *Swiss*.
final BuiltInThemeDef swissTheme = BuiltInThemeDef(
  key: 'swiss',
  name: 'Swiss',
  defaultAppearance: SlideAppearance.light,
  light: const [
    '#FFFFFF',
    '#0A0A0A',
    '#F5F5F5',
    '#525252',
    '#E30613',
    '#0A0A0A',
    '#0057B8',
    '#FFD500',
    '#00A651',
    '#737373',
    '#0057B8',
  ],
  dark: const [
    '#0A0A0A',
    '#FAFAFA',
    '#171717',
    '#A3A3A3',
    '#FF3B30',
    '#FAFAFA',
    '#4D9FFF',
    '#FFE14D',
    '#34D399',
    '#A3A3A3',
    '#4D9FFF',
  ],
  fonts: fonts(BundledFonts.roboto, 700, BundledFonts.roboto),
  textStyles: const {
    'title': ThemeTextStyle(size: 120, lineHeight: 1.0, letterSpacing: -0.03),
    'heading': ThemeTextStyle(letterSpacing: -0.02),
  },
  codeLight: 'monochrome-light',
  codeDark: 'monochrome-dark',
  tableStyle: ThemeTableStyle(
    header: defaultTableStyle.header,
    body: defaultTableStyle.body,
    bandFill: defaultTableStyle.bandFill,
    firstColumn: defaultTableStyle.firstColumn,
    totalRow: defaultTableStyle.totalRow,
    outerBorder: defaultTableStyle.outerBorder,
    horizontalBorder: defaultTableStyle.horizontalBorder,
    verticalBorder: defaultTableStyle.verticalBorder,
    cellPadding: defaultTableStyle.cellPadding,
    radius: 0,
  ),
  decorations: onLayouts(
    ['title', 'section'],
    [rule('bar', const SuRect(120, 96, 240, 24), 'theme:accent1')],
  ),
);
