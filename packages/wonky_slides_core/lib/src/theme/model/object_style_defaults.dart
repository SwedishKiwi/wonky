/// Built-in defaults of the optional theme columns (05 §2.7–§2.10), used when
/// a theme row leaves them null and as the base of the built-in themes.
library;

import '../color/color_ref.dart';
import 'box_text_style.dart';
import 'object_styles.dart';
import 'paint.dart';

/// Default `shapeStyleJson` (05 §2.7).
const ThemeShapeStyles defaultShapeStyles = ThemeShapeStyles(
  text: ObjectStyleDefaults(
    fill: NoFill(),
    stroke: SlideStroke.none(),
    textStyle: BoxTextStyle(autofit: 'resize', defaults: {'style': 'body'}),
  ),
  shape: ObjectStyleDefaults(
    fill: SolidFill(ThemeColor('accent1')),
    stroke: SlideStroke.none(),
    textStyle: BoxTextStyle(
      anchor: 'middle',
      defaults: {'style': 'body', 'color': 'theme:bg1', 'align': 'center'},
    ),
  ),
  line: ObjectStyleDefaults(
    stroke: SlideStroke(color: ThemeColor('text2'), width: 4, endArrow: 'none'),
  ),
  icon: ObjectStyleDefaults(stroke: SlideStroke(color: ThemeColor('text1'))),
  quickStyles: [
    QuickStyle(
      fill: SolidFill(ThemeColor('accent1')),
      textColor: ThemeColor('bg1'),
    ),
    QuickStyle(
      fill: SolidFill(ThemeColor('accent2')),
      textColor: ThemeColor('bg1'),
    ),
    QuickStyle(
      fill: SolidFill(ThemeColor('accent3')),
      textColor: ThemeColor('bg1'),
    ),
    QuickStyle(
      fill: SolidFill(ThemeColor('accent4')),
      textColor: ThemeColor('text1'),
    ),
    QuickStyle(
      fill: SolidFill(ThemeColor('bg2')),
      textColor: ThemeColor('text1'),
    ),
    QuickStyle(
      fill: SolidFill(ThemeColor('text1')),
      textColor: ThemeColor('bg1'),
    ),
    QuickStyle(
      fill: NoFill(),
      stroke: SlideStroke(color: ThemeColor('accent1'), width: 4),
      textColor: ThemeColor('accent1'),
    ),
    QuickStyle(
      fill: SolidFill(ThemeColor('accent1', [AlphaModifier(0.15)])),
      textColor: ThemeColor('accent1'),
    ),
  ],
  shadow: SlideShadow(color: HexColor(0x33000000), blur: 32, dx: 0, dy: 16),
);

/// Default `tableStyleJson` (05 §2.8).
const ThemeTableStyle defaultTableStyle = ThemeTableStyle(
  header: TableAreaStyle(
    fill: ThemeColor('accent1'),
    text: TableTextStyle(color: ThemeColor('bg1'), weight: 700),
  ),
  body: TableAreaStyle(
    fill: ThemeColor('bg1'),
    text: TableTextStyle(style: 'body2'),
  ),
  bandFill: ThemeColor('bg2'),
  firstColumn: TableAreaStyle(text: TableTextStyle(weight: 700)),
  totalRow: TableAreaStyle(
    fill: ThemeColor('bg2'),
    text: TableTextStyle(weight: 700),
    borderTop: TableBorder(3, 'solid', ThemeColor('text1')),
  ),
  outerBorder: TableBorder(0, 'none', ThemeColor('text2')),
  horizontalBorder: TableBorder(
    1,
    'solid',
    ThemeColor('text2', [AlphaModifier(0.3)]),
  ),
  verticalBorder: TableBorder(0, 'none', ThemeColor('text2')),
  cellPadding: [12, 16, 12, 16],
  radius: 12,
);

/// Default `codeStyleJson` (05 §2.9): the Wonky palette pair.
const ThemeCodeStyle defaultCodeStyle = ThemeCodeStyle();

/// Default `chartStyleJson` (05 §2.10).
const ThemeChartStyle defaultChartStyle = ThemeChartStyle();
