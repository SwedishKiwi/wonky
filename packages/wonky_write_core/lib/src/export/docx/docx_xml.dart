/// WordprocessingML building blocks: run and paragraph properties emitted in
/// schema order (ECMA-376 Part 1 §17.3.1.26 / §17.3.2.28), borders and
/// shading (07 §5.4, 06 §7.1).
library;

import '../../theme/model/values.dart';
import '../../theme/resolve/resolved_theme.dart';
import '../office/office_support.dart';

/// Namespace URIs of the parts written by the DOCX exporter.
abstract final class DocxNs {
  /// WordprocessingML main.
  static const w =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  /// Office relationships.
  static const r =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// DrawingML word processing.
  static const wp =
      'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';

  /// DrawingML main.
  static const a = 'http://schemas.openxmlformats.org/drawingml/2006/main';

  /// DrawingML picture.
  static const pic = 'http://schemas.openxmlformats.org/drawingml/2006/picture';

  /// Markup compatibility.
  static const mc =
      'http://schemas.openxmlformats.org/markup-compatibility/2006';

  /// Word 2010 extensions.
  static const w14 = 'http://schemas.microsoft.com/office/word/2010/wordml';

  /// Package relationships.
  static const rels =
      'http://schemas.openxmlformats.org/package/2006/relationships';

  /// Relationship type prefix.
  static const relType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// Root namespace declarations for document, header and footer parts.
  static const rootDecls =
      'xmlns:mc="$mc" xmlns:r="$r" xmlns:w="$w" xmlns:wp="$wp" '
      'xmlns:a="$a" xmlns:pic="$pic" xmlns:w14="$w14" mc:Ignorable="w14"';
}

/// The OOXML border style of a theme line style.
String docxBorderStyle(LineStyle s) => switch (s) {
  LineStyle.none => 'nil',
  LineStyle.solid => 'single',
  LineStyle.dashed => 'dashed',
  LineStyle.dotted => 'dotted',
  LineStyle.doubleLine => 'double',
};

/// A border element such as `<w:left …/>` for [b] (`nil` when invisible).
String docxBorder(String side, BorderPt? b, {double space = 0}) {
  if (b == null || !b.isVisible) return '<w:$side w:val="nil"/>';
  return '<w:$side w:val="${docxBorderStyle(b.style)}" '
      'w:sz="${OfficeUnits.eighths(b.width)}" '
      'w:space="${space.round().clamp(0, 31)}" '
      'w:color="${rgbHex(flattenAlpha(b.color))}"/>';
}

/// Shading with a solid [fill].
String docxShading(int fill) =>
    '<w:shd w:val="clear" w:color="auto" w:fill="${rgbHex(flattenAlpha(fill))}"/>';

/// Run properties (`w:rPr`), written in schema order.
final class RunProps {
  /// Run style id.
  String? style;

  /// Font family (all four slots).
  String? font;

  /// Bold.
  bool? bold;

  /// Italic.
  bool? italic;

  /// All caps.
  bool caps = false;

  /// Small caps.
  bool smallCaps = false;

  /// Strikethrough.
  bool strike = false;

  /// ARGB color.
  int? color;

  /// Letter spacing in pt.
  double? letterSpacing;

  /// Font size in pt.
  double? size;

  /// Underline (`single`).
  bool underline = false;

  /// Shading fill (ARGB).
  int? shading;

  /// Language tag (`w:lang`).
  String? lang;

  /// Sets font, size, weight, slant, color, spacing and case from [s].
  RunProps applyStyle(ResolvedTextStyle s, {bool withColor = true}) {
    font = s.fontFamily;
    size = s.fontSize;
    bold = s.fontWeight >= 600;
    italic = s.italic;
    if (withColor) color = s.color;
    letterSpacing = s.letterSpacing == 0 ? null : s.letterSpacing;
    caps = s.caseTransform == CaseTransform.uppercase;
    smallCaps = s.caseTransform == CaseTransform.smallCaps;
    return this;
  }

  /// Whether nothing is set.
  bool get isEmpty =>
      style == null &&
      font == null &&
      bold == null &&
      italic == null &&
      !caps &&
      !smallCaps &&
      !strike &&
      color == null &&
      letterSpacing == null &&
      size == null &&
      !underline &&
      shading == null &&
      lang == null;

  /// The `<w:rPr>` element (empty string when nothing is set).
  String xml() {
    if (isEmpty) return '';
    final b = StringBuffer('<w:rPr>');
    if (style != null) b.write('<w:rStyle w:val="${xmlAttr(style!)}"/>');
    if (font != null) {
      final f = xmlAttr(font!);
      b.write(
        '<w:rFonts w:ascii="$f" w:hAnsi="$f" w:eastAsia="$f" w:cs="$f"/>',
      );
    }
    if (bold != null) b.write(bold! ? '<w:b/><w:bCs/>' : '<w:b w:val="0"/>');
    if (italic != null) {
      b.write(italic! ? '<w:i/><w:iCs/>' : '<w:i w:val="0"/>');
    }
    if (caps) b.write('<w:caps/>');
    if (smallCaps) b.write('<w:smallCaps/>');
    if (strike) b.write('<w:strike/>');
    if (color != null) {
      b.write('<w:color w:val="${rgbHex(flattenAlpha(color!))}"/>');
    }
    if (letterSpacing != null) {
      b.write('<w:spacing w:val="${OfficeUnits.twips(letterSpacing!)}"/>');
    }
    if (size != null) {
      final hp = OfficeUnits.halfPoints(size!);
      b.write('<w:sz w:val="$hp"/><w:szCs w:val="$hp"/>');
    }
    if (underline) b.write('<w:u w:val="single"/>');
    if (shading != null) b.write(docxShading(shading!));
    if (lang != null) b.write('<w:lang w:val="${xmlAttr(lang!)}"/>');
    b.write('</w:rPr>');
    return b.toString();
  }
}

/// A tab stop.
typedef DocxTab = ({String kind, double positionPt});

/// Paragraph properties (`w:pPr`), written in schema order.
final class ParaProps {
  /// Paragraph style id.
  String? style;

  /// Keep with next.
  bool keepNext = false;

  /// Keep lines together.
  bool keepLines = false;

  /// Page break before.
  bool pageBreakBefore = false;

  /// Widow/orphan control.
  bool widowControl = false;

  /// Numbering (`numId`, `ilvl`).
  (int, int)? numbering;

  /// Borders: raw `<w:top …/>` … elements in order top, left, bottom,
  /// right.
  String? top, left, bottom, right;

  /// Shading fill.
  int? shading;

  /// Tab stops.
  List<DocxTab> tabs = const [];

  /// Space before (pt).
  double? spaceBefore;

  /// Space after (pt).
  double? spaceAfter;

  /// Line height multiplier (`auto` rule).
  double? lineHeight;

  /// Left indent (pt).
  double? indentLeft;

  /// Right indent (pt).
  double? indentRight;

  /// Hanging indent (pt).
  double? hanging;

  /// First-line indent (pt).
  double? firstLine;

  /// Alignment.
  ThemeAlign? align;

  /// Outline level 0–8.
  int? outlineLevel;

  /// Paragraph mark run properties.
  RunProps? markRun;

  /// The `w:jc` value of [a].
  static String jc(ThemeAlign a) => switch (a) {
    ThemeAlign.left => 'left',
    ThemeAlign.center => 'center',
    ThemeAlign.right => 'right',
    ThemeAlign.justify => 'both',
  };

  /// The `<w:pPr>` element (empty string when nothing is set).
  String xml() {
    final b = StringBuffer();
    if (style != null) b.write('<w:pStyle w:val="${xmlAttr(style!)}"/>');
    if (keepNext) b.write('<w:keepNext/>');
    if (keepLines) b.write('<w:keepLines/>');
    if (pageBreakBefore) b.write('<w:pageBreakBefore/>');
    if (widowControl) b.write('<w:widowControl/>');
    if (numbering != null) {
      b.write(
        '<w:numPr><w:ilvl w:val="${numbering!.$2}"/>'
        '<w:numId w:val="${numbering!.$1}"/></w:numPr>',
      );
    }
    if (top != null || left != null || bottom != null || right != null) {
      b.write('<w:pBdr>');
      for (final e in [top, left, bottom, right]) {
        if (e != null) b.write(e);
      }
      b.write('</w:pBdr>');
    }
    if (shading != null) b.write(docxShading(shading!));
    if (tabs.isNotEmpty) {
      b.write('<w:tabs>');
      for (final t in tabs) {
        b.write(
          '<w:tab w:val="${t.kind}" w:pos="${OfficeUnits.twips(t.positionPt)}"/>',
        );
      }
      b.write('</w:tabs>');
    }
    if (spaceBefore != null || spaceAfter != null || lineHeight != null) {
      b.write('<w:spacing');
      if (spaceBefore != null) {
        b.write(' w:before="${OfficeUnits.twips(spaceBefore!)}"');
      }
      if (spaceAfter != null) {
        b.write(' w:after="${OfficeUnits.twips(spaceAfter!)}"');
      }
      if (lineHeight != null) {
        b.write(' w:line="${(lineHeight! * 240).round()}" w:lineRule="auto"');
      }
      b.write('/>');
    }
    if (indentLeft != null ||
        indentRight != null ||
        hanging != null ||
        firstLine != null) {
      b.write('<w:ind');
      if (indentLeft != null) {
        b.write(' w:left="${OfficeUnits.twips(indentLeft!)}"');
      }
      if (indentRight != null) {
        b.write(' w:right="${OfficeUnits.twips(indentRight!)}"');
      }
      if (hanging != null) {
        b.write(' w:hanging="${OfficeUnits.twips(hanging!)}"');
      } else if (firstLine != null) {
        b.write(' w:firstLine="${OfficeUnits.twips(firstLine!)}"');
      }
      b.write('/>');
    }
    if (align != null) b.write('<w:jc w:val="${jc(align!)}"/>');
    if (outlineLevel != null) b.write('<w:outlineLvl w:val="$outlineLevel"/>');
    final mark = markRun?.xml() ?? '';
    b.write(mark);
    return b.isEmpty ? '' : '<w:pPr>$b</w:pPr>';
  }
}
