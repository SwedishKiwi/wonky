import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

void main() {
  group('Given an ink stroke', () {
    test('when encoded then points are quantized to 0.5 units and it parses '
        'back', () {
      final s = InkStroke(
        id: 'a',
        tool: InkTool.highlighter,
        color: 0xffef4444,
        width: 8,
        points: const [Offset(1.26, 2.74), Offset(10, 10)],
      );
      final back = InkStroke.tryParse(s.encode())!;
      expect(back.tool, InkTool.highlighter);
      expect(back.points.first, const Offset(1.5, 2.5));
      expect(back.touches(const Offset(5, 6), 1), isTrue);
      expect(back.touches(const Offset(50, 6), 1), isFalse);
    });

    test('when the JSON is malformed or not a drawing tool then parsing '
        'returns null', () {
      expect(InkStroke.tryParse('nope'), isNull);
      expect(
        InkStroke.tryParse(
          '{"id":"a","tool":"laser","color":1,"width":2,"points":[]}',
        ),
        isNull,
      );
    });

    test('when extended then the path passes through every point', () {
      final s = InkStroke(
        id: 'a',
        tool: InkTool.pen,
        color: 0xff000000,
        width: 2,
        points: const [Offset.zero],
      ).extend(const Offset(10, 0)).extend(const Offset(10, 10));
      expect(s.points, hasLength(3));
      final metric = s.path().computeMetrics().single;
      final end = metric.getTangentForOffset(metric.length)!.position;
      expect(end.dx, closeTo(10, 0.01));
      expect(end.dy, closeTo(10, 0.01));
    });
  });

  test('Given a one-euro filter when the input jitters slowly then it is '
      'smoothed, and the first sample passes through', () {
    final f = OneEuroFilter();
    expect(f.filter(const Offset(10, 10), 0), const Offset(10, 10));
    final out = f.filter(const Offset(12, 10), 16);
    expect(out.dx, greaterThan(10));
    expect(out.dx, lessThan(12));
  });

  group('Given the stroke painter', () {
    for (final b in Brightness.values) {
      testWidgets('when painting pen and highlighter strokes in ${b.name} '
          'then it paints without errors', (tester) async {
        final strokes = [
          InkStroke(
            id: 'p',
            tool: InkTool.pen,
            color: 0xffef4444,
            width: 4,
            points: const [Offset(10, 10), Offset(50, 40), Offset(90, 20)],
          ),
          InkStroke(
            id: 'h',
            tool: InkTool.highlighter,
            color: 0xfff59e0b,
            width: 20,
            points: const [Offset(10, 60), Offset(90, 60)],
          ),
        ];
        await pumpWonky(
          tester,
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: InkStrokePainter(
                strokes: strokes,
                scale: 2,
                darkBackground: b == Brightness.dark,
              ),
            ),
          ),
          brightness: b,
          center: true,
        );
        expect(tester.takeException(), isNull);
        final painter = InkStrokePainter(strokes: strokes, scale: 2);
        expect(
          painter.shouldRepaint(InkStrokePainter(strokes: strokes, scale: 2)),
          isFalse,
        );
        expect(
          painter.shouldRepaint(InkStrokePainter(strokes: strokes)),
          isTrue,
        );
        expect(
          painter.shouldRepaint(
            InkStrokePainter(strokes: [...strokes, strokes.first], scale: 2),
          ),
          isTrue,
        );
      });
    }
  });
}
