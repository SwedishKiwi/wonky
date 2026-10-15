import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';

import '../../../l10n/slides_l10n.dart';

/// The Slides texts of the shared [ChartStyleEditor].
class SlidesChartStyleStrings extends ChartStyleEditorStrings {
  const SlidesChartStyleStrings(this.l);

  final SlidesLocalizations l;

  @override
  String get sectionTitles => l.chartStyleTitles;
  @override
  String get sectionLegend => l.chartStyleLegend;
  @override
  String get sectionSeries => l.chartStyleSeries;
  @override
  String get sectionAxes => l.chartStyleAxes;
  @override
  String get sectionGridlines => l.chartStyleGridlines;
  @override
  String get sectionPie => l.chartStylePie;
  @override
  String get section3D => l.chartStyle3D;
  @override
  String get sectionLayout => l.chartStyleLayout;
  @override
  String get chartTitle => l.chartStyleChartTitle;
  @override
  String get subtitle => l.chartStyleSubtitle;
  @override
  String get horizontalAxisTitle => l.chartStyleHAxisTitle;
  @override
  String get verticalAxisTitle => l.chartStyleVAxisTitle;
  @override
  String get legendPosition => l.chartStyleLegendPosition;
  @override
  String get series => l.chartStyleSeries;
  @override
  String get color => l.chartStyleColor;
  @override
  String get lineWidth => l.chartStyleLineWidth;
  @override
  String get pointSize => l.chartStylePointSize;
  @override
  String get dataLabels => l.chartStyleDataLabels;
  @override
  String get horizontalAxisLine => l.chartStyleHAxisLine;
  @override
  String get verticalAxisLine => l.chartStyleVAxisLine;
  @override
  String get numberFormat => l.chartStyleNumberFormat;
  @override
  String get horizontalGridlines => l.chartStyleHGridlines;
  @override
  String get verticalGridlines => l.chartStyleVGridlines;
  @override
  String get maximize => l.chartStyleMaximize;
  @override
  String get donutHole => l.chartStyleDonutHole;
  @override
  String get sliceLabels => l.chartStyleSliceLabels;
  @override
  String get startAngle => l.chartStyleStartAngle;
  @override
  String get lighting => l.chartStyleLighting;
  @override
  String get walls => l.chartStyleWalls;
  @override
  String get depth => l.chartStyleDepth;
  @override
  String get gapDepth => l.chartStyleGapDepth;
  @override
  String get shape => l.chartStyleShape;
  @override
  String get explode => l.chartStyleExplode;
  @override
  String get automatic => l.chartStyleAutomatic;
  @override
  String get none => l.chartStyleNone;
  @override
  String get resetField => l.chartStyleResetField;
  @override
  String get changedHere => l.chartStyleChangedHere;
  @override
  String legend(LegendPosition p) => switch (p) {
    LegendPosition.auto => l.chartStyleAutomatic,
    LegendPosition.top => l.chartStyleLegendTop,
    LegendPosition.bottom => l.chartStyleLegendBottom,
    LegendPosition.left => l.chartStyleLegendLeft,
    LegendPosition.right => l.chartStyleLegendRight,
    LegendPosition.inside => l.chartStyleLegendInside,
    LegendPosition.none => l.chartStyleNone,
  };
  @override
  String sliceLabel(SliceLabel s) => switch (s) {
    SliceLabel.none => l.chartStyleNone,
    SliceLabel.label => l.chartStyleSliceLabel,
    SliceLabel.value => l.chartStyleSliceValue,
    SliceLabel.percentage => l.chartStyleSlicePercent,
    SliceLabel.valueAndPercentage => l.chartStyleSliceValuePercent,
  };
  @override
  String lightingOption(Chart3DLighting x) => switch (x) {
    Chart3DLighting.soft => l.chartStyleLightingSoft,
    Chart3DLighting.bright => l.chartStyleLightingBright,
    Chart3DLighting.flat => l.chartStyleLightingFlat,
  };
  @override
  String shapeOption(Chart3DShape x) => switch (x) {
    Chart3DShape.box => l.chartStyleShapeBox,
    Chart3DShape.cylinder => l.chartStyleShapeCylinder,
    Chart3DShape.cone => l.chartStyleShapeCone,
    Chart3DShape.pyramid => l.chartStyleShapePyramid,
  };
}
