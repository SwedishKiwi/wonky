import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:wonky_ui/wonky_ui.dart' show InkStroke, InkStrokePainter;

import '../../mcp_bridge/app_screenshot.dart';

/// The tools of the screenshot editor (specs/16 §5.2). The names are stable
/// (MCP, keys `dialog.board.screenshot.tool.<name>`).
enum ScreenshotTool {
  /// Opaque rectangle (never a blur: blurred text can be recovered).
  cover,

  /// Rectangle outline in the accent color.
  highlight,

  /// Straight arrow in the accent color.
  arrow,

  /// Freehand stroke, smoothed with `OneEuroFilter`.
  pen;

  /// Whether the tool draws in the accent color.
  bool get accent => this != cover;
}

/// The accent colors of the editor (`1`–`3`).
enum ScreenshotColor {
  red(Color(0xffef4444)),
  yellow(Color(0xfffacc15)),
  blue(Color(0xff3b82f6));

  const ScreenshotColor(this.color);

  final Color color;
}

/// The fill of the cover tool: solid black (never a blur).
const screenshotCoverColor = Color(0xff000000);

/// The stroke unit of an image of [size]: 1 px up to 1,600 px on the longer
/// side, scaled up beyond so annotations stay visible on large captures.
double screenshotStrokeUnit(Size size) =>
    math.max(1.0, math.max(size.width, size.height) / 1600);

/// One annotation of the screenshot editor, in image pixels.
@immutable
sealed class ScreenshotAnnotation {
  const ScreenshotAnnotation(this.id);

  final String id;

  /// The tool that drew it.
  ScreenshotTool get tool;

  /// The area it covers (for selection outlines and hit tests).
  Rect get bounds;

  /// A copy moved by [delta].
  ScreenshotAnnotation translate(Offset delta);

  /// A copy in [color] (accent annotations only; covers stay black).
  ScreenshotAnnotation recolor(Color color) => this;

  /// Whether [p] (image pixels) hits the annotation, within [tolerance].
  bool hits(Offset p, double tolerance);

  /// Paints the annotation on [canvas] (image pixels); [unit] is
  /// [screenshotStrokeUnit] of the image.
  void paint(Canvas canvas, double unit);
}

/// An opaque rectangle.
final class CoverAnnotation extends ScreenshotAnnotation {
  const CoverAnnotation(super.id, this.rect);

  final Rect rect;

  @override
  ScreenshotTool get tool => ScreenshotTool.cover;

  @override
  Rect get bounds => rect;

  @override
  CoverAnnotation translate(Offset delta) =>
      CoverAnnotation(id, rect.shift(delta));

  @override
  bool hits(Offset p, double tolerance) => rect.inflate(tolerance).contains(p);

  @override
  void paint(Canvas canvas, double unit) {
    // Whole pixels, no anti-aliasing: the edge pixels are covered too.
    final r = Rect.fromLTRB(
      rect.left.floorToDouble(),
      rect.top.floorToDouble(),
      rect.right.ceilToDouble(),
      rect.bottom.ceilToDouble(),
    );
    canvas.drawRect(
      r,
      Paint()
        ..color = screenshotCoverColor
        ..isAntiAlias = false,
    );
  }
}

/// A rectangle outline, 3 px (scaled by the stroke unit).
final class HighlightAnnotation extends ScreenshotAnnotation {
  const HighlightAnnotation(super.id, this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  ScreenshotTool get tool => ScreenshotTool.highlight;

  @override
  Rect get bounds => rect;

  @override
  HighlightAnnotation translate(Offset delta) =>
      HighlightAnnotation(id, rect.shift(delta), color);

  @override
  HighlightAnnotation recolor(Color color) =>
      HighlightAnnotation(id, rect, color);

  @override
  bool hits(Offset p, double tolerance) {
    final outer = rect.inflate(tolerance);
    final inner = rect.deflate(tolerance);
    return outer.contains(p) && (inner.isEmpty || !inner.contains(p));
  }

  @override
  void paint(Canvas canvas, double unit) => canvas.drawRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * unit
      ..color = color,
  );
}

/// A straight arrow from [from] to [to] (the head).
final class ArrowAnnotation extends ScreenshotAnnotation {
  const ArrowAnnotation(super.id, this.from, this.to, this.color);

  final Offset from;
  final Offset to;
  final Color color;

  @override
  ScreenshotTool get tool => ScreenshotTool.arrow;

  @override
  Rect get bounds => Rect.fromPoints(from, to);

  @override
  ArrowAnnotation translate(Offset delta) =>
      ArrowAnnotation(id, from + delta, to + delta, color);

  @override
  ArrowAnnotation recolor(Color color) => ArrowAnnotation(id, from, to, color);

  @override
  bool hits(Offset p, double tolerance) =>
      _segmentDistance(p, from, to) <= tolerance;

  @override
  void paint(Canvas canvas, double unit) {
    final width = 4 * unit;
    final d = to - from;
    final length = d.distance;
    if (length == 0) return;
    final dir = d / length;
    final head = math.min(18 * unit, length * 0.6);
    final base = to - dir * head;
    final normal = Offset(-dir.dy, dir.dx) * (head * 0.55);
    final paint = Paint()..color = color;
    canvas.drawLine(
      from,
      base,
      paint
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(base.dx + normal.dx, base.dy + normal.dy)
        ..lineTo(base.dx - normal.dx, base.dy - normal.dy)
        ..close(),
      Paint()..color = color,
    );
  }
}

/// A freehand stroke (the shared [InkStroke], in image pixels).
final class PenAnnotation extends ScreenshotAnnotation {
  PenAnnotation(this.stroke) : super(stroke.id);

  final InkStroke stroke;

  @override
  ScreenshotTool get tool => ScreenshotTool.pen;

  @override
  Rect get bounds {
    final pts = stroke.points;
    if (pts.isEmpty) return Rect.zero;
    var r = Rect.fromPoints(pts.first, pts.first);
    for (final p in pts) {
      r = r.expandToInclude(Rect.fromPoints(p, p));
    }
    return r.inflate(stroke.width / 2);
  }

  @override
  PenAnnotation translate(Offset delta) => PenAnnotation(
    InkStroke(
      id: stroke.id,
      tool: stroke.tool,
      color: stroke.color,
      width: stroke.width,
      points: [for (final p in stroke.points) p + delta],
    ),
  );

  @override
  PenAnnotation recolor(Color color) => PenAnnotation(
    InkStroke(
      id: stroke.id,
      tool: stroke.tool,
      color: color.toARGB32(),
      width: stroke.width,
      points: stroke.points,
    ),
  );

  @override
  bool hits(Offset p, double tolerance) => stroke.touches(p, tolerance);

  @override
  void paint(Canvas canvas, double unit) =>
      InkStrokePainter.paintStrokes(canvas, [stroke]);
}

double _segmentDistance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).distance;
}

/// Paints [annotations] in order on [canvas] (image pixels) for an image of
/// [imageSize].
void paintScreenshotAnnotations(
  Canvas canvas,
  Iterable<ScreenshotAnnotation> annotations,
  Size imageSize,
) {
  final unit = screenshotStrokeUnit(imageSize);
  for (final a in annotations) {
    a.paint(canvas, unit);
  }
}

/// Flattens [source] and [annotations] into a new image at the source
/// resolution (specs/16 §5.2). The caller disposes the result.
Future<ui.Image> flattenScreenshot(
  ui.Image source,
  List<ScreenshotAnnotation> annotations,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(source.width.toDouble(), source.height.toDouble());
  canvas.drawImage(source, Offset.zero, Paint());
  paintScreenshotAnnotations(canvas, annotations, size);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(source.width, source.height);
  } finally {
    picture.dispose();
  }
}

/// Turns the editor's image and annotations into the bytes that are
/// uploaded: flattened, then encoded with `encodeScreenshot`.
typedef ScreenshotFinisher =
    Future<EncodedScreenshot> Function(
      ui.Image source,
      List<ScreenshotAnnotation> annotations,
    );

/// The default [ScreenshotFinisher]: [flattenScreenshot] and
/// `encodeScreenshot` (PNG; JPEG at quality 85 through [jpegEncoder] when
/// the PNG is over 2 MB). Only this flattened image leaves the device.
Future<EncodedScreenshot> flattenAndEncodeScreenshot(
  ui.Image source,
  List<ScreenshotAnnotation> annotations, {
  ScreenshotJpegEncoder? jpegEncoder,
}) async {
  final flat = await flattenScreenshot(source, annotations);
  try {
    return await encodeScreenshot(flat, jpegEncoder: jpegEncoder);
  } finally {
    flat.dispose();
  }
}

/// The result of the screenshot editor: the annotations (still editable
/// until posting) and the flattened, encoded image.
@immutable
class AnnotatedScreenshot {
  const AnnotatedScreenshot({required this.annotations, required this.encoded});

  final List<ScreenshotAnnotation> annotations;
  final EncodedScreenshot encoded;
}
