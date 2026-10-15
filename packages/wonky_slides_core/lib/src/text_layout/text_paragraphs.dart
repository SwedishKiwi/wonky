/// The styled paragraph model shared by the text layout engines (SL-10):
/// a Delta body (02 §4.1) split into paragraphs with concrete run styles
/// (02 §4.2 cascade via `TextStyleResolver`), caps/script display
/// transforms, list markers with numbering, indents and spacing — all
/// scaled by the auto-fit scale. Engines differ only in measuring and line
/// breaking, so static rendering, the overlay, thumbnails and PDF agree on
/// everything else.
library;

import 'dart:math' as math;

import '../model/resolve/text_style_resolver.dart';
import '../scene/nodes/text_layout.dart';
import '../theme/model/text_styles.dart';
import '../theme/resolve/resolved_theme.dart';

/// One run with concrete display values.
final class StyledRun {
  /// Creates a run.
  const StyledRun({
    required this.text,
    required this.start,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontSize,
    required this.color,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.highlight,
    this.letterSpacing = 0,
    this.baselineShift = 0,
    this.link,
    this.code = false,
  });

  /// Display text (caps applied; soft breaks kept as U+2028).
  final String text;

  /// Offset of the run in the body's plain text.
  final int start;
  final String fontFamily;
  final int fontWeight;

  /// Size (su, scaled).
  final double fontSize;

  /// ARGB.
  final int color;
  final bool italic;
  final bool underline;
  final bool strike;

  /// ARGB text background or null.
  final int? highlight;

  /// su.
  final double letterSpacing;

  /// Superscript (> 0) / subscript (< 0) shift (su).
  final double baselineShift;
  final String? link;

  /// Inline code (`@mono` + chrome).
  final bool code;

  /// The end offset in the body's plain text (source length = display
  /// length, except for caps transforms that change the length).
  int get end => start + text.length;

  /// A copy with [text] and [start] replaced.
  StyledRun slice(String text, int start) => StyledRun(
    text: text,
    start: start,
    fontFamily: fontFamily,
    fontWeight: fontWeight,
    fontSize: fontSize,
    color: color,
    italic: italic,
    underline: underline,
    strike: strike,
    highlight: highlight,
    letterSpacing: letterSpacing,
    baselineShift: baselineShift,
    link: link,
    code: code,
  );

  /// The run as a positioned box at [x] with [width].
  TextRunBox box({required double x, required double width}) => TextRunBox(
    text: text,
    start: start,
    x: x,
    width: width,
    fontFamily: fontFamily,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    italic: italic,
    underline: underline,
    strike: strike,
    highlight: highlight,
    letterSpacing: letterSpacing,
    baselineShift: baselineShift,
    link: link,
  );
}

/// A paragraph ready for line breaking.
final class StyledParagraph {
  /// Creates a paragraph.
  const StyledParagraph({
    required this.index,
    required this.start,
    required this.end,
    required this.runs,
    required this.mark,
    required this.align,
    required this.lineHeight,
    required this.spaceBefore,
    required this.spaceAfter,
    required this.level,
    required this.textIndent,
    this.marker,
    this.markerX = 0,
    this.list,
    this.rtl = false,
  });

  /// Paragraph index in the body.
  final int index;

  /// Offset of the first character in the body's plain text.
  final int start;

  /// Offset of the paragraph's `"\n"`.
  final int end;

  /// Runs (empty for an empty paragraph).
  final List<StyledRun> runs;

  /// The style of the paragraph mark (empty paragraphs take their height
  /// from it).
  final StyledRun mark;

  /// `left`, `center`, `right`, `justify`.
  final String align;

  /// Line height multiplier.
  final double lineHeight;

  /// su (scaled).
  final double spaceBefore;

  /// su (scaled).
  final double spaceAfter;

  /// Indent level 0–8.
  final int level;

  /// Left edge of the text (su, scaled; includes the list hanging indent).
  final double textIndent;

  /// The list marker run, or null.
  final StyledRun? marker;

  /// Left edge of the marker (su).
  final double markerX;

  /// `bullet`, `ordered`, `check`, `unchecked` or null.
  final String? list;

  /// Right-to-left paragraph.
  final bool rtl;

  /// The paragraph's display text.
  String get text => runs.map((r) => r.text).join();

  /// Whether the paragraph has no characters.
  bool get isEmpty => runs.isEmpty;
}

/// Builds [StyledParagraph]s from a body.
abstract final class TextParagraphs {
  static final TextStyleResolver _resolver = TextStyleResolver(cacheSize: 1);

  /// Bullet glyphs by key (02 §4.1 `listStyle`).
  static const bulletGlyphs = {
    'disc': '•',
    'circle': '◦',
    'square': '▪',
    'dash': '–',
    'arrow': '→',
    'check': '✓',
    'star': '★',
    'none': '',
  };

  /// The paragraphs of [body] with [styles] at auto-fit [scale].
  static List<StyledParagraph> build(
    TextBody body,
    ResolvedTextStyles styles, {
    double scale = 1,
  }) {
    final theme = styles.theme;
    final out = <StyledParagraph>[];
    // Collect inserts per paragraph: (text, inline attrs), then the block
    // attributes of the closing "\n".
    var pending = <(String, Map<String, Object?>)>[];
    var offset = 0;
    var paraStart = 0;
    final counters = List<int>.filled(9, 0);

    void endParagraph(Map<String, Object?> block) {
      final index = out.length;
      final para = _paragraph(
        index,
        paraStart,
        offset,
        pending,
        block,
        styles,
        theme,
        scale,
        counters,
      );
      if (para.list != 'ordered') {
        for (var i = 0; i < counters.length; i++) {
          if (para.list == null || i >= para.level) counters[i] = 0;
        }
      }
      out.add(para);
      pending = [];
    }

    for (final op in body.ops) {
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = op['attributes'] is Map
          ? (op['attributes'] as Map).cast<String, Object?>()
          : const <String, Object?>{};
      var from = 0;
      while (from <= insert.length) {
        final nl = insert.indexOf('\n', from);
        if (nl < 0) {
          if (from < insert.length) {
            final t = insert.substring(from);
            pending.add((t, attrs));
            offset += t.length;
          }
          break;
        }
        if (nl > from) {
          final t = insert.substring(from, nl);
          pending.add((t, attrs));
          offset += t.length;
        }
        endParagraph(attrs);
        offset += 1;
        paraStart = offset;
        from = nl + 1;
      }
    }
    if (pending.isNotEmpty || out.isEmpty) endParagraph(const {});
    return out;
  }

  static StyledParagraph _paragraph(
    int index,
    int start,
    int end,
    List<(String, Map<String, Object?>)> inserts,
    Map<String, Object?> block,
    ResolvedTextStyles styles,
    ResolvedTheme? theme,
    double scale,
    List<int> counters,
  ) {
    final level = ((block['indent'] as num?)?.toInt() ?? 0).clamp(0, 8);
    final list = block['list'] as String?;
    final listStyles = theme?.lists ?? ThemeListStyles.defaults;
    final body2 = styles.styles['body2']?.size;

    EffectiveRunStyle runStyle(Map<String, Object?> inline) => theme == null
        ? _fallback(styles, block, inline)
        : _resolver.run(theme, styles, block: block, inline: inline);

    double sizeOf(EffectiveRunStyle s, Map<String, Object?> inline) {
      var size = s.size;
      final explicit =
          inline['size'] != null ||
          (block['style'] == null && styles.box?.defaults['size'] != null);
      if (list != null && level > 0 && !explicit) {
        final scaled = size * math.pow(listStyles.levelSizeScale, level);
        size = math.max(scaled, math.min(size, body2 ?? 0));
      }
      return size;
    }

    StyledRun styled(String text, int at, Map<String, Object?> inline) {
      final s = runStyle(inline);
      var size = sizeOf(s, inline) * scale;
      var shift = 0.0;
      if (s.script == 'super') {
        shift = size * 0.33;
        size *= 0.65;
      } else if (s.script == 'sub') {
        shift = -size * 0.12;
        size *= 0.65;
      }
      return StyledRun(
        text: _caps(text, s.caps),
        start: at,
        fontFamily: s.font.family,
        fontWeight: s.font.weight,
        fontSize: size,
        color: s.color,
        italic: s.font.italic,
        underline: s.underline,
        strike: s.strike,
        highlight: s.highlight ?? (s.code ? theme?.inlineCodeBackground : null),
        letterSpacing: s.letterSpacing * size,
        baselineShift: shift,
        link: s.link,
        code: s.code,
      );
    }

    final runs = <StyledRun>[];
    var at = start;
    for (final (text, inline) in inserts) {
      if (text.isEmpty) continue;
      runs.add(styled(text, at, inline));
      at += text.length;
    }
    final markStyle = runStyle(const {});
    final mark = styled('', end, const {});

    StyledRun? marker;
    var textIndent = level * listStyles.indentPerLevel * scale;
    final markerX = textIndent;
    if (list != null) {
      final glyph = _marker(
        list,
        level,
        block['listStyle'] as String?,
        block['listStart'] as num?,
        listStyles,
        counters,
      );
      if (glyph.isNotEmpty) {
        final first = runs.isEmpty ? mark : runs.first;
        final bulletColor = theme?.bulletColor ?? first.color;
        marker = StyledRun(
          text: glyph,
          start: start,
          fontFamily: first.fontFamily,
          fontWeight: list == 'ordered' ? first.fontWeight : 400,
          fontSize: first.fontSize,
          color: list == 'ordered' ? first.color : bulletColor,
        );
      }
      textIndent += listStyles.indentPerLevel * scale;
    }
    return StyledParagraph(
      index: index,
      start: start,
      end: end,
      runs: runs,
      mark: mark,
      align: (block['align'] as String?) ?? markStyle.align,
      lineHeight: markStyle.lineHeight,
      spaceBefore: markStyle.spaceBefore * scale,
      spaceAfter: markStyle.spaceAfter * scale,
      level: level,
      textIndent: textIndent,
      marker: marker,
      markerX: markerX,
      list: list,
      rtl: block['dir'] == 'rtl',
    );
  }

  /// A run style without a theme (layout tests, malformed styles): the
  /// paragraph's resolved text style with inline sizes and colors only.
  static EffectiveRunStyle _fallback(
    ResolvedTextStyles styles,
    Map<String, Object?> block,
    Map<String, Object?> inline,
  ) {
    final key = block['style'] as String?;
    final base = styles.styleFor(key);
    final defaults = key == null
        ? (styles.box?.defaults ?? const <String, Object?>{})
        : const <String, Object?>{};
    Object? pick(String k) => inline[k] ?? block[k] ?? defaults[k];
    return EffectiveRunStyle(
      styleKey: key ?? styles.defaultStyle,
      font: base.font,
      size: (pick('size') as num?)?.toDouble() ?? base.size,
      color: base.color,
      lineHeight: (pick('lineHeight') as num?)?.toDouble() ?? base.lineHeight,
      letterSpacing:
          (pick('letterSpacing') as num?)?.toDouble() ?? base.letterSpacing,
      align: (pick('align') as String?) ?? base.align,
      spaceBefore:
          (pick('spaceBefore') as num?)?.toDouble() ?? base.spaceBefore,
      spaceAfter: (pick('spaceAfter') as num?)?.toDouble() ?? base.spaceAfter,
      caps: (pick('caps') as String?) ?? base.caps,
      italic: inline['italic'] == true,
      underline: inline['underline'] == true,
      strike: inline['strike'] == true,
      script: inline['script'] as String?,
      link: inline['link'] as String?,
    );
  }

  static String _caps(String text, String? caps) => switch (caps) {
    'all' || 'small' => text.toUpperCase(),
    'title' => text.replaceAllMapped(
      RegExp(r'(^|[\s ])(\p{Ll})', unicode: true),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    ),
    _ => text,
  };

  static String _marker(
    String list,
    int level,
    String? listStyle,
    num? listStart,
    ThemeListStyles lists,
    List<int> counters,
  ) {
    switch (list) {
      case 'check':
        return '☑';
      case 'unchecked':
        return '☐';
      case 'ordered':
        counters[level] = listStart != null
            ? listStart.toInt()
            : counters[level] + 1;
        for (var i = level + 1; i < counters.length; i++) {
          counters[i] = 0;
        }
        final style = listStyle != null && numberingKeys.contains(listStyle)
            ? listStyle
            : lists.numbering[level];
        return '${formatListNumber(counters[level], style)}.';
      default:
        final key = listStyle ?? lists.bullets[level];
        if (key.startsWith('emoji:')) return key.substring(6);
        return bulletGlyphs[key] ?? bulletGlyphs['disc']!;
    }
  }

  /// [n] in numbering [style] (`decimal`, `lowerAlpha`, `upperAlpha`,
  /// `lowerRoman`, `upperRoman`).
  static String formatListNumber(int n, String style) {
    switch (style) {
      case 'lowerAlpha' || 'upperAlpha':
        if (n <= 0) return '$n';
        var v = n, s = '';
        while (v > 0) {
          v--;
          s = String.fromCharCode(97 + v % 26) + s;
          v ~/= 26;
        }
        return style == 'upperAlpha' ? s.toUpperCase() : s;
      case 'lowerRoman' || 'upperRoman':
        if (n <= 0 || n >= 4000) return '$n';
        const vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
        const syms = [
          'm',
          'cm',
          'd',
          'cd',
          'c',
          'xc',
          'l',
          'xl',
          'x',
          'ix',
          'v',
          'iv',
          'i',
        ];
        var v = n;
        final b = StringBuffer();
        for (var i = 0; i < vals.length; i++) {
          while (v >= vals[i]) {
            b.write(syms[i]);
            v -= vals[i];
          }
        }
        final s = b.toString();
        return style == 'upperRoman' ? s.toUpperCase() : s;
      default:
        return '$n';
    }
  }
}
