import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import 'pdf_fonts.dart';

/// The bundled static TTF set of Sheets PDFs (11 §7.4), shared by the app
/// (`assets/fonts/`) and the server (`web/fonts/`) so both embed the same
/// faces and the same family mapping (client and server PDFs match, 11
/// acceptance 9): Roboto, Lato, Source Sans 3 (`WonkySansThree-*.ttf`,
/// static instances of the variable font), Nunito, Montserrat, Merriweather
/// and Roboto Mono as themselves, Open Sans for every other sans family
/// (incl. Inter/Geist, whose variable faces the PDF writer can't instance),
/// EB Garamond for serif and JetBrains Mono for mono families (Courier
/// Prime, Courier New …).
abstract final class BundledPdfFonts {
  static const sans = 'Open Sans';
  static const serif = 'EB Garamond';
  static const mono = 'JetBrains Mono';
  static const roboto = 'Roboto';
  static const lato = 'Lato';
  static const robotoMono = 'Roboto Mono';
  static const sourceSans3 = 'Source Sans 3';
  static const nunito = 'Nunito';
  static const montserrat = 'Montserrat';
  static const merriweather = 'Merriweather';

  /// Regular, bold, italic, bold-italic file of each PDF family.
  static const files = <String, List<String>>{
    sans: [
      'OpenSans-Regular.ttf',
      'OpenSans-Bold.ttf',
      'OpenSans-Italic.ttf',
      'OpenSans-BoldItalic.ttf',
    ],
    serif: [
      'EBGaramond-Regular.ttf',
      'EBGaramond-Bold.ttf',
      'EBGaramond-Italic.ttf',
      'EBGaramond-BoldItalic.ttf',
    ],
    mono: [
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Bold.ttf',
      'JetBrainsMono-Italic.ttf',
      'JetBrainsMono-BoldItalic.ttf',
    ],
    roboto: [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Italic.ttf',
      'Roboto-BoldItalic.ttf',
    ],
    lato: [
      'Lato-Regular.ttf',
      'Lato-Bold.ttf',
      'Lato-Italic.ttf',
      'Lato-BoldItalic.ttf',
    ],
    sourceSans3: [
      'WonkySansThree-Regular.ttf',
      'WonkySansThree-Bold.ttf',
      'WonkySansThree-Italic.ttf',
      'WonkySansThree-BoldItalic.ttf',
    ],
    nunito: [
      'Nunito-Regular.ttf',
      'Nunito-Bold.ttf',
      'Nunito-Italic.ttf',
      'Nunito-BoldItalic.ttf',
    ],
    montserrat: [
      'Montserrat-Regular.ttf',
      'Montserrat-Bold.ttf',
      'Montserrat-Italic.ttf',
      'Montserrat-BoldItalic.ttf',
    ],
    merriweather: [
      'Merriweather-Regular.ttf',
      'Merriweather-Bold.ttf',
      'Merriweather-Italic.ttf',
      'Merriweather-BoldItalic.ttf',
    ],
    // No italic faces: the upright ones are used.
    robotoMono: [
      'RobotoMono-Regular.ttf',
      'RobotoMono-Bold.ttf',
      'RobotoMono-Regular.ttf',
      'RobotoMono-Bold.ttf',
    ],
  };

  /// Geometric and rounded sans families (shown with Lato on the grid).
  static const _geometric = {
    'nunito sans',
    'poppins',
    'raleway',
    'quicksand',
    'work sans',
    'century gothic',
    'futura',
    'avenir',
    'gill sans',
    'trebuchet ms',
  };

  static const _serif = {
    'lora',
    'playfair display',
    'noto serif',
    'tinos',
    'caladea',
    'gelasio',
    'times new roman',
    'times',
    'georgia',
    'cambria',
    'garamond',
    'eb garamond',
    'book antiqua',
    'palatino',
    'palatino linotype',
  };

  static const _mono = {
    'roboto mono',
    'source code pro',
    'courier prime',
    'cousine',
    'courier new',
    'courier',
    'consolas',
    'menlo',
    'monaco',
    'jetbrains mono',
    'geist mono',
    'lucida console',
  };

  /// Families embedded as themselves, by lower-case name.
  static const _asThemselves = {
    'roboto': roboto,
    'lato': lato,
    'roboto mono': robotoMono,
    'source sans 3': sourceSans3,
    'nunito': nunito,
    'montserrat': montserrat,
    'merriweather': merriweather,
  };

  /// The PDF family of a cell font family (the grid's display family,
  /// mapped onto the static faces above).
  static String pdfFamily(String family) {
    switch (family) {
      case roboto ||
          lato ||
          robotoMono ||
          sourceSans3 ||
          nunito ||
          montserrat ||
          merriweather:
        return family;
      case serif:
        return serif;
      case mono || 'Geist Mono':
        return mono;
      case 'Inter' || 'Geist' || sans:
        return sans;
    }
    final l = family.toLowerCase().trim();
    final named = _asThemselves[l];
    if (named != null) return named;
    if (l == 'source sans pro') return sourceSans3;
    if (_mono.contains(l) || l.contains('mono') || l.contains('courier')) {
      return mono;
    }
    if (_serif.contains(l) || (l.contains('serif') && !l.contains('sans'))) {
      return serif;
    }
    if (_geometric.contains(l)) return lato;
    if (l.startsWith('roboto')) return roboto;
    return sans;
  }

  /// Loads the families with [read] (a file name → its bytes, null when
  /// missing). Families without a regular face are left out; with none the
  /// standard PDF fonts are used.
  static Future<PdfFontProvider> load(
    Future<ByteData?> Function(String file) read,
  ) async {
    final families = <String, TtfFontFamily>{};
    for (final e in files.entries) {
      final f = e.value;
      final regular = await read(f[0]);
      if (regular == null) continue;
      families[e.key] = TtfFontFamily(
        regular: regular,
        bold: await read(f[1]),
        italic: await read(f[2]),
        boldItalic: await read(f[3]),
      );
    }
    if (families.isEmpty) return const BuiltInPdfFontProvider();
    return MappedPdfFontProvider(
      TtfPdfFontProvider(
        families: families,
        defaultFamily: families.containsKey(sans) ? sans : families.keys.first,
      ),
    );
  }
}

/// A provider that maps cell families with [BundledPdfFonts.pdfFamily]
/// before asking [inner].
final class MappedPdfFontProvider implements PdfFontProvider {
  /// Wraps [inner].
  const MappedPdfFontProvider(this.inner);

  final PdfFontProvider inner;

  @override
  PdfFont font(
    PdfDocument doc,
    String family, {
    bool bold = false,
    bool italic = false,
  }) => inner.font(
    doc,
    BundledPdfFonts.pdfFamily(family),
    bold: bold,
    italic: italic,
  );

  @override
  List<PdfFont> fallbacks(
    PdfDocument doc, {
    bool bold = false,
    bool italic = false,
  }) => inner.fallbacks(doc, bold: bold, italic: italic);
}
