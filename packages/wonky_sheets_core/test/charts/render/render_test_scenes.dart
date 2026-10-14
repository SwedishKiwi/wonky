import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:wonky_sheets_core/src/charts/scene/geometry.dart';
import 'package:wonky_sheets_core/src/charts/scene/path.dart';
import 'package:wonky_sheets_core/src/charts/scene/scene.dart';

/// Hand-built scenes shared by the renderer tests.
abstract final class RenderTestScenes {
  static const white = 0xFFFFFFFF;
  static const red = 0xFFFF0000;
  static const blue = 0xFF0000FF;
  static const black = 0xFF000000;
  static const text = TextStyleSpec(size: 12, color: black);

  /// A scene of [width] × [height] with a white background.
  static ChartScene scene(
    List<ScenePrimitive> primitives, {
    double width = 100,
    double height = 100,
    int background = white,
  }) => ChartScene(
    width: width,
    height: height,
    background: background,
    primitives: primitives,
  );

  /// A scene using every primitive type, a clip, group opacity, dashes and rotated text.
  static ChartScene kitchenSink() => scene(width: 400, height: 300, [
    const SRect(
      ChartRect(10, 10, 80, 50),
      fill: red,
      stroke: SStroke(black, width: 2),
      radius: 6,
    ),
    const SRect(ChartRect(50, 30, 80, 50), fill: 0x4D0000FF),
    const SPath(
      [
        PMoveTo(10, 100),
        PLineTo(90, 100),
        PCubicTo(90, 140, 50, 150, 10, 140),
        PClose(),
      ],
      fill: 0xFF00AA00,
      stroke: SStroke(black, width: 1, join: SStrokeJoin.bevel),
      evenOdd: true,
    ),
    SPolyline(
      Float64List.fromList([10, 180, 60, 160, 110, 190, 160, 170]),
      const SStroke(
        0xFF0088FF,
        width: 3,
        dash: [6, 3],
        cap: SStrokeCap.round,
        join: SStrokeJoin.round,
      ),
    ),
    SMarkers(
      Float64List.fromList([
        200,
        20,
        230,
        20,
        260,
        20,
        290,
        20,
        320,
        20,
        350,
        20,
      ]),
      MarkerShape.circle,
      10,
      fill: blue,
      stroke: const SStroke(white, width: 1),
      fills: Int32List.fromList([red, blue, red, blue, red, blue]),
      sizes: Float64List.fromList([8, 10, 12, 14, 16, 18]),
    ),
    for (final (i, shape) in MarkerShape.values.indexed)
      SMarkers(
        Float64List.fromList([200.0 + i * 30, 50]),
        shape,
        12,
        fill: 0xFF3949AB,
      ),
    const SArc(
      ChartPoint(250, 130),
      40,
      -math.pi / 2,
      math.pi,
      fill: 0xFFFBBC05,
    ),
    const SArc(
      ChartPoint(250, 130),
      40,
      math.pi / 2,
      math.pi,
      innerRadius: 20,
      fill: 0xFF4285F4,
      stroke: SStroke(white, width: 1),
    ),
    const SArc(
      ChartPoint(340, 130),
      30,
      0,
      2 * math.pi,
      innerRadius: 15,
      fill: 0xFFAB47BC,
    ),
    const SClip(ChartRect(200, 200, 50, 30), [
      SRect(ChartRect(180, 180, 100, 80), fill: red),
    ]),
    const SGroup([
      SRect(ChartRect(270, 200, 40, 40), fill: blue),
      SRect(ChartRect(290, 220, 40, 40), fill: blue),
    ], opacity: 0.5),
    const SText(
      'Title & <more>',
      ChartPoint(200, 280),
      TextStyleSpec(family: 'Open Sans', size: 14, bold: true, color: black),
      anchor: TextAnchor.bottomCenter,
      width: 100,
      height: 17,
      ascent: 13,
    ),
    const SText(
      'Axis',
      ChartPoint(390, 150),
      TextStyleSpec(size: 12, italic: true, color: 0xB3000000),
      anchor: TextAnchor.center,
      angle: -math.pi / 2,
      width: 30,
      height: 15,
      ascent: 12,
    ),
  ]);

  /// A scene whose primitives carry NaN and infinite coordinates.
  static ChartScene nonFinite() => scene([
    const SRect(ChartRect(double.nan, 10, 20, 20), fill: red),
    SPolyline(
      Float64List.fromList([10, 10, 20, double.nan, 30, 30, 40, 40]),
      const SStroke(black, width: 2),
    ),
    const SPath([
      PMoveTo(10, 10),
      PLineTo(double.infinity, 20),
      PLineTo(50, 50),
      PClose(),
    ], fill: blue),
    const SText('x', ChartPoint(double.nan, 5), text),
  ]);
}

/// RGBA of pixel ([x], [y]) of [image].
(int, int, int, int) rgbaAt(img.Image image, int x, int y) {
  final p = image.getPixel(x, y);
  return (p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt());
}

/// Number of pixels in the rectangle that differ from [background] (ARGB).
int inkCount(
  img.Image image,
  int x0,
  int y0,
  int x1,
  int y1, {
  int background = 0xFFFFFFFF,
}) {
  var n = 0;
  final br = Argb.red(background),
      bg = Argb.green(background),
      bb = Argb.blue(background);
  for (var y = math.max(0, y0); y < math.min(image.height, y1); y++) {
    for (var x = math.max(0, x0); x < math.min(image.width, x1); x++) {
      final (r, g, b, _) = rgbaAt(image, x, y);
      if ((r - br).abs() + (g - bg).abs() + (b - bb).abs() > 30) n++;
    }
  }
  return n;
}
