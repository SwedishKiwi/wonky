import '../../format/borders.dart';
import '../../format/theme.dart';
import '../../model/schema.dart';
import '../print/cell_display.dart';
import 'html_escape.dart';

/// Inline CSS for cells (clipboard `text/html`, HTML export).
abstract final class CellCss {
  /// CSS for one border edge: `1px solid #000000` (06 §8.1 widths).
  static String border(BorderSpec spec, SpreadsheetTheme theme) {
    final style = spec.style!;
    final color = theme.resolveColor(spec.color) ?? '#000000';
    final css = switch (style) {
      BorderStyle.thin => '1px solid',
      BorderStyle.medium => '2px solid',
      BorderStyle.thick => '3px solid',
      BorderStyle.dashed => '1px dashed',
      BorderStyle.dotted => '1px dotted',
      BorderStyle.double => '3px double',
    };
    return '$css $color';
  }

  /// The inline style of a cell.
  ///
  /// [defaultFont]/[defaultSize] are the table defaults (font declarations
  /// equal to them are omitted). [gridline] (`#e0e0e0`) is used for edges
  /// without a border. [overflowVisible] lets overflow text paint into empty
  /// neighbours (HTML export).
  static String style(
    CellDisplay d, {
    required SpreadsheetTheme theme,
    required String defaultFont,
    required double defaultSize,
    CellEdges? edges,
    String? gridline,
    bool overflowVisible = false,
    bool includePadding = true,
  }) {
    final f = d.format;
    final b = StringBuffer();
    void p(String k, String v) => b
      ..write(k)
      ..write(':')
      ..write(v)
      ..write(';');

    p('overflow', overflowVisible ? 'visible' : 'hidden');
    if (includePadding) p('padding', '2px 3px 2px 3px');
    p('vertical-align', switch (f.vAlign) {
      VerticalAlign.top => 'top',
      VerticalAlign.middle => 'middle',
      VerticalAlign.bottom => 'bottom',
    });
    p('text-align', d.hAlign.name);
    if (f.fontFamily != defaultFont) p('font-family', HtmlText.cssFontFamily(f.fontFamily));
    if (f.fontSize != defaultSize) p('font-size', '${HtmlText.num(f.fontSize)}pt');
    if (f.bold) p('font-weight', 'bold');
    if (f.italic) p('font-style', 'italic');
    final deco = [if (d.underline) 'underline', if (f.strikethrough) 'line-through'];
    if (deco.isNotEmpty) p('text-decoration', deco.join(' '));
    if (d.textColor != null) p('color', d.textColor!);
    if (d.fillColor != null) p('background-color', d.fillColor!);
    switch (f.wrap) {
      case WrapStrategy.wrap:
        p('wrap-strategy', '4');
        p('white-space', 'normal');
        p('word-wrap', 'break-word');
      case WrapStrategy.clip:
        p('wrap-strategy', '2');
        p('white-space', 'nowrap');
      case WrapStrategy.overflow:
        p('white-space', 'nowrap');
    }
    if (f.rotation == 255) {
      p('writing-mode', 'vertical-lr');
      p('text-orientation', 'upright');
    } else if (f.rotation != 0) {
      p('transform', 'rotate(${-f.rotation}deg)');
    }
    if (edges != null) {
      void edge(String side, BorderSpec? s) {
        if (s != null && !s.isNone) {
          p('border-$side', border(s, theme));
        } else if (gridline != null) {
          p('border-$side', '1px solid $gridline');
        }
      }

      edge('top', edges.top);
      edge('right', edges.right);
      edge('bottom', edges.bottom);
      edge('left', edges.left);
    }
    return b.toString();
  }

  /// Inline style of a rich run relative to the cell (`<span style>`).
  static String runStyle(Map<String, Object?> f, SpreadsheetTheme theme) {
    final b = StringBuffer();
    void p(String k, String v) => b
      ..write(k)
      ..write(':')
      ..write(v)
      ..write(';');
    final family = f['fontFamily'];
    if (family is String) p('font-family', HtmlText.cssFontFamily(family));
    final size = f['fontSize'];
    if (size is num) p('font-size', '${HtmlText.num(size.toDouble())}pt');
    if (f['bold'] == true) p('font-weight', 'bold');
    if (f['bold'] == false) p('font-weight', 'normal');
    if (f['italic'] == true) p('font-style', 'italic');
    if (f['italic'] == false) p('font-style', 'normal');
    final deco = [if (f['underline'] == true) 'underline', if (f['strikethrough'] == true) 'line-through'];
    if (deco.isNotEmpty) p('text-decoration', deco.join(' '));
    final color = theme.resolveColor(f['textColor'] as String?);
    if (color != null) p('color', color);
    return b.toString();
  }

  /// Inner HTML of a cell: escaped display text (`<br/>` line breaks), rich
  /// runs as `<span>`s, links as `<a>`. [href] maps a stored link to an
  /// `href` (null drops the link); default: [HtmlText.safeUrl].
  static String body(
    CellDisplay d,
    SpreadsheetTheme theme, {
    String? Function(String url)? href,
  }) {
    final toHref = href ?? HtmlText.safeUrl;
    final text = d.text;
    final rich = d.rich;
    String inner;
    if (rich != null && rich.text == text && rich.runs.isNotEmpty) {
      final b = StringBuffer();
      var pos = 0;
      for (final run in rich.runs) {
        if (run.start > pos) b.write(HtmlText.escapeMultiline(text.substring(pos, run.start)));
        final seg = HtmlText.escapeMultiline(text.substring(run.start, run.end));
        final style = runStyle(run.format, theme);
        var html = style.isEmpty ? seg : '<span style="${HtmlText.attr(style)}">$seg</span>';
        final link = run.link == null ? null : toHref(run.link!);
        if (link != null) html = '<a href="${HtmlText.attr(link)}">$html</a>';
        b.write(html);
        pos = run.end;
      }
      if (pos < text.length) b.write(HtmlText.escapeMultiline(text.substring(pos)));
      inner = b.toString();
    } else {
      inner = HtmlText.escapeMultiline(text);
    }
    final link = d.linkUrl == null ? null : toHref(d.linkUrl!);
    if (link != null) return '<a href="${HtmlText.attr(link)}">$inner</a>';
    return inner;
  }
}
