import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/io/print/print.dart';

void main() {
  group('Given the standard PDF fonts', () {
    late PdfDocument doc;
    late PdfFont helvetica;
    setUp(() {
      doc = PdfDocument();
      helvetica = const BuiltInPdfFontProvider().font(doc, 'Inter');
    });

    const cases = [
      ('Plain ASCII', 'Plain ASCII'),
      ('Café €5 – “quoted”', 'Café \x805 \x96 \x93quoted\x94'),
      ('tab\tand\nbreak', 'tab and break'),
      ('漢字 ok', '?? ok'),
      ('9:30 AM', '9:30 AM'),
    ];
    for (final (input, expected) in cases) {
      test('when splitting "$input" then the run text is WinAnsi', () {
        final runs = PdfGlyphRuns.split(input, helvetica, const []);
        expect(runs.map((r) => r.text).join(), expected);
        expect(runs.every((r) => identical(r.font, helvetica)), isTrue);
      });
    }

    test('when measuring then widths come from the font metrics', () {
      final m = PdfFontMeasurer(const BuiltInPdfFontProvider(), doc);
      const style = CellTextStyle(family: 'Arial', size: 10);
      expect(m.width('ii', style), closeTo(2 * 0.222 * 10, 1e-9));
      expect(
        m.width('€', style),
        closeTo(helvetica.stringMetrics('\x80').advanceWidth * 10, 1e-9),
      );
      expect(m.lineHeight(style), greaterThan(10));
    });
  });

  group('Given cell font families', () {
    for (final (family, base) in [
      ('Roboto Mono', 'courier'),
      ('Merriweather', 'times'),
      ('Georgia', 'times'),
      ('Inter', 'helvetica'),
      ('Unknown Font', 'helvetica'),
    ]) {
      test('when choosing a standard font for $family then it is $base', () {
        expect(BuiltInPdfFontProvider.baseFamily(family), base);
      });
    }

    for (final (family, expected) in [
      ('Arial', 'Arimo'),
      ('times new roman', 'Tinos'),
      ('roboto', 'Roboto'),
      ('Comic Sans MS', 'Inter'),
    ]) {
      test('when substituting $family then $expected is used', () {
        expect(
          CellFontSubstitution.resolve(family, {
            'Arimo',
            'Tinos',
            'Roboto',
            'Inter',
          }),
          expected,
        );
      });
    }
  });
}
