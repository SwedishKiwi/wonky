import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/themes.dart';

import '../support/chart_fixture.dart';
import '../support/scene_fixture.dart';

void main() {
  final light = SceneFixture().resolve().theme;
  final dark = SceneFixture().resolve(appearance: SlideAppearance.dark).theme;

  SlideChartLook look(
    Map<String, Object?> dataJson, {
    ResolvedTheme? theme,
    int? background,
    ChartSourceSnapshot? snapshot,
  }) => SlideChartSpec.effective(
    snapshot: snapshot ?? revenueSnapshot(threeD: true),
    element: ChartElementData.fromJson(dataJson),
    deckTheme: theme ?? light,
    slideBackground: background,
  );

  group('Given a chart matching the deck theme', () {
    final l = look({
      'style': {'useDeckTheme': true},
    });

    test(
      'when computing the spec then the sheet colors and fonts are replaced',
      () {
        expect(l.spec.seriesStyle('north').color, isNull);
        expect(l.spec.style.palette, isNull);
        expect(
          l.spec.style.fontFamily,
          light.font(light.chartStyle.font).family,
        );
        expect(
          l.spec.title.font.family,
          light.font(const FontRef('@heading')).family,
        );
        expect(l.spec.title.font.bold, isTrue);
        expect(l.spec.threeD.floorColor, isNotNull);
      },
    );

    test(
      'when computing the theme then the deck palette is used on a transparent '
      'background',
      () {
        expect(l.theme.background, 0);
        expect(l.theme.palette.first, light.chartPalette.first | 0xFF000000);
        expect(
          l.theme.source.accentArgbs.first,
          light.colorOf('accent1')! | 0xFF000000,
        );
        expect(l.locale, 'en_US');
      },
    );

    test('when the slide is dark then the text is light', () {
      final d = look({
        'style': {'useDeckTheme': true},
      }, background: 0xFF101010);
      expect(
        ChartTheme.contrast(d.theme.text, 0xFF101010),
        greaterThanOrEqualTo(4.5),
      );
      expect(d.theme.isDark, isTrue);
    });
  });

  group('Given a chart keeping its source style', () {
    final l = look({
      'style': {'useDeckTheme': false},
    });

    test(
      'when computing then the sheet palette, fonts and background are kept',
      () {
        expect(l.spec.seriesStyle('north').color, '#FF0000');
        expect(l.spec.title.font.family, 'Comic Neue');
        expect(l.theme.background, 0xFFFFF8E1);
        expect(l.spec.style.background, isNull);
        expect(l.theme.source.accentArgbs.first, 0xFF4285F4);
        expect(l.theme.fontFamily, 'Roboto');
      },
    );

    test(
      'when the background is transparent on a dark slide then text is light',
      () {
        final d = look(
          {
            'style': {'useDeckTheme': false},
            'background': 'transparent',
          },
          theme: dark,
          background: 0xFF000000,
        );
        expect(d.theme.background, 0);
        expect(d.theme.isDark, isTrue);
        expect(d.theme.text, 0xFFFAFAFA);
      },
    );

    test(
      'when the snapshot has no source theme then the deck accents are used',
      () {
        final s = revenueSnapshot();
        final noTheme = ChartSourceSnapshot(
          spec: s.spec,
          dataSnapshot: ChartDataSnapshot(data: s.data),
        );
        final d = look({
          'style': {'useDeckTheme': false},
        }, snapshot: noTheme);
        expect(
          d.theme.source.accentArgbs.first,
          light.colorOf('accent1')! | 0xFF000000,
        );
      },
    );
  });

  group('Given deck-side settings', () {
    test('when a palette and font are set then they apply', () {
      final l = look({
        'style': {
          'useDeckTheme': true,
          'palette': ['#123456'],
          'font': '@mono',
        },
      });
      expect(l.spec.style.palette, ['#123456']);
      expect(
        l.spec.style.fontFamily,
        light.font(const FontRef('@mono')).family,
      );
    });

    test('when overrides are set then the allowlisted ones apply', () {
      final l = look({
        'overrides': {
          'legend': {'position': 'bottom'},
          'type': 'pie',
          'series': {
            'north': {'color': '#00FF00', 'type': 'line'},
          },
        },
      });
      expect(l.spec.legend.position, LegendPosition.bottom);
      expect(l.spec.type, ChartType.column);
      expect(l.spec.seriesStyle('north').color, '#00FF00');
      expect(l.spec.seriesStyle('north').type, isNull);
      expect(l.warnings, isEmpty);
    });

    test('when an override is invalid then it is dropped with a warning', () {
      final l = look({
        'overrides': {
          'legend': {'position': 'sideways'},
          'title': {'text': 'Kept'},
        },
      });
      expect(l.spec.title.text, 'Kept');
      expect(l.warnings, [SlideChartSpec.invalidOverrides]);
    });

    test('when a camera is set then it goes into threeD', () {
      final l = look({'camera': Chart3DView.presets['isometric']!.toJson()});
      expect(l.spec.threeD.azimuth, 45);
      expect(l.spec.threeD.elevation, closeTo(35.264, 1e-9));
      expect(l.spec.threeD.perspective, 0);
    });

    test('when the background is a color then the chart is drawn on it', () {
      final l = look({'background': '#202020'});
      expect(l.theme.background, 0xFF202020);
      expect(l.theme.isDark, isTrue);
    });
  });
}
