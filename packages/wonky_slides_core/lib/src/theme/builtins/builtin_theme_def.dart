/// The definition format of a built-in theme and the builder that expands it
/// into a [ThemePackage] for a slide size (Slides 05 §4, §6, §7).
library;

import '../color/color_ref.dart';
import '../json/json_util.dart';
import '../layout/layout_library.dart';
import '../layout/placeholder_type.dart';
import '../layout/slide_size.dart';
import '../model/background.dart';
import '../model/box_text_style.dart';
import '../model/common.dart';
import '../model/deck_theme_data.dart';
import '../model/object_style_defaults.dart';
import '../model/object_styles.dart';
import '../model/paint.dart';
import '../model/text_styles.dart';
import '../model/theme_colors.dart';
import '../model/theme_fonts.dart';
import 'theme_package.dart';

/// The master's part key in built-in themes.
const String builtInMasterPart = 'master:default';

/// A decoration (non-placeholder element) in the 1920 × 1080 design grid.
final class ThemeDecoration {
  /// Creates a decoration.
  const ThemeDecoration({
    required this.name,
    this.kind = 'shape',
    required this.rect,
    this.geometry = 'rect',
    this.adjust,
    this.fill,
    this.stroke,
    this.effects,
    this.opacity,
    this.text,
    this.textStyle,
    this.front = false,
  });

  /// Part name, unique within its owner.
  final String name;

  /// Element kind (`shape`, `text`).
  final String kind;

  /// Frame in the design grid.
  final SuRect rect;

  /// Shape geometry key (shapes).
  final String geometry;

  /// Geometry handles.
  final JsonMap? adjust;

  /// Fill.
  final SlideFill? fill;

  /// Stroke.
  final SlideStroke? stroke;

  /// Effects JSON (02 §5.4).
  final JsonMap? effects;

  /// Opacity.
  final double? opacity;

  /// Text (text decorations).
  final String? text;

  /// Box text properties (text decorations).
  final BoxTextStyle? textStyle;

  /// Drawn above the placeholders instead of behind them.
  final bool front;
}

/// The data of one built-in theme (05 §6).
final class BuiltInThemeDef {
  /// Creates a definition.
  const BuiltInThemeDef({
    required this.key,
    required this.name,
    this.version = 1,
    required this.defaultAppearance,
    required this.light,
    required this.dark,
    required this.fonts,
    this.textStyles = const {},
    this.background,
    this.codeLight = 'wonky-light',
    this.codeDark = 'wonky-dark',
    this.codeChrome = 'window',
    this.shapeStyles,
    this.tableStyle,
    this.decorations = const {},
    this.layoutBackgrounds = const {},
    this.placeholderTweak,
  });

  /// Stable key (A-05-2).
  final String key;

  /// Display name.
  final String name;

  /// Definition version.
  final int version;

  /// The appearance new decks start with.
  final SlideAppearance defaultAppearance;

  /// Light scheme: `bg1, text1, bg2, text2, accent1…6, link` as hex.
  final List<String> light;

  /// Dark scheme, same order.
  final List<String> dark;

  /// Heading / body / mono.
  final ThemeFonts fonts;

  /// Overrides of the default text styles (non-null properties win).
  final Map<String, ThemeTextStyle> textStyles;

  /// Theme background (default: solid `bg1`).
  final SlideBackground? background;

  /// Code palette for light backgrounds (`BuiltInPalettes` id).
  final String codeLight;

  /// Code palette for dark backgrounds.
  final String codeDark;

  /// Default chrome of code elements.
  final String codeChrome;

  /// Default object styles (default: [defaultShapeStyles]).
  final ThemeShapeStyles? shapeStyles;

  /// Table style (default: [defaultTableStyle]).
  final ThemeTableStyle? tableStyle;

  /// Decorations per owner: `master` or a layout key.
  final Map<String, List<ThemeDecoration>> decorations;

  /// Layout backgrounds by layout key.
  final Map<String, SlideBackground> layoutBackgrounds;

  /// Restyles a layout placeholder (`master` for master placeholders).
  final PlaceholderDef Function(String owner, PlaceholderDef p)?
  placeholderTweak;

  /// `builtin:<key>@<version>` (`DeckTheme.sourceKey`, 02 §2.1).
  String get sourceKey => 'builtin:$key@$version';

  /// The theme row content for [size] (text styles scaled by the size's
  /// unit, 1 for every preset).
  DeckThemeData themeData({SlideSize size = SlideSize.widescreen}) {
    final unit = LayoutGeometry.of(size).unit;
    final styles = <String, ThemeTextStyle>{};
    for (final k in themeTextStyleKeys) {
      final base = defaultThemeTextStyles[k]!;
      final o = textStyles[k];
      styles[k] = o == null ? base : _over(base, o);
    }
    var text = ThemeTextStyles(styles: styles);
    if (unit != 1) text = text.scaled(unit);
    return DeckThemeData(
      name: name,
      sourceKey: sourceKey,
      colors: ThemeColors(
        light: ThemeColorScheme.fromHexList(light),
        dark: ThemeColorScheme.fromHexList(dark),
      ),
      fonts: fonts,
      textStyles: text,
      background: background ?? SlideBackground.themeDefault,
      shapeStyles: shapeStyles ?? defaultShapeStyles,
      tableStyle: tableStyle ?? defaultTableStyle,
      codeStyle: ThemeCodeStyle(
        lightPalette: codeLight,
        darkPalette: codeDark,
        chrome: codeChrome,
      ),
      chartStyle: defaultChartStyle,
    );
  }

  static ThemeTextStyle _over(ThemeTextStyle base, ThemeTextStyle o) =>
      ThemeTextStyle(
        font: o.font ?? base.font,
        size: o.size ?? base.size,
        weight: o.weight ?? base.weight,
        italic: o.italic ?? base.italic,
        lineHeight: o.lineHeight ?? base.lineHeight,
        letterSpacing: o.letterSpacing ?? base.letterSpacing,
        color: o.color ?? base.color,
        caps: o.caps ?? base.caps,
        align: o.align ?? base.align,
        spaceBefore: o.spaceBefore ?? base.spaceBefore,
        spaceAfter: o.spaceAfter ?? base.spaceAfter,
      );

  /// Expands the definition into a package with geometry for [size].
  ThemePackage build({SlideSize size = SlideSize.widescreen}) {
    final theme = themeData(size: size);
    final g = LayoutGeometry.of(size);
    final masterPlaceholders = [
      for (final p in BuiltInLayouts.masterForSize(size))
        placeholderTweak?.call('master', p) ?? p,
    ];
    final masterTypes = {
      for (final p in masterPlaceholders) p.type: 'el:master/${p.name}',
    };
    final masterElements = [
      ..._decorations('master', g, front: false),
      for (final p in masterPlaceholders)
        _placeholder('master', p, theme, null),
      ..._decorations('master', g, front: true),
    ];
    final layouts = [
      for (final l in BuiltInLayouts.forSize(size))
        ThemeLayoutSpec(
          partKey: 'layout:${l.key}',
          key: l.key,
          name: l.name,
          background: layoutBackgrounds[l.key],
          elements: [
            ..._decorations(l.key, g, front: false),
            for (final p in l.placeholders)
              _placeholder(
                l.key,
                placeholderTweak?.call(l.key, p) ?? p,
                theme,
                masterTypes[p.type],
              ),
            ..._decorations(l.key, g, front: true),
          ],
        ),
    ];
    return ThemePackage(
      key: key,
      version: version,
      theme: theme,
      defaultAppearance: defaultAppearance,
      size: size,
      masters: [
        ThemeMasterSpec(
          partKey: builtInMasterPart,
          name: name,
          elements: masterElements,
          layouts: layouts,
        ),
      ],
    );
  }

  List<ThemeElementSpec> _decorations(
    String owner,
    LayoutGeometry g, {
    required bool front,
  }) => [
    for (final d in decorations[owner] ?? const <ThemeDecoration>[])
      if (d.front == front)
        ThemeElementSpec(
          partKey: 'el:$owner/${d.name}',
          kind: d.kind,
          name: d.name,
          frame: g.mapRect(d.rect),
          text: d.text == null ? null : plainDelta(d.text!),
          textStyle: d.textStyle,
          fill: d.fill,
          stroke: d.stroke,
          effects: d.effects,
          opacity: d.opacity,
          data: d.kind == 'shape'
              ? {
                  'v': 1,
                  'geometry': d.geometry,
                  if (d.adjust != null) 'adjust': d.adjust,
                }
              : null,
          decorative: true,
          locked: true,
        ),
  ];

  static ThemeElementSpec _placeholder(
    String owner,
    PlaceholderDef p,
    DeckThemeData theme,
    String? masterPart,
  ) {
    final defaults = <String, Object?>{};
    if (p.styleKey != null) {
      defaults['style'] = p.styleKey;
      final scale = p.sizeScale;
      final base = theme.textStyles[p.styleKey!].size;
      if (scale != null && base != null) {
        defaults['size'] = normalizeJsonNumber(
          (base * scale).roundToDouble().clamp(minFontSize, maxFontSize),
        );
      }
    }
    putIfNotNull(defaults, 'align', p.align);
    if (p.list == PlaceholderDef.noList) {
      defaults['listStyle'] = 'none';
    } else {
      putIfNotNull(defaults, 'list', p.list);
    }
    putIfNotNull(defaults, 'spaceAfter', p.spaceAfter);
    putIfNotNull(defaults, 'color', p.color);
    final holdsText = p.type.holdsText;
    final kind = switch (p.type) {
      SlidePlaceholderType.picture => 'image',
      SlidePlaceholderType.chart => 'chart',
      SlidePlaceholderType.table => 'table',
      SlidePlaceholderType.code => 'code',
      _ => 'text',
    };
    return ThemeElementSpec(
      partKey: 'el:$owner/${p.name}',
      kind: kind,
      name: _placeholderName(p),
      placeholderType: p.type,
      placeholderOf: owner == 'master' || masterPart == null
          ? null
          : masterPart,
      frame: p.rect,
      text: p.prompt == null ? null : plainDelta(p.prompt!),
      textStyle: holdsText
          ? BoxTextStyle(
              anchor: p.anchor ?? 'top',
              insets: const [0, 0, 0, 0],
              autofit: 'shrink',
              wrap: true,
              defaults: defaults,
            )
          : null,
      fill: p.fill == null ? null : SolidFill(ColorRef.parse(p.fill!)),
      data: p.data == null ? null : {'v': 1, ...p.data!},
    );
  }

  static String _placeholderName(PlaceholderDef p) => switch (p.type) {
    SlidePlaceholderType.title => 'Title',
    SlidePlaceholderType.subtitle => 'Subtitle',
    SlidePlaceholderType.body => 'Text',
    SlidePlaceholderType.picture => 'Picture',
    SlidePlaceholderType.chart => 'Chart',
    SlidePlaceholderType.table => 'Table',
    SlidePlaceholderType.code => 'Code',
    SlidePlaceholderType.caption => 'Caption',
    SlidePlaceholderType.bigNumber => 'Big number',
    SlidePlaceholderType.quote => 'Quote',
    SlidePlaceholderType.attribution => 'Attribution',
    SlidePlaceholderType.slideNumber => 'Slide number',
    SlidePlaceholderType.footer => 'Footer',
    SlidePlaceholderType.date => 'Date',
    SlidePlaceholderType.object => 'Object',
  };
}

/// Shorthand: a solid theme-color fill.
SlideFill themeFill(String ref) => SolidFill(ColorRef.parse(ref));
