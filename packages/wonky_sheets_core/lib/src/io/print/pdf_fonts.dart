import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import 'cell_text_layout.dart';

/// Supplies `pdf` fonts for cell fonts (11 §7.4). Fonts belong to one
/// [PdfDocument]; providers cache them per document.
abstract interface class PdfFontProvider {
  /// The font for [family] (as stored in the cell; substitution is the
  /// provider's job) in [doc].
  PdfFont font(
    PdfDocument doc,
    String family, {
    bool bold = false,
    bool italic = false,
  });

  /// Fonts tried per glyph, in order, when [font] lacks a glyph (fallback
  /// chain: Noto Sans → Noto Sans Symbols → CJK …).
  List<PdfFont> fallbacks(
    PdfDocument doc, {
    bool bold = false,
    bool italic = false,
  });
}

/// Regular/bold/italic/bold-italic TTF data of one family.
final class TtfFontFamily {
  /// Creates a family; missing variants fall back to [regular].
  const TtfFontFamily({
    required this.regular,
    this.bold,
    this.italic,
    this.boldItalic,
  });

  final ByteData regular;
  final ByteData? bold;
  final ByteData? italic;
  final ByteData? boldItalic;

  /// The data for a variant.
  ByteData variant({bool bold = false, bool italic = false}) {
    if (bold && italic) {
      return boldItalic ?? this.bold ?? this.italic ?? regular;
    }
    if (bold) return this.bold ?? regular;
    if (italic) return this.italic ?? regular;
    return regular;
  }
}

/// Cell font substitution for names that aren't bundled (06 §6.1).
abstract final class CellFontSubstitution {
  static const Map<String, String> map = {
    'arial': 'Arimo',
    'helvetica': 'Arimo',
    'helvetica neue': 'Arimo',
    'times new roman': 'Tinos',
    'times': 'Tinos',
    'courier new': 'Cousine',
    'courier': 'Cousine',
    'calibri': 'Carlito',
    'cambria': 'Caladea',
    'georgia': 'Gelasio',
    'verdana': 'Inter',
    'tahoma': 'Inter',
    'segoe ui': 'Inter',
  };

  /// The bundled family [family] is rendered with (unknown → [fallback]).
  static String resolve(
    String family,
    Set<String> available, {
    String fallback = 'Inter',
  }) {
    if (available.contains(family)) return family;
    final lower = family.toLowerCase();
    for (final a in available) {
      if (a.toLowerCase() == lower) return a;
    }
    final sub = map[lower];
    if (sub != null && available.contains(sub)) return sub;
    return fallback;
  }
}

final Expando<Map<String, PdfFont>> _docFonts = Expando('wonky-pdf-fonts');

Map<String, PdfFont> _cacheFor(PdfDocument doc) =>
    _docFonts[doc] ??= <String, PdfFont>{};

/// The 14 standard PDF fonts: monospace families → Courier, serif families →
/// Times, others → Helvetica. Latin-1 only (other glyphs need TTF fonts).
final class BuiltInPdfFontProvider implements PdfFontProvider {
  /// Creates the provider.
  const BuiltInPdfFontProvider();

  static const _mono = {
    'roboto mono',
    'source code pro',
    'courier prime',
    'cousine',
    'courier new',
    'courier',
    'consolas',
    'monaco',
    'menlo',
    'monospace',
  };
  static const _serif = {
    'merriweather',
    'lora',
    'playfair display',
    'noto serif',
    'tinos',
    'times new roman',
    'times',
    'caladea',
    'cambria',
    'gelasio',
    'georgia',
    'garamond',
    'serif',
  };

  /// `helvetica`, `times` or `courier` for a cell family.
  static String baseFamily(String family) {
    final l = family.toLowerCase();
    if (_mono.contains(l)) return 'courier';
    if (_serif.contains(l)) return 'times';
    return 'helvetica';
  }

  @override
  PdfFont font(
    PdfDocument doc,
    String family, {
    bool bold = false,
    bool italic = false,
  }) {
    final base = baseFamily(family);
    final key = 'builtin:$base:$bold:$italic';
    return _cacheFor(doc).putIfAbsent(key, () {
      switch (base) {
        case 'courier':
          if (bold && italic) return PdfFont.courierBoldOblique(doc);
          if (bold) return PdfFont.courierBold(doc);
          if (italic) return PdfFont.courierOblique(doc);
          return PdfFont.courier(doc);
        case 'times':
          if (bold && italic) return PdfFont.timesBoldItalic(doc);
          if (bold) return PdfFont.timesBold(doc);
          if (italic) return PdfFont.timesItalic(doc);
          return PdfFont.times(doc);
        default:
          if (bold && italic) return PdfFont.helveticaBoldOblique(doc);
          if (bold) return PdfFont.helveticaBold(doc);
          if (italic) return PdfFont.helveticaOblique(doc);
          return PdfFont.helvetica(doc);
      }
    });
  }

  @override
  List<PdfFont> fallbacks(
    PdfDocument doc, {
    bool bold = false,
    bool italic = false,
  }) => const [];
}

/// Bundled TTF fonts (apps and the server pass the curated cell fonts).
/// Unknown families are substituted (06 §6.1), then [defaultFamily]; when
/// no TTF is available the [base] provider is used.
final class TtfPdfFontProvider implements PdfFontProvider {
  /// Creates the provider.
  TtfPdfFontProvider({
    required this.families,
    this.defaultFamily = 'Inter',
    this.fallbackFamilies = const [],
    this.base = const BuiltInPdfFontProvider(),
  });

  /// Families by name.
  final Map<String, TtfFontFamily> families;
  final String defaultFamily;

  /// Glyph fallback chain (e.g. Noto Sans, Noto Sans Symbols, CJK).
  final List<TtfFontFamily> fallbackFamilies;
  final PdfFontProvider base;

  @override
  PdfFont font(
    PdfDocument doc,
    String family, {
    bool bold = false,
    bool italic = false,
  }) {
    final name = CellFontSubstitution.resolve(
      family,
      families.keys.toSet(),
      fallback: defaultFamily,
    );
    final fam = families[name];
    if (fam == null) return base.font(doc, family, bold: bold, italic: italic);
    return _cacheFor(doc).putIfAbsent(
      'ttf:$name:$bold:$italic',
      () => PdfTtfFont(doc, fam.variant(bold: bold, italic: italic)),
    );
  }

  @override
  List<PdfFont> fallbacks(
    PdfDocument doc, {
    bool bold = false,
    bool italic = false,
  }) => [
    for (var i = 0; i < fallbackFamilies.length; i++)
      _cacheFor(doc).putIfAbsent(
        'ttf-fallback:$i:$bold:$italic',
        () => PdfTtfFont(
          doc,
          fallbackFamilies[i].variant(bold: bold, italic: italic),
        ),
      ),
  ];
}

/// A run of text drawn with one font.
typedef PdfFontRun = ({PdfFont font, String text});

/// Splits text into font runs with per-glyph fallback; glyphs no font
/// supports become `?` (or are dropped when even `?` is unsupported).
abstract final class PdfGlyphRuns {
  /// Font runs of [text].
  static List<PdfFontRun> split(
    String text,
    PdfFont primary,
    List<PdfFont> fallbacks,
  ) {
    final out = <PdfFontRun>[];
    PdfFont? curFont;
    final cur = StringBuffer();
    void emit(PdfFont f, int rune) {
      if (!identical(f, curFont) && cur.isNotEmpty) {
        out.add((font: curFont!, text: cur.toString()));
        cur.clear();
      }
      curFont = f;
      cur.writeCharCode(rune);
    }

    for (var r in text.runes) {
      if (r == 0x09 ||
          r == 0x0a ||
          r == 0x0d ||
          r == 0xa0 ||
          r == 0x2007 ||
          r == 0x2009 ||
          r == 0x202f) {
        r = 0x20;
      }
      if (r < 0x20) continue;
      final own = _code(primary, r);
      if (own != null) {
        emit(primary, own);
        continue;
      }
      PdfFont? fb;
      int? code;
      for (final f in fallbacks) {
        code = _code(f, r);
        if (code != null) {
          fb = f;
          break;
        }
      }
      if (fb != null) {
        emit(fb, code!);
      } else if (_code(primary, 0x3f) != null) {
        emit(primary, 0x3f);
      }
    }
    if (cur.isNotEmpty) out.add((font: curFont!, text: cur.toString()));
    return out;
  }

  /// WinAnsi (Windows-1252) bytes 0x80–0x9F of the standard PDF fonts by
  /// Unicode code point.
  static const Map<int, int> _winAnsi = {
    0x20ac: 0x80,
    0x201a: 0x82,
    0x0192: 0x83,
    0x201e: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02c6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8a,
    0x2039: 0x8b,
    0x0152: 0x8c,
    0x017d: 0x8e,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201c: 0x93,
    0x201d: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02dc: 0x98,
    0x2122: 0x99,
    0x0161: 0x9a,
    0x203a: 0x9b,
    0x0153: 0x9c,
    0x017e: 0x9e,
    0x0178: 0x9f,
  };

  /// The character code [f] draws [rune] with, or null when unsupported.
  /// Standard fonts use WinAnsi: Latin-1 plus the 0x80–0x9F extras.
  static int? _code(PdfFont f, int rune) {
    if (f is PdfTtfFont) return f.isRuneSupported(rune) ? rune : null;
    if ((rune >= 0x20 && rune < 0x7f) || (rune >= 0xa0 && rune <= 0xff)) {
      return rune;
    }
    return _winAnsi[rune];
  }
}

/// [CellTextMeasurer] over `pdf` font metrics (sizes and widths in points),
/// using the same fonts and glyph fallback as [SheetsPdfRenderer].
final class PdfFontMeasurer implements CellTextMeasurer {
  /// Creates a measurer for fonts of [provider] in [doc] (a private metrics
  /// document when omitted).
  PdfFontMeasurer(this.provider, [PdfDocument? doc])
    : doc = doc ?? PdfDocument();

  final PdfFontProvider provider;
  final PdfDocument doc;
  final Map<(String, CellTextStyle), double> _cache = {};

  /// The primary font of [style].
  PdfFont fontOf(CellTextStyle style) =>
      provider.font(doc, style.family, bold: style.bold, italic: style.italic);

  /// Font runs of [text] in [style].
  List<PdfFontRun> runs(String text, CellTextStyle style) => PdfGlyphRuns.split(
    text,
    fontOf(style),
    provider.fallbacks(doc, bold: style.bold, italic: style.italic),
  );

  @override
  double width(String text, CellTextStyle style) {
    if (text.isEmpty) return 0;
    if (text.length <= 2) {
      return _cache.putIfAbsent((text, style), () => _measure(text, style));
    }
    return _measure(text, style);
  }

  double _measure(String text, CellTextStyle style) {
    var w = 0.0;
    for (final run in runs(text, style)) {
      w += run.font.stringMetrics(run.text).advanceWidth * style.size;
    }
    return w;
  }

  @override
  double ascent(CellTextStyle style) => fontOf(style).ascent.abs() * style.size;

  @override
  double descent(CellTextStyle style) =>
      fontOf(style).descent.abs() * style.size;

  @override
  double lineHeight(CellTextStyle style) {
    final f = fontOf(style);
    return (f.ascent.abs() + f.descent.abs()) * 1.15 * style.size;
  }
}
