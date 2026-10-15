import 'dart:collection';
import 'dart:convert';

import '../../scene/nodes/text_layout.dart';
import '../../theme/fonts/slides_fonts.dart';
import '../../theme/model/box_text_style.dart';
import '../../theme/model/common.dart';
import '../../theme/resolve/resolved_theme.dart';

/// The effective style of one text run (02 §4.2).
final class EffectiveRunStyle {
  /// Creates a run style.
  const EffectiveRunStyle({
    required this.styleKey,
    required this.font,
    required this.size,
    required this.color,
    required this.lineHeight,
    required this.letterSpacing,
    required this.align,
    required this.spaceBefore,
    required this.spaceAfter,
    this.caps,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.code = false,
    this.highlight,
    this.script,
    this.link,
  });

  /// The paragraph's theme style key.
  final String styleKey;

  /// The bundled face (weight snapped, italic applied).
  final ResolvedFontFace font;

  /// Size (su).
  final double size;

  /// ARGB color.
  final int color;

  /// Line height multiplier.
  final double lineHeight;

  /// Letter spacing (em).
  final double letterSpacing;

  /// Paragraph alignment.
  final String align;

  /// Space before the paragraph (su).
  final double spaceBefore;

  /// Space after the paragraph (su).
  final double spaceAfter;

  /// `all`, `small`, `title` or null.
  final String? caps;
  final bool italic;
  final bool underline;
  final bool strike;

  /// Inline code (`@mono`).
  final bool code;

  /// Highlight ARGB or null.
  final int? highlight;

  /// `super`, `sub` or null.
  final String? script;

  /// Link target or null.
  final String? link;
}

/// Resolves text styles (02 §4.2): per run **inline attributes** ▸
/// **paragraph `style`** ▸ **box defaults** (`textStyleJson.defaults`,
/// merged along the placeholder chain) ▸ **theme text style** of the box's
/// default style key ▸ theme `body`.
///
/// [resolve] is memoized per (theme content hash, appearance, box style,
/// default style key).
final class TextStyleResolver {
  /// Creates a resolver keeping up to [cacheSize] entries.
  TextStyleResolver({this.cacheSize = 256});

  /// Maximum memoized entries.
  final int cacheSize;

  final LinkedHashMap<String, ResolvedTextStyles> _cache = LinkedHashMap();

  /// The styles of a text body whose box properties (after the placeholder
  /// chain) are [box] and whose default paragraph style is [defaultStyle].
  ResolvedTextStyles resolve(
    ResolvedTheme theme, {
    BoxTextStyle? box,
    String? defaultStyle,
  }) {
    final key =
        '${theme.contentHash}/${theme.appearance.name}/'
        '${defaultStyle ?? ''}/${box == null ? '' : jsonEncode(box.toJson())}';
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final styleKey = defaultStyle ?? box?.styleKey ?? 'body';
    final out = ResolvedTextStyles(
      styles: theme.textStyles,
      defaultStyle: theme.textStyles.containsKey(styleKey) ? styleKey : 'body',
      box: box,
      theme: theme,
    );
    _cache[key] = out;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return out;
  }

  /// The effective style of a run with [inline] attributes in a paragraph
  /// with [block] attributes.
  EffectiveRunStyle run(
    ResolvedTheme theme,
    ResolvedTextStyles styles, {
    Map<String, Object?> block = const {},
    Map<String, Object?> inline = const {},
  }) {
    final paragraphKey = block['style'] as String?;
    final base = styles.styleFor(paragraphKey);
    // Box defaults apply when the paragraph names no style of its own.
    final defaults = paragraphKey == null
        ? (styles.box?.defaults ?? const <String, Object?>{})
        : const <String, Object?>{};
    Object? pick(String k) => inline[k] ?? block[k] ?? defaults[k];

    final fontRef = pick('font') as String?;
    final code = inline['code'] == true;
    final bold = inline['bold'] == true;
    final italic = inline['italic'] == true;
    var weight = (pick('weight') as num?)?.toInt() ?? base.font.requestedWeight;
    if (bold && weight < 600) weight = 700;
    final ResolvedFontFace font;
    if (code) {
      font = theme.font(const FontRef('@mono'), italic: italic);
    } else if (fontRef != null) {
      font = theme.font(FontRef(fontRef), weight: weight, italic: italic);
    } else if (weight != base.font.requestedWeight || italic) {
      font = SlidesFonts.resolve(
        base.font.requestedFamily,
        weight: weight,
        italic: italic,
        defaultCategory: base.font.category,
      );
    } else {
      font = base.font;
    }
    int colorOf(Object? v, int fallback) =>
        v is String ? theme.colorString(v, fallback: fallback) : fallback;
    final link = inline['link'] as String?;
    return EffectiveRunStyle(
      styleKey: paragraphKey ?? styles.defaultStyle,
      font: font,
      size: (pick('size') as num?)?.toDouble() ?? base.size,
      color: link != null && inline['color'] == null
          ? theme.linkColor
          : colorOf(pick('color'), base.color),
      lineHeight: (pick('lineHeight') as num?)?.toDouble() ?? base.lineHeight,
      letterSpacing:
          (pick('letterSpacing') as num?)?.toDouble() ?? base.letterSpacing,
      align: (pick('align') as String?) ?? base.align,
      spaceBefore:
          (pick('spaceBefore') as num?)?.toDouble() ?? base.spaceBefore,
      spaceAfter: (pick('spaceAfter') as num?)?.toDouble() ?? base.spaceAfter,
      caps: (pick('caps') as String?) ?? base.caps,
      italic: italic,
      underline:
          inline['underline'] == true || (link != null && theme.linkUnderline),
      strike: inline['strike'] == true,
      code: code,
      highlight: inline['highlight'] is String
          ? theme.colorString(inline['highlight'] as String)
          : null,
      script: inline['script'] as String?,
      link: link,
    );
  }
}
