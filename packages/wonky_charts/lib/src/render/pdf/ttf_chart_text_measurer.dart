import 'dart:typed_data';

import 'package:pdf/pdf.dart' show TtfParser;

import '../../layout/text_measurer.dart';
import '../../scene/scene.dart';

/// The metrics of one TrueType face for chart layout, parsed with the `pdf` package's
/// [TtfParser] (no `PdfDocument` needed).
final class TtfChartFace {
  /// Parses [bytes] (a static TrueType face).
  TtfChartFace(Uint8List bytes)
    : _parser = TtfParser(ByteData.sublistView(bytes));

  final TtfParser _parser;

  /// Above the baseline in em (positive).
  double get ascent => _parser.ascent / _parser.unitsPerEm;

  /// Below the baseline in em (negative, as in the font).
  double get descent => _parser.descent / _parser.unitsPerEm;

  /// Whether the face has a glyph for [rune].
  bool supports(int rune) => _parser.charToGlyphIndexMap.containsKey(rune);

  /// The advance of [rune] in em (0 without a glyph).
  double advance(int rune) {
    final g = _parser.charToGlyphIndexMap[rune];
    if (g == null) return 0;
    return _parser.glyphInfoMap[g]?.advanceWidth ?? 0;
  }
}

/// The four faces of one family; missing styles fall back to [regular] (like the PDF
/// renderer with embedded fonts).
final class TtfChartFamily {
  /// Creates a family.
  const TtfChartFamily(this.regular, {this.bold, this.italic, this.boldItalic});

  final TtfChartFace regular;
  final TtfChartFace? bold;
  final TtfChartFace? italic;
  final TtfChartFace? boldItalic;

  /// The face of a bold/italic combination.
  TtfChartFace pick(bool isBold, bool isItalic) {
    if (isBold && isItalic) return boldItalic ?? bold ?? italic ?? regular;
    if (isBold) return bold ?? regular;
    if (isItalic) return italic ?? regular;
    return regular;
  }
}

/// A [TextMeasurer] from TTF bytes (Slides 08 §12, §2.7 `TtfTextMeasurer`): charts drawn into
/// a PDF with an embedded deck font are laid out with exactly the advances the PDF draws
/// (`PdfChartRenderer` with `PdfTtfFont`s of the same bytes): characters the face can't show
/// measure like the `?` they are drawn as, line height = ascent − descent.
///
/// [families] are looked up by `TextStyleSpec.family` (case-insensitive); other families use
/// [defaultFamily]. Pure Dart: works on the server and the web.
///
/// (Named `TtfChartTextMeasurer` because the Slides core's text layout already has a
/// `TtfTextMeasurer`.)
final class TtfChartTextMeasurer implements TextMeasurer {
  /// Creates a measurer.
  TtfChartTextMeasurer(
    this.defaultFamily, {
    Map<String, TtfChartFamily> families = const {},
  }) : _families = {
         for (final e in families.entries) e.key.toLowerCase(): e.value,
       };

  /// A measurer over one family from raw bytes.
  factory TtfChartTextMeasurer.fromBytes(
    Uint8List regular, {
    Uint8List? bold,
    Uint8List? italic,
    Uint8List? boldItalic,
  }) => TtfChartTextMeasurer(
    TtfChartFamily(
      TtfChartFace(regular),
      bold: bold == null ? null : TtfChartFace(bold),
      italic: italic == null ? null : TtfChartFace(italic),
      boldItalic: boldItalic == null ? null : TtfChartFace(boldItalic),
    ),
  );

  final TtfChartFamily defaultFamily;
  final Map<String, TtfChartFamily> _families;

  @override
  TextMetrics measure(String text, TextStyleSpec style) {
    final size = style.size > 0 ? style.size : 0.0;
    final family =
        (style.family == null
            ? null
            : _families[style.family!.toLowerCase()]) ??
        defaultFamily;
    final face = family.pick(style.bold, style.italic);
    var em = 0.0;
    for (final r in text.runes) {
      if (r == 0x0A || r == 0x0D || r == 0x09) {
        em += face.advance(0x20);
      } else if (r < 0x20 || r == 0x7F) {
        continue;
      } else {
        em += face.supports(r) ? face.advance(r) : face.advance(0x3F);
      }
    }
    return TextMetrics(
      em * size,
      (face.ascent - face.descent) * size,
      face.ascent * size,
    );
  }
}
