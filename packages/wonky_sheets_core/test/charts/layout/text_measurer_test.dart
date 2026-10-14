import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/charts.dart';

void main() {
  const style = TextStyleSpec(size: 10);
  const m = ApproxTextMeasurer();

  group('Given the approximate measurer', () {
    test('when measuring "Ag" at 10 px then the Helvetica widths are used', () {
      final r = m.measure('Ag', style);

      expect(r.width, closeTo(6.67 + 5.56, 1e-9));
      expect(r.height, closeTo(11.7, 1e-9));
      expect(r.ascent, closeTo(9.3, 1e-9));
    });

    test('when measuring bold text then it is wider', () {
      expect(
        m.measure('Total', style.copyWith(bold: true)).width,
        greaterThan(m.measure('Total', style).width),
      );
    });

    test('when measuring CJK text then each character is one em', () {
      expect(m.measure('漢字', style).width, 20);
    });
  });

  group('Given ellipsizing', () {
    test('when the text fits then it is unchanged', () {
      expect(m.ellipsize('Short', style, 100), 'Short');
    });

    test(
      'when the text is too wide then it is cut with an ellipsis that fits',
      () {
        final s = m.ellipsize('A rather long legend label', style, 60);

        expect(s, endsWith('…'));
        expect(m.measure(s, style).width, lessThanOrEqualTo(60));
        expect(s.length, greaterThan(3));
      },
    );

    test('when not even the ellipsis fits then the result is empty', () {
      expect(m.ellipsize('Label', style, 2), '');
    });
  });

  group('Given the export measurers', () {
    test(
      'when measuring with the PDF Helvetica metrics then widths match the font',
      () {
        final pdf = PdfTextMeasurer();

        final r = pdf.measure('Ag', style);

        expect(r.width, closeTo(12.23, 0.05));
        expect(r.ascent, greaterThan(0));
        expect(r.height, greaterThan(r.ascent));
      },
    );

    test(
      'when measuring with the raster metrics then longer text is wider',
      () {
        const raster = RasterTextMeasurer();

        expect(
          raster.measure('Revenue', style).width,
          greaterThan(raster.measure('Rev', style).width),
        );
        expect(raster.measure('', style).width, 0);
      },
    );
  });
}
