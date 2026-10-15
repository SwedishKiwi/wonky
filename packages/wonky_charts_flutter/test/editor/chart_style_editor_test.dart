import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';

import '../support.dart';

/// The shared Customize editor in override mode (Slides 08 §8.1, §20).
void main() {
  Finder key(String k) => find.byKey(ValueKey<String>(k));

  test('Given a path when a patch is built then it nests and resets with '
      'null', () {
    expect(ChartStyleEditor.patchAt(['series', 'a', 'color'], '#FF0000'), {
      'series': {
        'a': {'color': '#FF0000'},
      },
    });
    expect(ChartStyleEditor.patchAt(['title', 'text'], null), {
      'title': {'text': null},
    });
    final o = {
      'legend': {'position': 'top'},
    };
    expect(ChartStyleEditor.isOverridden(o, ['legend', 'position']), isTrue);
    expect(ChartStyleEditor.isOverridden(o, ['legend', 'font']), isFalse);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Given override mode (${brightness.name}, 300 px) when the '
        'editor shows a column chart then only allowed fields show, changed '
        'ones have a dot and a reset', (tester) async {
      final patches = <Map<String, Object?>>[];
      const spec = ChartSpec(type: ChartType.column);
      await pumpShad(
        tester,
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: ChartStyleEditor(
              spec: spec,
              data: twoSeries(),
              overrides: const {
                'legend': {'position': 'bottom'},
              },
              // Legend and titles only.
              allows: (p) => p.first == 'legend' || p.first == 'title',
              initiallyOpen: const {'titles', 'legend', 'series'},
              onPatch: (p, {coalesceKey}) => patches.add(p),
            ),
          ),
        ),
        size: const Size(300, 900),
        brightness: brightness,
      );
      expect(key('charts.style.title'), findsOneWidget);
      expect(key('charts.style.subtitle'), findsNothing);
      expect(key('charts.style.group.series'), findsNothing);
      expect(key('charts.style.changed.legend.position'), findsOneWidget);
      await tester.tap(key('charts.style.reset.legend.position'));
      expect(patches.single, {
        'legend': {'position': null},
      });
      await tester.enterText(key('charts.style.title'), 'Mine');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(patches.last, {
        'title': {'text': 'Mine'},
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Given full mode when a 3D pie is edited then the pie and 3D '
      'groups show', (tester) async {
    final spec = ChartSpec.fromJson(const {
      'v': 1,
      'type': 'pie',
      'threeD': {'enabled': true},
    });
    await pumpShad(
      tester,
      SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: ChartStyleEditor(
            spec: spec,
            data: twoSeries(),
            initiallyOpen: const {'pie', 'threeD'},
            onPatch: (p, {coalesceKey}) {},
          ),
        ),
      ),
      size: const Size(360, 1200),
    );
    expect(key('charts.style.group.pie'), findsOneWidget);
    expect(key('charts.style.group.threeD'), findsOneWidget);
    expect(key('charts.style.group.axes'), findsNothing);
    expect(find.text('Explode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
