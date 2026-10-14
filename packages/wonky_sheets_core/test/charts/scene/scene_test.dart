import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/charts/charts.dart';

ChartScene sceneWith(List<ScenePrimitive> p) =>
    ChartScene(width: 200, height: 100, background: 0xFFFFFFFF, primitives: p);

void main() {
  group('Given a path builder', () {
    test('when adding a quarter arc then it ends on the circle', () {
      final b = PathBuilder()..arc(0, 0, 10, 0, math.pi / 2);
      final end = b.commands.last as PCubicTo;

      expect(b.commands.first, const PMoveTo(10, 0));
      expect(end.x, closeTo(0, 1e-9));
      expect(end.y, closeTo(10, 1e-9));
    });

    test('when adding a polygon then it is closed', () {
      final b = PathBuilder()..polygon([0, 0, 10, 0, 10, 10]);

      expect(b.commands, [
        const PMoveTo(0, 0),
        const PLineTo(10, 0),
        const PLineTo(10, 10),
        const PClose(),
      ]);
    });

    test('when flattening a circle then a point inside is contained', () {
      final b = PathBuilder()
        ..arc(50, 50, 20, 0, math.pi)
        ..arc(50, 50, 20, math.pi, math.pi)
        ..close();
      final polys = PathGeometry.flatten(b.commands);

      expect(PathGeometry.containsPoint(polys, 50, 50), isTrue);
      expect(PathGeometry.containsPoint(polys, 75, 50), isFalse);
    });
  });

  group('Given text primitives', () {
    const style = TextStyleSpec(size: 10);

    test(
      'when anchored at the center then the box is centered on the point',
      () {
        const t = SText(
          'Hi',
          ChartPoint(100, 50),
          style,
          anchor: TextAnchor.center,
          width: 20,
          height: 12,
          ascent: 9,
        );

        expect(t.box, const ChartRect(90, 44, 20, 12));
      },
    );

    test('when rotated by 90° then the bounds swap width and height', () {
      const t = SText(
        'Hi',
        ChartPoint(100, 50),
        style,
        anchor: TextAnchor.center,
        angle: math.pi / 2,
        width: 20,
        height: 12,
        ascent: 9,
      );

      expect(t.bounds.width, closeTo(12, 1e-9));
      expect(t.bounds.height, closeTo(20, 1e-9));
      expect(t.containsPoint(100, 58, 0), isTrue);
      expect(t.containsPoint(108, 50, 0), isFalse);
    });
  });

  group('Given a scene with a column, a line and markers', () {
    final scene = sceneWith([
      const SRect(
        ChartRect(0, 0, 200, 100),
        fill: 0xFFFFFFFF,
        tag: SceneTag(SceneRole.background),
      ),
      const SRect(
        ChartRect(10, 40, 20, 60),
        fill: 0xFF0000FF,
        tag: SceneTag(SceneRole.point, seriesKey: 'a', pointIndex: 3),
      ),
      SPolyline(
        Float64List.fromList([50, 50, 100, 50, 150, 80]),
        const SStroke(0xFF000000, width: 2),
        indices: Int32List.fromList([4, 5, 7]),
        tag: const SceneTag(SceneRole.series, seriesKey: 'b'),
      ),
      SClip(const ChartRect(0, 0, 120, 100), [
        SMarkers(
          Float64List.fromList([100, 20, 180, 20]),
          MarkerShape.circle,
          8,
          fill: 0xFFFF0000,
          tag: const SceneTag(SceneRole.point, seriesKey: 'c'),
        ),
      ]),
    ]);

    test('when hitting inside the column then its point is found', () {
      final hit = scene.hitTest(20, 70)!;

      expect(
        hit.tag,
        const SceneTag(SceneRole.point, seriesKey: 'a', pointIndex: 3),
      );
      expect(hit.distance, 0);
    });

    test(
      'when hitting near a line vertex then the vertex point index is resolved',
      () {
        final hit = scene.hitTest(101, 53)!;

        expect(hit.tag.seriesKey, 'b');
        expect(hit.tag.pointIndex, 5);
      },
    );

    test('when hitting a marker then it wins over the line below', () {
      final hit = scene.hitTest(100, 22)!;

      expect(hit.tag.seriesKey, 'c');
      expect(hit.tag.pointIndex, 0);
    });

    test('when a marker is outside its clip then it is not hit', () {
      final hit = scene.hitTest(180, 20);

      expect(hit?.tag.seriesKey, isNot('c'));
    });

    test('when nothing tagged is near then only the background is hit', () {
      expect(scene.hitTest(190, 95)!.tag.role, SceneRole.background);
    });

    test('when flattening then clips are expanded in paint order', () {
      expect(scene.flattened.map((p) => p.typeId), [
        'rect',
        'rect',
        'polyline',
        'markers',
      ]);
    });

    test('when encoding then numbers are rounded and colors are hex', () {
      final json = scene.toJson();

      expect(json['bg'], '#FFFFFFFF');
      final p = json['p']! as List;
      expect((p[1] as Map)['fill'], '#FF0000FF');
      expect((p[2] as Map)['indices'], [4, 5, 7]);
    });
  });

  group('Given a doughnut slice', () {
    const arc = SArc(
      ChartPoint(50, 50),
      40,
      -math.pi / 2,
      math.pi / 2,
      innerRadius: 20,
      fill: 0xFF00FF00,
      tag: SceneTag(SceneRole.point, pointIndex: 0),
    );

    test('when hit in the ring then it is found, in the hole it is not', () {
      final scene = sceneWith([arc]);

      expect(scene.hitTest(70, 30, tolerance: 0)?.tag.pointIndex, 0);
      expect(scene.hitTest(55, 45, tolerance: 0), isNull);
      expect(scene.hitTest(30, 70, tolerance: 0), isNull);
    });

    test('when converted to a path then it has outer and inner arcs', () {
      final cmds = arc.toPath();

      expect(cmds.first, isA<PMoveTo>());
      expect(cmds.last, const PClose());
      expect(cmds.whereType<PCubicTo>().length, 2);
    });
  });

  group('Given color helpers', () {
    test('when applying opacity then alpha is scaled', () {
      expect(Argb.withOpacity(0xFF112233, 0.5), 0x80112233);
    });

    test('when mixing then channels interpolate', () {
      expect(Argb.lerp(0xFF000000, 0xFFFFFFFF, 0.5), 0xFF808080);
    });

    test('when formatting then hex strings are upper case', () {
      expect(argbHex(0x80FF00AA), '#80FF00AA');
      expect(Argb.rgbHex(0x80FF00AA), '#FF00AA');
    });
  });
}
