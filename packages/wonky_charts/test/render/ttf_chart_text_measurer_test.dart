import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

/// A bundled font of `wonky_fonts` (tests run in the package folder).
Uint8List font(String name) =>
    File('../wonky_fonts/fonts/$name').readAsBytesSync();

void main() {
  group('Given the TTF bytes of a deck font', () {
    final regular = font('Lato-Regular.ttf');
    final bold = font('Lato-Bold.ttf');
    final measurer = TtfChartTextMeasurer.fromBytes(regular, bold: bold);
    final doc = PdfDocument();
    final pdfRegular = PdfTtfFont(doc, ByteData.sublistView(regular));
    final pdfBold = PdfTtfFont(doc, ByteData.sublistView(bold));

    for (final text in ['Revenue by region', 'Q3 2026: 1,234.5 €', 'Äpfel']) {
      test('when measuring "$text" then the width equals the PDF font\'s', () {
        const style = TextStyleSpec(size: 13);
        expect(
          measurer.measure(text, style).width,
          closeTo(pdfRegular.stringMetrics(text).advanceWidth * 13, 1e-9),
        );
        expect(
          measurer.measure(text, style.copyWith(bold: true)).width,
          closeTo(pdfBold.stringMetrics(text).advanceWidth * 13, 1e-9),
        );
      });
    }

    test('when measuring then the line metrics match the PDF measurer', () {
      final pdf = PdfTextMeasurer(font: pdfRegular, boldFont: pdfBold);
      const style = TextStyleSpec(size: 20);
      final a = measurer.measure('Hello', style);
      final b = pdf.measure('Hello', style);
      expect(a.width, closeTo(b.width, 1e-9));
      expect(a.height, closeTo(b.height, 1e-9));
      expect(a.ascent, closeTo(b.ascent, 1e-9));
    });

    test('when a character is missing then it measures like "?"', () {
      const style = TextStyleSpec(size: 10);
      expect(
        measurer.measure('\u{1F600}', style).width,
        measurer.measure('?', style).width,
      );
    });

    test('when a family is registered then it is picked by name', () {
      final mono = TtfChartFamily(
        TtfChartFace(font('JetBrainsMono-Regular.ttf')),
      );
      final m = TtfChartTextMeasurer(
        TtfChartFamily(TtfChartFace(regular)),
        families: {'JetBrains Mono': mono},
      );
      const style = TextStyleSpec(size: 10, family: 'jetbrains mono');
      expect(m.measure('iii', style).width, m.measure('MMM', style).width);
    });
  });
}
