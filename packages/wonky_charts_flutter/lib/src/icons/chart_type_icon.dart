import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_charts/wonky_charts.dart';

import 'chart3d_glyph.dart';

/// A painted glyph per chart type and variant (Sheets 08 §19 `ChartTypeIcon`,
/// Slides 08 §2.2), drawn with the shad theme's chart colors: the Sheets
/// type picker and Slides' chart insert dialog and inspector.
class ChartTypeIcon extends StatelessWidget {
  const ChartTypeIcon({
    super.key,
    required this.id,
    required this.type,
    this.stacking = ChartStacking.none,
    this.pieHole = 0,
    this.smooth = false,
    this.threeD = false,
  });

  /// The icon of [spec]'s type and variant.
  factory ChartTypeIcon.of(ChartSpec spec, {Key? key}) {
    final hole = spec.type == ChartType.pie && spec.pieOptions.pieHole > 0;
    final smooth = spec.type == ChartType.line && spec.style.smooth;
    final prefix = switch (spec.stacking) {
      ChartStacking.normal when spec.type.supportsStacking => 'stacked',
      ChartStacking.percent when spec.type.supportsStacking => 'percent',
      _ => '',
    };
    final base = hole
        ? 'doughnut'
        : smooth
        ? 'smoothLine'
        : spec.type.id;
    final id = prefix.isEmpty
        ? base
        : '$prefix${base[0].toUpperCase()}${base.substring(1)}';
    return ChartTypeIcon(
      key: key,
      id: spec.is3D ? '${id}3d' : id,
      type: spec.type,
      stacking: spec.stacking,
      pieHole: hole ? spec.pieOptions.pieHole : 0,
      smooth: smooth,
      threeD: spec.is3D,
    );
  }

  /// Variant id (`column`, `stackedColumn`, `smoothLine`, `doughnut`,
  /// `column3d`, …).
  final String id;
  final ChartType type;
  final ChartStacking stacking;
  final double pieHole;
  final bool smooth;

  /// Drawn in 3D (Sheets 08 §23).
  final bool threeD;

  @override
  Widget build(BuildContext context) {
    final c = ShadTheme.of(context).colorScheme;
    if (threeD) {
      return CustomPaint(
        painter: Chart3DGlyphPainter(
          type: type,
          stacking: stacking,
          pieHole: pieHole,
          colors: [c.chart1, c.chart2, c.chart3],
          floor: Color.lerp(c.background, c.mutedForeground, 0.25)!,
          background: c.background,
        ),
      );
    }
    return CustomPaint(
      painter: _GlyphPainter(
        (id: id, smooth: smooth, pieHole: pieHole),
        [c.chart1, c.chart2, c.chart3],
        c.mutedForeground,
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.v, this.colors, this.muted);

  final ({String id, bool smooth, double pieHole}) v;
  final List<Color> colors;
  final Color muted;

  Paint _fill(int i) => Paint()..color = colors[i % colors.length];
  Paint _stroke(int i, [double w = 1.6]) => Paint()
    ..color = colors[i % colors.length]
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final axis = Paint()
      ..color = muted.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    void axes() {
      canvas.drawLine(Offset(1, h - 1), Offset(w - 1, h - 1), axis);
      canvas.drawLine(Offset(1, 1), Offset(1, h - 1), axis);
    }

    const vals = [0.45, 0.8, 0.6, 0.95];
    const vals2 = [0.3, 0.2, 0.35, 0.25];
    switch (v.id) {
      case 'column' || 'stackedColumn' || 'percentColumn' || 'histogram':
        axes();
        final n = v.id == 'histogram' ? 6 : 4;
        final hist = [0.2, 0.5, 0.9, 0.75, 0.4, 0.15];
        final gap = v.id == 'histogram' ? 0.0 : w * 0.06;
        final bw = (w - 4 - gap * (n + 1)) / n;
        for (var i = 0; i < n; i++) {
          final x = 3 + gap + i * (bw + gap);
          final a = v.id == 'histogram' ? hist[i] : vals[i];
          if (v.id == 'column' || v.id == 'histogram') {
            canvas.drawRect(
              Rect.fromLTWH(x, (h - 2) * (1 - a), bw, (h - 2) * a),
              _fill(0),
            );
          } else {
            final total = v.id == 'percentColumn' ? 1.0 : a;
            final b = v.id == 'percentColumn' ? 0.55 : vals2[i];
            final top = (h - 2) * (1 - total);
            final split =
                top + (h - 2) * total * (1 - b / math.max(total, 0.01));
            canvas.drawRect(Rect.fromLTRB(x, top, x + bw, split), _fill(1));
            canvas.drawRect(Rect.fromLTRB(x, split, x + bw, h - 2), _fill(0));
          }
        }
      case 'bar' || 'stackedBar' || 'percentBar':
        axes();
        const n = 3;
        final gap = h * 0.1;
        final bh = (h - 2 - gap * (n + 1)) / n;
        for (var i = 0; i < n; i++) {
          final y = 1 + gap + i * (bh + gap);
          final a = vals[i];
          if (v.id == 'bar') {
            canvas.drawRect(Rect.fromLTWH(2, y, (w - 4) * a, bh), _fill(0));
          } else {
            final total = v.id == 'percentBar' ? 1.0 : a;
            final split = (w - 4) * total * 0.6;
            canvas.drawRect(Rect.fromLTWH(2, y, split, bh), _fill(0));
            canvas.drawRect(
              Rect.fromLTWH(2 + split, y, (w - 4) * total - split, bh),
              _fill(1),
            );
          }
        }
      case 'line' || 'smoothLine':
        axes();
        final pts = [
          Offset(3, h * 0.7),
          Offset(w * 0.3, h * 0.35),
          Offset(w * 0.55, h * 0.55),
          Offset(w * 0.8, h * 0.2),
          Offset(w - 2, h * 0.3),
        ];
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (var i = 1; i < pts.length; i++) {
          if (v.smooth) {
            final p0 = pts[i - 1], p1 = pts[i];
            final mx = (p0.dx + p1.dx) / 2;
            path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
          } else {
            path.lineTo(pts[i].dx, pts[i].dy);
          }
        }
        canvas.drawPath(path, _stroke(0, 2));
        final p2 = Path()
          ..moveTo(3, h * 0.85)
          ..lineTo(w * 0.35, h * 0.7)
          ..lineTo(w * 0.6, h * 0.78)
          ..lineTo(w - 2, h * 0.6);
        canvas.drawPath(p2, _stroke(1, 2));
      case 'area' || 'stackedArea' || 'percentArea':
        axes();
        final top = v.id == 'percentArea' ? 2.0 : null;
        final p1 = Path()
          ..moveTo(2, h - 2)
          ..lineTo(2, top ?? h * 0.5)
          ..lineTo(w * 0.35, top ?? h * 0.25)
          ..lineTo(w * 0.65, top ?? h * 0.4)
          ..lineTo(w - 2, top ?? h * 0.15)
          ..lineTo(w - 2, h - 2)
          ..close();
        canvas.drawPath(p1, _fill(1)..color = colors[1].withValues(alpha: 0.7));
        final p0 = Path()
          ..moveTo(2, h - 2)
          ..lineTo(2, h * 0.75)
          ..lineTo(w * 0.35, h * 0.55)
          ..lineTo(w * 0.65, h * 0.7)
          ..lineTo(w - 2, h * 0.5)
          ..lineTo(w - 2, h - 2)
          ..close();
        canvas.drawPath(p0, _fill(0));
      case 'combo':
        axes();
        for (var i = 0; i < 4; i++) {
          final bw = (w - 8) / 4 * 0.6;
          final x = 4 + i * (w - 8) / 4;
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              (h - 2) * (1 - vals[i] * 0.7),
              bw,
              (h - 2) * vals[i] * 0.7,
            ),
            _fill(0),
          );
        }
        final p = Path()
          ..moveTo(4, h * 0.45)
          ..lineTo(w * 0.4, h * 0.2)
          ..lineTo(w * 0.7, h * 0.35)
          ..lineTo(w - 3, h * 0.1);
        canvas.drawPath(p, _stroke(1, 2));
      case 'pie' || 'doughnut':
        final c = Offset(w / 2, h / 2);
        final r = math.min(w, h) / 2 - 1;
        final rect = Rect.fromCircle(center: c, radius: r);
        const sweeps = [2.4, 1.9, 1.98];
        var a = -math.pi / 2;
        final ring = v.pieHole > 0;
        final rr = ring ? r * 0.72 : r;
        final arcRect = Rect.fromCircle(center: c, radius: rr);
        for (var i = 0; i < 3; i++) {
          if (ring) {
            canvas.drawArc(
              arcRect,
              a,
              sweeps[i] - 0.06,
              false,
              _stroke(i, r * 0.5)..strokeCap = StrokeCap.butt,
            );
          } else {
            canvas.drawArc(rect, a, sweeps[i], true, _fill(i));
          }
          a += sweeps[i];
        }
      case 'scatter' || 'bubble':
        axes();
        const pts = [
          (0.2, 0.7, 2.0),
          (0.4, 0.4, 3.5),
          (0.55, 0.6, 2.5),
          (0.75, 0.25, 4.5),
          (0.88, 0.45, 2.0),
        ];
        for (var i = 0; i < pts.length; i++) {
          final (x, y, s) = pts[i];
          canvas.drawCircle(
            Offset(w * x, h * y),
            v.id == 'bubble' ? s * 1.4 : 2.2,
            _fill(v.id == 'bubble' ? i : 0)
              ..color = colors[v.id == 'bubble' ? i % 3 : 0].withValues(
                alpha: v.id == 'bubble' ? 0.8 : 1,
              ),
          );
        }
      case 'candlestick':
        axes();
        for (var i = 0; i < 4; i++) {
          final x = 6 + i * (w - 10) / 4;
          final up = i.isEven;
          final top = h * (up ? 0.25 : 0.35) + i;
          final bottom = h * (up ? 0.6 : 0.75) - i;
          canvas.drawLine(
            Offset(x + 3, top - 4),
            Offset(x + 3, bottom + 4),
            _stroke(up ? 0 : 1, 1),
          );
          canvas.drawRect(
            Rect.fromLTRB(x, top, x + 6, bottom),
            _fill(up ? 0 : 1),
          );
        }
      case 'waterfall':
        axes();
        const steps = [(0.0, 0.5), (0.5, 0.7), (0.7, 0.45), (0.45, 0.85)];
        for (var i = 0; i < steps.length; i++) {
          final (a, b) = steps[i];
          final x = 4 + i * (w - 8) / 4;
          final bw = (w - 8) / 4 * 0.7;
          canvas.drawRect(
            Rect.fromLTRB(
              x,
              (h - 2) * (1 - math.max(a, b)),
              x + bw,
              (h - 2) * (1 - math.min(a, b)),
            ),
            _fill(b >= a ? 0 : 1),
          );
        }
      case 'scorecard':
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, w - 2, h - 2),
          const Radius.circular(3),
        );
        canvas.drawRRect(r, _stroke(2, 1));
        canvas.drawRect(
          Rect.fromLTWH(w * 0.25, h * 0.3, w * 0.5, h * 0.22),
          _fill(0),
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.35, h * 0.62, w * 0.3, h * 0.1),
          _fill(1),
        );
      case 'table':
        final p = Paint()
          ..color = muted
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), p);
        canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h / 4), _fill(0));
        for (var i = 2; i < 4; i++) {
          canvas.drawLine(Offset(1, h * i / 4), Offset(w - 1, h * i / 4), p);
        }
        canvas.drawLine(Offset(w / 2, 1), Offset(w / 2, h - 1), p);
      case 'radar':
        final c = Offset(w / 2, h / 2);
        final r = math.min(w, h) / 2 - 1;
        final web = Path();
        final data = Path();
        const ds = [0.9, 0.6, 0.8, 0.5, 0.7];
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          final q = c + Offset(math.cos(a), math.sin(a)) * r * ds[i];
          if (i == 0) {
            web.moveTo(p.dx, p.dy);
            data.moveTo(q.dx, q.dy);
          } else {
            web.lineTo(p.dx, p.dy);
            data.lineTo(q.dx, q.dy);
          }
        }
        web.close();
        data.close();
        canvas.drawPath(web, axis..style = PaintingStyle.stroke);
        canvas.drawPath(
          data,
          _fill(0)..color = colors[0].withValues(alpha: 0.5),
        );
        canvas.drawPath(data, _stroke(0, 1.4));
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.v.id != v.id || old.colors != colors || old.muted != muted;
}
