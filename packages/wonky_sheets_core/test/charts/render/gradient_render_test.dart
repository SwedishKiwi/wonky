import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/render/render.dart';
import 'package:wonky_sheets_core/src/charts/scene/path.dart';
import 'package:wonky_sheets_core/src/charts/scene/scene.dart';

/// A 100 × 20 rectangle path filled red → blue from left to right.
ChartScene _gradientScene() {
  final p = PathBuilder()
    ..moveTo(0, 0)
    ..lineTo(100, 0)
    ..lineTo(100, 20)
    ..lineTo(0, 20)
    ..close();
  return ChartScene(
    width: 100,
    height: 20,
    background: 0xFFFFFFFF,
    primitives: [
      SPath(
        p.commands,
        fill: 0xFF800080,
        gradient: const SGradient(0, 10, 100, 10, 0xFFFF0000, 0xFF0000FF),
      ),
    ],
  );
}

void main() {
  group('Given a path with a linear gradient (3D faces, 08 §23.5)', () {
    test('when rasterized then the colors run from the start to the end '
        'color instead of the flat fallback', () {
      final image = const RasterChartRenderer().renderImage(_gradientScene());
      final left = image.getPixel(2, 10);
      final mid = image.getPixel(50, 10);
      final right = image.getPixel(97, 10);
      expect(left.r, greaterThan(230));
      expect(left.b, lessThan(25));
      expect(right.b, greaterThan(230));
      expect(right.r, lessThan(25));
      expect(mid.r, inInclusiveRange(100, 155));
      expect(mid.b, inInclusiveRange(100, 155));
    });

    test('when drawn into a PDF then it is an axial shading clipped to the '
        'path', () async {
      final pdf = latin1.decode(
        await const PdfChartRenderer().renderDocument(
          _gradientScene(),
          compress: false,
        ),
      );
      expect(pdf, contains('/ShadingType 2'));
      expect(RegExp(r'/S\d+ sh').hasMatch(pdf), isTrue);
    });
  });
}
