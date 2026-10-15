import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

void main() {
  group('Given opaque data range references (Slides 08 §2.4)', () {
    const range = {'s': 'sheet-1', 'r1': 'row-a', 'c1': 'col-a', 'r1k': 'k'};

    test('when a spec round-trips then the ranges are stored unchanged', () {
      final json = {
        'v': 1,
        'type': 'column',
        'data': {
          'ranges': [range],
        },
        'typeOptions': {'keyValueRef': range},
      };
      final spec = ChartSpec.fromJson(json);
      expect(spec.data.ranges.single.sourceId, 'sheet-1');
      expect(jsonEncode(spec.data.toJson()['ranges']), jsonEncode([range]));
      expect(ChartSpec.fromJson(jsonDecode(jsonEncode(spec.toJson()))), spec);
    });

    test('when parsing JSON text then it reads like the map', () {
      expect(DataRangeRef.tryParse(jsonEncode(range)), DataRangeRef(range));
    });

    test('when the source id is missing then it is not a reference', () {
      expect(DataRangeRef.tryParse({'r1': 'x'}), isNull);
      expect(DataRangeRef.tryParse('not json'), isNull);
      expect(DataRangeRef.tryParse(42), isNull);
      expect(() => DataRangeRef(const {'s': 1}), throwsArgumentError);
      final spec = ChartSpec.fromJson({
        'v': 1,
        'type': 'column',
        'data': {
          'ranges': [
            {'r1': 'x'},
            range,
          ],
        },
      });
      expect(spec.data.ranges, [DataRangeRef(range)]);
    });

    test('when validating then a range without a source id is reported', () {
      final issues = ChartSpecSchema.validate({
        'v': 1,
        'type': 'column',
        'data': {
          'ranges': [
            {'r1': 'x'},
          ],
        },
      });
      expect(issues.single.path, 'data.ranges[0]');
    });

    test('when comparing then null values are ignored and order is not', () {
      expect(
        DataRangeRef(const {'s': 'a', 'r1': 'x', 'r2': null}),
        DataRangeRef(const {'r1': 'x', 's': 'a'}),
      );
      expect(
        DataRangeRef(const {'s': 'a'}).hashCode,
        DataRangeRef(const {'s': 'a'}).hashCode,
      );
    });
  });
}
