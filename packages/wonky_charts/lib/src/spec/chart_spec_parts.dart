import 'chart_type.dart';
import 'spec_json.dart';

/// Font object (08 §3.3): `null` fields inherit the chart default.
final class ChartFont extends SpecNode {
  /// Creates a font.
  const ChartFont({
    this.family,
    this.size,
    this.bold = false,
    this.italic = false,
    this.color,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory ChartFont.fromJson(Object? json) {
    final r = JsonReader(json);
    return ChartFont(
      family: r.str('family'),
      size: r.dbl('size'),
      bold: r.boolOr('bold', false),
      italic: r.boolOr('italic', false),
      color: r.str('color'),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {'family', 'size', 'bold', 'italic', 'color'};

  /// The empty (all inherited) font.
  static const inherit = ChartFont();

  final String? family;
  final double? size;
  final bool bold;
  final bool italic;

  /// WonkyColor string (`#RRGGBB`, `theme:accent1`) or null = automatic.
  final String? color;
  final Map<String, Object?> extras;

  /// Copy with changes.
  ChartFont copyWith({
    String? family,
    double? size,
    bool? bold,
    bool? italic,
    String? color,
  }) => ChartFont(
    family: family ?? this.family,
    size: size ?? this.size,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    color: color ?? this.color,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..opt('family', family)
      ..opt('size', size == null ? null : jsonNum(size!))
      ..unlessDefault('bold', bold, false)
      ..unlessDefault('italic', italic, false)
      ..opt('color', color);
    return w.json;
  }
}

/// Chart title, subtitle or axis title.
final class ChartTitle extends SpecNode {
  /// Creates a title.
  const ChartTitle({
    this.text = '',
    this.font = ChartFont.inherit,
    this.align = TitleAlign.auto,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory ChartTitle.fromJson(Object? json) {
    final r = JsonReader(json);
    return ChartTitle(
      text: r.strOr('text', ''),
      font: ChartFont.fromJson(r.obj('font')),
      align: r.enumOr('align', TitleAlign.values, TitleAlign.auto),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {'text', 'font', 'align'};

  /// No title.
  static const none = ChartTitle();

  final String text;
  final ChartFont font;
  final TitleAlign align;
  final Map<String, Object?> extras;

  /// Whether there is visible text.
  bool get hasText => text.trim().isNotEmpty;

  /// Copy with changes.
  ChartTitle copyWith({String? text, ChartFont? font, TitleAlign? align}) =>
      ChartTitle(
        text: text ?? this.text,
        font: font ?? this.font,
        align: align ?? this.align,
        extras: extras,
      );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..unlessDefault('text', text, '')
      ..nested('font', font.toJson())
      ..unlessDefault('align', align.name, TitleAlign.auto.name);
    return w.json;
  }
}

/// `style` section (08 §3.3).
final class ChartStyle extends SpecNode {
  /// Creates a style.
  const ChartStyle({
    this.background,
    this.fontFamily,
    this.border,
    this.maximize = false,
    this.smooth = false,
    this.plotNullValues = false,
    this.compareMode = CompareMode.datum,
    this.palette,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory ChartStyle.fromJson(Object? json) {
    final r = JsonReader(json);
    final pal = r.list('palette');
    return ChartStyle(
      background: r.str('background'),
      fontFamily: r.str('fontFamily'),
      border: r.str('border'),
      maximize: r.boolOr('maximize', false),
      smooth: r.boolOr('smooth', false),
      plotNullValues: r.boolOr('plotNullValues', false),
      compareMode: r.enumOr(
        'compareMode',
        CompareMode.values,
        CompareMode.datum,
      ),
      palette: pal == null
          ? null
          : [
              for (final c in pal)
                if (c is String) c,
            ],
      extras: r.extras(_keys),
    );
  }

  static const _keys = {
    'background',
    'fontFamily',
    'border',
    'maximize',
    'smooth',
    'plotNullValues',
    'compareMode',
    'palette',
  };

  /// Null = automatic (app theme in the editor, white in exports).
  final String? background;

  /// Null = spreadsheet theme font.
  final String? fontFamily;

  /// Border color or null (none).
  final String? border;
  final bool maximize;
  final bool smooth;
  final bool plotNullValues;
  final CompareMode compareMode;

  /// Custom palette (`#hex` list) or null = theme accents.
  final List<String>? palette;
  final Map<String, Object?> extras;

  /// Copy with changes.
  ChartStyle copyWith({
    String? background,
    String? fontFamily,
    String? border,
    bool? maximize,
    bool? smooth,
    bool? plotNullValues,
    CompareMode? compareMode,
    List<String>? palette,
  }) => ChartStyle(
    background: background ?? this.background,
    fontFamily: fontFamily ?? this.fontFamily,
    border: border ?? this.border,
    maximize: maximize ?? this.maximize,
    smooth: smooth ?? this.smooth,
    plotNullValues: plotNullValues ?? this.plotNullValues,
    compareMode: compareMode ?? this.compareMode,
    palette: palette ?? this.palette,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..opt('background', background)
      ..opt('fontFamily', fontFamily)
      ..opt('border', border)
      ..unlessDefault('maximize', maximize, false)
      ..unlessDefault('smooth', smooth, false)
      ..unlessDefault('plotNullValues', plotNullValues, false)
      ..unlessDefault('compareMode', compareMode.name, CompareMode.datum.name)
      ..opt('palette', palette == null ? null : List<String>.of(palette!));
    return w.json;
  }
}

/// Axis labels.
final class AxisLabels extends SpecNode {
  /// Creates label settings.
  const AxisLabels({
    this.show = true,
    this.font = ChartFont.inherit,
    this.slant = LabelSlant.auto,
    this.angle = 0,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory AxisLabels.fromJson(Object? json) {
    final r = JsonReader(json);
    return AxisLabels(
      show: r.boolOr('show', true),
      font: ChartFont.fromJson(r.obj('font')),
      slant: r.enumOr('slant', LabelSlant.values, LabelSlant.auto),
      angle: r.dblOr('angle', 0),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {'show', 'font', 'slant', 'angle'};

  final bool show;
  final ChartFont font;
  final LabelSlant slant;

  /// Custom angle in degrees (−90..90) for [LabelSlant.custom].
  final double angle;
  final Map<String, Object?> extras;

  /// Copy with changes.
  AxisLabels copyWith({
    bool? show,
    ChartFont? font,
    LabelSlant? slant,
    double? angle,
  }) => AxisLabels(
    show: show ?? this.show,
    font: font ?? this.font,
    slant: slant ?? this.slant,
    angle: angle ?? this.angle,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..unlessDefault('show', show, true)
      ..nested('font', font.toJson())
      ..unlessDefault('slant', slant.name, LabelSlant.auto.name)
      ..unlessDefault('angle', jsonNum(angle), 0);
    return w.json;
  }
}

/// One axis (08 §3.5).
final class ChartAxis extends SpecNode {
  /// Creates an axis.
  const ChartAxis({
    this.title = ChartTitle.none,
    this.showLine = true,
    this.labels = const AxisLabels(),
    this.reverse = false,
    this.min,
    this.max,
    this.logScale = false,
    this.numberFormat,
    this.dateGrouping,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory ChartAxis.fromJson(Object? json) {
    final r = JsonReader(json);
    return ChartAxis(
      title: ChartTitle.fromJson(r.obj('title')),
      showLine: r.boolOr('showLine', true),
      labels: AxisLabels.fromJson(r.obj('labels')),
      reverse: r.boolOr('reverse', false),
      min: r.dbl('min'),
      max: r.dbl('max'),
      logScale: r.boolOr('logScale', false),
      numberFormat: r.str('numberFormat'),
      dateGrouping: r.str('dateGrouping'),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {
    'title',
    'showLine',
    'labels',
    'reverse',
    'min',
    'max',
    'logScale',
    'numberFormat',
    'dateGrouping',
  };

  /// Default axis.
  static const standard = ChartAxis();

  final ChartTitle title;
  final bool showLine;
  final AxisLabels labels;
  final bool reverse;
  final double? min;
  final double? max;
  final bool logScale;

  /// Null = from source cells.
  final String? numberFormat;

  /// P2 (`year`, `quarter`, …); kept verbatim.
  final String? dateGrouping;
  final Map<String, Object?> extras;

  /// Copy with changes.
  ChartAxis copyWith({
    ChartTitle? title,
    bool? showLine,
    AxisLabels? labels,
    bool? reverse,
    double? min,
    double? max,
    bool? logScale,
    String? numberFormat,
  }) => ChartAxis(
    title: title ?? this.title,
    showLine: showLine ?? this.showLine,
    labels: labels ?? this.labels,
    reverse: reverse ?? this.reverse,
    min: min ?? this.min,
    max: max ?? this.max,
    logScale: logScale ?? this.logScale,
    numberFormat: numberFormat ?? this.numberFormat,
    dateGrouping: dateGrouping,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..nested('title', title.toJson())
      ..unlessDefault('showLine', showLine, true)
      ..nested('labels', labels.toJson())
      ..unlessDefault('reverse', reverse, false)
      ..opt('min', min == null ? null : jsonNum(min!))
      ..opt('max', max == null ? null : jsonNum(max!))
      ..unlessDefault('logScale', logScale, false)
      ..opt('numberFormat', numberFormat)
      ..opt('dateGrouping', dateGrouping);
    return w.json;
  }
}

/// `axes` section: horizontal, left vertical, right vertical (08 §3.5).
final class ChartAxes extends SpecNode {
  /// Creates the axes.
  const ChartAxes({
    this.h = ChartAxis.standard,
    this.v = ChartAxis.standard,
    this.v2 = ChartAxis.standard,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory ChartAxes.fromJson(Object? json) {
    final r = JsonReader(json);
    return ChartAxes(
      h: ChartAxis.fromJson(r.obj('h')),
      v: ChartAxis.fromJson(r.obj('v')),
      v2: ChartAxis.fromJson(r.obj('v2')),
      extras: r.extras(const {'h', 'v', 'v2'}),
    );
  }

  final ChartAxis h;
  final ChartAxis v;
  final ChartAxis v2;
  final Map<String, Object?> extras;

  /// Copy with changes.
  ChartAxes copyWith({ChartAxis? h, ChartAxis? v, ChartAxis? v2}) => ChartAxes(
    h: h ?? this.h,
    v: v ?? this.v,
    v2: v2 ?? this.v2,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..nested('h', h.toJson())
      ..nested('v', v.toJson())
      ..nested('v2', v2.toJson());
    return w.json;
  }
}

/// `legend` section.
final class ChartLegend extends SpecNode {
  /// Creates a legend.
  const ChartLegend({
    this.position = LegendPosition.auto,
    this.font = ChartFont.inherit,
    this.alignment = LegendAlignment.center,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory ChartLegend.fromJson(Object? json) {
    final r = JsonReader(json);
    return ChartLegend(
      position: r.enumOr(
        'position',
        LegendPosition.values,
        LegendPosition.auto,
      ),
      font: ChartFont.fromJson(r.obj('font')),
      alignment: r.enumOr(
        'alignment',
        LegendAlignment.values,
        LegendAlignment.center,
      ),
      extras: r.extras(const {'position', 'font', 'alignment'}),
    );
  }

  final LegendPosition position;
  final ChartFont font;
  final LegendAlignment alignment;
  final Map<String, Object?> extras;

  /// Copy with changes.
  ChartLegend copyWith({
    LegendPosition? position,
    ChartFont? font,
    LegendAlignment? alignment,
  }) => ChartLegend(
    position: position ?? this.position,
    font: font ?? this.font,
    alignment: alignment ?? this.alignment,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..unlessDefault('position', position.name, LegendPosition.auto.name)
      ..nested('font', font.toJson())
      ..unlessDefault('alignment', alignment.name, LegendAlignment.center.name);
    return w.json;
  }
}

/// Major or minor gridlines of one axis.
final class GridlineSpec extends SpecNode {
  /// Creates gridline settings. [show] null = automatic (major: value axes on, category axes
  /// off; minor: off).
  const GridlineSpec({
    this.show,
    this.count,
    this.spacing,
    this.color,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory GridlineSpec.fromJson(Object? json) {
    final r = JsonReader(json);
    return GridlineSpec(
      show: r.boolean('show'),
      count: r.integer('count'),
      spacing: r.dbl('spacing'),
      color: r.str('color'),
      extras: r.extras(const {'show', 'count', 'spacing', 'color'}),
    );
  }

  final bool? show;

  /// Major: number of gridlines (null = auto); minor: lines between majors.
  final int? count;

  /// Major spacing in axis units (overrides [count]).
  final double? spacing;
  final String? color;
  final Map<String, Object?> extras;

  /// Copy with changes.
  GridlineSpec copyWith({
    bool? show,
    int? count,
    double? spacing,
    String? color,
  }) => GridlineSpec(
    show: show ?? this.show,
    count: count ?? this.count,
    spacing: spacing ?? this.spacing,
    color: color ?? this.color,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..opt('show', show)
      ..opt('count', count)
      ..opt('spacing', spacing == null ? null : jsonNum(spacing!))
      ..opt('color', color);
    return w.json;
  }
}

/// Tick marks of one axis.
final class TickSpec extends SpecNode {
  /// Creates tick settings.
  const TickSpec({
    this.major = TickMark.none,
    this.minor = TickMark.none,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory TickSpec.fromJson(Object? json) {
    final r = JsonReader(json);
    return TickSpec(
      major: r.enumOr('major', TickMark.values, TickMark.none),
      minor: r.enumOr('minor', TickMark.values, TickMark.none),
      extras: r.extras(const {'major', 'minor'}),
    );
  }

  final TickMark major;
  final TickMark minor;
  final Map<String, Object?> extras;

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..unlessDefault('major', major.name, TickMark.none.name)
      ..unlessDefault('minor', minor.name, TickMark.none.name);
    return w.json;
  }
}

/// Gridlines and ticks of one axis (08 §3.6).
final class AxisGridlines extends SpecNode {
  /// Creates gridline settings.
  const AxisGridlines({
    this.major = const GridlineSpec(),
    this.minor = const GridlineSpec(),
    this.ticks = const TickSpec(),
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory AxisGridlines.fromJson(Object? json) {
    final r = JsonReader(json);
    return AxisGridlines(
      major: GridlineSpec.fromJson(r.obj('major')),
      minor: GridlineSpec.fromJson(r.obj('minor')),
      ticks: TickSpec.fromJson(r.obj('ticks')),
      extras: r.extras(const {'major', 'minor', 'ticks'}),
    );
  }

  final GridlineSpec major;
  final GridlineSpec minor;
  final TickSpec ticks;
  final Map<String, Object?> extras;

  /// Copy with changes.
  AxisGridlines copyWith({
    GridlineSpec? major,
    GridlineSpec? minor,
    TickSpec? ticks,
  }) => AxisGridlines(
    major: major ?? this.major,
    minor: minor ?? this.minor,
    ticks: ticks ?? this.ticks,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..nested('major', major.toJson())
      ..nested('minor', minor.toJson())
      ..nested('ticks', ticks.toJson());
    return w.json;
  }
}

/// `gridlines` section: [h] = gridlines at the horizontal axis' ticks (vertical lines), [v] =
/// gridlines at the vertical axis' ticks (horizontal lines).
final class ChartGridlines extends SpecNode {
  /// Creates the section.
  const ChartGridlines({
    this.h = const AxisGridlines(),
    this.v = const AxisGridlines(),
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory ChartGridlines.fromJson(Object? json) {
    final r = JsonReader(json);
    return ChartGridlines(
      h: AxisGridlines.fromJson(r.obj('h')),
      v: AxisGridlines.fromJson(r.obj('v')),
      extras: r.extras(const {'h', 'v'}),
    );
  }

  final AxisGridlines h;
  final AxisGridlines v;
  final Map<String, Object?> extras;

  /// Copy with changes.
  ChartGridlines copyWith({AxisGridlines? h, AxisGridlines? v}) =>
      ChartGridlines(h: h ?? this.h, v: v ?? this.v, extras: extras);

  @override
  Map<String, Object?> toJson() {
    final w = JsonWriter(extras)
      ..nested('h', h.toJson())
      ..nested('v', v.toJson());
    return w.json;
  }
}
