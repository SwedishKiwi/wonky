import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/render/render.dart';
import 'package:wonky_sheets_core/src/charts/scene/geometry.dart';
import 'package:wonky_sheets_core/src/charts/scene/scene.dart';

import 'render_test_scenes.dart';

Future<String> _uncompressed(ChartScene scene, {double margin = 36}) async =>
    latin1.decode(
      await const PdfChartRenderer().renderDocument(
        scene,
        margin: margin,
        compress: false,
      ),
    );

void main() {
  group('Given the kitchen-sink scene', () {
    final scene = RenderTestScenes.kitchenSink();

    test('when rendering a document then the bytes are a PDF file', () async {
      final bytes = await const PdfChartRenderer().renderDocument(scene);

      expect(latin1.decode(bytes.sublist(0, 5)), equals('%PDF-'));
      expect(
        latin1.decode(bytes.sublist(bytes.length - 8)).trim(),
        endsWith('%%EOF'),
      );
      expect(bytes.length, inInclusiveRange(1000, 200000));
    });

    test(
      'when rendering then the page is the chart plus half-inch margins',
      () async {
        final pdf = await _uncompressed(scene);

        expect(pdf, contains('/MediaBox[0 0 472 372]'));
      },
    );

    test(
      'when rendering with a custom margin then the page size follows it',
      () async {
        final pdf = await _uncompressed(scene, margin: 0);

        expect(pdf, contains('/MediaBox[0 0 400 300]'));
      },
    );

    test(
      'when rendering then bold and italic text use the Helvetica variants',
      () async {
        final pdf = await _uncompressed(scene);

        expect(pdf, contains('/Helvetica-Bold'));
        expect(pdf, contains('/Helvetica-Oblique'));
      },
    );

    test(
      'when rendering then clips, dashes and transparency are emitted',
      () async {
        final pdf = await _uncompressed(scene);

        expect(pdf, contains('W n'));
        expect(pdf, contains('[6 3] 0 d'));
        expect(pdf, contains('/ca 0.302'));
        expect(pdf, contains('(Title & <more>)'));
      },
    );

    test('when compressing then the document is smaller', () async {
      final compressed = await const PdfChartRenderer().renderDocument(scene);
      final plain = await const PdfChartRenderer().renderDocument(
        scene,
        compress: false,
      );

      expect(compressed.length, lessThan(plain.length));
    });
  });

  group('Given a page of an existing document', () {
    late PdfDocument doc;
    late PdfGraphics g;
    setUp(() {
      doc = PdfDocument(compress: false);
      g = PdfPage(doc, pageFormat: PdfPageFormat.a4).getGraphics();
    });

    test(
      'when drawing with an offset and scale then it completes and saves',
      () async {
        const PdfChartRenderer().draw(
          RenderTestScenes.kitchenSink(),
          g,
          offset: const ChartPoint(50, 700),
          scale: 0.75,
        );

        final pdf = latin1.decode(await doc.save());
        expect(pdf, contains('0.75 0 0 -0.75 50 700 cm'));
      },
    );

    test(
      'when drawing with explicit fonts then those fonts are used',
      () async {
        final courier = PdfFont.courier(doc);
        final courierBold = PdfFont.courierBold(doc);

        const PdfChartRenderer().draw(
          RenderTestScenes.scene([
            const SText('plain', ChartPoint(10, 10), RenderTestScenes.text),
            const SText('bold', ChartPoint(10, 30), TextStyleSpec(bold: true)),
          ]),
          g,
          font: courier,
          boldFont: courierBold,
        );

        final pdf = latin1.decode(await doc.save());
        expect(pdf, contains('/Courier-Bold'));
        expect(pdf, isNot(contains('/Helvetica-Bold')));
      },
    );

    test(
      'when text has characters outside the font then drawing does not throw',
      () async {
        const PdfChartRenderer().draw(
          RenderTestScenes.scene([
            const SText('→ 12 € ✓', ChartPoint(10, 10), RenderTestScenes.text),
          ]),
          g,
        );

        final pdf = latin1.decode(await doc.save());
        expect(pdf, contains('(? 12 ? ?)'));
      },
    );

    test(
      'when a group has opacity then it multiplies into the children',
      () async {
        const PdfChartRenderer().draw(
          RenderTestScenes.scene([
            SGroup([
              SPolyline(
                Float64List.fromList([0, 0, 10, 10]),
                const SStroke(0x80000000, width: 2),
              ),
            ], opacity: 0.5),
          ]),
          g,
        );

        final pdf = latin1.decode(await doc.save());
        expect(pdf, contains('/CA 0.251'));
      },
    );

    test('when text is rotated then a rotation matrix precedes it', () async {
      const PdfChartRenderer().draw(
        RenderTestScenes.scene([
          const SText(
            'R',
            ChartPoint(20, 20),
            RenderTestScenes.text,
            angle: 1.5707963267948966,
            anchor: TextAnchor.baselineLeft,
          ),
        ]),
        g,
      );

      final pdf = latin1.decode(await doc.save());
      expect(pdf, contains('0 1 1 0 20 20 cm'));
    });
  });

  group('Given a scene with non-finite coordinates', () {
    test('when rendering PDF then no NaN reaches the document', () async {
      final bytes = await const PdfChartRenderer().renderDocument(
        RenderTestScenes.nonFinite(),
        compress: false,
      );

      final pdf = latin1.decode(bytes);
      expect(pdf, isNot(contains('NaN')));
      expect(pdf, isNot(contains('Infinity')));
    });
  });
}
