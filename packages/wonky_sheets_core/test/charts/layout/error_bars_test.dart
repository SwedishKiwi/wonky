import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/chart_test_support.dart';

List<ScenePrimitive> _where(
  List<ScenePrimitive> list,
  bool Function(ScenePrimitive p) test,
) {
  final out = <ScenePrimitive>[];
  void visit(ScenePrimitive p) {
    if (test(p)) out.add(p);
    if (p is SGroup) p.children.forEach(visit);
    if (p is SClip) p.children.forEach(visit);
  }

  list.forEach(visit);
  return out;
}

void main() {
  group('Given error bar settings', () {
    test('when computing extents then constant, percent and stdev follow '
        'the values', () {
      const values = [10.0, 20.0, double.nan, 30.0];
      expect(const ErrorBarsSpec(value: 2).extents(values).take(2), [2, 2]);
      expect(
        const ErrorBarsSpec(
          type: ErrorBarType.percent,
          value: 10,
        ).extents(values),
        [1, 2, isNaN, 3],
      );
      final sd = const ErrorBarsSpec(
        type: ErrorBarType.stdev,
        value: 2,
      ).extents(values);
      expect(sd.first, closeTo(20, 1e-9), reason: 'sample sd 10 × 2');
    });

    test('when parsing JSON then show: false disables them and bad values '
        'fall back', () {
      expect(ErrorBarsSpec.fromJson(null), isNull);
      expect(ErrorBarsSpec.fromJson({'show': false}), isNull);
      final e = ErrorBarsSpec.fromJson({'type': 'percent', 'value': -1})!;
      expect((e.type, e.value), (ErrorBarType.percent, 10));
      expect(
        ChartSpecSchema.validate({
          'v': 1,
          'type': 'column',
          'data': const <String, Object?>{},
          'series': {
            'k': {
              'errorBars': {'type': 'bogus'},
            },
          },
        }),
        isNotEmpty,
      );
    });
  });

  group('Given a column chart with error bars on one series', () {
    test('when laid out then whiskers are drawn for that series and the '
        'value axis covers them', () {
      final model = buildTable([
        ['Region', 'Sales', 'Costs'],
        ['North', 10, 4],
        ['South', 20, 6],
      ]).$2;
      final base = specFor(model, 'A1:C3');
      final key = columnKey(model, 'B');
      final spec = base.patch({
        'series': {
          key: {
            'errorBars': {'type': 'constant', 'value': 15},
          },
        },
      });
      final scene = sceneOf(spec, model);
      final bars = _where(
        scene.primitives,
        (p) => p.tag?.detail == 'errorBars',
      );
      expect(bars, hasLength(1));
      expect(bars.single.tag?.seriesKey, key);
      final path = bars.single as SPath;
      // 2 points × (whisker + 2 caps) × (move + line).
      expect(path.cmds, hasLength(12));
      final labels = _where(
        scene.primitives,
        (p) => p is SText && p.tag?.role == SceneRole.axisLabel,
      ).map((p) => (p as SText).text).toList();
      expect(labels.last, '40', reason: '20 + 15 is on the scale');
      expect(labels, contains('-10'), reason: '10 - 15 is on the scale');
    });

    test('when the series is stacked then no error bars are drawn', () {
      final model = buildTable([
        ['Region', 'Sales', 'Costs'],
        ['North', 10, 4],
      ]).$2;
      final key = columnKey(model, 'B');
      final spec = specFor(model, 'A1:C2').patch({
        'stacking': 'normal',
        'series': {
          key: {
            'errorBars': {'value': 5},
          },
        },
      });
      final scene = sceneOf(spec, model);
      expect(
        _where(scene.primitives, (p) => p.tag?.detail == 'errorBars'),
        isEmpty,
      );
    });
  });
}
