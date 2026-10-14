import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import 'support/print_support.dart';

final _now = DateTime.utc(2026, 10, 14, 9, 30);

Future<String> _pdf(WorkbookModel m, {bool dark = false}) async =>
    latin1.decode(
      await SheetsPdfRenderer.render(
        m,
        ModelCellSource(m),
        Paginator.paginate(m, const PrintJob()),
        now: _now,
        compress: false,
        darkTheme: dark,
      ),
    );

/// A fill color operator of the dark page background (#1F1F1F).
final _darkPage = RegExp(r'0\.12\d* 0\.12\d* 0\.12\d* rg');

/// The dark theme's automatic text color (#E8EAED).
final _lightText = RegExp(r'0\.909\d* 0\.917\d* 0\.929\d* rg');

void main() {
  group('Given a number grid exported as PDF', () {
    late WorkbookModel m;
    setUp(() => (_, m) = numberGrid());

    test('when the dark theme is off then pages have no background and '
        'text is black', () async {
      final pdf = await _pdf(m);

      expect(_darkPage.hasMatch(pdf), isFalse);
      expect(_lightText.hasMatch(pdf), isFalse);
    });

    test('when the dark theme is on then every page gets the dark '
        'background and automatic text is light', () async {
      final pdf = await _pdf(m, dark: true);

      final pages = '/Type/Page/'.allMatches(pdf).length;
      expect(_darkPage.allMatches(pdf).length, greaterThanOrEqualTo(pages));
      expect(_lightText.hasMatch(pdf), isTrue);
    });
  });

  group('Given the bundled PDF font set', () {
    test('when mapping cell families then client and server use the same '
        'static faces', () {
      const cases = {
        'Roboto': 'Roboto',
        'Lato': 'Lato',
        'Roboto Mono': 'Roboto Mono',
        'Inter': 'Open Sans',
        'Geist': 'Open Sans',
        'Arial': 'Open Sans',
        'Open Sans': 'Open Sans',
        'EB Garamond': 'EB Garamond',
        'Georgia': 'EB Garamond',
        'Noto Serif': 'EB Garamond',
        'Courier New': 'JetBrains Mono',
        'Geist Mono': 'JetBrains Mono',
        'Montserrat': 'Montserrat',
        'montserrat': 'Montserrat',
        'Nunito': 'Nunito',
        'Merriweather': 'Merriweather',
        'Source Sans 3': 'Source Sans 3',
        'Source Sans Pro': 'Source Sans 3',
        'Poppins': 'Lato',
        'Lora': 'EB Garamond',
        'Courier Prime': 'JetBrains Mono',
        'Roboto Condensed': 'Roboto',
      };
      cases.forEach((family, pdf) {
        expect(BundledPdfFonts.pdfFamily(family), pdf, reason: family);
      });
    });

    test('when no font files are found then the standard PDF fonts are '
        'used', () async {
      final p = await BundledPdfFonts.load((_) async => null);

      expect(p, isA<BuiltInPdfFontProvider>());
    });
  });
}
