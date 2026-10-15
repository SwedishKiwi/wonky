/// The theme's default object styles: `shapeStyleJson` (05 §2.7),
/// `tableStyleJson` (§2.8), `codeStyleJson` (§2.9) and `chartStyleJson`
/// (§2.10).
library;

import 'package:wonky_code/wonky_code.dart';

import '../color/color_ref.dart';
import '../json/json_util.dart';
import 'box_text_style.dart';
import 'common.dart';
import 'paint.dart';
import 'text_styles.dart';

// ---------------------------------------------------------------------------
// shapeStyleJson

/// Defaults of one object kind (text box, shape, line, icon).
final class ObjectStyleDefaults {
  /// Creates defaults.
  const ObjectStyleDefaults({this.fill, this.stroke, this.textStyle});

  /// Default fill.
  final SlideFill? fill;

  /// Default stroke.
  final SlideStroke? stroke;

  /// Default box text properties.
  final BoxTextStyle? textStyle;

  /// JSON form.
  JsonMap toJson() => {
    if (fill != null) 'fill': fill!.toJson(),
    if (stroke != null) 'stroke': stroke!.toJson(),
    if (textStyle != null) 'textStyle': textStyle!.toJson(),
  };

  static ObjectStyleDefaults? _fromJson(
    Object? json,
    String path,
    IssueSink sink,
  ) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'fill', 'stroke', 'textStyle'},
      required: false,
    );
    if (r == null) return null;
    return ObjectStyleDefaults(
      fill: r.has('fill')
          ? SlideFill.fromJson(r.map['fill'], r.at('fill'), sink)
          : null,
      stroke: r.has('stroke')
          ? SlideStroke.fromJson(r.map['stroke'], r.at('stroke'), sink)
          : null,
      textStyle: r.has('textStyle')
          ? BoxTextStyle.fromJson(r.map['textStyle'], r.at('textStyle'), sink)
          : null,
    );
  }
}

/// One entry of the shape quick-style row (03 §6.3).
final class QuickStyle {
  /// Creates a quick style.
  const QuickStyle({this.fill, this.stroke, this.textColor});

  /// Fill.
  final SlideFill? fill;

  /// Stroke.
  final SlideStroke? stroke;

  /// Text color.
  final ColorRef? textColor;

  /// JSON form.
  JsonMap toJson() => {
    if (fill != null) 'fill': fill!.toJson(),
    if (stroke != null) 'stroke': stroke!.toJson(),
    if (textColor != null) 'textColor': textColor!.json,
  };
}

/// The `shapeStyleJson` column.
final class ThemeShapeStyles {
  /// Creates default object styles.
  const ThemeShapeStyles({
    this.text = const ObjectStyleDefaults(),
    this.shape = const ObjectStyleDefaults(),
    this.line = const ObjectStyleDefaults(),
    this.icon = const ObjectStyleDefaults(),
    this.quickStyles = const [],
    this.shadow,
  });

  /// Maximum quick styles.
  static const maxQuickStyles = 8;

  /// Text boxes.
  final ObjectStyleDefaults text;

  /// Shapes.
  final ObjectStyleDefaults shape;

  /// Lines (stroke only).
  final ObjectStyleDefaults line;

  /// Icons (stroke color).
  final ObjectStyleDefaults icon;

  /// Quick styles (≤ 8).
  final List<QuickStyle> quickStyles;

  /// Shadow used when a user turns shadow on.
  final SlideShadow? shadow;

  /// The JSON column value.
  JsonMap toJson() => {
    'v': 1,
    'text': text.toJson(),
    'shape': shape.toJson(),
    'line': line.toJson(),
    'icon': icon.toJson(),
    'quickStyles': [for (final q in quickStyles) q.toJson()],
    if (shadow != null) 'shadow': shadow!.toJson(),
  };

  /// Parses the column. Errors → `null`.
  static ThemeShapeStyles? fromJson(
    Object? json,
    IssueSink sink, {
    String path = 'shapeStyleJson',
  }) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'v', 'text', 'shape', 'line', 'icon', 'quickStyles', 'shadow'},
    );
    if (r == null) return null;
    r.version(required: true);
    final before = sink.errors.length;
    ObjectStyleDefaults part(String key) =>
        ObjectStyleDefaults._fromJson(r.map[key], r.at(key), sink) ??
        const ObjectStyleDefaults();
    final quick = <QuickStyle>[];
    final list = r.list('quickStyles') ?? const [];
    if (list.length > maxQuickStyles) {
      sink.error(
        r.at('quickStyles'),
        'too_many',
        'At most $maxQuickStyles quick styles.',
      );
    }
    for (var i = 0; i < list.length && i < maxQuickStyles; i++) {
      final q = JsonReader.object(
        list[i],
        '${r.at('quickStyles')}[$i]',
        sink,
        known: {'fill', 'stroke', 'textColor'},
      );
      if (q == null) continue;
      quick.add(
        QuickStyle(
          fill: q.has('fill')
              ? SlideFill.fromJson(q.map['fill'], q.at('fill'), sink)
              : null,
          stroke: q.has('stroke')
              ? SlideStroke.fromJson(q.map['stroke'], q.at('stroke'), sink)
              : null,
          textColor: readColor(q, 'textColor'),
        ),
      );
    }
    final styles = ThemeShapeStyles(
      text: part('text'),
      shape: part('shape'),
      line: part('line'),
      icon: part('icon'),
      quickStyles: List.unmodifiable(quick),
      shadow: r.has('shadow')
          ? SlideShadow.fromJson(r.map['shadow'], r.at('shadow'), sink)
          : null,
    );
    return sink.errors.length > before ? null : styles;
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeShapeStyles && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}

// ---------------------------------------------------------------------------
// tableStyleJson

/// A table border `"width|dash|color"` (`"1|solid|theme:text2/alpha:0.3"`).
final class TableBorder {
  /// Creates a border.
  const TableBorder(this.width, this.dash, this.color);

  /// No border.
  static const TableBorder none = TableBorder(0, 'none', ThemeColor('text2'));

  /// Width (su); 0 = none.
  final double width;

  /// `none` or a stroke dash style.
  final String dash;

  /// Color.
  final ColorRef color;

  /// Whether the border is drawn.
  bool get isVisible => width > 0 && dash != 'none';

  /// The string form.
  String get json => '${normalizeJsonNumber(width)}|$dash|${color.json}';

  /// Parses the string form; errors → `null`.
  static TableBorder? parse(Object? raw, String path, IssueSink sink) {
    if (raw is! String) {
      sink.error(path, 'wrong_type', 'Expected "width|dash|color".');
      return null;
    }
    final parts = raw.split('|');
    final width = parts.isNotEmpty ? double.tryParse(parts[0]) : null;
    final color = parts.length == 3 ? ColorRef.tryParse(parts[2]) : null;
    if (parts.length != 3 ||
        width == null ||
        width < 0 ||
        width > 100 ||
        !(dashValues.contains(parts[1]) || parts[1] == 'none') ||
        color == null) {
      sink.error(path, 'invalid_border', '"$raw" is not "width|dash|color".');
      return null;
    }
    return TableBorder(width, parts[1], color);
  }

  @override
  bool operator ==(Object other) => other is TableBorder && other.json == json;

  @override
  int get hashCode => json.hashCode;
}

/// Text overrides of a table area.
final class TableTextStyle {
  /// Creates text overrides.
  const TableTextStyle({this.color, this.weight, this.style, this.italic});

  /// Color.
  final ColorRef? color;

  /// Weight.
  final int? weight;

  /// Theme text style key.
  final String? style;

  /// Italic.
  final bool? italic;

  /// JSON form.
  JsonMap toJson() {
    final out = <String, Object?>{};
    putIfNotNull(out, 'color', color?.json);
    putIfNotNull(out, 'weight', weight);
    putIfNotNull(out, 'style', style);
    putIfNotNull(out, 'italic', italic);
    return out;
  }

  static TableTextStyle? _fromJson(Object? json, String path, IssueSink sink) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'color', 'weight', 'style', 'italic'},
      required: false,
    );
    if (r == null) return null;
    return TableTextStyle(
      color: readColor(r, 'color'),
      weight: r.integer('weight', min: 100, max: 900),
      style: r.string('style', allowed: themeTextStyleKeys.toSet()),
      italic: r.boolean('italic'),
    );
  }
}

/// One table area (header, body, first column, total row).
final class TableAreaStyle {
  /// Creates an area style.
  const TableAreaStyle({this.fill, this.text, this.borderTop});

  /// Background.
  final ColorRef? fill;

  /// Text overrides.
  final TableTextStyle? text;

  /// Border above the area (total row).
  final TableBorder? borderTop;

  /// JSON form.
  JsonMap toJson() => {
    if (fill != null) 'fill': fill!.json,
    if (text != null) 'text': text!.toJson(),
    if (borderTop != null) 'borderTop': borderTop!.json,
  };

  static TableAreaStyle? _fromJson(Object? json, String path, IssueSink sink) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'fill', 'text', 'borderTop'},
      required: false,
    );
    if (r == null) return null;
    return TableAreaStyle(
      fill: readColor(r, 'fill'),
      text: TableTextStyle._fromJson(r.map['text'], r.at('text'), sink),
      borderTop: r.has('borderTop')
          ? TableBorder.parse(r.map['borderTop'], r.at('borderTop'), sink)
          : null,
    );
  }
}

/// The `tableStyleJson` column.
final class ThemeTableStyle {
  /// Creates a table style.
  const ThemeTableStyle({
    this.header = const TableAreaStyle(),
    this.body = const TableAreaStyle(),
    this.bandFill,
    this.firstColumn = const TableAreaStyle(),
    this.totalRow = const TableAreaStyle(),
    this.outerBorder = TableBorder.none,
    this.horizontalBorder = TableBorder.none,
    this.verticalBorder = TableBorder.none,
    this.cellPadding = const [12, 16, 12, 16],
    this.radius = 0,
  });

  /// Header row.
  final TableAreaStyle header;

  /// Body cells.
  final TableAreaStyle body;

  /// Banded rows/columns.
  final ColorRef? bandFill;

  /// First column.
  final TableAreaStyle firstColumn;

  /// Total row.
  final TableAreaStyle totalRow;

  /// Outer border.
  final TableBorder outerBorder;

  /// Horizontal inner borders.
  final TableBorder horizontalBorder;

  /// Vertical inner borders.
  final TableBorder verticalBorder;

  /// Cell padding `[t, r, b, l]` su.
  final List<double> cellPadding;

  /// Corner radius (su).
  final double radius;

  /// The JSON column value.
  JsonMap toJson() => {
    'v': 1,
    'header': header.toJson(),
    'body': body.toJson(),
    if (bandFill != null) 'bandFill': bandFill!.json,
    'firstColumn': firstColumn.toJson(),
    'totalRow': totalRow.toJson(),
    'borders': {
      'outer': outerBorder.json,
      'horizontal': horizontalBorder.json,
      'vertical': verticalBorder.json,
    },
    'cellPadding': [for (final p in cellPadding) normalizeJsonNumber(p)],
    'radius': normalizeJsonNumber(radius),
  };

  /// Parses the column. Errors → `null`.
  static ThemeTableStyle? fromJson(
    Object? json,
    IssueSink sink, {
    String path = 'tableStyleJson',
  }) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {
        'v',
        'header',
        'body',
        'bandFill',
        'firstColumn',
        'totalRow',
        'borders',
        'cellPadding',
        'radius',
      },
    );
    if (r == null) return null;
    r.version(required: true);
    final before = sink.errors.length;
    TableAreaStyle area(String key) =>
        TableAreaStyle._fromJson(r.map[key], r.at(key), sink) ??
        const TableAreaStyle();
    final b = r.child('borders', known: {'outer', 'horizontal', 'vertical'});
    TableBorder border(String key) =>
        (b != null && b.has(key)
            ? TableBorder.parse(b.map[key], b.at(key), sink)
            : null) ??
        TableBorder.none;
    var padding = const <double>[12, 16, 12, 16];
    final rawPadding = r.list('cellPadding');
    if (rawPadding != null) {
      if (rawPadding.length == 4 &&
          rawPadding.every((v) => v is num && v >= 0 && v <= 200)) {
        padding = [for (final v in rawPadding) (v as num).toDouble()];
      } else {
        sink.error(
          r.at('cellPadding'),
          'wrong_type',
          'Expected [t, r, b, l] su.',
        );
      }
    }
    final style = ThemeTableStyle(
      header: area('header'),
      body: area('body'),
      bandFill: readColor(r, 'bandFill'),
      firstColumn: area('firstColumn'),
      totalRow: area('totalRow'),
      outerBorder: border('outer'),
      horizontalBorder: border('horizontal'),
      verticalBorder: border('vertical'),
      cellPadding: padding,
      radius: r.number('radius', min: 0, max: 200) ?? 0,
    );
    return sink.errors.length > before ? null : style;
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeTableStyle && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}

// ---------------------------------------------------------------------------
// codeStyleJson

/// Code element chrome values (07).
const Set<String> codeChromeValues = {'none', 'tab', 'window', 'caption'};

/// The `codeStyleJson` column (consumed by Slides 07).
final class ThemeCodeStyle {
  /// Creates a code style.
  const ThemeCodeStyle({
    this.lightPalette = 'wonky-light',
    this.darkPalette = 'wonky-dark',
    this.customLight,
    this.customDark,
    this.font = const FontRef('@mono'),
    this.cornerRadius = 16,
    this.shadow = 'soft',
    this.chrome = 'window',
  });

  /// `BuiltInPalettes` id used on light backgrounds.
  final String lightPalette;

  /// `BuiltInPalettes` id used on dark backgrounds.
  final String darkPalette;

  /// Inline palette overriding [lightPalette].
  final SyntaxPalette? customLight;

  /// Inline palette overriding [darkPalette].
  final SyntaxPalette? customDark;

  /// Font (theme mono by default).
  final FontRef font;

  /// Box corner radius (su).
  final double cornerRadius;

  /// Box shadow: `none`, `soft`, `strong`.
  final String shadow;

  /// Default chrome of new code elements.
  final String chrome;

  /// The palette for light backgrounds.
  SyntaxPalette get light =>
      customLight ??
      BuiltInPalettes.byId(lightPalette) ??
      BuiltInPalettes.wonkyLight;

  /// The palette for dark backgrounds.
  SyntaxPalette get dark =>
      customDark ??
      BuiltInPalettes.byId(darkPalette) ??
      BuiltInPalettes.wonkyDark;

  /// The JSON column value.
  JsonMap toJson() => {
    'v': 1,
    'palettes': {'light': lightPalette, 'dark': darkPalette},
    'custom': customLight == null && customDark == null
        ? null
        : {
            if (customLight != null) 'light': customLight!.toJson(),
            if (customDark != null) 'dark': customDark!.toJson(),
          },
    'font': font.value,
    'box': {
      'cornerRadius': normalizeJsonNumber(cornerRadius),
      'shadow': shadow,
    },
    'chrome': chrome,
  };

  /// Parses the column. Errors → `null`; unknown palette ids fall back to
  /// the Wonky pair with a warning.
  static ThemeCodeStyle? fromJson(
    Object? json,
    IssueSink sink, {
    String path = 'codeStyleJson',
  }) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'v', 'palettes', 'custom', 'font', 'box', 'chrome'},
    );
    if (r == null) return null;
    r.version(required: true);
    final before = sink.errors.length;
    final p = r.child('palettes', known: {'light', 'dark'});
    String palette(String key, String fallback) {
      final id = p?.string(key);
      if (id == null) return fallback;
      if (!BuiltInPalettes.json.containsKey(id)) {
        sink.warn(
          p!.at(key),
          'unknown_palette',
          'Unknown code palette "$id"; $fallback is used.',
        );
        return fallback;
      }
      return id;
    }

    final c = r.child('custom', known: {'light', 'dark'});
    SyntaxPalette? custom(String key) {
      final raw = c?.map[key];
      if (raw == null) return null;
      if (raw is! Map) {
        sink.error(c!.at(key), 'wrong_type', 'Expected a palette object.');
        return null;
      }
      try {
        return SyntaxPalette.fromJson(raw.cast<String, Object?>());
      } on FormatException catch (e) {
        sink.error(c!.at(key), 'invalid_palette', e.message);
        return null;
      }
    }

    final box = r.child('box', known: {'cornerRadius', 'shadow'});
    final style = ThemeCodeStyle(
      lightPalette: palette('light', 'wonky-light'),
      darkPalette: palette('dark', 'wonky-dark'),
      customLight: custom('light'),
      customDark: custom('dark'),
      font: readFontRef(r, 'font') ?? const FontRef('@mono'),
      cornerRadius: box?.number('cornerRadius', min: 0, max: 400) ?? 16,
      shadow:
          box?.string('shadow', allowed: {'none', 'soft', 'strong'}) ?? 'soft',
      chrome: r.string('chrome', allowed: codeChromeValues) ?? 'window',
    );
    return sink.errors.length > before ? null : style;
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeCodeStyle && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}

// ---------------------------------------------------------------------------
// chartStyleJson

/// The `chartStyleJson` column (consumed by Slides 08).
final class ThemeChartStyle {
  /// Creates a chart style.
  const ThemeChartStyle({
    this.palette = const [
      ThemeColor('accent1'),
      ThemeColor('accent2'),
      ThemeColor('accent3'),
      ThemeColor('accent4'),
      ThemeColor('accent5'),
      ThemeColor('accent6'),
    ],
    this.font = const FontRef('@body'),
    this.textColor = const ThemeColor('text2'),
    this.titleStyle = 'body2',
    this.gridlines = const ThemeColor('text2', [AlphaModifier(0.15)]),
    this.axis = const ThemeColor('text2', [AlphaModifier(0.5)]),
    this.background = const TransparentColor(),
    this.lighting = 'soft',
    this.floor = const ThemeColor('bg2'),
  });

  /// Series colors in order (1–12).
  final List<ColorRef> palette;

  /// Font.
  final FontRef font;

  /// Labels and legends.
  final ColorRef textColor;

  /// Text style key of chart titles.
  final String titleStyle;

  /// Gridlines.
  final ColorRef gridlines;

  /// Axis lines.
  final ColorRef axis;

  /// Plot background.
  final ColorRef background;

  /// 3D lighting preset (`soft`, `studio`, `flat`).
  final String lighting;

  /// 3D floor.
  final ColorRef floor;

  /// The JSON column value.
  JsonMap toJson() => {
    'v': 1,
    'palette': [for (final c in palette) c.json],
    'font': font.value,
    'textColor': textColor.json,
    'titleStyle': titleStyle,
    'gridlines': gridlines.json,
    'axis': axis.json,
    'background': background.json,
    'threeD': {'lighting': lighting, 'floor': floor.json},
  };

  /// Parses the column. Errors → `null`.
  static ThemeChartStyle? fromJson(
    Object? json,
    IssueSink sink, {
    String path = 'chartStyleJson',
  }) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {
        'v',
        'palette',
        'font',
        'textColor',
        'titleStyle',
        'gridlines',
        'axis',
        'background',
        'threeD',
      },
    );
    if (r == null) return null;
    r.version(required: true);
    final before = sink.errors.length;
    const d = ThemeChartStyle();
    var palette = d.palette;
    final raw = r.list('palette');
    if (raw != null) {
      if (raw.isEmpty || raw.length > 12) {
        sink.error(r.at('palette'), 'wrong_length', 'Expected 1–12 colors.');
      } else {
        palette = [
          for (var i = 0; i < raw.length; i++)
            parseColorValue(raw[i], '${r.at('palette')}[$i]', sink) ??
                const TransparentColor(),
        ];
      }
    }
    final t = r.child('threeD', known: {'lighting', 'floor'});
    final style = ThemeChartStyle(
      palette: List.unmodifiable(palette),
      font: readFontRef(r, 'font') ?? d.font,
      textColor: readColor(r, 'textColor') ?? d.textColor,
      titleStyle:
          r.string('titleStyle', allowed: themeTextStyleKeys.toSet()) ??
          d.titleStyle,
      gridlines: readColor(r, 'gridlines') ?? d.gridlines,
      axis: readColor(r, 'axis') ?? d.axis,
      background: readColor(r, 'background') ?? d.background,
      lighting:
          t?.string('lighting', allowed: {'soft', 'studio', 'flat'}) ??
          d.lighting,
      floor: (t == null ? null : readColor(t, 'floor')) ?? d.floor,
    );
    return sink.errors.length > before ? null : style;
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeChartStyle && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}
