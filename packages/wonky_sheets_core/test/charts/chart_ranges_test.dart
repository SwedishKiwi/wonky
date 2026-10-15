import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart';

void main() {
  const range = GridRange(
    sheetId: '0193a3c2-0000-7000-8000-000000000001',
    r1: '0193a3c2-0000-7000-8000-000000000002',
    c1: '0193a3c2-0000-7000-8000-000000000003',
    r2: '0193a3c2-0000-7000-8000-000000000004',
    c2: '0193a3c2-0000-7000-8000-000000000005',
    r1k: 'a0',
  );

  group('Given chart range references over GridRange JSON (08 §24)', () {
    test('when converting to a reference and back then the range is equal', () {
      final ref = range.toRef();
      expect(ref.toJson(), range.toJson());
      expect(GridRange.fromRef(ref), range);
      expect(GridRange.fromRef(ref).r1k, 'a0');
    });

    test('when a spec stores ranges then the JSON is the GridRange JSON', () {
      final spec = ChartSpec(data: ChartDataSpec(ranges: [range].toRefs()));
      final stored = jsonEncode(spec.toJson()['data']);
      expect(stored, contains(jsonEncode([range.toJson()])));
      expect(ChartSpec.fromJson(spec.toJson()).data.gridRanges, [range]);
    });

    test('when a reference holds base-62 ids then the range decodes them', () {
      final b62 = Base62Uuid.encode(range.sheetId);
      final ref = DataRangeRef({'s': b62});
      expect(GridRange.fromRef(ref).sheetId, range.sheetId);
    });

    test('when scorecard refs are set then they read as ranges', () {
      final o = ScorecardOptions.fromJson({
        'keyValueRef': range.toJson(),
        'baselineRef': jsonEncode(range.toJson()),
      });
      expect(o.keyValueRange, range);
      expect(o.baselineRange, range);
      expect(const ScorecardOptions().keyValueRange, isNull);
    });
  });

  group('Given the spreadsheet theme as a chart theme source', () {
    test('when reading accents then they are the resolved accent colors', () {
      const t = SpreadsheetTheme.standard;
      expect(t.accentArgbs, [for (final a in t.accents) t.resolveArgb(a)]);
      expect(ChartTheme.from(t).source, same(t));
      expect(ChartTheme.from(t).fontFamily, t.textFont);
    });
  });
}
