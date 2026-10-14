import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/chart_test_support.dart';

const _box = Chart3DBox(
  'b',
  0xFF3366CC,
  SceneTag(SceneRole.point, seriesKey: 's', pointIndex: 0),
  min: Vec3(0, 0, -0.5),
  max: Vec3(1, 2, 0.5),
);

ChartSpec _spec3D(
  WorkbookModel m,
  String a1,
  ChartType type, {
  Map<String, Object?> threeD = const {},
  ChartStacking stacking = ChartStacking.none,
  Map<String, Object?> typeOptions = const {},
}) => specFor(m, a1, type: type, typeOptions: typeOptions).copyWith(
  stacking: stacking,
  threeD: ChartThreeD.fromJson({'enabled': true, ...threeD}),
);

void _expectClose(Vec3 a, Vec3 b, [double eps = 1e-9]) {
  expect(a.x, closeTo(b.x, eps));
  expect(a.y, closeTo(b.y, eps));
  expect(a.z, closeTo(b.z, eps));
}

void main() {
  group('Given the threeD spec section', () {
    test('when parsing defaults then nothing is written back', () {
      final t = ChartThreeD.fromJson(const {});

      expect(t.enabled, isFalse);
      expect(t.toJson(), isEmpty);
    });

    test('when parsing out-of-range values then they are clamped', () {
      final t = ChartThreeD.fromJson(const {
        'enabled': true,
        'azimuth': -30,
        'elevation': 120,
        'perspective': 99,
        'depth': 5,
        'explode': 3,
      });

      expect(t.azimuth, 330);
      expect(t.elevation, 90);
      expect(t.perspective, ChartThreeD.maxPerspective);
      expect(t.depth, 20);
      expect(t.explode, 1);
    });

    test('when a spec round-trips then threeD is kept', () {
      final spec = ChartSpec.fromJson({
        'v': 1,
        'type': 'column',
        'data': {'ranges': <Object?>[]},
        'threeD': {'enabled': true, 'azimuth': 40, 'lighting': 'bright'},
      });

      expect(spec.is3D, isTrue);
      expect(spec.toJson()['threeD'], {
        'enabled': true,
        'azimuth': 40,
        'lighting': 'bright',
      });
    });

    test(
      'when patched through the schema then invalid values are rejected',
      () {
        const spec = ChartSpec();

        expect(
          () => spec.patch({
            'threeD': {'elevation': 120},
          }),
          throwsA(isA<ChartSpecValidationException>()),
        );
        expect(
          spec
              .patch({
                'threeD': {'enabled': true, 'shape': 'cylinder'},
              })
              .threeD
              .shape,
          Chart3DShape.cylinder,
        );
      },
    );

    test(
      'when the type changes then threeD stays and only applies to 3D types',
      () {
        final spec = const ChartSpec(
          threeD: ChartThreeD(enabled: true),
        ).withType(ChartType.scatter);

        expect(spec.threeD.enabled, isTrue);
        expect(spec.is3D, isFalse);
        expect(spec.withType(ChartType.pie).is3D, isTrue);
      },
    );

    test('when reading the JSON schema then threeD is described', () {
      final props =
          (ChartSpecSchema.jsonSchema()['properties']! as Map)['threeD'] as Map;

      expect((props['properties']! as Map).keys, contains('azimuth'));
    });
  });

  group('Given an orbit camera fitted to a box', () {
    final bounds = Aabb3(const Vec3(0, 0, -0.5), const Vec3(2, 1, 0.5));
    const viewport = ChartRect(10, 20, 300, 200);
    final camera = Chart3DCamera.fit(
      bounds: bounds,
      azimuthDeg: 25,
      elevationDeg: 20,
      fovDeg: 20,
      viewport: viewport,
    );

    test('when projecting the corners then they fit the viewport', () {
      for (final p in bounds.corners) {
        final q = camera.project(p);
        expect(
          q.x,
          inInclusiveRange(viewport.left - 1e-6, viewport.right + 1e-6),
        );
        expect(
          q.y,
          inInclusiveRange(viewport.top - 1e-6, viewport.bottom + 1e-6),
        );
      }
    });

    test(
      'when casting a ray through a projected point then it passes the point',
      () {
        const p = Vec3(1.5, 0.75, 0.25);
        final q = camera.project(p);
        final (o, d) = camera.ray(q.x, q.y);

        _expectClose(d, (p - o).normalized, 1e-9);
      },
    );

    test('when mapped like a GPU perspective camera then the pixels agree', () {
      const p = Vec3(0.3, 0.9, -0.4);
      final v = p - camera.eye;
      final zf = v.dot(camera.forward);
      final k = 1 / math.tan(camera.gpuFovY / 2);
      final g = camera.gpuViewport;
      final x = g.centerX + g.height / 2 * k * v.dot(camera.right) / zf;
      final y = g.centerY - g.height / 2 * k * v.dot(camera.up) / zf;
      final q = camera.project(p);

      expect(x, closeTo(q.x, 1e-6));
      expect(y, closeTo(q.y, 1e-6));
    });

    test('when the azimuth grows then the eye moves toward +x', () {
      expect(camera.eye.x, greaterThan(bounds.center.x));
      expect(camera.eye.z, greaterThan(bounds.center.z));
      expect(camera.eye.y, greaterThan(bounds.center.y));
    });
  });

  group('Given the mesher', () {
    test('when meshing a box then it has 6 outward faces', () {
      final faces = Chart3DMesher.mesh(_box).single.faces;

      expect(faces, hasLength(6));
      for (final f in faces) {
        expect(f.normal.length, closeTo(1, 1e-9));
        expect((f.centroid - _box.center).dot(f.normal), greaterThan(0));
        _expectClose(polygonNormal(f.points), f.normal, 1e-9);
      }
    });

    test(
      'when meshing a cylinder then its sides are smooth and its caps flat',
      () {
        const cyl = Chart3DBox(
          'c',
          0xFF000000,
          null,
          min: Vec3(0, 0, 0),
          max: Vec3(1, 1, 1),
          shape: Chart3DShape.cylinder,
        );
        final faces = Chart3DMesher.mesh(cyl).single.faces;

        expect(faces, hasLength(Chart3DMesher.cylinderSegments + 2));
        expect(faces.where((f) => f.normals != null), hasLength(40));
        expect(faces.last.normal.y, closeTo(1, 1e-9));
      },
    );

    test('when meshing a cone then the sides meet in a tip', () {
      const cone = Chart3DBox(
        'c',
        0xFF000000,
        null,
        min: Vec3(0, 0, 0),
        max: Vec3(1, 1, 1),
        shape: Chart3DShape.cone,
      );
      final sides = Chart3DMesher.mesh(
        cone,
      ).single.faces.where((f) => f.points.length == 3);

      expect(sides, hasLength(Chart3DMesher.cylinderSegments));
      for (final f in sides) {
        expect(f.points.any((p) => p.y == 1 && p.x == 0.5), isTrue);
      }
    });

    test('when meshing a wedge then bottoms, sides and tops are layered', () {
      const w = Chart3DWedge(
        'w',
        0xFF000000,
        null,
        center: Vec3.zero,
        start: 0,
        sweep: math.pi / 2,
        radius: 1,
        innerRadius: 0.4,
        height: 0.2,
      );
      final chunks = Chart3DMesher.mesh(w);

      expect(chunks.first.layer, 0);
      expect(chunks.last.layer, 20);
      expect(chunks.last.faces.single.normal.y, 1);
      expect(
        chunks.where((c) => c.layer == 10).expand((c) => c.faces).length,
        greaterThan(4),
      );
    });

    test(
      'when meshing a slab then each half segment maps to its nearest point',
      () {
        final s = Chart3DSlab(
          's',
          0xFF000000,
          const SceneTag(SceneRole.series, seriesKey: 'k'),
          xs: Float64List.fromList([0, 1, 2]),
          tops: Float64List.fromList([1, 2, 1]),
          bottoms: Float64List.fromList([0, 0, 0]),
          z0: -0.1,
          z1: 0.1,
        );
        final chunks = Chart3DMesher.mesh(s);

        expect(
          [for (final c in chunks) c.effectiveTag!.pointIndex],
          [0, 1, 1, 2],
        );
      },
    );

    test('when a profile crosses its base then the segment is split there', () {
      final s = Chart3DSlab(
        's',
        0xFF000000,
        null,
        xs: Float64List.fromList([0, 2]),
        tops: Float64List.fromList([1, -3]),
        bottoms: Float64List.fromList([0, 0]),
        z0: 0,
        z1: 1,
      );

      expect(Chart3DMesher.mesh(s), hasLength(3));
    });

    test('when values are missing then the slab breaks into runs', () {
      final s = Chart3DSlab(
        's',
        0xFF000000,
        null,
        xs: Float64List.fromList([0, 1, 2, 3]),
        tops: Float64List.fromList([1, double.nan, 1, 1]),
        bottoms: Float64List.fromList([0, double.nan, 0, 0]),
        z0: 0,
        z1: 1,
      );

      // A single point and a two-point run (two halves).
      expect(Chart3DMesher.mesh(s), hasLength(3));
    });
  });

  group('Given a 3D column chart of 6 months × 3 regions', () {
    late WorkbookModel m;
    late ChartScene scene;
    setUp(() {
      m = monthlyRevenue();
      scene = sceneOf(_spec3D(m, 'A1:D7', ChartType.column), m);
    });

    test('when laid out then it has a 3D scene with one box per value', () {
      final s3 = scene.threeD!;

      expect(s3.model.kind, Chart3DKind.cartesian);
      expect(s3.model.dataItems.whereType<Chart3DBox>(), hasLength(18));
      expect(
        s3.model.items.where((i) => i.part == Chart3DPart.wall),
        hasLength(2),
      );
    });

    test(
      'when laid out then the geometry group and labels are in the scene',
      () {
        final group = scene.primitives.whereType<SGroup>().singleWhere(
          (g) => g.tag?.detail == ChartScene.chart3dGroupDetail,
        );

        expect(group.children, isNotEmpty);
        expect(textsOf(scene, SceneRole.axisLabel, detail: 'h'), [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
        ]);
        expect(
          textsOf(scene, SceneRole.axisLabel, detail: 'v'),
          contains('30'),
        );
      },
    );

    test('when picking the top of a column then that point is hit', () {
      final s3 = scene.threeD!;
      final box = s3.model.dataItems.whereType<Chart3DBox>().firstWhere(
        (b) => b.tag!.pointIndex == 2 && b.tag!.seriesKey == columnKey(m, 'C'),
      );
      final top = s3.camera.project(
        Vec3(box.center.x, box.max.y, box.center.z),
      );
      final hit = s3.pick(top.x, top.y + 1)!;

      expect(hit.tag.seriesKey, columnKey(m, 'C'));
      expect(hit.tag.pointIndex, 2);
    });

    test('when picking the empty corner then nothing is hit', () {
      expect(scene.threeD!.pick(1, 1), isNull);
    });

    test('when painted then nearer columns come after farther ones', () {
      final s3 = scene.threeD!;
      final paths = scene.flattened.whereType<SPath>().toList();
      int lastIndexOf(int point, String col) => paths.lastIndexWhere(
        (p) =>
            p.tag?.pointIndex == point && p.tag?.seriesKey == columnKey(m, col),
      );
      // The camera is right of the chart: the right neighbour is nearer.
      expect(s3.camera.eye.x, greaterThan(s3.model.bounds.center.x));
      expect(lastIndexOf(0, 'C'), greaterThan(lastIndexOf(0, 'B')));
      expect(lastIndexOf(1, 'B'), greaterThan(lastIndexOf(0, 'D')));
    });

    test(
      'when lit softly then large faces get gradients, flat lighting has none',
      () {
        final flat = sceneOf(
          _spec3D(m, 'A1:D7', ChartType.column, threeD: {'lighting': 'flat'}),
          m,
        );

        expect(
          scene.flattened.whereType<SPath>().where((p) => p.gradient != null),
          isNotEmpty,
        );
        expect(
          flat.flattened.whereType<SPath>().where((p) => p.gradient != null),
          isEmpty,
        );
      },
    );

    test('when walls are hidden then there is no floor or wall', () {
      final s = sceneOf(
        _spec3D(m, 'A1:D7', ChartType.column, threeD: {'wallsVisible': false}),
        m,
      );

      expect(
        s.threeD!.model.items.where((i) => i.part != Chart3DPart.data),
        isEmpty,
      );
    });

    test('when orbiting to the other side then the side wall moves', () {
      double sideX(ChartScene s) => s.threeD!.model.items
          .whereType<Chart3DBox>()
          .singleWhere((b) => b.key == 'frame:side')
          .center
          .x;
      final left = sceneOf(
        _spec3D(m, 'A1:D7', ChartType.column, threeD: {'azimuth': 30}),
        m,
      );
      final right = sceneOf(
        _spec3D(m, 'A1:D7', ChartType.column, threeD: {'azimuth': 330}),
        m,
      );

      expect(sideX(left), lessThan(sideX(right)));
    });

    test(
      'when a series is highlighted then the others fade to the background',
      () {
        final s = layoutChart(
          _spec3D(m, 'A1:D7', ChartType.column),
          resolveChart(_spec3D(m, 'A1:D7', ChartType.column), m),
          options: ChartLayoutOptions(highlightSeriesKey: columnKey(m, 'B')),
        ).scene;
        final colors = {
          for (final b in s.threeD!.model.dataItems) b.tag!.seriesKey: b.color,
        };

        expect(
          colors[columnKey(m, 'B')],
          s.threeD!.model.dataItems.first.color,
        );
        expect(
          colors[columnKey(m, 'C')],
          isNot(scene.threeD!.model.dataItems.elementAt(6).color),
        );
      },
    );

    test('when animating from other data then values are interpolated', () {
      final spec = _spec3D(m, 'A1:D7', ChartType.column);
      final data = resolveChart(spec, m);
      final to = scene.threeD!.model;
      final from = Chart3DModel.lerp(to, to, 1);
      final half = layoutChart(
        spec,
        data,
        options: ChartLayoutOptions(
          transitionFrom3D: Chart3DModel(
            kind: from.kind,
            items: const [],
            labels: const [],
            bounds: from.bounds,
            azimuth: from.azimuth,
            elevation: from.elevation,
            fov: from.fov,
            lighting: from.lighting,
            background: from.background,
            floorY: 0,
          ),
          transition3D: 0.5,
        ),
      ).scene.threeD!.model;
      final a = to.dataItems.first as Chart3DBox;
      final b = half.dataItems.first as Chart3DBox;

      expect(b.max.y - b.min.y, closeTo((a.max.y - a.min.y) / 2, 1e-9));
    });
  });

  group('Given other 3D chart types', () {
    late WorkbookModel m;
    setUp(() => m = monthlyRevenue());

    test('when stacked to 100 % then every stack reaches the top', () {
      final s = sceneOf(
        _spec3D(m, 'A1:D7', ChartType.column, stacking: ChartStacking.percent),
        m,
      ).threeD!;
      final tops = <int, double>{};
      for (final b in s.model.dataItems.whereType<Chart3DBox>()) {
        final i = b.tag!.pointIndex!;
        tops[i] = math.max(tops[i] ?? 0, b.max.y);
      }

      expect(tops.values.toSet(), hasLength(1));
    });

    test('when drawing bars then values run along x', () {
      final s = sceneOf(_spec3D(m, 'A1:D7', ChartType.bar), m).threeD!;
      final bars = s.model.dataItems.whereType<Chart3DBox>().toList();

      expect(bars.every((b) => b.axis == 0), isTrue);
      expect(bars.every((b) => b.min.x <= 1e-9), isTrue);
    });

    test('when drawing lines then each series is a ribbon row', () {
      final s = sceneOf(_spec3D(m, 'A1:D13', ChartType.line), m).threeD!;
      final slabs = s.model.dataItems.whereType<Chart3DSlab>().toList();

      expect(slabs, hasLength(3));
      expect(slabs[0].z0, greaterThan(slabs[1].z0));
      expect(slabs[0].xs, hasLength(12));
    });

    test('when drawing a stacked area then slabs share one row', () {
      final s = sceneOf(
        _spec3D(m, 'A1:D13', ChartType.area, stacking: ChartStacking.normal),
        m,
      ).threeD!;
      final slabs = s.model.dataItems.whereType<Chart3DSlab>().toList();

      expect(slabs.map((x) => x.z0).toSet(), hasLength(1));
      expect(slabs[1].bottoms[0], closeTo(slabs[0].tops[0], 1e-9));
    });

    test(
      'when drawing a pie then each positive value is a wedge with a label',
      () {
        final scene = sceneOf(
          _spec3D(m, 'A1:B7', ChartType.pie, threeD: {'explode': 0.2}),
          m,
        );
        final wedges = scene.threeD!.model.dataItems
            .whereType<Chart3DWedge>()
            .toList();

        expect(wedges, hasLength(6));
        expect(
          wedges.fold(0.0, (s, w) => s + w.sweep),
          closeTo(2 * math.pi, 1e-9),
        );
        expect(wedges.every((w) => w.offset > 0), isTrue);
        expect(textsOf(scene, SceneRole.dataLabel), hasLength(6));
      },
    );

    test('when drawing a doughnut then wedges are hollow', () {
      final s = sceneOf(
        _spec3D(m, 'A1:B7', ChartType.pie, typeOptions: {'pieHole': 0.5}),
        m,
      ).threeD!;

      expect(
        s.model.dataItems.whereType<Chart3DWedge>().first.innerRadius,
        0.5,
      );
    });

    test(
      'when the theme is dark then the floor is lighter than the background',
      () {
        final dark = ChartTheme.from(
          SpreadsheetTheme.standard,
          dark: true,
          export: true,
        );
        final s = sceneOf(
          _spec3D(m, 'A1:D7', ChartType.column),
          m,
          theme: dark,
        );
        final floor = s.threeD!.model.items.firstWhere(
          (i) => i.part == Chart3DPart.floor,
        );

        expect(
          Chart3DShading.luma(floor.color),
          greaterThan(Chart3DShading.luma(s.background)),
        );
      },
    );

    test('when exported as SVG then gradients are defined', () {
      final svg = const SvgChartRenderer().render(
        sceneOf(_spec3D(m, 'A1:D7', ChartType.column), m),
      );

      expect(svg, contains('<linearGradient'));
      expect(svg, contains('fill="url(#wcg0)"'));
    });

    test('when exported as PNG then the raster renderer draws it', () {
      final png = const RasterChartRenderer().render(
        sceneOf(_spec3D(m, 'A1:D7', ChartType.column), m),
      );

      expect(png.sublist(1, 4), 'PNG'.codeUnits);
    });

    test('when described then the description says 3D', () {
      final spec = _spec3D(m, 'A1:D7', ChartType.column);

      expect(
        ChartDescriber.describe(spec, resolveChart(spec, m)),
        startsWith('3D Column chart'),
      );
    });
  });
}
