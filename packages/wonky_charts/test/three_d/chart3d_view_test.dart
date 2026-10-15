import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

import '../support/sample_data.dart';

void main() {
  group('Given two views across 0/360', () {
    const a = Chart3DView(azimuth: 350, elevation: 10, perspective: 10);
    const b = Chart3DView(azimuth: 20, elevation: 40, perspective: 30);

    test('when lerping halfway then the azimuth takes the short arc', () {
      final v = Chart3DView.lerp(a, b, 0.5);
      expect(v.azimuth, closeTo(5, 1e-9));
      expect(v.elevation, closeTo(25, 1e-9));
      expect(v.perspective, closeTo(20, 1e-9));
    });

    test('when lerping clockwise backwards then it goes the long way', () {
      final v = Chart3DView.lerp(b, a, 0.5, turn: Chart3DTurn.cw);
      // 20 → 350 clockwise = +330, halfway = 185.
      expect(v.azimuth, closeTo(185, 1e-9));
    });

    test('when lerping counter-clockwise then the azimuth decreases', () {
      final v = Chart3DView.lerp(a, b, 0.5, turn: Chart3DTurn.ccw);
      // 350 → 20 counter-clockwise = −330, halfway = 185.
      expect(v.azimuth, closeTo(185, 1e-9));
    });

    test('when lerping with an extra turn then the delta grows by 360', () {
      expect(Chart3DView.azimuthDelta(350, 20, turns: 1), closeTo(390, 1e-9));
      expect(Chart3DView.lerp(a, b, 1, turns: 1).azimuth, closeTo(20, 1e-9));
    });

    test('when at the ends then the views equal the inputs', () {
      expect(Chart3DView.lerp(a, b, 0), a);
      expect(Chart3DView.lerp(a, b, 1), b);
      expect(Chart3DView.lerp(a, b, 7), b);
    });
  });

  group('Given exactly opposite azimuths', () {
    test('when lerping the shortest way then the tie turns clockwise', () {
      expect(Chart3DView.azimuthDelta(0, 180), 180);
      expect(Chart3DView.azimuthDelta(90, 90, turn: Chart3DTurn.ccw), 0);
    });
  });

  group('Given JSON and specs', () {
    test('when parsing out-of-range values then they are clamped', () {
      final v = Chart3DView.fromJson({
        'azimuth': 400,
        'elevation': 120,
        'perspective': 99,
      })!;
      expect(v.elevation, 90);
      expect(v.perspective, 60);
      expect(v.normalized.azimuth, 40);
    });

    test('when keys are missing then the fallback fills them', () {
      final v = Chart3DView.fromJson({
        'elevation': 30,
      }, fallback: Chart3DView.presets['front']);
      expect(v, const Chart3DView(azimuth: 0, elevation: 30, perspective: 10));
      expect(Chart3DView.fromJson('x'), isNull);
    });

    test('when reading a pie spec then the pie defaults apply', () {
      final spec = ChartSpec.fromJson({
        'type': 'pie',
        'threeD': {'enabled': true},
      });
      expect(
        Chart3DView.of(spec),
        const Chart3DView(azimuth: 0, elevation: 40, perspective: 15),
      );
    });

    test('when applying a view then the spec angles change', () {
      final t = Chart3DView.presets['isometric']!.applyTo(
        const ChartThreeD(enabled: true),
      );
      expect(t.azimuth, 45);
      expect(t.elevation, closeTo(35.264, 1e-9));
      expect(t.perspective, 0);
      expect(
        Chart3DView.fromJson(Chart3DView.presets['side']!.toJson()),
        Chart3DView.presets['side'],
      );
    });

    test('when asking for a pie preset then the pie table is used', () {
      expect(Chart3DView.preset('flat', type: ChartType.pie)!.elevation, 85);
      expect(Chart3DView.preset('flat'), isNull);
    });
  });

  group('Given a 3D chart animating between two views', () {
    const spec = ChartSpec(
      type: ChartType.column,
      threeD: ChartThreeD(enabled: true),
    );
    Chart3DScene scene(ChartLayoutOptions options) => ChartPipeline.layout(
      spec,
      sampleData(),
      size: const ChartSize(600, 371),
      theme: sampleTheme,
      measurer: const ApproxTextMeasurer(),
      options: options,
    ).scene.threeD!;

    test(
      'when fitting for the union then the zoom never exceeds either fit',
      () {
        final front = Chart3DView.presets['front']!;
        final iso = Chart3DView.presets['isometric']!;
        final at = Chart3DView.lerp(front, iso, 0.5);
        final options = ChartLayoutOptions(
          azimuth3D: at.azimuth,
          elevation3D: at.elevation,
          perspective3D: at.perspective,
        );
        final free = scene(options);
        final pinned = scene(
          ChartLayoutOptions(
            azimuth3D: at.azimuth,
            elevation3D: at.elevation,
            perspective3D: at.perspective,
            fitViews3D: [front, iso],
          ),
        );
        expect(
          pinned.camera.scale,
          lessThanOrEqualTo(free.camera.scale + 1e-9),
        );
        expect(pinned.model.fov, at.perspective);
      },
    );

    test('when the only view is the current one then the fit is unchanged', () {
      final v = Chart3DView.of(spec);
      final free = scene(const ChartLayoutOptions());
      final pinned = scene(ChartLayoutOptions(fitViews3D: [v]));
      expect(pinned.camera.scale, closeTo(free.camera.scale, 1e-6));
    });
  });
}
