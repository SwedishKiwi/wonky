import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';

/// A noisy image (PNG compresses it poorly, so sizes are predictable).
Future<ui.Image> _noise(int w, int h) async {
  final pixels = Uint8List(w * h * 4);
  var seed = 7;
  for (var i = 0; i < pixels.length; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    pixels[i] = i % 4 == 3 ? 255 : seed >> 16 & 0xff;
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  group('Given the app screenshot', () {
    late CommandTestHarness h;
    setUp(() => h = CommandTestHarness());
    tearDown(() => h.dispose());

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepaintBoundary(
          key: h.services.screenshotBoundary,
          child: const ColoredBox(color: Color(0xff3366cc)),
        ),
      );
    }

    testWidgets('when capturing then it is taken at the device pixel ratio '
        'and capped', (tester) async {
      await pumpApp(tester);
      // 400×300 logical px at 2× = 800×600.
      final full = await tester.runAsync(
        () => captureAppScreenshot(h.services),
      );
      expect([full!.width, full.height], [800, 600]);
      full.dispose();
      final side = await tester.runAsync(
        () => captureAppScreenshot(h.services, maxSide: 400),
      );
      expect([side!.width, side.height], [400, 300]);
      side.dispose();
      final pixels = await tester.runAsync(
        () => captureAppScreenshot(h.services, maxPixels: 120000),
      );
      expect(pixels!.width * pixels.height, lessThanOrEqualTo(120000));
      expect(pixels.width, closeTo(400, 1));
      pixels.dispose();
    });

    testWidgets('when nothing was built then capturing returns null', (
      tester,
    ) async {
      final r = await tester.runAsync(() => captureAppScreenshot(h.services));
      expect(r, isNull);
    });
  });

  group('Given screenshot encoding', () {
    testWidgets('when the PNG is small then it stays PNG', (tester) async {
      final r = await tester.runAsync(() async {
        final image = await _noise(40, 30);
        final e = await encodeScreenshot(image);
        image.dispose();
        return e;
      });
      expect(r!.mimeType, 'image/png');
      expect([r.width, r.height], [40, 30]);
      expect(r.bytes.sublist(1, 4), 'PNG'.codeUnits);
    });

    testWidgets('when the PNG is too large and there is no JPEG encoder then '
        'it is downscaled below the limit', (tester) async {
      final r = await tester.runAsync(() async {
        final image = await _noise(200, 200);
        final e = await encodeScreenshot(
          image,
          maxPngBytes: 20000,
          maxBytes: 40000,
        );
        image.dispose();
        return e;
      });
      expect(r!.mimeType, 'image/png');
      expect(r.bytes.length, lessThanOrEqualTo(40000));
      expect(r.width, lessThan(200));
    });

    testWidgets('when the PNG is too large and a JPEG encoder is given then '
        'JPEG at quality 85 is used', (tester) async {
      final qualities = <int>[];
      final r = await tester.runAsync(() async {
        final image = await _noise(200, 200);
        final e = await encodeScreenshot(
          image,
          maxPngBytes: 20000,
          jpegEncoder: (img, q) async {
            qualities.add(q);
            return Uint8List.fromList([0xff, 0xd8, 0xff]);
          },
        );
        image.dispose();
        return e;
      });
      expect(r!.mimeType, 'image/jpeg');
      expect(qualities, [85]);
      expect(r.width, 200);
    });
  });
}
