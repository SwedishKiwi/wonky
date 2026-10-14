import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../io/support/ir_corpus.dart';
import '../support/chart_test_support.dart';

void main() {
  group('Given a surface chart of 6 months × 3 regions', () {
    late WorkbookModel m;
    late ChartScene scene;
    setUp(() {
      m = monthlyRevenue();
      scene = sceneOf(specFor(m, 'A1:D7', type: ChartType.surface), m);
    });

    test('when laid out then it is always 3D with one patch per grid cell '
        'colored by value band', () {
      expect(ChartType.surface.only3D, isTrue);
      expect(specFor(m, 'A1:D7', type: ChartType.surface).is3D, isTrue);
      final s3 = scene.threeD!;
      final patches = s3.model.dataItems.whereType<Chart3DPatch>().toList();
      // (6 − 1) months × (3 − 1) region pairs.
      expect(patches, hasLength(10));
      expect(patches.map((p) => p.color).toSet().length, greaterThan(1));
      expect(Chart3DMesher.mesh(patches.first).single.faces, hasLength(2));
    });

    test('when the legend is drawn then it lists the value bands', () {
      final legend = textsOf(scene, SceneRole.legendEntry);
      expect(legend, isNotEmpty);
      expect(legend.every((t) => t.contains(' – ')), isTrue);
    });

    test('when picking the middle of a patch then its series and point are '
        'hit', () {
      final s3 = scene.threeD!;
      final p = s3.model.dataItems.whereType<Chart3DPatch>().first;
      var x = 0.0, y = 0.0, z = 0.0;
      for (final c in p.corners) {
        x += c.x / 4;
        y += c.y / 4;
        z += c.z / 4;
      }
      final at = s3.camera.project(Vec3(x, y, z));
      final hit = s3.pick(at.x, at.y);
      expect(hit, isNotNull);
      expect(hit!.tag.pointIndex, p.tag!.pointIndex);
    });

    test('when exported as SVG then it renders', () {
      final spec = specFor(m, 'A1:D7', type: ChartType.surface);
      final svg = ChartPipeline.exportSvg(
        spec: spec,
        model: m,
        values: ModelCellSource(m),
        size: const ChartSize(400, 300),
      );
      expect(svg, contains('<svg'));
    });
  });

  group('Given a 3D column chart with a hovered column', () {
    late WorkbookModel m;
    setUp(() => m = monthlyRevenue());

    test('when laid out then that column is lighter than without hover, '
        'and the GPU mesh hash changes', () {
      final spec = specFor(
        m,
        'A1:D7',
      ).copyWith(threeD: const ChartThreeD(enabled: true));
      final plain = sceneOf(spec, m);
      final box = plain.threeD!.model.dataItems.whereType<Chart3DBox>().first;
      final hovered = sceneOf(
        spec,
        m,
        options: ChartLayoutOptions(hover3D: box.tag),
      );
      List<int> fills(ChartScene s) => [
        for (final p in s.flattened.whereType<SPath>())
          if (p.tag == box.tag && p.fill != null) p.fill!,
      ];
      int luma(int c) => ((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF);
      final a = fills(plain), b = fills(hovered);
      expect(a, isNotEmpty);
      expect(b.length, a.length);
      for (var i = 0; i < a.length; i++) {
        expect(luma(b[i]), greaterThan(luma(a[i])));
      }
      final chunk = hovered.threeD!.chunks.firstWhere(
        (c) => c.item.key == box.key,
      );
      expect(hovered.threeD!.isHovered(chunk), isTrue);
      expect(hovered.threeD!.meshHash, isNot(plain.threeD!.meshHash));
      expect(
        hovered.threeD!.model.contentHash,
        plain.threeD!.model.contentHash,
        reason: 'hover does not animate',
      );
    });
  });

  group('Given a surface chart in a workbook', () {
    test('when exported to XLSX and imported again then it is a 3-D surface '
        'chart both ways', () {
      final doc = IrCorpus.charts();
      final sheet = doc.sheets.single;
      final data = sheet.charts.first.spec['data'];
      sheet.charts
        ..clear()
        ..add(
          IrChart(
            anchor: const IrAnchor(row: 0, col: 4, width: 480, height: 300),
            spec: {'v': 1, 'type': 'surface', 'data': data},
          ),
        );
      final bytes = XlsxExporter.export(
        doc,
        XlsxExportOptions(modified: DateTime.utc(2026, 3, 4)),
      );
      final xml = ZipPackage.open(bytes).text('xl/charts/chart1.xml')!;
      expect(xml, contains('<c:surface3DChart>'));
      expect(xml, contains('<c:serAx>'));
      final back = XlsxImporter.import(bytes);
      expect(back.sheets.single.charts.single.spec['type'], 'surface');
    });
  });

  group('Given a 3D line chart', () {
    late WorkbookModel m;
    setUp(() => m = monthlyRevenue());

    ChartSpec line(Map<String, Object?> patch) => specFor(
      m,
      'A1:D7',
      type: ChartType.line,
    ).copyWith(threeD: const ChartThreeD(enabled: true)).patch(patch);

    test('when smooth then the ribbons are sampled densely and picking maps '
        'back to the points', () {
      final plain = sceneOf(line(const {}), m).threeD!;
      final smooth = sceneOf(
        line(const {
          'style': {'smooth': true},
        }),
        m,
      ).threeD!;
      final a = plain.model.dataItems.whereType<Chart3DSlab>().first;
      final b = smooth.model.dataItems.whereType<Chart3DSlab>().first;
      expect(a.xs, hasLength(6));
      expect(b.xs, hasLength(5 * 8 + 1));
      expect(b.pointIndexOf(16), 2);
      expect(b.tops[8], closeTo(a.tops[1], 1e-9), reason: 'through points');
    });

    test('when data labels and a trendline are on then labels sit on the '
        'ribbon and the trendline is a ribbon of its own', () {
      final key = columnKey(m, 'B');
      final scene = sceneOf(
        line({
          'series': {
            key: {
              'dataLabels': {'show': true},
              'trendline': {'type': 'linear'},
            },
          },
        }),
        m,
      );
      final s3 = scene.threeD!;
      expect(
        s3.model.labels.where((l) => l.tag?.role == SceneRole.dataLabel),
        hasLength(6),
      );
      expect(
        s3.model.dataItems.whereType<Chart3DSlab>().where(
          (x) => x.tag?.role == SceneRole.trendline,
        ),
        hasLength(1),
      );
    });

    test('when a 3D column chart has a trendline then it is drawn in front of '
        'the columns', () {
      final key = columnKey(m, 'C');
      final spec = specFor(m, 'A1:D7')
          .copyWith(threeD: const ChartThreeD(enabled: true))
          .patch({
            'series': {
              key: {
                'trendline': {'type': 'movingAverage', 'period': 2},
              },
            },
          });
      final s3 = sceneOf(spec, m).threeD!;
      final t = s3.model.dataItems.whereType<Chart3DSlab>().single;
      expect(t.tag?.seriesKey, key);
      expect(t.tops.first.isNaN, isTrue, reason: 'no average for point 1');
    });
  });
}
