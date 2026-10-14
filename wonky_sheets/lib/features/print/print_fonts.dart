import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' show PdfDocument, PdfFont;
import 'package:wonky_sheets_core/model.dart';

import '../formatting/cell_fonts.dart';

/// PDF fonts of the client (11 §7.4): the bundled static TTFs (Roboto,
/// Lato and Roboto Mono as themselves, Open Sans for the other sans
/// families incl. Inter/Geist whose variable faces the PDF writer can't
/// instance, EB Garamond for serif, JetBrains Mono for mono), the same
/// faces the preview paints with — so preview and PDF share metrics.
/// Without the assets (tests) the standard PDF fonts are used.
class SheetsPdfFonts implements PdfFontProvider {
  SheetsPdfFonts._(this._ttf);

  final PdfFontProvider _ttf;

  static const sans = CellFonts.openSans;
  static const serif = CellFonts.ebGaramond;
  static const mono = CellFonts.jetBrainsMono;

  static Future<SheetsPdfFonts>? _instance;

  /// Loads the fonts once (falls back to the built-in PDF fonts).
  static Future<SheetsPdfFonts> load() => _instance ??= _load();

  static Future<SheetsPdfFonts> _load() async {
    Future<ByteData?> asset(String f) async {
      try {
        return await rootBundle.load('assets/fonts/$f');
      } catch (_) {
        return null;
      }
    }

    Future<TtfFontFamily?> family(
      String regular,
      String bold,
      String italic,
      String boldItalic,
    ) async {
      final r = await asset(regular);
      if (r == null) return null;
      return TtfFontFamily(
        regular: r,
        bold: await asset(bold),
        italic: await asset(italic),
        boldItalic: await asset(boldItalic),
      );
    }

    final families = <String, TtfFontFamily>{
      sans: ?await family(
        'OpenSans-Regular.ttf',
        'OpenSans-Bold.ttf',
        'OpenSans-Italic.ttf',
        'OpenSans-BoldItalic.ttf',
      ),
      serif: ?await family(
        'EBGaramond-Regular.ttf',
        'EBGaramond-Bold.ttf',
        'EBGaramond-Italic.ttf',
        'EBGaramond-BoldItalic.ttf',
      ),
      mono: ?await family(
        'JetBrainsMono-Regular.ttf',
        'JetBrainsMono-Bold.ttf',
        'JetBrainsMono-Italic.ttf',
        'JetBrainsMono-BoldItalic.ttf',
      ),
      CellFonts.roboto: ?await family(
        'Roboto-Regular.ttf',
        'Roboto-Bold.ttf',
        'Roboto-Italic.ttf',
        'Roboto-BoldItalic.ttf',
      ),
      CellFonts.lato: ?await family(
        'Lato-Regular.ttf',
        'Lato-Bold.ttf',
        'Lato-Italic.ttf',
        'Lato-BoldItalic.ttf',
      ),
      CellFonts.robotoMono: ?await family(
        'RobotoMono-Regular.ttf',
        'RobotoMono-Bold.ttf',
        'RobotoMono-Regular.ttf',
        'RobotoMono-Bold.ttf',
      ),
    };
    if (families.isEmpty) {
      return SheetsPdfFonts._(const BuiltInPdfFontProvider());
    }
    await Future.wait([
      for (final f in families.keys) CellFonts.ensureLoaded(f),
    ]);
    return SheetsPdfFonts._(
      TtfPdfFontProvider(
        families: families,
        defaultFamily: families.containsKey(sans) ? sans : families.keys.first,
      ),
    );
  }

  /// The PDF family of a cell family: the static bundled families as
  /// themselves, others serif/mono by category, every other family sans.
  static String pdfFamily(String family) {
    final shown = CellFonts.displayFamily(family);
    return switch (shown) {
      CellFonts.roboto || CellFonts.lato || CellFonts.robotoMono => shown,
      CellFonts.ebGaramond => serif,
      CellFonts.jetBrainsMono || CellFonts.geistMono => mono,
      _ => sans,
    };
  }

  /// The Flutter family the preview paints [family] with (the PDF face).
  static String screenFamily(String family) =>
      CellFonts.screenFamily(pdfFamily(family));

  @override
  PdfFont font(
    PdfDocument doc,
    String family, {
    bool bold = false,
    bool italic = false,
  }) => _ttf.font(doc, pdfFamily(family), bold: bold, italic: italic);

  @override
  List<PdfFont> fallbacks(
    PdfDocument doc, {
    bool bold = false,
    bool italic = false,
  }) => _ttf.fallbacks(doc, bold: bold, italic: italic);
}
