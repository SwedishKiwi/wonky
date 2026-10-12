import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';

void main() {
  group('Given a text column', () {
    final values = <CellValue>[
      const TextValue('East'),
      const TextValue('West'),
      const TextValue('East'),
      CellValue.empty,
      const TextValue('North'),
      const TextValue('East'),
    ];
    final texts = [for (final v in values) ValueText.automatic(v)];

    test('when computing stats then counts, unique and frequencies are reported', () {
      final s = ColumnStats.compute(values, texts);
      expect((s.kind, s.valueCount, s.emptyCount, s.uniqueCount), (ColumnKind.text, 5, 1, 3));
      expect(s.frequencies, [
        const FrequencyEntry('East', 3, 0.6),
        const FrequencyEntry('North', 1, 0.2),
        const FrequencyEntry('West', 1, 0.2),
      ]);
      expect((s.minTextLength, s.maxTextLength), (4, 5));
      expect(s.numeric, isNull);
      expect(s.top(1).single.text, 'East');
    });
  });

  group('Given a numeric column', () {
    final nums = [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0];
    final values = [for (final n in nums) NumberValue(n)];

    test('when computing the summary then sum, average, median, min and max are exact', () {
      final s = ColumnStats.compute(values, [for (final n in nums) '$n']);
      final n = s.numeric!;
      expect((n.sum, n.average, n.median, n.min, n.max), (31.0, 3.875, 3.5, 1.0, 9.0));
      expect(s.kind, ColumnKind.number);
    });

    test('when building the histogram then buckets cover the data and counts add up', () {
      final s = ColumnStats.compute(values, [for (final n in nums) '$n']);
      expect(s.histogram.first.start, 1.0);
      expect(s.histogram.last.end, 9.0);
      expect(s.histogram.fold<int>(0, (a, b) => a + b.count), 8);
      expect(s.histogram.length, lessThanOrEqualTo(ColumnStats.maxBuckets));
    });

    test('when many values exist then at most 20 buckets are used', () {
      final many = [for (var i = 0; i < 100000; i++) NumberValue((i * 37 % 1000).toDouble())];
      final s = ColumnStats.compute(many, List.filled(many.length, ''));
      expect(s.histogram.length, 20);
    });

    test('when all values are equal then there is one bucket', () {
      expect(ColumnStats.compute([NumberValue(2), NumberValue(2)], ['2', '2']).histogram.single.count, 2);
    });
  });

  group('Given a date column', () {
    test('when the span is short then the histogram is by month', () {
      final ds = [DateSerial.fromYmd(2026, 1, 5), DateSerial.fromYmd(2026, 1, 20), DateSerial.fromYmd(2026, 3, 1)];
      final s = ColumnStats.compute([for (final d in ds) NumberValue(d.toDouble())], ['a', 'b', 'c'], numberFormat: 'yyyy-mm-dd');
      expect(s.kind, ColumnKind.date);
      expect([for (final b in s.histogram) (b.label, b.count)], [('2026-01', 2), ('2026-02', 0), ('2026-03', 1)]);
    });

    test('when the span is long then the histogram is by year', () {
      final ds = [DateSerial.fromYmd(2020, 1, 5), DateSerial.fromYmd(2026, 1, 20)];
      final s = ColumnStats.compute([for (final d in ds) NumberValue(d.toDouble())], ['a', 'b'], numberFormat: 'preset:date');
      expect(s.histogram.map((b) => b.label), ['2020', '2021', '2022', '2023', '2024', '2025', '2026']);
    });
  });

  group('Given a sheet column', () {
    test('when computing from the sheet then display texts and the column format are used', () {
      final b = WorkbookBuilder();
      final sid = b.sheet('Sheet1', rows: 5, cols: 1);
      b.values('A1', [
        [1],
        [2],
        ['x'],
      ]);
      final m = b.build();
      final s = ColumnStats.fromSheet(
        CellTextReader(ModelCellSource(m), const FunctionDisplayText(_fmt)),
        sid,
        0,
        0,
        4,
      );
      expect((s.valueCount, s.emptyCount, s.numeric!.sum), (3, 2, 3.0));
    });
  });
}

String _fmt(CellValue v, String? f) => ValueText.automatic(v);
