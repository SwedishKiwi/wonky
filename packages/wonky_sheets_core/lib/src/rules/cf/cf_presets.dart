import '../../format/attributes.dart';
import '../../format/theme.dart';
import 'cf_rule.dart';

/// A named single-color formatting style of the CF editor (06 §15.4).
final class CfFormattingStyle {
  /// Creates a style.
  const CfFormattingStyle(this.id, this.label, this.values);

  /// Stable id.
  final String id;

  /// Editor label.
  final String label;
  final Map<FormatAttr, Object> values;

  /// The style as a format.
  CellFormat get format => CellFormat(values);
}

/// A named color scale preset (06 §15.5).
final class ColorScalePreset {
  /// Creates a preset.
  const ColorScalePreset(this.id, this.label, this.points);

  /// Stable id.
  final String id;

  /// Editor label.
  final String label;

  /// Points (min, optional percentile-50 midpoint, max).
  final List<ColorScalePoint> points;

  /// The preset as a rule.
  CfColorScaleRule get rule => CfColorScaleRule(points);
}

/// Formatting style and color scale presets of the CF editor.
abstract final class CfPresets {
  /// Google's chart colors used by the scale presets.
  static const white = '#FFFFFF';
  static const green = '#57BB8A';
  static const red = '#E67C73';
  static const yellow = '#FFD666';
  static const blue = '#6FA8DC';

  /// Default fill of new single-color rules.
  static const defaultFill = '#B7E1CD';

  /// The 9 formatting styles (Default first).
  static const List<CfFormattingStyle> formattingStyles = [
    CfFormattingStyle('default', 'Default', {FormatAttr.fillColor: defaultFill}),
    CfFormattingStyle('greenFill', 'Green fill', {
      FormatAttr.fillColor: '#CEEAD6',
      FormatAttr.textColor: '#137333',
    }),
    CfFormattingStyle('yellowFill', 'Yellow fill', {
      FormatAttr.fillColor: '#FCE8B2',
      FormatAttr.textColor: '#B05A00',
    }),
    CfFormattingStyle('redFill', 'Red fill', {
      FormatAttr.fillColor: '#FAD2CF',
      FormatAttr.textColor: '#A50E0E',
    }),
    CfFormattingStyle('greenBold', 'Green bold text', {
      FormatAttr.textColor: '#137333',
      FormatAttr.bold: true,
    }),
    CfFormattingStyle('redBold', 'Red bold text', {
      FormatAttr.textColor: '#A50E0E',
      FormatAttr.bold: true,
    }),
    CfFormattingStyle('bold', 'Bold', {FormatAttr.bold: true}),
    CfFormattingStyle('italicGrey', 'Grey italic', {
      FormatAttr.textColor: '#666666',
      FormatAttr.italic: true,
    }),
    CfFormattingStyle('strikeGrey', 'Grey strikethrough', {
      FormatAttr.textColor: '#999999',
      FormatAttr.strikethrough: true,
    }),
  ];

  static List<ColorScalePoint> _two(String a, String b) => [
    ColorScalePoint.of(CfValueKind.min, a),
    ColorScalePoint.of(CfValueKind.max, b),
  ];

  static List<ColorScalePoint> _three(String a, String m, String b) => [
    ColorScalePoint.of(CfValueKind.min, a),
    ColorScalePoint.of(CfValueKind.percentile, m, '50'),
    ColorScalePoint.of(CfValueKind.max, b),
  ];

  /// The 12 color scale presets; the last one derives from the theme's accent 1.
  static List<ColorScalePreset> colorScales([SpreadsheetTheme theme = SpreadsheetTheme.standard]) {
    final accent = theme.resolveColor('theme:accent1') ?? theme.accents.first;
    return [
      ColorScalePreset('whiteGreen', 'White to green', _two(white, green)),
      ColorScalePreset('greenWhite', 'Green to white', _two(green, white)),
      ColorScalePreset('whiteRed', 'White to red', _two(white, red)),
      ColorScalePreset('redWhite', 'Red to white', _two(red, white)),
      ColorScalePreset('redWhiteGreen', 'Red to white to green', _three(red, white, green)),
      ColorScalePreset('greenWhiteRed', 'Green to white to red', _three(green, white, red)),
      ColorScalePreset('redYellowGreen', 'Red to yellow to green', _three(red, yellow, green)),
      ColorScalePreset('greenYellowRed', 'Green to yellow to red', _three(green, yellow, red)),
      ColorScalePreset('whiteBlue', 'White to blue', _two(white, blue)),
      ColorScalePreset('blueWhite', 'Blue to white', _two(blue, white)),
      ColorScalePreset('yellowGreen', 'Yellow to green', _two(yellow, green)),
      ColorScalePreset(
        'accent1',
        'Theme accent 1 light to dark',
        _two(ColorUtil.lighten(accent, 0.8), ColorUtil.darken(accent, 0.2)),
      ),
    ];
  }
}
