import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:web/web.dart' as web;

import '../../mcp_bridge/app_screenshot.dart' show ScreenshotJpegEncoder;

/// JPEG through an off-document canvas: the image's RGBA pixels are put
/// into a `<canvas>` and encoded with `toBlob('image/jpeg', quality)`.
ScreenshotJpegEncoder? get jpegEncoder => _encode;

Future<Uint8List?> _encode(ui.Image image, int quality) async {
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) return null;
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = image.width
      ..height = image.height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) return null;
    final pixels = Uint8ClampedList.view(
      data.buffer,
      data.offsetInBytes,
      data.lengthInBytes,
    );
    context.putImageData(
      web.ImageData(pixels.toJS, image.width, image.height.toJS),
      0,
      0,
    );
    final done = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? blob) => done.complete(blob)).toJS,
      'image/jpeg',
      (quality.clamp(1, 100) / 100).toJS,
    );
    final blob = await done.future;
    if (blob == null) return null;
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}
