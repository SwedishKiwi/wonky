import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../shell/shell_services.dart';

/// Captures the `RepaintBoundary` of [key] at [pixelRatio], scaled down so
/// the image has at most [maxPixels] pixels and (with [maxSide]) its longer
/// side at most [maxSide] pixels. Returns the image and the pixel ratio
/// used, or null when there is nothing to capture or capturing fails.
Future<(ui.Image, double)?> captureRepaintBoundary(
  GlobalKey key, {
  double pixelRatio = 1,
  int maxPixels = 4000000,
  int? maxSide,
}) async {
  final object = key.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary || !object.attached) return null;
  final size = object.size;
  if (size.isEmpty) return null;
  var ratio = pixelRatio;
  final pixels = size.width * size.height * ratio * ratio;
  if (pixels > maxPixels) ratio *= math.sqrt(maxPixels / pixels);
  if (maxSide != null) {
    final longest = math.max(size.width, size.height) * ratio;
    if (longest > maxSide) ratio *= maxSide / longest;
  }
  try {
    // `toImage` asserts a painted boundary (debug builds only).
    if (kDebugMode && object.debugNeedsPaint) {
      await SchedulerBinding.instance.endOfFrame;
    }
    return (await object.toImage(pixelRatio: ratio), ratio);
  } catch (e) {
    debugPrint('captureRepaintBoundary: $e');
    return null;
  }
}

/// Captures everything the app paints (specs/16 §5.1): the
/// [ShellServices.screenshotBoundary] at the device pixel ratio, capped at
/// [maxPixels] and downscaled so the longer side is at most [maxSide].
/// Includes open menus, toasts and the shell's dialogs; not the browser's
/// chrome. Null on failure (no boundary yet, a renderer error). The caller
/// disposes the image.
Future<ui.Image?> captureAppScreenshot(
  ShellServices s, {
  int maxPixels = 4000000,
  int maxSide = 2560,
}) async {
  final context = s.screenshotBoundary.currentContext;
  if (context == null) return null;
  final dpr = View.maybeOf(context)?.devicePixelRatio ?? 1.0;
  final r = await captureRepaintBoundary(
    s.screenshotBoundary,
    pixelRatio: dpr,
    maxPixels: maxPixels,
    maxSide: maxSide,
  );
  return r?.$1;
}

/// An encoded screenshot.
@immutable
class EncodedScreenshot {
  const EncodedScreenshot({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;

  /// `image/png` or `image/jpeg`.
  final String mimeType;
  final int width;
  final int height;
}

/// Encodes [image] as JPEG at [quality] (0–100); null when it cannot.
typedef ScreenshotJpegEncoder =
    Future<Uint8List?> Function(ui.Image image, int quality);

/// Encodes a screenshot for upload (specs/16 §5.2): PNG while it is at most
/// [maxPngBytes]; otherwise JPEG at quality 85 through [jpegEncoder], and
/// downscaled (repeatedly) while it is still over [maxBytes].
///
/// `wonky_app` has no JPEG encoder of its own (no `package:image`
/// dependency): without [jpegEncoder] a PNG over [maxPngBytes] is kept when
/// it is at most [maxBytes] and downscaled otherwise. [image] is not
/// disposed. Throws a [StateError] when the image cannot be encoded.
Future<EncodedScreenshot> encodeScreenshot(
  ui.Image image, {
  int maxPngBytes = 2 * 1024 * 1024,
  int maxBytes = 5 * 1024 * 1024,
  ScreenshotJpegEncoder? jpegEncoder,
}) async {
  var current = image;
  try {
    for (var attempt = 0; attempt < 12; attempt++) {
      final data = await current.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding failed.');
      final png = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      EncodedScreenshot result(Uint8List bytes, String mime) =>
          EncodedScreenshot(
            bytes: bytes,
            mimeType: mime,
            width: current.width,
            height: current.height,
          );
      if (png.length <= maxPngBytes) return result(png, 'image/png');
      var size = png.length;
      if (jpegEncoder != null) {
        final jpeg = await jpegEncoder(current, 85);
        if (jpeg != null) {
          if (jpeg.length <= maxBytes) return result(jpeg, 'image/jpeg');
          size = jpeg.length;
        } else if (png.length <= maxBytes) {
          return result(png, 'image/png');
        }
      } else if (png.length <= maxBytes) {
        return result(png, 'image/png');
      }
      // Bytes scale roughly with the pixel count.
      final factor = (math.sqrt(maxBytes / size) * 0.9).clamp(0.1, 0.9);
      final w = math.max(1, (current.width * factor).floor());
      final h = math.max(1, (current.height * factor).floor());
      final next = await _scaled(current, w, h);
      if (!identical(current, image)) current.dispose();
      current = next;
    }
    throw StateError('The screenshot stays too large.');
  } finally {
    if (!identical(current, image)) current.dispose();
  }
}

Future<ui.Image> _scaled(ui.Image src, int width, int height) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    src,
    Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height).whenComplete(picture.dispose);
}
