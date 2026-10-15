import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/charts.dart';

import '../support/chart_fixture.dart';

void main() {
  group('Given a linked chart dataJson', () {
    final json = {
      'v': 1,
      'source': 'linked',
      'style': {
        'useDeckTheme': false,
        'palette': ['#112233'],
        'font': '@heading',
      },
      'camera': {'azimuth': 45, 'elevation': 35.264, 'perspective': 0},
      'overrides': {
        'legend': {'position': 'bottom'},
      },
      'background': 'theme',
      'interactive': {'hoverTooltips': true},
      'future': 'kept',
    };

    test('when parsing then every key is read', () {
      final d = ChartElementData.fromJson(jsonEncode(json));
      expect(d.source, SlideChartSource.linked);
      expect(d.style.useDeckTheme, isFalse);
      expect(d.style.palette, ['#112233']);
      expect(d.style.font, '@heading');
      expect(d.camera, Chart3DView.presets['isometric']);
      expect(d.overrides['legend'], {'position': 'bottom'});
      expect(d.background, 'theme');
      expect(d.interactive.hoverTooltips, isTrue);
      expect(d.interactive.orbitInPresent, isFalse);
      expect(d.extras, {'future': 'kept'});
    });

    test('when writing then the JSON round-trips', () {
      final d = ChartElementData.fromJson(json);
      final back = ChartElementData.fromJson(d.toJson());
      expect(back.toJson(), d.toJson());
      expect(d.toJson()['future'], 'kept');
    });

    test('when copying then the camera and background can be cleared', () {
      final d = ChartElementData.fromJson(
        json,
      ).copyWith(clearCamera: true, clearBackground: true);
      expect(d.camera, isNull);
      expect(d.background, isNull);
    });
  });

  group('Given static charts', () {
    test('when the snapshot is stored then it is read', () {
      final d = ChartElementData.fromJson({
        'source': 'static',
        'snapshot': revenueSnapshot().toJson(),
      });
      expect(d.source, SlideChartSource.static);
      expect(d.snapshot!.data.series.first.key, 'north');
      expect(d.snapshot!.dataSnapshot.source.spreadsheetTitle, 'Finance 2026');
    });

    test(
      'when written by the M9 planner (spec + data) then it is migrated',
      () {
        final snap = revenueSnapshot();
        final d = ChartElementData.fromJson({
          'source': 'static',
          'spec': snap.spec.toJson(),
          'data': snap.dataSnapshot.toJson(),
        });
        expect(d.snapshot!.spec.type, ChartType.column);
        expect(d.snapshot!.data.series, hasLength(2));
        expect(d.spec, isNull);
        expect(d.data, isNull);
      },
    );

    test(
      'when pasted unlinked from Sheets (spec only) then there is no data',
      () {
        final d = ChartElementData.fromJson({
          'source': 'static',
          'spec': {'type': 'pie'},
        });
        expect(d.snapshot!.spec.type, ChartType.pie);
        expect(d.snapshot!.dataSnapshot.isPlaceholder, isTrue);
      },
    );
  });

  group('Given invalid dataJson', () {
    test('when parsing then defaults are used', () {
      final d = ChartElementData.fromJson('nope');
      expect(d.source, SlideChartSource.linked);
      expect(d.style.useDeckTheme, isTrue);
      expect(ChartElementData.fromJson(null).camera, isNull);
    });
  });
}
