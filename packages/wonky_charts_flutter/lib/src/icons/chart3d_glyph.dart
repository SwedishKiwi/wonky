import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:wonky_charts/wonky_charts.dart';

import '../render/chart_painter.dart';

/// The painted icon of a 3D chart type in the type picker (08 §23.9): a tiny
/// scene of the type rendered by the core software renderer, so the icon
/// shows the real 3D look.
class Chart3DGlyphPainter extends CustomPainter {
  Chart3DGlyphPainter({
    required this.type,
    required this.stacking,
    required this.colors,
    required this.floor,
    required this.background,
    this.pieHole = 0,
  });

  final ChartType type;
  final ChartStacking stacking;
  final double pieHole;
  final List<Color> colors;
  final Color floor;
  final Color background;

  int _c(int i) => colors[i % colors.length].toARGB32();

  List<Chart3DItem> _items() {
    const vals = [0.45, 0.8, 0.6, 0.95];
    const vals2 = [0.3, 0.2, 0.35, 0.25];
    final items = <Chart3DItem>[];
    switch (type) {
      case ChartType.pie:
        const v = [0.35, 0.25, 0.22, 0.18];
        var a = 0.0;
        for (var i = 0; i < v.length; i++) {
          final sweep = v[i] * 2 * math.pi;
          items.add(
            Chart3DWedge(
              'w$i',
              _c(i),
              null,
              center: Vec3.zero,
              start: a,
              sweep: sweep,
              radius: 1,
              innerRadius: pieHole,
              height: 0.28,
              offset: i == 0 ? 0.12 : 0,
            ),
          );
          a += sweep;
        }
      case ChartType.surface:
        // A 4 × 3 height field colored by band.
        const h = [
          [0.25, 0.45, 0.4, 0.7],
          [0.35, 0.7, 0.55, 0.85],
          [0.2, 0.5, 0.75, 0.6],
        ];
        for (var r = 0; r < 2; r++) {
          for (var i = 0; i < 3; i++) {
            final v = [h[r][i], h[r][i + 1], h[r + 1][i + 1], h[r + 1][i]];
            final avg = v.reduce((a, b) => a + b) / 4;
            items.add(
              Chart3DPatch(
                'p$r$i',
                _c(avg < 0.45 ? 0 : (avg < 0.6 ? 1 : 2)),
                null,
                corners: [
                  Vec3(i * 0.6, v[0], 0.4 - r * 0.4),
                  Vec3((i + 1) * 0.6, v[1], 0.4 - r * 0.4),
                  Vec3((i + 1) * 0.6, v[2], 0.4 - (r + 1) * 0.4),
                  Vec3(i * 0.6, v[3], 0.4 - (r + 1) * 0.4),
                ],
              ),
            );
          }
        }
      case ChartType.line || ChartType.area:
        final xs = Float64List.fromList([0, 0.6, 1.2, 1.8]);
        final stacked =
            type == ChartType.area && stacking != ChartStacking.none;
        for (var s = 0; s < 2; s++) {
          final z = stacked ? 0.0 : (s == 0 ? 0.3 : -0.3);
          final tops = Float64List.fromList([
            for (var i = 0; i < 4; i++)
              s == 0
                  ? vals[i] * (stacked ? 0.6 : 1)
                  : (stacked ? vals[i] * 0.6 + vals2[i] : vals2[i] + 0.35),
          ]);
          final bottoms = Float64List.fromList([
            for (var i = 0; i < 4; i++)
              type == ChartType.line
                  ? tops[i] - 0.1
                  : (stacked && s == 1 ? vals[i] * 0.6 : 0),
          ]);
          items.add(
            Chart3DSlab(
              's$s',
              _c(s),
              null,
              xs: xs,
              tops: tops,
              bottoms: bottoms,
              z0: z - 0.18,
              z1: z + 0.18,
            ),
          );
        }
      default:
        final bar = type == ChartType.bar;
        for (var i = 0; i < 3; i++) {
          final c0 = i * 0.62 + 0.08, c1 = c0 + 0.42;
          final total = stacking == ChartStacking.percent ? 1.0 : vals[i];
          final first = stacking == ChartStacking.none
              ? vals[i]
              : (stacking == ChartStacking.percent ? 0.6 : vals[i] * 0.65);
          final segs = stacking == ChartStacking.none
              ? [(0.0, first, 0)]
              : [(0.0, first, 0), (first, total, 1)];
          for (final (lo, hi, k) in segs) {
            final a = bar ? Vec3(lo * 1.8, 1.8 - c1, -0.2) : Vec3(c0, lo, -0.2);
            final b = bar ? Vec3(hi * 1.8, 1.8 - c0, 0.2) : Vec3(c1, hi, 0.2);
            items.add(
              Chart3DBox(
                'b$i$k',
                _c(k),
                null,
                min: Vec3(math.min(a.x, b.x), math.min(a.y, b.y), a.z),
                max: Vec3(math.max(a.x, b.x), math.max(a.y, b.y), b.z),
                axis: bar ? 0 : 1,
              ),
            );
          }
        }
    }
    if (type != ChartType.pie) {
      items.insert(
        0,
        Chart3DBox(
          'floor',
          floor.toARGB32(),
          null,
          part: Chart3DPart.floor,
          min: const Vec3(-0.05, -0.06, -0.45),
          max: const Vec3(1.9, 0, 0.45),
        ),
      );
    }
    return items;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pie = type == ChartType.pie;
    final model = Chart3DModel(
      kind: pie ? Chart3DKind.pie : Chart3DKind.cartesian,
      items: _items(),
      labels: const [],
      bounds: pie
          ? const Aabb3(Vec3(-1.1, 0, -1.1), Vec3(1.1, 0.28, 1.1))
          : Aabb3(
              const Vec3(-0.05, -0.06, -0.45),
              Vec3(1.9, type == ChartType.bar ? 1.8 : 1.0, 0.45),
            ),
      azimuth: pie ? 0 : 25,
      elevation: pie ? 45 : 22,
      fov: 20,
      lighting: Chart3DLighting.soft,
      background: background.toARGB32(),
      floorY: 0,
    );
    final scene = Chart3DScene(
      model,
      ChartRect(1, 1, size.width - 2, size.height - 2),
    );
    paintChartScene(
      canvas,
      ChartScene(
        width: size.width,
        height: size.height,
        background: 0,
        primitives: scene.renderGeometry(),
      ),
    );
  }

  @override
  bool shouldRepaint(Chart3DGlyphPainter old) =>
      old.type != type ||
      old.stacking != stacking ||
      old.pieHole != pieHole ||
      old.floor != floor ||
      !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
