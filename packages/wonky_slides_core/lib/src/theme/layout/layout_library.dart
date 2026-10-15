/// The 16 built-in layouts and the master placeholders (Slides 05 §4), with
/// geometry generated for any slide size (05 §7).
library;

import 'dart:math' as math;

import '../json/json_util.dart';
import '../model/common.dart';
import 'placeholder_type.dart';
import 'slide_size.dart';

/// The built-in layout keys (stable identifiers, A-05-2), in picker order.
const List<String> builtInLayoutKeys = [
  'title',
  'section',
  'titleBody',
  'titleOnly',
  'twoColumns',
  'comparison',
  'bigNumber',
  'quote',
  'statement',
  'imageFull',
  'imageLeft',
  'imageRight',
  'code',
  'chart',
  'agenda',
  'blank',
];

/// Maps the 1920 × 1080 design grid of the layout library onto a slide size
/// (05 §7: layouts are *re-generated* for the new aspect, not letterboxed).
///
/// Each axis is mapped piecewise-linearly: the 120 su margin bands at both
/// edges become `120 × u` (u = shorter side / 1080) and the content band
/// between them stretches to fill the rest. 1920 × 1080 maps to itself;
/// every landscape preset keeps 120 su margins and the 1080 su height.
final class LayoutGeometry {
  /// Creates the mapping for [width] × [height].
  const LayoutGeometry(this.width, this.height);

  /// The mapping for [size].
  LayoutGeometry.of(SlideSize size) : this(size.width, size.height);

  /// Design grid width.
  static const double baseWidth = 1920;

  /// Design grid height.
  static const double baseHeight = 1080;

  /// Design grid margin.
  static const double baseMargin = 120;

  /// Target width.
  final double width;

  /// Target height.
  final double height;

  /// The unit scale: shorter side / 1080 (1 for every preset).
  double get unit => math.min(width, height) / baseHeight;

  /// The margin in su.
  double get margin => baseMargin * unit;

  static double _map(double v, double base, double target, double band) {
    final m = LayoutGeometry.baseMargin;
    if (v <= m) return v / m * band;
    if (v >= base - m) return target - (base - v) / m * band;
    return band + (v - m) / (base - 2 * m) * (target - 2 * band);
  }

  /// Maps an x coordinate of the design grid.
  double mapX(double x) => _map(x, baseWidth, width, margin);

  /// Maps a y coordinate of the design grid.
  double mapY(double y) => _map(y, baseHeight, height, margin);

  /// Maps a design-grid rectangle (both corners mapped).
  SuRect mapRect(SuRect r) {
    final x0 = mapX(r.x), x1 = mapX(r.right);
    final y0 = mapY(r.y), y1 = mapY(r.bottom);
    return SuRect(_round(x0), _round(y0), _round(x1 - x0), _round(y1 - y0));
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}

/// One placeholder of a layout (or the master) in the design grid.
final class PlaceholderDef {
  /// Creates a placeholder definition.
  const PlaceholderDef({
    required this.name,
    required this.type,
    required this.rect,
    this.styleKey,
    this.sizeScale,
    this.anchor,
    this.align,
    this.list,
    this.spaceAfter,
    this.prompt,
    this.fill,
    this.color,
    this.data,
  });

  /// Part name, unique within its layout (`title`, `body`, `bodyRight`, …):
  /// built-in part keys are `el:<layoutKey>/<name>` (02 §2.1).
  final String name;

  /// The placeholder type.
  final SlidePlaceholderType type;

  /// Frame in the 1920 × 1080 design grid.
  final SuRect rect;

  /// Default paragraph style key (`defaults.style`).
  final String? styleKey;

  /// Font size relative to the theme style (`heading ×1.25`).
  final double? sizeScale;

  /// Vertical anchor.
  final String? anchor;

  /// Paragraph alignment.
  final String? align;

  /// Default list kind (`bullet`, `ordered`; [noList] turns the master
  /// placeholder's list off; null = inherited).
  final String? list;

  /// [list] value of a body placeholder without a list (written as the box
  /// default `listStyle: none`, 02 §4.2).
  static const noList = 'none';

  /// Paragraph space after (su).
  final double? spaceAfter;

  /// Prompt text shown on empty instances.
  final String? prompt;

  /// Background fill color of the box (ColorRef string).
  final String? fill;

  /// Default text color (ColorRef string), when the theme's style color
  /// does not suit the layout (text on a color band).
  final String? color;

  /// Kind data (`{"fit": "cover"}` for pictures, …).
  final JsonMap? data;

  /// A copy at [rect].
  PlaceholderDef withRect(SuRect rect) => PlaceholderDef(
    name: name,
    type: type,
    rect: rect,
    styleKey: styleKey,
    sizeScale: sizeScale,
    anchor: anchor,
    align: align,
    list: list,
    spaceAfter: spaceAfter,
    prompt: prompt,
    fill: fill,
    color: color,
    data: data,
  );

  /// A copy with the given properties replaced.
  PlaceholderDef copyWith({
    String? styleKey,
    double? sizeScale,
    String? anchor,
    String? align,
    String? prompt,
    String? fill,
    String? color,
    SuRect? rect,
  }) => PlaceholderDef(
    name: name,
    type: type,
    rect: rect ?? this.rect,
    styleKey: styleKey ?? this.styleKey,
    sizeScale: sizeScale ?? this.sizeScale,
    anchor: anchor ?? this.anchor,
    align: align ?? this.align,
    list: list,
    spaceAfter: spaceAfter,
    prompt: prompt ?? this.prompt,
    fill: fill ?? this.fill,
    color: color ?? this.color,
    data: data,
  );
}

/// A built-in layout: key, name and placeholders.
final class LayoutDef {
  /// Creates a layout definition.
  const LayoutDef(this.key, this.name, this.placeholders);

  /// Stable key (`titleBody`).
  final String key;

  /// Display name (`Title and content`).
  final String name;

  /// Placeholders in reading order.
  final List<PlaceholderDef> placeholders;

  /// The placeholder types in order (for signature matching).
  List<SlidePlaceholderType> get types => [
    for (final p in placeholders) p.type,
  ];
}

const _titleRect = SuRect(120, 72, 1680, 144);
const _bodyRect = SuRect(120, 264, 1680, 720);

PlaceholderDef _title({String style = 'heading', double? scale}) =>
    PlaceholderDef(
      name: 'title',
      type: SlidePlaceholderType.title,
      rect: _titleRect,
      styleKey: style,
      sizeScale: scale,
      anchor: 'bottom',
      prompt: 'Click to add title',
    );

PlaceholderDef _body(
  String name,
  SuRect rect, {
  String? list = 'bullet',
  String style = 'body',
}) => PlaceholderDef(
  name: name,
  type: SlidePlaceholderType.body,
  rect: rect,
  styleKey: style,
  list: list,
  prompt: 'Click to add text',
);

const _picturePrompt = 'Click to add an image';

/// The layout library (05 §4) and the master placeholders.
abstract final class BuiltInLayouts {
  /// Layout definitions in the 1920 × 1080 design grid, in picker order.
  static final List<LayoutDef> designGrid = List.unmodifiable([
    LayoutDef('title', 'Title', [
      const PlaceholderDef(
        name: 'title',
        type: SlidePlaceholderType.title,
        rect: SuRect(120, 360, 1680, 240),
        styleKey: 'title',
        anchor: 'bottom',
        prompt: 'Click to add title',
      ),
      const PlaceholderDef(
        name: 'subtitle',
        type: SlidePlaceholderType.subtitle,
        rect: SuRect(120, 624, 1680, 144),
        styleKey: 'subtitle',
        prompt: 'Click to add subtitle',
      ),
    ]),
    LayoutDef('section', 'Section header', [
      const PlaceholderDef(
        name: 'label',
        type: SlidePlaceholderType.caption,
        rect: SuRect(120, 336, 1680, 48),
        styleKey: 'label',
        anchor: 'bottom',
        prompt: 'Section 1',
      ),
      const PlaceholderDef(
        name: 'title',
        type: SlidePlaceholderType.title,
        rect: SuRect(120, 400, 1680, 200),
        styleKey: 'heading',
        sizeScale: 1.25,
        anchor: 'middle',
        prompt: 'Click to add section title',
      ),
      const PlaceholderDef(
        name: 'subtitle',
        type: SlidePlaceholderType.subtitle,
        rect: SuRect(120, 624, 1680, 96),
        styleKey: 'subtitle',
        prompt: 'Click to add subtitle',
      ),
    ]),
    LayoutDef('titleBody', 'Title and content', [
      _title(),
      _body('body', _bodyRect),
    ]),
    LayoutDef('titleOnly', 'Title only', [_title()]),
    LayoutDef('twoColumns', 'Two columns', [
      _title(),
      _body('body', const SuRect(120, 264, 816, 720)),
      _body('bodyRight', const SuRect(984, 264, 816, 720)),
    ]),
    LayoutDef('comparison', 'Comparison', [
      _title(),
      const PlaceholderDef(
        name: 'headingLeft',
        type: SlidePlaceholderType.subtitle,
        rect: SuRect(120, 264, 816, 88),
        styleKey: 'heading',
        sizeScale: 0.6,
        anchor: 'bottom',
        prompt: 'Click to add heading',
      ),
      _body('body', const SuRect(120, 368, 816, 616)),
      const PlaceholderDef(
        name: 'headingRight',
        type: SlidePlaceholderType.subtitle,
        rect: SuRect(984, 264, 816, 88),
        styleKey: 'heading',
        sizeScale: 0.6,
        anchor: 'bottom',
        prompt: 'Click to add heading',
      ),
      _body('bodyRight', const SuRect(984, 368, 816, 616)),
    ]),
    LayoutDef('bigNumber', 'Big number', [
      const PlaceholderDef(
        name: 'bigNumber',
        type: SlidePlaceholderType.bigNumber,
        rect: SuRect(120, 200, 1680, 440),
        styleKey: 'bigNumber',
        align: 'center',
        anchor: 'bottom',
        prompt: '100%',
      ),
      const PlaceholderDef(
        name: 'caption',
        type: SlidePlaceholderType.caption,
        rect: SuRect(120, 680, 1680, 200),
        styleKey: 'subtitle',
        align: 'center',
        prompt: 'Click to add a caption',
      ),
    ]),
    LayoutDef('quote', 'Quote', [
      const PlaceholderDef(
        name: 'quote',
        type: SlidePlaceholderType.quote,
        rect: SuRect(240, 240, 1440, 480),
        styleKey: 'quote',
        anchor: 'middle',
        prompt: 'Click to add a quote',
      ),
      const PlaceholderDef(
        name: 'attribution',
        type: SlidePlaceholderType.attribution,
        rect: SuRect(240, 760, 1440, 72),
        styleKey: 'attribution',
        prompt: 'Name, role',
      ),
    ]),
    LayoutDef('statement', 'Statement', [
      _body(
        'body',
        const SuRect(240, 280, 1440, 520),
        // A sentence, not a list: turns the master body's bullets off.
        list: PlaceholderDef.noList,
        style: 'heading',
      ).copyWith(
        align: 'center',
        anchor: 'middle',
        prompt: 'Click to add a statement',
      ),
    ]),
    LayoutDef('imageFull', 'Full-bleed image', [
      const PlaceholderDef(
        name: 'picture',
        type: SlidePlaceholderType.picture,
        rect: SuRect(0, 0, 1920, 1080),
        prompt: _picturePrompt,
        data: {'fit': 'cover'},
      ),
      const PlaceholderDef(
        name: 'caption',
        type: SlidePlaceholderType.caption,
        rect: SuRect(120, 920, 1680, 96),
        styleKey: 'caption',
        anchor: 'middle',
        fill: 'theme:bg1/alpha:0.7',
        prompt: 'Click to add a caption',
      ),
    ]),
    LayoutDef('imageLeft', 'Image left', [
      const PlaceholderDef(
        name: 'picture',
        type: SlidePlaceholderType.picture,
        rect: SuRect(0, 0, 900, 1080),
        prompt: _picturePrompt,
        data: {'fit': 'cover'},
      ),
      const PlaceholderDef(
        name: 'title',
        type: SlidePlaceholderType.title,
        rect: SuRect(1020, 120, 780, 240),
        styleKey: 'heading',
        anchor: 'bottom',
        prompt: 'Click to add title',
      ),
      _body('body', const SuRect(1020, 384, 780, 600)),
    ]),
    LayoutDef('imageRight', 'Image right', [
      const PlaceholderDef(
        name: 'picture',
        type: SlidePlaceholderType.picture,
        rect: SuRect(1020, 0, 900, 1080),
        prompt: _picturePrompt,
        data: {'fit': 'cover'},
      ),
      const PlaceholderDef(
        name: 'title',
        type: SlidePlaceholderType.title,
        rect: SuRect(120, 120, 780, 240),
        styleKey: 'heading',
        anchor: 'bottom',
        prompt: 'Click to add title',
      ),
      _body('body', const SuRect(120, 384, 780, 600)),
    ]),
    LayoutDef('code', 'Code', [
      _title(scale: 0.8),
      const PlaceholderDef(
        name: 'code',
        type: SlidePlaceholderType.code,
        rect: SuRect(120, 248, 1680, 760),
        prompt: 'Click to add code',
        data: {'language': 'dart'},
      ),
    ]),
    LayoutDef('chart', 'Chart', [
      _title(),
      const PlaceholderDef(
        name: 'chart',
        type: SlidePlaceholderType.chart,
        rect: SuRect(120, 248, 1680, 656),
        prompt: 'Click to add a chart',
      ),
      const PlaceholderDef(
        name: 'caption',
        type: SlidePlaceholderType.caption,
        rect: SuRect(120, 928, 1680, 72),
        styleKey: 'caption',
        prompt: 'Click to add a caption',
      ),
    ]),
    LayoutDef('agenda', 'Agenda', [
      _title(),
      const PlaceholderDef(
        name: 'body',
        type: SlidePlaceholderType.body,
        rect: _bodyRect,
        styleKey: 'body',
        list: 'ordered',
        spaceAfter: 32,
        prompt: 'Click to add agenda items',
      ),
    ]),
    const LayoutDef('blank', 'Blank', []),
  ]);

  /// Master placeholders (05 §4): title and body (style sources for all
  /// layouts), slide number and footer. Date is P2.
  static const List<PlaceholderDef> masterDesignGrid = [
    PlaceholderDef(
      name: 'title',
      type: SlidePlaceholderType.title,
      rect: _titleRect,
      styleKey: 'heading',
      anchor: 'bottom',
      prompt: 'Click to edit the title style',
    ),
    PlaceholderDef(
      name: 'body',
      type: SlidePlaceholderType.body,
      rect: _bodyRect,
      styleKey: 'body',
      list: 'bullet',
      prompt: 'Click to edit the text styles',
    ),
    PlaceholderDef(
      name: 'slideNumber',
      type: SlidePlaceholderType.slideNumber,
      rect: SuRect(1680, 992, 120, 48),
      styleKey: 'label',
      align: 'right',
      anchor: 'middle',
    ),
    PlaceholderDef(
      name: 'footer',
      type: SlidePlaceholderType.footer,
      rect: SuRect(120, 992, 1200, 48),
      styleKey: 'label',
      anchor: 'middle',
    ),
  ];

  /// The layout [key] in the design grid, or `null`.
  static LayoutDef? byKey(String key) {
    for (final l in designGrid) {
      if (l.key == key) return l;
    }
    return null;
  }

  /// Every layout with geometry for [size].
  static List<LayoutDef> forSize(SlideSize size) {
    final g = LayoutGeometry.of(size);
    return [
      for (final l in designGrid)
        LayoutDef(l.key, l.name, [
          for (final p in l.placeholders) p.withRect(g.mapRect(p.rect)),
        ]),
    ];
  }

  /// The master placeholders with geometry for [size].
  static List<PlaceholderDef> masterForSize(SlideSize size) {
    final g = LayoutGeometry.of(size);
    return [for (final p in masterDesignGrid) p.withRect(g.mapRect(p.rect))];
  }
}
