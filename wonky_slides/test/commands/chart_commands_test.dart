import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/config/slides_features.dart';
import 'package:wonky_slides/features/elements/chart/chart_api.dart';
import 'package:wonky_slides/features/elements/chart/chart_links.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';
import 'package:wonky_charts/wonky_charts.dart'
    show ChartDataSnapshot, ChartSourceSnapshot;
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart' show ChartSnapshot, UpdateChartLink;

import '../features/elements/chart/chart_fixture.dart';
import '../harness/deck_harness.dart';

void main() {
  late DeckHarness d;
  late FakeChartApi api;
  late String slide, linked, stat;

  void open({bool threeD = false, bool autoUpdate = false}) {
    final f = chartDeck(threeD: threeD, autoUpdate: autoUpdate);
    slide = f.slide;
    linked = f.linked;
    stat = f.static;
    d = DeckHarness.open(fixture: f.b);
    api = FakeChartApi();
    SlidesChartApi.install(d.services, api);
    d.editor.setCurrentSlide(slide);
  }

  setUp(() {
    SlidesFeatures.enabled = {...SlidesFeatures.shipped, SlidesFeature.charts};
  });
  tearDown(() async {
    await d.dispose();
    SlidesFeatures.reset();
  });

  Future<CommandResult> agent(
    String id, [
    Map<String, Object?> args = const {},
  ]) => d.h.invoke(id, args, InvocationSource.mcp);

  /// 08 §19 #10: execute → undo → redo, one undo step.
  Future<CommandResult> roundTrip(String id, Map<String, Object?> args) async {
    final before = d.model.dump();
    final steps = d.undoLabels.length;
    final r = await agent(id, args);
    expect(r.status, CommandStatus.ok, reason: '$id: ${r.message}');
    final after = d.model.dump();
    expect(after, isNot(equals(before)), reason: '$id changed nothing');
    expect(d.undoLabels.length, steps + 1, reason: '$id: one undo step');
    await d.undo();
    expect(d.model.dump(), before, reason: '$id undo');
    await d.redo();
    expect(d.model.dump(), after, reason: '$id redo');
    return r;
  }

  ChartElementData data(String id) =>
      ChartElementData.fromJson(d.model.element(id)!.dataJson);

  group('Given a deck with a linked and a static chart', () {
    setUp(open);

    test('when a chart is inserted from Sheets by id then a linked chart '
        'with its snapshot arrives in one undo step', () async {
      final r = await roundTrip('slides.insert.chartFromSheets', {
        'spreadsheetUuid': sheetUuid,
        'chartObjectIds': [chartId],
      });
      final id = ((r.data! as Map)['elementIds'] as List).single as String;
      final link = d.model.chartLinkOf(id)!;
      expect(link.chartObjectId, chartId);
      expect(link.sourceVersion, 'log1.1:aaaa:42');
      expect(data(id).source, SlideChartSource.linked);
      expect(data(id).style.useDeckTheme, isTrue);
      final e = d.model.element(id)!;
      expect(e.altText, contains('Revenue by region'));
      // Centered at 70 % of the slide width.
      expect(e.width, closeTo(1920 * 0.7, 1));
      expect(e.x, closeTo((1920 - e.width!) / 2, 1));
    });

    test('when it is inserted without the link then it is a static chart '
        'with its snapshot and no ChartLink', () async {
      final r = await roundTrip('slides.insert.chartFromSheets', {
        'spreadsheetUuid': sheetUuid,
        'chartObjectIds': [chartId, chart3dId],
        'link': false,
        'useDeckTheme': false,
      });
      final ids = ((r.data! as Map)['elementIds'] as List).cast<String>();
      expect(ids, hasLength(2));
      for (final id in ids) {
        expect(d.model.chartLinkOf(id), isNull);
        expect(data(id).source, SlideChartSource.static);
        expect(data(id).snapshot?.data.series, hasLength(2));
        expect(data(id).style.useDeckTheme, isFalse);
      }
      // Two charts side by side.
      final a = d.model.element(ids[0])!, b = d.model.element(ids[1])!;
      expect(b.x, greaterThan(a.x! + a.width!));
    });

    test('when an empty chart placeholder is selected then the insert '
        'fills it', () async {
      final b = chartDeck();
      final ph = b.b.element(
        b.slide,
        ElementKind.chart,
        columns: const {'placeholderType': 'chart', 'dataJson': '{"v":1}'},
      );
      await d.dispose();
      d = DeckHarness.open(fixture: b.b);
      api = FakeChartApi();
      SlidesChartApi.install(d.services, api);
      d.editor
        ..setCurrentSlide(b.slide)
        ..selectElements([ph]);
      final r = await roundTrip('slides.insert.chartFromSheets', {
        'spreadsheetUuid': sheetUuid,
        'chartObjectIds': [chartId],
      });
      expect((r.data! as Map)['elementIds'], [ph]);
      expect(d.model.chartLinkOf(ph), isNotNull);
    });

    test('when an agent inserts without ids, or offline, then it fails with '
        'the 08 §4.3 messages', () async {
      final r = await agent('slides.insert.chartFromSheets');
      expect(r.status, CommandStatus.failed);
      api.errors[chartId] = ChartApiError.exportDisabled;
      final e = await agent('slides.insert.chartFromSheets', {
        'spreadsheetUuid': sheetUuid,
        'chartObjectIds': [chartId],
      });
      expect(e.message, slidesL10nEnglish.chartErrExportDisabled);
      api.online = false;
      final st = d.services.dispatcher.stateOf('slides.insert.chartFromSheets');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, slidesL10nEnglish.chartErrOffline);
    });

    test('when the source changed then Update writes the new snapshot in '
        'one step, keeps overrides and camera, and undo shows Update '
        'again', () async {
      await agent('slides.chart.updateStyle', {
        'elementId': linked,
        'patch': {
          'title': {'text': 'Mine'},
        },
      });
      api.snapshots[chartId] = resolved(
        version: 'log2.2:aaaa:43',
        north: 99,
        extra: true,
      );
      api.statuses[linked] = ChartLinkStatusData(
        elementId: linked,
        status: ChartLinkStatusCode.changed,
        newVersion: 'log2.2:aaaa:43',
        summary: 'Data changed',
      );
      final links = ChartLinks.of(d.editor);
      await links.check();
      expect(links.statusOf(linked), ChartLinkStatusCode.changed);
      expect(links.changedIds, [linked]);

      await roundTrip('slides.chart.update', {'elementId': linked});
      final link = d.model.chartLinkOf(linked)!;
      expect(link.sourceVersion, 'log2.2:aaaa:43');
      expect(
        ChartSourceSnapshot.fromColumns(
          link.sourceSpecJson,
          link.dataSnapshotJson,
        ).data.series,
        hasLength(3),
      );
      expect(data(linked).overrides['title'], {'text': 'Mine'});
      expect(links.statusOf(linked), ChartLinkStatusCode.upToDate);
      await d.undo();
      expect(links.statusOf(linked), ChartLinkStatusCode.changed);
    });

    test('when several links changed then Update all is one step', () async {
      api.statuses[linked] = ChartLinkStatusData(
        elementId: linked,
        status: ChartLinkStatusCode.changed,
        newVersion: 'log2.2:aaaa:43',
      );
      api.snapshots[chartId] = resolved(version: 'log2.2:aaaa:43');
      await ChartLinks.of(d.editor).check();
      await roundTrip('slides.chart.update', {'all': true});
      expect(ChartLinks.of(d.editor).changedIds, isEmpty);
    });

    test('when the source chart is gone then Update fails and the badge '
        'says so', () async {
      api.errors[chartId] = ChartApiError.chartNotFound;
      final r = await agent('slides.chart.update', {'elementId': linked});
      expect(r.status, CommandStatus.failed);
      expect(
        ChartLinks.of(d.editor).statusOf(linked),
        ChartLinkStatusCode.chartDeleted,
      );
    });

    test(
      'when Update automatically is set then it toggles in one step',
      () async {
        await roundTrip('slides.chart.setAutoUpdate', {'elementId': linked});
        expect(d.model.chartLinkOf(linked)!.autoUpdate, isTrue);
        final st = d.services.dispatcher.stateOf('slides.chart.setAutoUpdate', {
          'elementId': linked,
        });
        expect(st.checked, isTrue);
      },
    );

    test('when it is unlinked then the snapshot moves into the element and '
        'the link row is deleted', () async {
      await roundTrip('slides.chart.unlink', {'elementId': linked});
      expect(d.model.chartLinkOf(linked), isNull);
      expect(data(linked).source, SlideChartSource.static);
      expect(data(linked).snapshot?.data.series, hasLength(2));
      // Static charts are not linked: no Update.
      expect(
        d.services.dispatcher.stateOf('slides.chart.update', {
          'elementId': linked,
        }).enabled,
        isFalse,
      );
    });

    test('when a static chart is relinked then it is linked again without '
        'its frozen snapshot', () async {
      await roundTrip('slides.chart.relink', {
        'elementId': stat,
        'spreadsheetUuid': sheetUuid,
        'chartObjectId': chart3dId,
      });
      expect(d.model.chartLinkOf(stat)!.chartObjectId, chart3dId);
      expect(data(stat).source, SlideChartSource.linked);
      expect(
        jsonDecode(d.model.element(stat)!.dataJson!),
        isNot(contains('snapshot')),
      );
    });

    test('when the restyle and style overrides are edited then the '
        'allowlist is enforced', () async {
      await roundTrip('slides.chart.setUseDeckTheme', {
        'elementId': linked,
        'useDeckTheme': false,
      });
      expect(data(linked).style.useDeckTheme, isFalse);
      await roundTrip('slides.chart.updateStyle', {
        'elementId': linked,
        'patch': {
          'legend': {'position': 'bottom'},
          'series': {
            'north': {'color': '#FF0000'},
          },
        },
        'options': {'background': 'transparent'},
      });
      expect(data(linked).overrides['legend'], {'position': 'bottom'});
      expect(data(linked).background, 'transparent');
      final bad = await agent('slides.chart.updateStyle', {
        'elementId': linked,
        'patch': {'type': 'pie'},
      });
      expect(bad.status, CommandStatus.failed);
      expect(bad.message, startsWith('invalid_args'));
      final bad2 = await agent('slides.chart.updateStyle', {
        'elementId': linked,
        'options': {'snapshot': null},
      });
      expect(bad2.status, CommandStatus.failed);
      await roundTrip('slides.chart.resetOverrides', {'elementId': linked});
      expect(data(linked).overrides, isEmpty);
    });

    test(
      'when style edits share a coalesce key then they are one undo step',
      () async {
        final steps = d.undoLabels.length;
        for (final t in ['A', 'AB', 'ABC']) {
          await agent('slides.chart.updateStyle', {
            'elementId': linked,
            'patch': {
              'title': {'text': t},
            },
            'coalesceKey': 'title',
          });
        }
        expect(d.undoLabels.length, steps + 1);
        await d.undo();
        expect(data(linked).overrides, isEmpty);
      },
    );

    test('when the data table is asked for by an agent then the rows come '
        'back', () async {
      final r = await agent('slides.chart.viewDataTable', {'elementId': stat});
      final m = r.data! as Map;
      expect(m['headers'], ['Month', 'North', 'South']);
      expect((m['rows'] as List).first, ['Jan', '10', '30']);
    });

    test(
      'when the source is opened then the Sheets route selects the chart',
      () async {
        final r = await agent('slides.chart.openSource', {'elementId': linked});
        expect(
          (r.data! as Map)['path'],
          '/sheets/s/$sheetUuid?object=$chartId',
        );
      },
    );

    test('when links are checked then statuses come back, unchanged charts '
        'get the newer token without an undo step', () async {
      api.statuses[linked] = ChartLinkStatusData(
        elementId: linked,
        status: ChartLinkStatusCode.upToDate,
        newVersion: 'log9.9:aaaa:42',
      );
      final steps = d.undoLabels.length;
      final r = await agent('slides.chart.checkUpdates');
      expect((r.data! as Map)['charts'], [
        {'elementId': linked, 'status': 'upToDate'},
      ]);
      expect(d.model.chartLinkOf(linked)!.sourceVersion, 'log9.9:aaaa:42');
      expect(d.undoLabels.length, steps);
    });

    test('when a chart pasted without data is checked then its first '
        'snapshot is written as maintenance', () async {
      d.session.execute(
        UpdateChartLink(
          linked,
          ChartSnapshot(
            sourceSpecJson: jsonEncode(sheetSpec()),
            dataSnapshotJson: '{"v":1}',
            sourceVersion: '',
          ),
        ),
      );
      final steps = d.undoLabels.length;
      await ChartLinks.of(d.editor).check();
      final link = d.model.chartLinkOf(linked)!;
      expect(link.sourceVersion, 'log1.1:aaaa:42');
      expect(
        ChartDataSnapshot.fromJson(link.dataSnapshotJson).isPlaceholder,
        isFalse,
      );
      expect(d.undoLabels.length, steps);
    });
  });

  group('Given a linked chart with Update automatically', () {
    setUp(() => open(autoUpdate: true));

    test('when its source changed then the editor applies the update without '
        'an undo step', () async {
      api.snapshots[chartId] = resolved(version: 'log2.2:bbbb:43', north: 1);
      api.statuses[linked] = ChartLinkStatusData(
        elementId: linked,
        status: ChartLinkStatusCode.changed,
        newVersion: 'log2.2:bbbb:43',
      );
      final steps = d.undoLabels.length;
      await ChartLinks.of(d.editor).check();
      expect(d.model.chartLinkOf(linked)!.sourceVersion, 'log2.2:bbbb:43');
      expect(d.undoLabels.length, steps);
    });
  });

  group('Given a linked 3D chart', () {
    setUp(() => open(threeD: true));

    test('when a camera preset is applied then dataJson.camera is set in '
        'one step and Reset clears it', () async {
      d.editor.selectElements([linked]);
      await roundTrip('slides.chart.setCamera', {'preset': 'isometric'});
      expect(data(linked).camera?.azimuth, 45);
      expect(data(linked).camera?.elevation, closeTo(35.3, 0.05));
      await agent('slides.chart.setCamera', {'reset': true});
      expect(data(linked).camera, isNull);
    });

    test(
      'when the camera is rotated by keys then the steps coalesce',
      () async {
        d.editor.selectElements([linked]);
        final steps = d.undoLabels.length;
        await d.run('slides.chart.setCamera', {'deltaAzimuth': 5});
        await d.run('slides.chart.setCamera', {'deltaAzimuth': 5});
        await d.run('slides.chart.setCamera', {'deltaElevation': -5});
        expect(d.undoLabels.length, steps + 1);
        expect(data(linked).camera?.azimuth, 30);
        expect(data(linked).camera?.elevation, 15);
        expect(d.undoLabels.first, slidesL10nEnglish.undoRotateChart);
      },
    );

    test('when a 2D chart is selected then the camera is unavailable', () {
      d.editor.selectElements([stat]);
      final st = d.services.dispatcher.stateOf('slides.chart.setCamera');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, slidesL10nEnglish.reasonSelect3DChart);
    });
  });
}
