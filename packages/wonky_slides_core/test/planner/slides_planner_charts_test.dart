import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/ops.dart';

import '../support/chart_fixture.dart';
import '../support/planner_fixture.dart';

void main() {
  final f = PlannerFixture();

  ResolvedChartSnapshot resolved({bool big = false}) {
    final snap = revenueSnapshot();
    var data = snap.dataSnapshot.encode();
    if (big) {
      // Pad the source info past 32 KB so the column is compressed.
      data = ChartDataSnapshot(
        data: snap.data,
        source: ChartSourceInfo(rangesA1: List.filled(4000, 'Q3!A1:C4')),
        version: 'log2:abc:43',
      ).encode();
    }
    return ResolvedChartSnapshot(
      spreadsheetUuid: '00000000-0000-4000-8000-0000000000e1',
      chartObjectId: '00000000-0000-4000-8000-0000000000e2',
      sourceSpecJson: snap.spec.encode(),
      dataSnapshotJson: data,
      sourceVersion: 'log2:abc:43',
    );
  }

  group('Given a linked chart', () {
    test('when updating with a large snapshot then gz: columns are stored and '
        'read back', () {
      final deck = f.session();
      deck.execute(ChartLinkOps.update(f.chart, resolved(big: true)));
      final link = deck.model.chartLinkOf(f.chart)!;
      expect(link.dataSnapshotJson, startsWith('gz:'));
      expect(link.sourceVersion, 'log2:abc:43');
      final snap = ChartSourceSnapshot.fromColumns(
        link.sourceSpecJson,
        link.dataSnapshotJson,
      );
      expect(snap.dataSnapshot.source.rangesA1, hasLength(4000));
    });

    test('when a gz: column is corrupt then the update is refused', () {
      final deck = f.session();
      expect(
        () => deck.execute(
          UpdateChartLink(
            f.chart,
            const ChartSnapshot(
              sourceSpecJson: '{"v":1}',
              dataSnapshotJson: 'gz:AAAA',
              sourceVersion: 'x',
            ),
          ),
        ),
        throwsA(
          isA<PlanException>().having(
            (e) => e.code,
            'code',
            PlanException.invalidArgument,
          ),
        ),
      );
    });

    test('when unlinking then the snapshot moves into dataJson.snapshot', () {
      final deck = f.session();
      deck.execute(ChartLinkOps.update(f.chart, resolved(big: true)));
      deck.execute(UnlinkChart(f.chart));
      expect(deck.model.chartLinkOf(f.chart), isNull);
      final data = ChartElementData.fromJson(
        deck.model.element(f.chart)!.dataJson,
      );
      expect(data.source, SlideChartSource.static);
      expect(data.snapshot!.spec.type, ChartType.column);
      expect(data.snapshot!.dataSnapshot.version, 'log2:abc:43');
      expect(data.spec, isNull);
      final raw = jsonDecode(deck.model.element(f.chart)!.dataJson!) as Map;
      expect(raw.containsKey('data'), isFalse);
    });

    test('when refreshing the token then only the version changes', () {
      final deck = f.session();
      final link = deck.model.chartLinkOf(f.chart)!;
      deck.execute(ChartLinkOps.refreshToken(link, 'new:abc:1'));
      final after = deck.model.chartLinkOf(f.chart)!;
      expect(after.sourceVersion, 'new:abc:1');
      expect(after.dataSnapshotJson, link.dataSnapshotJson);
      expect(
        ChartLinkOps.probesOf(deck.model).single.sourceVersion,
        'new:abc:1',
      );
    });
  });

  group('Given chart style patches', () {
    for (final (label, patch) in [
      (
        'a data override',
        {
          'overrides': {
            'data': {'aggregate': 'sum'},
          },
        },
      ),
      (
        'a series type override',
        {
          'overrides': {
            'series': {
              'north': {'type': 'line'},
            },
          },
        },
      ),
      ('a snapshot', {'snapshot': <String, Object?>{}}),
      ('a source change', {'source': 'native'}),
    ]) {
      test('when the patch has $label then it is refused', () {
        expect(
          () => f.session().execute(SetChartStyle(f.chart, patch)),
          throwsA(
            isA<PlanException>().having(
              (e) => e.code,
              'code',
              PlanException.invalidArgument,
            ),
          ),
        );
      });
    }

    test('when the patch is allowlisted then it is merged', () {
      final deck = f.session();
      deck.execute(
        SetChartStyle(f.chart, const {
          'overrides': {
            'legend': {'position': 'bottom'},
          },
          'camera': {'azimuth': 45, 'elevation': 30, 'perspective': 0},
        }),
      );
      final d = ChartElementData.fromJson(
        deck.model.element(f.chart)!.dataJson,
      );
      expect(d.overrides, {
        'legend': {'position': 'bottom'},
      });
      expect(d.camera!.azimuth, 45);
    });
  });
}
