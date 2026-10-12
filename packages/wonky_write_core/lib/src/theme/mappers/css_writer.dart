/// `ThemeCssWriter` and unit helpers shared by exporters (06 §7).
library;

import '../model/style_enums.dart';
import '../model/values.dart';
import '../resolve/resolved_theme.dart';

/// Unit conversions for renderers (theme values are in pt).
abstract final class ThemeUnits {
  /// pt → CSS px (1pt = 4/3 px).
  static double ptToPx(double pt) => pt * 4 / 3;

  /// pt → DOCX half-points.
  static int ptToHalfPoints(double pt) => (pt * 2).round();

  /// pt → twips (DOCX/RTF).
  static int ptToTwips(double pt) => (pt * 20).round();

  /// ARGB → `#RRGGBB`.
  static String hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// ARGB → CSS color (`#RRGGBB`, or `rgba()` when translucent).
  static String css(int argb) {
    final a = (argb >> 24) & 0xFF;
    if (a == 0xFF) return hex(argb);
    if (a == 0) return 'transparent';
    final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
    return 'rgba($r, $g, $b, ${(a / 255).toStringAsFixed(3)})';
  }

  /// Space between two blocks: `max(spaceAfter(a), spaceBefore(b))`.
  static double collapse(double spaceAfter, double spaceBefore) =>
      spaceAfter > spaceBefore ? spaceAfter : spaceBefore;
}

/// CSS output target.
enum CssTarget {
  /// Self-contained HTML export.
  html,

  /// EPUB (no page background; colors only when requested; em sizes).
  epub,

  /// *Export theme as CSS…*.
  standalone,
}

/// A web font face for `@font-face`.
final class CssFontFace {
  /// Creates a face.
  const CssFontFace({
    required this.family,
    required this.url,
    this.weight = 400,
    this.italic = false,
  });

  /// Family name.
  final String family;

  /// `url(...)` target (relative path or data URI).
  final String url;

  /// Weight.
  final int weight;

  /// Italic.
  final bool italic;
}

/// Writes a self-contained stylesheet for a resolved theme, scoped under
/// `.wonky-doc`.
final class ThemeCssWriter {
  /// Creates a writer.
  const ThemeCssWriter();

  /// Generic families appended to font stacks.
  static String _stack(String family, {bool mono = false}) {
    final generic = mono
        ? 'ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace'
        : 'system-ui, -apple-system, "Segoe UI", sans-serif';
    final serifish = RegExp(
      r'Serif|Garamond|Baskerville|Lora|Merriweather|Crimson|Literata|Playfair|Times',
    ).hasMatch(family);
    return '"$family", ${mono ? generic : (serifish ? 'Georgia, "Times New Roman", serif' : generic)}';
  }

  /// The stylesheet for [light] (and [dark] in a `prefers-color-scheme`
  /// media query). [pageSize]/[pageMargins] (pt) add an `@page` rule;
  /// [fonts] add `@font-face` rules. For [CssTarget.epub], colors are only
  /// emitted when [useColors].
  String write(
    ResolvedWriteTheme light, {
    ResolvedWriteTheme? dark,
    CssTarget target = CssTarget.html,
    (double, double)? pageSize,
    EdgesPt? pageMargins,
    List<CssFontFace> fonts = const [],
    bool useColors = true,
  }) {
    final b = StringBuffer(
      '/* Wonky Write theme: ${light.name} (${light.contentHash.substring(0, 12)}) */\n',
    );
    for (final f in fonts) {
      b.writeln(
        '@font-face { font-family: "${f.family}"; src: url("${f.url}") format("truetype"); '
        'font-weight: ${f.weight}; font-style: ${f.italic ? 'italic' : 'normal'}; font-display: swap; }',
      );
    }
    if (pageSize != null) {
      final m = pageMargins;
      b.writeln(
        '@page { size: ${_n(pageSize.$1)}pt ${_n(pageSize.$2)}pt;'
        '${m == null ? '' : ' margin: ${_n(m.top)}pt ${_n(m.right)}pt ${_n(m.bottom)}pt ${_n(m.left)}pt;'} }',
      );
    }
    final colors = target != CssTarget.epub || useColors;
    b.write(_rules(light, target: target, colors: colors, layout: true));
    if (dark != null && colors) {
      b.writeln('@media (prefers-color-scheme: dark) {');
      b.write(_rules(dark, target: target, colors: true, layout: false));
      b.writeln('}');
    }
    return b.toString();
  }

  static String _n(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _rules(
    ResolvedWriteTheme t, {
    required CssTarget target,
    required bool colors,
    required bool layout,
  }) {
    final b = StringBuffer();
    final base = t.body.style.fontSize;
    String size(double pt) =>
        target == CssTarget.epub ? '${_n(pt / base)}em' : '${_n(pt)}pt';
    String len(double pt) =>
        target == CssTarget.epub ? '${_n(pt / base)}em' : '${_n(pt)}pt';
    String c(int argb) => ThemeUnits.css(argb);

    void rule(String selector, Map<String, String?> props) {
      final entries = props.entries.where((e) => e.value != null).toList();
      if (entries.isEmpty) return;
      b.write('$selector { ');
      for (final e in entries) {
        b.write('${e.key}: ${e.value}; ');
      }
      b.writeln('}');
    }

    Map<String, String?> text(
      ResolvedTextStyle s, {
      bool mono = false,
      bool withSize = true,
    }) => {
      if (layout) 'font-family': _stack(s.fontFamily, mono: mono),
      if (layout && withSize) 'font-size': size(s.fontSize),
      if (layout) 'font-weight': '${s.fontWeight}',
      if (layout) 'font-style': s.italic ? 'italic' : 'normal',
      if (layout) 'line-height': _n(s.lineHeight),
      if (layout && s.letterSpacing != 0)
        'letter-spacing': '${_n(s.letterSpacing)}pt',
      if (colors) 'color': c(s.color),
      if (layout && s.caseTransform == CaseTransform.smallCaps)
        'font-variant': 'small-caps',
      if (layout &&
          s.caseTransform != CaseTransform.none &&
          s.caseTransform != CaseTransform.smallCaps)
        'text-transform': s.caseTransform.name,
      if (layout && s.fontFeatures.isNotEmpty)
        'font-feature-settings': s.fontFeatures.map((f) => '"$f"').join(', '),
    };

    String border(BorderPt? x) => x == null || !x.isVisible
        ? 'none'
        : '${_n(x.width)}pt ${x.style == LineStyle.doubleLine ? 'double' : x.style.name} ${colors ? c(x.color) : 'currentColor'}';

    Map<String, String?> box(ResolvedBox x, {bool spacing = true}) => {
      if (layout && spacing) 'margin-top': len(x.spaceBefore),
      if (layout && spacing) 'margin-bottom': len(x.spaceAfter),
      if (layout && (x.padding.vertical > 0 || x.padding.horizontal > 0))
        'padding':
            '${len(x.padding.top)} ${len(x.padding.right)} ${len(x.padding.bottom)} ${len(x.padding.left)}',
      if (colors && x.background != null) 'background-color': c(x.background!),
      if (x.border.hasAny) ...{
        'border-top': border(x.border.top),
        'border-right': border(x.border.right),
        'border-bottom': border(x.border.bottom),
        'border-left': border(x.border.left),
      },
      if (layout && x.borderRadius > 0) 'border-radius': len(x.borderRadius),
      if (layout) 'text-align': x.align.name,
      if (layout && x.pageBreakBefore) 'break-before': 'page',
      if (layout && x.keepWithNext) 'break-after': 'avoid',
    };

    const s = '.wonky-doc';
    // Page / body.
    if (target == CssTarget.html && colors) {
      rule('html', {'background-color': c(t.page.paperColor)});
    }
    rule(s, {
      ...text(t.body.style),
      if (target != CssTarget.epub && colors)
        'background-color': c(t.page.paperColor),
      if (layout && target != CssTarget.epub)
        'max-width': '${_n(ThemeUnits.ptToPx(t.page.pagelessMaxWidth))}px',
      if (layout && target != CssTarget.epub) 'margin': '0 auto',
      if (layout && target != CssTarget.epub)
        'padding':
            '${len(t.page.pagelessPadding.top)} ${len(t.page.pagelessPadding.right)} '
            '${len(t.page.pagelessPadding.bottom)} ${len(t.page.pagelessPadding.left)}',
      if (layout) 'overflow-wrap': 'break-word',
    });
    rule('$s p', {
      ...box(t.body.box),
      if (layout && t.body.firstLineIndent > 0)
        'text-indent': len(t.body.firstLineIndent),
    });
    if (layout) {
      rule('$s > :first-child', {'margin-top': '0'});
    }
    // Headings.
    for (final h in t.headings) {
      final sel = '$s h${h.level}';
      rule(sel, {
        ...text(h.style),
        ...box(h.box),
        if (h.borderBottom != null && h.borderBottom!.isVisible)
          'border-bottom': border(h.borderBottom),
        if (layout && h.borderBottom != null && h.borderBottom!.isVisible)
          'padding-bottom': len(h.borderBottomGap),
      });
      final after = t.paragraphAfterHeading;
      if (layout && !after.isEmpty) {
        rule('$sel + p', {
          if (after.spaceBefore != null) 'margin-top': len(after.spaceBefore!),
          if (after.spaceAfter != null) 'margin-bottom': len(after.spaceAfter!),
        });
      }
    }
    if (layout) _numbering(b, t.headingNumbering, rule);
    // Inline.
    rule('$s strong', {
      if (layout) 'font-weight': '${t.bold.fontWeight ?? 700}',
      if (colors && t.bold.color != null) 'color': c(t.bold.color!),
    });
    rule('$s em', {
      if (layout) 'font-style': t.italic.oblique ? 'oblique' : 'italic',
      if (colors && t.italic.color != null) 'color': c(t.italic.color!),
    });
    rule('$s del', {
      if (layout) 'text-decoration': 'line-through',
      if (colors && t.strike.lineColor != null)
        'text-decoration-color': c(t.strike.lineColor!),
      if (layout)
        'text-decoration-thickness': '${_n(t.strike.lineThickness)}pt',
      if (colors && t.strike.color != null) 'color': c(t.strike.color!),
    });
    final ic = t.inlineCode;
    rule('$s code', {
      if (layout) 'font-family': _stack(ic.fontFamily, mono: true),
      if (layout) 'font-size': '${_n(ic.sizeRatio)}em',
      if (colors) 'color': c(ic.color),
      if (colors && ic.background != null)
        'background-color': c(ic.background!),
      if (layout) 'padding': '0 ${len(ic.paddingX)}',
      if (layout && ic.borderRadius > 0) 'border-radius': len(ic.borderRadius),
      if (ic.border != null && ic.border!.isVisible)
        'border': border(ic.border),
    });
    final link = t.link;
    rule('$s a', {
      if (colors) 'color': c(link.color),
      if (layout)
        'text-decoration': link.underline == LinkUnderline.always
            ? 'underline'
            : 'none',
      if (layout && link.underline == LinkUnderline.always)
        'text-decoration-style': link.underlineStyle == LineStyle.doubleLine
            ? 'double'
            : link.underlineStyle.name,
      if (layout)
        'text-decoration-thickness': '${_n(link.underlineThickness)}pt',
    });
    rule('$s a:hover', {
      if (colors) 'color': c(link.hoverColor),
      if (layout && link.underline == LinkUnderline.hover)
        'text-decoration': 'underline',
    });
    final m = t.mention;
    rule('$s a.wonky-mention', {
      if (colors) 'color': c(m.color),
      if (colors && m.background != null) 'background-color': c(m.background!),
      if (layout) 'border-radius': len(m.borderRadius),
      if (layout) 'font-weight': '${m.fontWeight}',
      if (layout) 'padding': '0 0.2em',
      if (layout) 'text-decoration': 'none',
    });
    // Blockquote.
    final q = t.blockquote;
    rule('$s blockquote', {
      ...text(q.style, withSize: true),
      ...box(q.box),
      if (layout) 'margin-left': '0',
      if (layout) 'margin-right': '0',
      'border-left': border(q.bar),
    });
    rule('$s blockquote p', {
      if (layout) 'margin': '0 0 ${len(t.body.box.spaceAfter)} 0',
    });
    rule('$s blockquote p:last-child', {if (layout) 'margin-bottom': '0'});
    // Code blocks.
    final cb = t.codeBlock;
    rule('$s pre', {
      ...text(cb.style, mono: true),
      ...box(cb.box),
      if (layout) 'white-space': 'pre-wrap',
      if (layout) 'tab-size': '${cb.tabSize}',
      if (layout) 'overflow-x': 'auto',
    });
    rule('$s pre code', {
      if (layout) 'font-size': 'inherit',
      if (layout) 'font-family': 'inherit',
      if (colors) 'background': 'none',
      if (layout) 'padding': '0',
      if (layout) 'border': 'none',
      if (colors) 'color': 'inherit',
    });
    if (layout && cb.showLanguageLabel) {
      rule('$s pre[data-language]::before', {
        'content': 'attr(data-language)',
        'display': 'block',
        'font-size': '0.75em',
        'opacity': '0.7',
        'margin-bottom': '0.25em',
      });
    }
    for (final e in t.syntax.entries) {
      final ts = e.value;
      rule('$s .tok-${e.key.name}', {
        if (colors) 'color': c(ts.color),
        if (layout && ts.italic) 'font-style': 'italic',
        if (layout && ts.fontWeight != null) 'font-weight': '${ts.fontWeight}',
      });
    }
    // Lists.
    final l = t.list;
    rule('$s ul, $s ol', {
      ...text(l.style, withSize: true),
      ...box(l.box),
      if (layout) 'padding-left': len(l.indentPerLevel),
    });
    rule('$s li ul, $s li ol', {if (layout) 'margin': '0'});
    rule('$s li', {if (layout) 'margin-bottom': len(l.itemSpacing)});
    rule('$s li::marker', {if (colors) 'color': c(l.bulletColor)});
    rule('$s ol > li::marker', {if (colors) 'color': c(l.numberColor)});
    if (layout) {
      for (var level = 0; level < 9; level++) {
        final ul = [for (var i = 0; i <= level; i++) 'ul'].join(' ');
        final glyph = l.bullets[level % l.bullets.length].replaceAll(
          '"',
          r'\"',
        );
        rule('$s $ul:not(.wonky-tasks) > li', {
          'list-style-type': '"$glyph  "',
        });
        final ol = [for (var i = 0; i <= level; i++) 'ol'].join(' ');
        final style = l.numbering[level % l.numbering.length];
        final css = switch (style) {
          ListNumberStyle.decimal => 'decimal',
          ListNumberStyle.lowerAlpha => 'lower-alpha',
          ListNumberStyle.upperAlpha => 'upper-alpha',
          ListNumberStyle.lowerRoman => 'lower-roman',
          ListNumberStyle.upperRoman => 'upper-roman',
        };
        rule('$s $ol > li::marker', {
          'content': 'counter(list-item, $css) "${l.numberSuffix} "',
        });
      }
    }
    // Tasks.
    final tk = t.task;
    rule('$s ul.wonky-tasks', {
      if (layout) 'list-style': 'none',
      if (layout) 'padding-left': len(l.indentPerLevel),
    });
    rule('$s li.wonky-task', {...text(tk.style, withSize: true)});
    rule('$s li.wonky-task input', {
      if (layout) 'width': len(tk.checkbox.size),
      if (layout) 'height': len(tk.checkbox.size),
      if (layout) 'margin': '0 0.4em 0 -${len(tk.checkbox.size + 4)}',
      if (layout) 'vertical-align': 'middle',
      if (colors) 'accent-color': c(tk.checkbox.checkedFill),
    });
    rule('$s li.wonky-task-checked', {
      if (layout && tk.checkedStrike) 'text-decoration': 'line-through',
      if (layout) 'opacity': _n(tk.checkedOpacity),
      if (colors) 'color': c(tk.checkedColor),
    });
    // Rule.
    final r = t.rule;
    final width = r.width.fraction != null
        ? '${_n(r.width.fraction! * 100)}%'
        : len(r.width.points ?? 0);
    if (r.style == RuleStyle.ornament) {
      rule('$s hr', {
        ...box(r.box),
        if (layout) 'border': 'none',
        if (layout) 'text-align': 'center',
        if (layout) 'height': 'auto',
        if (layout) 'overflow': 'visible',
      });
      rule('$s hr::after', {
        if (layout) 'content': '"${r.ornament.replaceAll('"', r'\"')}"',
        ...text(r.ornamentStyle),
      });
    } else {
      rule('$s hr', {
        ...box(r.box),
        if (layout) 'border': 'none',
        'border-top':
            '${_n(r.thickness)}pt ${r.style == RuleStyle.doubleLine ? 'double' : r.style.name} ${colors ? c(r.color) : 'currentColor'}',
        if (layout) 'width': width,
        if (layout) 'margin-left': 'auto',
        if (layout) 'margin-right': 'auto',
      });
    }
    // Images.
    final im = t.image;
    rule('$s figure.wonky-image', {
      ...box(im.box),
      if (layout) 'margin-left': '0',
      if (layout) 'margin-right': '0',
      if (layout)
        'text-align': im.align == ImageAlign.center ? 'center' : 'left',
    });
    rule('$s figure.wonky-image img', {
      if (layout)
        'max-width': im.maxWidth.fraction != null
            ? '${_n(im.maxWidth.fraction! * 100)}%'
            : len(im.maxWidth.points ?? 0),
      if (layout) 'height': 'auto',
      if (layout && im.borderRadius > 0) 'border-radius': len(im.borderRadius),
      if (im.border != null && im.border!.isVisible)
        'border': border(im.border),
      if (layout && im.shadow != ShadowLevel.none)
        'box-shadow': im.shadow == ShadowLevel.soft
            ? '0 1px 4px rgba(0,0,0,0.18)'
            : '0 4px 16px rgba(0,0,0,0.3)',
    });
    rule('$s figure.wonky-image figcaption', {
      if (layout && !im.caption.show) 'display': 'none',
      ...text(im.caption.style),
      if (layout) 'text-align': im.caption.align.name,
      if (layout) 'margin-top': len(im.caption.gap),
    });
    // Tables.
    final tb = t.table;
    final cellBorder =
        '${_n(tb.borderWidth)}pt solid ${colors ? c(tb.borderColor) : 'currentColor'}';
    rule('$s table', {
      ...text(tb.style),
      ...box(tb.box),
      if (layout) 'border-collapse': 'collapse',
      if (layout && tb.width == TableWidth.full) 'width': '100%',
      if (tb.borders == TableBorders.all || tb.borders == TableBorders.outer)
        'border': cellBorder,
    });
    final cellPad =
        '${len(tb.cellPadding.top)} ${len(tb.cellPadding.right)} ${len(tb.cellPadding.bottom)} ${len(tb.cellPadding.left)}';
    rule('$s th, $s td', {
      if (layout) 'padding': cellPad,
      if (layout) 'vertical-align': 'top',
      if (tb.borders == TableBorders.all) 'border': cellBorder,
      if (tb.borders == TableBorders.horizontal) 'border-bottom': cellBorder,
    });
    rule('$s th', {
      ...text(tb.headerStyle),
      if (colors && tb.headerBackground != null)
        'background-color': c(tb.headerBackground!),
      if (tb.borders == TableBorders.headerOnly) 'border-bottom': cellBorder,
      if (layout) 'text-align': 'left',
    });
    if (tb.zebra && tb.zebraColor != null && colors) {
      rule('$s tbody tr:nth-child(even) td', {
        'background-color': c(tb.zebraColor!),
      });
    }
    // Header/footer typography (print page boxes are not widely supported;
    // exposed for standalone use).
    if (target == CssTarget.standalone) {
      rule('$s .wonky-header', {
        ...text(t.header.style),
        if (layout) 'text-align': t.header.align.name,
      });
      rule('$s .wonky-footer', {
        ...text(t.footer.style),
        if (layout) 'text-align': t.footer.align.name,
      });
    }
    // TOC.
    rule('$s nav.wonky-toc ol', {
      if (layout) 'list-style': 'none',
      if (layout) 'padding-left': len(l.indentPerLevel),
    });
    rule('$s nav.wonky-toc > ol', {if (layout) 'padding-left': '0'});
    rule('$s p.wonky-image-missing', {
      if (colors) 'color': c(t.body.style.color),
      if (layout) 'font-style': 'italic',
    });
    return b.toString();
  }

  void _numbering(
    StringBuffer b,
    ResolvedHeadingNumbering n,
    void Function(String, Map<String, String?>) rule,
  ) {
    if (!n.enabled) return;
    const s = '.wonky-doc';
    rule(s, {
      'counter-reset': [for (var l = 1; l <= 6; l++) 'wk-h$l'].join(' '),
    });
    for (var level = 1; level <= 6; level++) {
      rule('$s h$level', {
        'counter-increment': 'wk-h$level',
        'counter-reset': level < 6
            ? [for (var l = level + 1; l <= 6; l++) 'wk-h$l'].join(' ')
            : null,
      });
      if (level < n.fromLevel || level > n.toLevel) continue;
      final parts = <String>[];
      switch (n.style) {
        case HeadingNumberingStyle.decimal:
          parts.add('counter(wk-h$level) "."');
        case HeadingNumberingStyle.outline || HeadingNumberingStyle.legal:
          for (var l = n.fromLevel; l <= level; l++) {
            if (l > n.fromLevel) parts.add('"."');
            parts.add('counter(wk-h$l)');
          }
          if (n.style == HeadingNumberingStyle.legal) parts.add('"."');
        case HeadingNumberingStyle.upperRomanUpperAlphaDecimal:
          final i = (level - n.fromLevel) % 3;
          parts.add(
            'counter(wk-h$level, ${const ['upper-roman', 'upper-alpha', 'decimal'][i]}) "."',
          );
      }
      var suffix = n.suffix;
      if (parts.last.endsWith('"."') && suffix.startsWith('.')) {
        suffix = suffix.substring(1);
      }
      parts.add('"${suffix.replaceAll('"', r'\"')}"');
      rule('$s h$level::before', {'content': parts.join(' ')});
    }
  }
}
