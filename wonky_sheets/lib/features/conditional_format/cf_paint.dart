import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../theme/sheets_tokens.dart';

/// Painting of conditional-format decorations (06 §15.6–15.7): data bars in
/// the cell background and icon-set icons left of the text. Used by the
/// cell layer and by the rule previews of the CF panel.
abstract final class CfDecorations {
  /// Icon size at 100 % zoom.
  static const double iconSize = 14;

  /// Paints the data bar of [o] inside [cell] (inset 2 px, 70 % height).
  static void paintDataBar(
    Canvas canvas,
    Rect cell,
    ConditionalOverlay o,
    double zoom, {
    required Color axisColor,
  }) {
    final fraction = o.dataBarFraction;
    if (fraction == null) return;
    final color = hexToColor(o.dataBarColor) ?? const Color(0xFF638EC6);
    final inset = 2 * zoom;
    final box = Rect.fromLTRB(
      cell.left + inset,
      cell.top + cell.height * 0.15,
      cell.right - inset,
      cell.bottom - cell.height * 0.15,
    );
    if (box.width <= 0 || box.height <= 0) return;
    double x(double f) => o.dataBarRightToLeft
        ? box.right - f * box.width
        : box.left + f * box.width;
    final a = x(o.dataBarStart.clamp(0.0, 1.0));
    final b = x((o.dataBarStart + fraction).clamp(0.0, 1.0));
    final bar = Rect.fromLTRB(
      math.min(a, b),
      box.top,
      math.max(math.max(a, b), math.min(a, b) + (fraction > 0 ? 1 : 0)),
      box.bottom,
    );
    if (bar.width > 0) {
      final paint = Paint();
      if (o.dataBarGradient) {
        // Gradient grows away from the axis (the bar's start side).
        final fromLeft = (a <= b);
        paint.shader = LinearGradient(
          begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [color, color.withValues(alpha: 0.1)],
        ).createShader(bar);
      } else {
        paint.color = color;
      }
      canvas.drawRect(bar, paint);
      canvas.drawRect(
        bar.deflate(0.5),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final axis = o.dataBarAxis;
    if (axis != null && axis > 0 && axis < 1) {
      final ax = x(axis);
      final p = Paint()
        ..color = axisColor
        ..strokeWidth = 1;
      for (var y = box.top; y < box.bottom; y += 3) {
        canvas.drawLine(
          Offset(ax, y),
          Offset(ax, math.min(box.bottom, y + 1.5)),
          p,
        );
      }
    }
  }

  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC04);
  static const _red = Color(0xFFEA4335);
  static const _gray = Color(0xFF80868B);
  static const _black = Color(0xFF3C4043);
  static const _gold = Color(0xFFF9AB00);
  static const _blue = Color(0xFF4285F4);

  /// Paints icon [index] of the icon set [setId] into [box] (a square).
  static void paintIcon(Canvas canvas, Rect box, String setId, int index) {
    final set = IconSetKind.byId(setId);
    if (set == null) return;
    final n = set.iconCount;
    final i = index.clamp(0, n - 1);
    final s = box.shortestSide;
    final c = box.center;
    final fill = Paint()..isAntiAlias = true;
    Color traffic(int i) => switch (n) {
      4 => const [_green, _yellow, _red, _black][i],
      _ => const [_green, _yellow, _red][i],
    };
    switch (set) {
      case IconSetKind.arrows3 ||
          IconSetKind.arrowsGray3 ||
          IconSetKind.arrows4 ||
          IconSetKind.arrows5:
        // Angles: 90° up … −90° down, spread over the icons.
        final angle = n == 1 ? 0.0 : 90 - 180 * i / (n - 1);
        final color = set == IconSetKind.arrowsGray3
            ? _gray
            : (i == 0
                  ? _green
                  : i == n - 1
                  ? _red
                  : _yellow);
        _arrow(canvas, c, s, angle * math.pi / 180, fill..color = color);
      case IconSetKind.triangles3:
        if (i == 1) {
          canvas.drawRect(
            Rect.fromCenter(center: c, width: s * 0.6, height: s * 0.18),
            fill..color = _yellow,
          );
        } else {
          final up = i == 0;
          final path = Path()
            ..moveTo(c.dx, c.dy + (up ? -s * 0.35 : s * 0.35))
            ..lineTo(c.dx + s * 0.4, c.dy + (up ? s * 0.3 : -s * 0.3))
            ..lineTo(c.dx - s * 0.4, c.dy + (up ? s * 0.3 : -s * 0.3))
            ..close();
          canvas.drawPath(path, fill..color = up ? _green : _red);
        }
      case IconSetKind.trafficLights3 || IconSetKind.trafficLights4:
        canvas.drawCircle(c, s * 0.42, fill..color = traffic(i));
        canvas.drawCircle(
          c,
          s * 0.42,
          Paint()
            ..color = const Color(0x33000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case IconSetKind.signs3:
        switch (i) {
          case 0:
            canvas.drawCircle(c, s * 0.4, fill..color = _green);
          case 1:
            final path = Path()
              ..moveTo(c.dx, c.dy - s * 0.42)
              ..lineTo(c.dx + s * 0.45, c.dy + s * 0.38)
              ..lineTo(c.dx - s * 0.45, c.dy + s * 0.38)
              ..close();
            canvas.drawPath(path, fill..color = _yellow);
          default:
            final path = Path()
              ..moveTo(c.dx, c.dy - s * 0.45)
              ..lineTo(c.dx + s * 0.45, c.dy)
              ..lineTo(c.dx, c.dy + s * 0.45)
              ..lineTo(c.dx - s * 0.45, c.dy)
              ..close();
            canvas.drawPath(path, fill..color = _red);
        }
      case IconSetKind.symbols3:
        final color = const [_green, _yellow, _red][i];
        canvas.drawCircle(c, s * 0.45, fill..color = color);
        final stroke = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1.2, s * 0.12);
        if (i == 0) {
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - s * 0.2, c.dy)
              ..lineTo(c.dx - s * 0.05, c.dy + s * 0.15)
              ..lineTo(c.dx + s * 0.22, c.dy - s * 0.15),
            stroke,
          );
        } else if (i == 1) {
          canvas.drawLine(
            Offset(c.dx, c.dy - s * 0.22),
            Offset(c.dx, c.dy + s * 0.05),
            stroke,
          );
          canvas.drawCircle(
            Offset(c.dx, c.dy + s * 0.2),
            s * 0.05,
            Paint()..color = const Color(0xFFFFFFFF),
          );
        } else {
          final d = s * 0.17;
          canvas.drawLine(c - Offset(d, d), c + Offset(d, d), stroke);
          canvas.drawLine(c + Offset(-d, d), c + Offset(d, -d), stroke);
        }
      case IconSetKind.flags3:
        final color = const [_green, _yellow, _red][i];
        final pole = Paint()
          ..color = _black
          ..strokeWidth = math.max(1, s * 0.08);
        final x0 = c.dx - s * 0.3;
        canvas.drawLine(
          Offset(x0, c.dy - s * 0.42),
          Offset(x0, c.dy + s * 0.45),
          pole,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x0, c.dy - s * 0.42)
            ..lineTo(c.dx + s * 0.38, c.dy - s * 0.2)
            ..lineTo(x0, c.dy + s * 0.04)
            ..close(),
          fill..color = color,
        );
      case IconSetKind.stars3:
        _star(canvas, c, s * 0.48, fillFraction: 1 - i / 2);
      case IconSetKind.ratings4 || IconSetKind.ratings5:
        final bars = n - 1;
        final filled = n - 1 - i;
        final w = s / (bars * 1.6);
        for (var k = 0; k < bars; k++) {
          final h = s * (0.3 + 0.6 * (k + 1) / bars);
          final left = box.left + k * w * 1.6 + w * 0.3;
          canvas.drawRect(
            Rect.fromLTWH(left, box.bottom - h - s * 0.05, w, h),
            Paint()..color = k < filled ? _blue : const Color(0x33808080),
          );
        }
      case IconSetKind.quarters5:
        final r = s * 0.42;
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = _black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        final sweep = 2 * math.pi * (4 - i) / 4;
        if (sweep > 0) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            -math.pi / 2,
            sweep,
            true,
            fill..color = _black,
          );
        }
    }
  }

  static void _arrow(
    Canvas canvas,
    Offset c,
    double s,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-angle + math.pi / 2);
    // Arrow pointing up before rotation.
    final path = Path()
      ..moveTo(0, -s * 0.45)
      ..lineTo(s * 0.4, -s * 0.02)
      ..lineTo(s * 0.14, -s * 0.02)
      ..lineTo(s * 0.14, s * 0.45)
      ..lineTo(-s * 0.14, s * 0.45)
      ..lineTo(-s * 0.14, -s * 0.02)
      ..lineTo(-s * 0.4, -s * 0.02)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  static void _star(
    Canvas canvas,
    Offset c,
    double r, {
    required double fillFraction,
  }) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rad = k.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + k * math.pi / 5;
      final p = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    if (fillFraction > 0) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          c.dx - r,
          c.dy - r,
          c.dx - r + 2 * r * fillFraction,
          c.dy + r,
        ),
      );
      canvas.drawPath(path, Paint()..color = _gold);
      canvas.restore();
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

/// A small widget rendering one icon of an icon set (CF panel).
class CfIconView extends StatelessWidget {
  const CfIconView({
    super.key,
    required this.setId,
    required this.index,
    this.size = 16,
  });

  final String setId;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _IconPainter(setId, index)),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.setId, this.index);

  final String setId;
  final int index;

  @override
  void paint(Canvas canvas, Size size) =>
      CfDecorations.paintIcon(canvas, Offset.zero & size, setId, index);

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.setId != setId || old.index != index;
}
