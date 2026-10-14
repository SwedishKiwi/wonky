import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// Grid paint tokens of Wonky Sheets (04 §14, 03 §2.9) for one brightness.
///
/// User-set cell colors are absolute; only "Automatic" text/border colors,
/// the empty-cell background and the grid chrome follow these tokens.
@immutable
class GridPaintTokens {
  const GridPaintTokens({
    required this.brightness,
    required this.sheetBackground,
    required this.gridLine,
    required this.headerBg,
    required this.headerFg,
    required this.headerSelectedBg,
    required this.headerFullBg,
    required this.headerBorder,
    required this.selectionFill,
    required this.selectionBorder,
    required this.fillHandle,
    required this.frozenDivider,
    required this.autoText,
    required this.autoBorder,
    required this.linkText,
    required this.noteTriangle,
    required this.commentHighlight,
    required this.errorTriangle,
    required this.invalidTriangle,
    required this.protectedStripe,
    required this.spillFrame,
    required this.pivotHeaderFill,
    required this.pivotTotalFill,
    required this.skeleton,
    required this.referenceColors,
    required this.formulaNumber,
    required this.formulaString,
    required this.formulaFunction,
    required this.formulaOperator,
    required this.formulaError,
  });

  final Brightness brightness;
  final Color sheetBackground;
  final Color gridLine;
  final Color headerBg;
  final Color headerFg;
  final Color headerSelectedBg;
  final Color headerFullBg;
  final Color headerBorder;
  final Color selectionFill;
  final Color selectionBorder;
  final Color fillHandle;
  final Color frozenDivider;
  final Color autoText;
  final Color autoBorder;
  final Color linkText;
  final Color noteTriangle;
  final Color commentHighlight;
  final Color errorTriangle;
  final Color invalidTriangle;
  final Color protectedStripe;
  final Color spillFrame;

  /// Pivot table header rows and total rows (07 §7.5).
  final Color pivotHeaderFill;
  final Color pivotTotalFill;
  final Color skeleton;

  /// Formula reference colors (10, cycling).
  final List<Color> referenceColors;
  final Color formulaNumber;
  final Color formulaString;
  final Color formulaFunction;
  final Color formulaOperator;
  final Color formulaError;

  bool get isDark => brightness == Brightness.dark;

  /// The color of reference [index] (cycles after 10).
  Color reference(int index) => referenceColors[index % referenceColors.length];

  static const light = GridPaintTokens(
    brightness: Brightness.light,
    sheetBackground: Color(0xFFFFFFFF),
    gridLine: Color(0xFFE1E1E1),
    headerBg: Color(0xFFF8F9FA),
    headerFg: Color(0xFF5F6368),
    headerSelectedBg: Color(0xFFD3E3FD),
    headerFullBg: Color(0x400B57D0),
    headerBorder: Color(0xFFC4C7C5),
    selectionFill: Color(0x1A1A73E8),
    selectionBorder: Color(0xFF1A73E8),
    fillHandle: Color(0xFF1A73E8),
    frozenDivider: Color(0xFFBDC1C6),
    autoText: Color(0xFF000000),
    autoBorder: Color(0xFF000000),
    linkText: Color(0xFF1155CC),
    noteTriangle: Color(0xFF000000),
    commentHighlight: Color(0xFFFBBC04),
    errorTriangle: Color(0xFFD93025),
    invalidTriangle: Color(0xFFE37400),
    protectedStripe: Color(0x405F6368),
    spillFrame: Color(0x994285F4),
    pivotHeaderFill: Color(0xFFE8F0FE),
    pivotTotalFill: Color(0xFFF1F3F4),
    skeleton: Color(0xFFF1F3F4),
    referenceColors: [
      Color(0xFF1A73E8),
      Color(0xFFD93025),
      Color(0xFF188038),
      Color(0xFF9334E6),
      Color(0xFFE37400),
      Color(0xFF12B5CB),
      Color(0xFFE52592),
      Color(0xFF7CB342),
      Color(0xFFF9AB00),
      Color(0xFF5F6368),
    ],
    formulaNumber: Color(0xFF1967D2),
    formulaString: Color(0xFF188038),
    formulaFunction: Color(0xFF202124),
    formulaOperator: Color(0xFF5F6368),
    formulaError: Color(0xFFD93025),
  );

  static const dark = GridPaintTokens(
    brightness: Brightness.dark,
    sheetBackground: Color(0xFF1F1F1F),
    gridLine: Color(0xFF3A3A3A),
    headerBg: Color(0xFF262626),
    headerFg: Color(0xFFA8A8A8),
    headerSelectedBg: Color(0xFF2B3F5C),
    headerFullBg: Color(0x4D8AB4F8),
    headerBorder: Color(0xFF444444),
    selectionFill: Color(0x298AB4F8),
    selectionBorder: Color(0xFF8AB4F8),
    fillHandle: Color(0xFF8AB4F8),
    frozenDivider: Color(0xFF5F6368),
    autoText: Color(0xFFE8EAED),
    autoBorder: Color(0xFFE8EAED),
    linkText: Color(0xFF8AB4F8),
    noteTriangle: Color(0xFFE8EAED),
    commentHighlight: Color(0xFFFDD663),
    errorTriangle: Color(0xFFF28B82),
    invalidTriangle: Color(0xFFFCAD70),
    protectedStripe: Color(0x40BDC1C6),
    spillFrame: Color(0x998AB4F8),
    pivotHeaderFill: Color(0xFF233042),
    pivotTotalFill: Color(0xFF2A2C2E),
    skeleton: Color(0xFF2E2E2E),
    referenceColors: [
      Color(0xFF8AB4F8),
      Color(0xFFF28B82),
      Color(0xFF81C995),
      Color(0xFFC58AF9),
      Color(0xFFFCAD70),
      Color(0xFF78D9EC),
      Color(0xFFFF8BCB),
      Color(0xFFAED581),
      Color(0xFFFDD663),
      Color(0xFFBDC1C6),
    ],
    formulaNumber: Color(0xFF8AB4F8),
    formulaString: Color(0xFF81C995),
    formulaFunction: Color(0xFFE8EAED),
    formulaOperator: Color(0xFFA8A8A8),
    formulaError: Color(0xFFF28B82),
  );

  /// Tokens for [brightness].
  static GridPaintTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Tokens of the ambient shad theme.
  static GridPaintTokens ofContext(BuildContext context) =>
      of(ShadTheme.of(context).brightness);
}

/// Parses `#RRGGBB` / `#RRGGBBAA` into a [Color] (null when invalid).
Color? hexToColor(String? hex) {
  if (hex == null || !hex.startsWith('#')) return null;
  final t = hex.substring(1);
  if (t.length != 6 && t.length != 8) return null;
  final rgb = int.tryParse(t.substring(0, 6), radix: 16);
  if (rgb == null) return null;
  final a = t.length == 8 ? int.tryParse(t.substring(6), radix: 16) : 0xFF;
  if (a == null) return null;
  return Color((a << 24) | rgb);
}

/// `#RRGGBB` of [c] (alpha dropped).
String colorToHex(Color c) {
  String h(double v) =>
      (v * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}
