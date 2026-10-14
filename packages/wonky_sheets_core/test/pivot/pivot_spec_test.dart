import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/pivot/pivot.dart';

void main() {
  group('Given a full PivotSpec JSON', () {
    const json = {
      'v': 1,
      'rows': [
        {
          'source': 'c1',
          'label': 'Area',
          'showTotals': false,
          'order': 'desc',
          'sortByValue': {'valueIndex': 0},
          'repeatLabels': true,
          'group': {
            'kind': 'manual',
            'groups': [
              {
                'name': 'East',
                'items': ['NY', 'MA'],
              },
            ],
            'ungrouped': 'Other',
          },
        },
      ],
      'columns': [
        {
          'source': 'c2',
          'label': null,
          'showTotals': true,
          'order': 'asc',
          'sortByValue': null,
          'repeatLabels': false,
          'group': {'kind': 'date', 'unit': 'yearMonth'},
        },
      ],
      'values': [
        {
          'source': 'c3',
          'formula': null,
          'summarizeBy': 'varp',
          'name': null,
          'showAs': 'percentOfColumnTotal',
          'numberFormat': '0.0',
        },
      ],
      'filters': [
        {
          'source': 'c4',
          'criteria': {
            'hiddenValues': ['x'],
          },
        },
      ],
      'valueLayout': 'rows',
      'showEmptyGroups': false,
    };

    test('when parsing and encoding then the JSON round-trips', () {
      final spec = PivotSpec.parse(jsonEncode(json));

      expect(spec.toJson(), json);
      expect(spec, PivotSpec.parse(json));
    });

    test('when parsing then every part is decoded', () {
      final spec = PivotSpec.parse(json);
      final row = spec.rows.single;

      expect(row.ascending, isFalse);
      expect(row.sortByValueIndex, 0);
      expect(
        row.group,
        isA<PivotManualGrouping>().having(
          (g) => g.ungrouped,
          'ungrouped',
          'Other',
        ),
      );
      expect(
        spec.columns.single.group,
        isA<PivotDateGrouping>().having(
          (g) => g.unit,
          'unit',
          PivotDateUnit.yearMonth,
        ),
      );
      expect(spec.values.single.summarizeBy, PivotSummarize.variancep);
      expect(spec.values.single.showAs, PivotShowAs.percentOfColumnTotal);
      expect(spec.filters.single.criteria.hiddenValues, {'x'});
      expect(spec.valueLayout, PivotValueLayout.rows);
    });
  });

  group('Given malformed input', () {
    for (final input in <Object?>['', 'not json', 42, null]) {
      test('when parsing $input then the spec is empty', () {
        expect(PivotSpec.parse(input).isEmpty, isTrue);
      });
    }

    test('when a histogram has no positive size then it is dropped', () {
      expect(PivotGrouping.tryParse({'kind': 'histogram', 'size': 0}), isNull);
      expect(
        PivotGrouping.tryParse({'kind': 'histogram', 'size': 10, 'min': '5'}),
        isA<PivotHistogramGrouping>().having((g) => g.min, 'min', 5),
      );
    });
  });

  group('Given value display names', () {
    test('when no name is set then it is "<SUMMARIZE> of <header>"', () {
      expect(
        const PivotValueSpec(
          source: 'c',
          summarizeBy: PivotSummarize.counta,
        ).displayName('Units'),
        'COUNTA of Units',
      );
      expect(
        const PivotValueSpec(
          formula: '=1',
        ).displayName(null, calculatedIndex: 2),
        'Calculated Field 2',
      );
      expect(const PivotValueSpec(name: 'Mine').displayName('x'), 'Mine');
    });

    test(
      'when listing field tokens then ids appear once in first-use order',
      () {
        final f =
            '=${PivotFormula.tokenOf('b')}*${PivotFormula.tokenOf('a')}'
            '+${PivotFormula.tokenOf('b')}';

        expect(PivotFormula.fieldIds(f), ['b', 'a']);
      },
    );
  });
}
