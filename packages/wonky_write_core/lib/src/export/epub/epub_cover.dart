/// EPUB cover pages: an image cover or a generated SVG title page
/// (07 §5.8).
library;

import 'dart:math' as math;

import 'package:wonky_fonts/wonky_fonts.dart';
import '../../theme/model/color_ref.dart';
import '../../theme/resolve/resolved_theme.dart';
import '../office/office_support.dart';
import 'epub_chapters.dart';

/// Writes `OEBPS/cover.xhtml`.
abstract final class EpubCoverWriter {
  static const _style =
      '<style>\n'
      'html, body { margin: 0; padding: 0; height: 100%; }\n'
      '.wonky-cover { height: 100%; text-align: center; }\n'
      '.wonky-cover img { max-width: 100%; max-height: 100%; }\n'
      '.wonky-cover svg { display: block; width: 100%; height: 100%; }\n'
      '</style>';

  /// Cover width of the generated SVG (user units).
  static const svgWidth = 600;

  /// Cover height of the generated SVG (user units).
  static const svgHeight = 900;

  /// A cover page showing the image at [imageHref] (relative to `OEBPS/`).
  static String image({
    required String language,
    required String title,
    required String imageHref,
  }) => epubXhtmlDocument(
    language: language,
    title: 'Cover',
    head: _style,
    body:
        '<div class="wonky-cover"><img src="${xmlAttr(imageHref)}" '
        'alt="${xmlAttr(title)}"/></div>',
  );

  /// A cover page with an inline SVG: [title] and [author] set in the
  /// theme's heading font, with accent-colored rules.
  static String generated({
    required String language,
    required String title,
    required String? author,
    required ResolvedWriteTheme theme,
  }) => epubXhtmlDocument(
    language: language,
    title: 'Cover',
    head: _style,
    body:
        '<div class="wonky-cover">\n${svg(title: title, author: author, theme: theme)}</div>',
  );

  /// The inline SVG of [generated].
  static String svg({
    required String title,
    required String? author,
    required ResolvedWriteTheme theme,
  }) {
    final heading = theme.headings.first.style;
    final paper = theme.page.paperColor;
    final background = (paper >>> 24) == 0 ? 0xFFFFFFFF : flattenAlpha(paper);
    final accent = flattenAlpha(
      theme.palette[PaletteKey.accent] ?? theme.link.color,
      background: background,
    );
    final ink = flattenAlpha(heading.color, background: background);
    final muted = flattenAlpha(
      theme.palette[PaletteKey.muted] ?? theme.body.style.color,
      background: background,
    );
    final family = heading.fontFamily.replaceAll(RegExp('["\'<>&]'), '');
    final generic =
        FontRegistry.lookup(heading.fontFamily)?.category.cssGeneric ?? 'serif';
    final font = xmlAttr("'$family', $generic");
    final weight = heading.fontWeight;

    const margin = 60;
    const usable = svgWidth - 2 * margin;
    final (size, lines) = _fitTitle(title.isEmpty ? 'Untitled' : title, usable);
    final lineHeight = (size * 1.2).round();
    final blockHeight = lineHeight * lines.length;
    final top = ((svgHeight - blockHeight) / 2 - 40).round();

    final b = StringBuffer()
      ..write(
        '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" '
        'viewBox="0 0 $svgWidth $svgHeight" preserveAspectRatio="xMidYMid meet" '
        'role="img" aria-label="${xmlAttr(title)}">\n',
      )
      ..write(
        '<rect x="0" y="0" width="$svgWidth" height="$svgHeight" '
        'fill="#${rgbHex(background)}"/>\n',
      )
      ..write(
        '<rect x="0" y="0" width="$svgWidth" height="24" fill="#${rgbHex(accent)}"/>\n',
      )
      ..write(
        '<rect x="$margin" y="${top - 48}" width="96" height="6" fill="#${rgbHex(accent)}"/>\n',
      )
      ..write(
        '<text x="$margin" y="$top" font-family="$font" font-size="$size" '
        'font-weight="$weight" fill="#${rgbHex(ink)}">\n',
      );
    for (var i = 0; i < lines.length; i++) {
      b.write(
        '<tspan x="$margin" dy="${i == 0 ? size : lineHeight}">${xmlText(lines[i])}</tspan>\n',
      );
    }
    b.write('</text>\n');
    final by = author?.trim() ?? '';
    if (by.isNotEmpty) {
      b.write(
        '<text x="$margin" y="${top + blockHeight + 72}" font-family="$font" '
        'font-size="26" fill="#${rgbHex(muted)}">${xmlText(by)}</text>\n',
      );
    }
    b
      ..write(
        '<rect x="0" y="${svgHeight - 24}" width="$svgWidth" height="24" '
        'fill="#${rgbHex(accent)}"/>\n',
      )
      ..write('</svg>\n');
    return b.toString();
  }

  /// Picks the largest font size whose word-wrapped lines fit [width]
  /// (approximate glyph width 0.55 em) in at most five lines.
  static (int, List<String>) _fitTitle(String title, int width) {
    const sizes = [64, 56, 48, 40, 34, 28, 24];
    var result = (sizes.last, <String>[]);
    for (final size in sizes) {
      final perLine = math.max(4, (width / (size * 0.55)).floor());
      final lines = _wrap(title, perLine);
      result = (size, lines);
      if (lines.length <= 5) break;
    }
    if (result.$2.length > 8) {
      final kept = result.$2.take(8).toList();
      kept[7] = '${kept[7]}…';
      result = (result.$1, kept);
    }
    return result;
  }

  static List<String> _wrap(String text, int perLine) {
    final lines = <String>[];
    var line = '';
    for (var word in text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      while (word.runes.length > perLine) {
        if (line.isNotEmpty) {
          lines.add(line);
          line = '';
        }
        final runes = word.runes.toList();
        lines.add(String.fromCharCodes(runes.take(perLine)));
        word = String.fromCharCodes(runes.skip(perLine));
      }
      if (line.isEmpty) {
        line = word;
      } else if (line.runes.length + 1 + word.runes.length <= perLine) {
        line = '$line $word';
      } else {
        lines.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines.isEmpty ? [text] : lines;
  }
}
