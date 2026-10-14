@Tags(['e2e'])
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wonky_sheets/features/charts/render/chart_painter.dart';
import 'package:wonky_sheets/features/charts3d/gpu/flutter_scene_renderer.dart';
import 'package:wonky_sheets_core/model.dart';

/// GPU vs software tuning check of 3D charts (08 §23.5, §23.7): the same
/// scene is rendered by the `flutter_scene` backend and by the core
/// software renderer; the lit top and front faces of every column must have
/// about the same hue and brightness in both. Needs Flutter GPU (a desktop
/// device: `flutter test integration_test/chart3d_backends_test.dart -d
/// macos`); skipped where the backend can't start.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const size = 400.0;
  const colors = [0xFF4285F4, 0xFFEA4335, 0xFFFBBC04, 0xFF34A853];

  Chart3DScene scene(Chart3DLighting lighting) {
    final items = <Chart3DItem>[
      const Chart3DBox(
        'floor',
        0xFFE8EAED,
        null,
        part: Chart3DPart.floor,
        min: Vec3(-0.1, -0.05, -0.6),
        max: Vec3(2.5, 0, 0.6),
      ),
      for (var i = 0; i < colors.length; i++)
        Chart3DBox(
          'c$i',
          colors[i],
          SceneTag(SceneRole.point, seriesKey: 's', pointIndex: i),
          min: Vec3(i * 0.6, 0, -0.2),
          max: Vec3(i * 0.6 + 0.4, 0.6 + i * 0.25, 0.2),
        ),
    ];
    return Chart3DScene(
      Chart3DModel(
        kind: Chart3DKind.cartesian,
        items: items,
        labels: const [],
        bounds: const Aabb3(Vec3(-0.1, -0.05, -0.6), Vec3(2.5, 1.5, 0.6)),
        azimuth: 25,
        elevation: 22,
        fov: 15,
        lighting: lighting,
        background: 0xFFFFFFFF,
        floorY: 0,
      ),
      const ChartRect(10, 10, size - 20, size - 20),
    );
  }

  Future<ByteData> render(void Function(ui.Canvas c) draw) async {
    final r = ui.PictureRecorder();
    final c = ui.Canvas(r);
    c.drawRect(
      const ui.Rect.fromLTWH(0, 0, size, size),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    draw(c);
    final img = await r.endRecording().toImage(size.toInt(), size.toInt());
    return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  }

  (double, double, double) sample(ByteData d, ({double x, double y}) p) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final x = (p.x + dx).round(), y = (p.y + dy).round();
        final o = (y * size.toInt() + x) * 4;
        r += d.getUint8(o);
        g += d.getUint8(o + 1);
        b += d.getUint8(o + 2);
        n++;
      }
    }
    return (r / n, g / n, b / n);
  }

  double hue((double, double, double) c) {
    final (r, g, b) = c;
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    if (mx - mn < 1) return 0;
    final h = mx == r
        ? (g - b) / (mx - mn)
        : mx == g
        ? 2 + (b - r) / (mx - mn)
        : 4 + (r - g) / (mx - mn);
    return ((h * 60) + 360) % 360;
  }

  double luma((double, double, double) c) =>
      0.2126 * c.$1 + 0.7152 * c.$2 + 0.0722 * c.$3;

  for (final lighting in Chart3DLighting.values) {
    testWidgets('GPU and software renderings agree ($lighting)', (
      tester,
    ) async {
      final gpu = await FlutterSceneChart3DRenderer.create();
      if (gpu == null) {
        markTestSkipped('Flutter GPU is not available');
        return;
      }
      final s = scene(lighting);
      final soft = await render(
        (c) => paintChartScene(
          c,
          ChartScene(
            width: size,
            height: size,
            background: 0,
            primitives: s.renderGeometry(),
          ),
        ),
      );
      final hard = await render(
        (c) => gpu.paint(c, s, key: Object(), pixelRatio: 1),
      );
      for (final item in s.model.dataItems.whereType<Chart3DBox>()) {
        for (final p in [
          Vec3(item.center.x, item.max.y, item.center.z), // top
          Vec3(item.center.x, item.center.y, item.max.z), // front
        ]) {
          final pr = s.camera.project(p);
          final at = (x: pr.x, y: pr.y);
          final a = sample(soft, at), b = sample(hard, at);
          final dh = (hue(a) - hue(b)).abs();
          expect(math.min(dh, 360 - dh), lessThan(20), reason: item.key);
          final ratio = (luma(b) + 1) / (luma(a) + 1);
          expect(ratio, inInclusiveRange(0.7, 1.4), reason: item.key);
        }
      }
    });
  }
}
