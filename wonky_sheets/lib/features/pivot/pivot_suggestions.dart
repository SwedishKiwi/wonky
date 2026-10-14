import 'package:wonky_sheets_core/model.dart';

import 'pivot_spec_edit.dart';

/// A suggested pivot (07 §7.11, P2): a label and the spec it applies.
final class PivotSuggestion {
  const PivotSuggestion(this.kind, this.value, this.field, this.spec);

  /// `sum` ("Revenue by Region") or `count` ("Count of Region").
  final String kind;

  /// Header of the value field.
  final String value;

  /// Header of the row field.
  final String field;
  final PivotSpec spec;
}

/// Up to [max] suggestions for [fields]: numeric measures by categorical or
/// date dimensions (low cardinality first), then counts of a dimension.
List<PivotSuggestion> suggestPivots(
  List<PivotSourceField> fields,
  SourceTable? table, {
  int max = 3,
}) {
  final numbers = [
    for (final f in fields)
      if (f.kind == PivotFieldKind.number) f,
  ];
  int cardinality(PivotSourceField f) {
    final c = table?.column(f.colId);
    if (c == null) return 1 << 20;
    final seen = <String>{};
    final n = c.values.length < 2000 ? c.values.length : 2000;
    for (var i = 0; i < n; i++) {
      seen.add(c.displayText(i).toLowerCase());
      if (seen.length > 200) break;
    }
    return seen.length;
  }

  final dims = [
    for (final f in fields)
      if ((f.kind == PivotFieldKind.text ||
              f.kind == PivotFieldKind.date ||
              f.kind == PivotFieldKind.boolean) &&
          cardinality(f) <= 50)
        f,
  ]..sort((a, b) => cardinality(a).compareTo(cardinality(b)));
  final out = <PivotSuggestion>[];
  for (final d in dims) {
    for (final m in numbers) {
      if (out.length >= max) return out;
      final row = d.kind == PivotFieldKind.date
          ? PivotGroupSpec(
              d.colId,
              group: const PivotDateGrouping(PivotDateUnit.yearMonth),
            )
          : PivotGroupSpec(d.colId);
      out.add(
        PivotSuggestion(
          'sum',
          m.header,
          d.header,
          PivotSpec(
            rows: [row],
            values: [PivotValueSpec(source: m.colId)],
          ),
        ),
      );
      break;
    }
  }
  for (final d in dims) {
    if (out.length >= max) break;
    out.add(
      PivotSuggestion(
        'count',
        d.header,
        d.header,
        PivotSpec(
          rows: [PivotGroupSpec(d.colId)],
          values: [
            PivotValueSpec(source: d.colId, summarizeBy: PivotSummarize.counta),
          ],
        ),
      ),
    );
  }
  return out;
}
