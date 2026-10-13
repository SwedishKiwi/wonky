import '../../addressing/grid_geometry.dart';
import '../../formula/model/workbook_view.dart';
import '../../formula/values/fvalue.dart';
import '../../model/grid_range.dart';
import '../../model/workbook_model.dart';
import '../data/data_algorithms.dart';
import '../data/value_formatter.dart';
import '../spec/chart_data_spec.dart';
import '../spec/chart_spec.dart';
import '../spec/chart_type.dart';

/// Profile of one column of a chart selection (08 §5.1), after header detection.
final class ColumnProfile {
  /// Creates a profile.
  const ColumnProfile({
    required this.key,
    required this.range,
    required this.offset,
    this.header = '',
    this.count = 0,
    this.numberCount = 0,
    this.dateCount = 0,
    this.textCount = 0,
    this.distinctCount = 0,
    this.monotonicIncreasing = false,
    this.allPositive = false,
  });

  /// Column id (series key).
  final String key;

  /// Range index and offset inside it.
  final int range;
  final int offset;
  final String header;

  /// Non-empty cells.
  final int count;
  final int numberCount;

  /// Numbers with a date/time format.
  final int dateCount;
  final int textCount;
  final int distinctCount;

  /// Numbers strictly increasing (ignoring empties).
  final bool monotonicIncreasing;

  /// All numbers > 0.
  final bool allPositive;

  /// Share of numbers among non-empty cells.
  double get numericShare => count == 0 ? 0 : numberCount / count;

  /// Share of date/time numbers among non-empty cells.
  double get dateShare => count == 0 ? 0 : dateCount / count;

  /// Whether the column is numeric (≥ 80 % numbers, not dates).
  bool get isNumeric => count > 0 && numericShare >= 0.8 && dateShare < 0.8;

  /// Whether the column holds dates/times.
  bool get isDate => count > 0 && dateShare >= 0.8;

  /// Whether the column is text-like (labels).
  bool get isText => count > 0 && !isNumeric && !isDate;
}

/// Profile of a whole selection.
final class SelectionProfile {
  /// Creates a profile.
  const SelectionProfile({
    required this.ranges,
    required this.columns,
    required this.rowCount,
    required this.headerCount,
  });

  /// Builds the profile of [ranges] (visible cells only, like the resolver).
  factory SelectionProfile.fromRanges(
    List<GridRange> ranges,
    WorkbookModel model,
    CellSource values,
  ) {
    final cols =
        <
          (
            String key,
            int range,
            int offset,
            List<FValue> cells,
            List<String?> formats,
          )
        >[];
    for (var ri = 0; ri < ranges.length; ri++) {
      final g = ranges[ri];
      final sheet = model.sheet(g.sheetId);
      final rr = sheet?.resolve(g);
      if (sheet == null || rr == null) continue;
      var rect = rr.rect;
      if (rr.wholeColumns || rr.wholeRows) {
        final used = sheet.usedRect();
        if (used == null) continue;
        final b = rr.wholeColumns && used.bottom < rect.bottom
            ? used.bottom
            : rect.bottom;
        final r = rr.wholeRows && used.right < rect.right
            ? used.right
            : rect.right;
        if (b < rect.top || r < rect.left) continue;
        rect = GridRect(rect.top, rect.left, b, r);
      }
      final rows = [
        for (var r = rect.top; r <= rect.bottom; r++)
          if (!values.isHidden(sheet.id, GridDimension.rows, r)) r,
      ];
      var k = 0;
      for (var c = rect.left; c <= rect.right; c++) {
        if (values.isHidden(sheet.id, GridDimension.columns, c)) continue;
        final cells = <FValue>[];
        final formats = <String?>[];
        for (final r in rows) {
          var v = values.valueAt(sheet.id, r, c);
          if (v is FRich) v = v.scalar;
          cells.add(v);
          formats.add(
            v is FNumber ? values.numberFormatAt(sheet.id, r, c) : null,
          );
        }
        cols.add((sheet.columns.idAt(c), ri, k++, cells, formats));
      }
    }
    final h = HeaderDetection.detect([for (final c in cols) c.$4]);
    var rowCount = 0;
    final profiles = <ColumnProfile>[];
    for (final (key, ri, off, cells, formats) in cols) {
      final header = h > 0 && cells.isNotEmpty && cells[0] is FText
          ? (cells[0] as FText).v
          : '';
      var count = 0, nums = 0, dates = 0, texts = 0;
      var mono = true, pos = true;
      double? last;
      final distinct = <Object>{};
      for (var i = h; i < cells.length; i++) {
        final v = cells[i];
        if (v is FEmpty) continue;
        count++;
        if (v is FNumber) {
          nums++;
          final f = formats[i];
          if (v.hint.isDateLike || ChartFormats.isDateTime(f)) dates++;
          if (v.v <= 0) pos = false;
          if (last != null && v.v <= last) mono = false;
          last = v.v;
          distinct.add(v.v);
        } else {
          if (v is FText) texts++;
          distinct.add(v is FText ? v.v.toLowerCase() : v.debugText);
        }
      }
      if (cells.length - h > rowCount) rowCount = cells.length - h;
      profiles.add(
        ColumnProfile(
          key: key,
          range: ri,
          offset: off,
          header: header,
          count: count,
          numberCount: nums,
          dateCount: dates,
          textCount: texts,
          distinctCount: distinct.length,
          monotonicIncreasing: nums > 1 && mono,
          allPositive: nums > 0 && pos,
        ),
      );
    }
    return SelectionProfile(
      ranges: ranges,
      columns: profiles,
      rowCount: rowCount,
      headerCount: h,
    );
  }

  final List<GridRange> ranges;
  final List<ColumnProfile> columns;

  /// Data rows (after headers).
  final int rowCount;

  /// Detected header rows (written into the spec, 08 §4.2).
  final int headerCount;
}

/// One suggested chart.
final class ChartSuggestion {
  /// Creates a suggestion.
  const ChartSuggestion(
    this.spec, {
    required this.label,
    this.isDefault = false,
  });

  /// The ready-to-insert spec.
  final ChartSpec spec;

  /// English name (`"Doughnut chart"`).
  final String label;

  /// Whether this is the rule's default chart.
  final bool isDefault;

  /// The chart type.
  ChartType get type => spec.type;
}

/// Recommended charts for a selection (08 §5).
abstract final class ChartRecommender {
  /// Up to 4 suggestions; the first is the default (rules 1–9 of 08 §5.2, first match).
  static List<ChartSuggestion> recommend(SelectionProfile profile) {
    final cols = profile.columns.where((c) => c.count > 0).toList();
    if (cols.isEmpty) return const [];
    final first = cols.first;
    final rest = cols.skip(1).toList();
    final numericRest = rest.where((c) => c.isNumeric).toList();
    final textCols = cols.where((c) => c.isText).length;

    ChartSpec build(
      ChartType type, {
      bool domain = true,
      ChartStacking stacking = ChartStacking.none,
      ChartAggregate? aggregate,
      double pieHole = 0,
      List<ColumnProfile>? series,
      bool treatAsText = false,
    }) {
      final s =
          series ??
          (domain ? numericRest : cols.where((c) => c.isNumeric).toList());
      return ChartSpec(
        type: type,
        stacking: stacking,
        data: ChartDataSpec(
          ranges: profile.ranges,
          headerCount: profile.headerCount,
          useFirstColumnAsLabels: domain,
          treatLabelsAsText: treatAsText,
          aggregate: aggregate,
          domain: domain
              ? DomainRef(
                  ref: DataRef(range: first.range, offset: first.offset),
                  key: first.key,
                )
              : null,
          seriesRefs: [
            for (final c in s)
              SeriesRef(
                key: c.key,
                ref: DataRef(range: c.range, offset: c.offset),
              ),
          ],
        ),
        typeOptions: pieHole > 0 ? {'pieHole': pieHole} : const {},
      );
    }

    List<ChartSuggestion> out(List<(ChartSpec, String)> items) => [
      for (var i = 0; i < items.length && i < 4; i++)
        ChartSuggestion(items[i].$1, label: items[i].$2, isDefault: i == 0),
    ];

    // Rule 8: single numeric cell.
    if (cols.length == 1 && profile.rowCount <= 1 && first.isNumeric) {
      return out([
        (build(ChartType.scorecard, domain: false), 'Scorecard chart'),
      ]);
    }
    // Rule 1: pie.
    if (first.isText &&
        first.distinctCount <= 12 &&
        numericRest.length == 1 &&
        rest.length == 1 &&
        numericRest.single.allPositive) {
      return out([
        (build(ChartType.pie), 'Pie chart'),
        (build(ChartType.column), 'Column chart'),
        (build(ChartType.bar), 'Bar chart'),
        (build(ChartType.pie, pieHole: 0.5), 'Doughnut chart'),
      ]);
    }
    // Rule 7: candlestick (date + low/open/close/high by header names).
    if (first.isDate && numericRest.length == 4 && _isOhlc(numericRest)) {
      final ordered = _ohlcOrder(numericRest);
      return out([
        (build(ChartType.candlestick, series: ordered), 'Candlestick chart'),
        (build(ChartType.line), 'Line chart'),
      ]);
    }
    // Rule 2: time series.
    if (first.isDate && numericRest.isNotEmpty) {
      return out([
        (build(ChartType.line), 'Line chart'),
        (build(ChartType.area), 'Area chart'),
        (build(ChartType.column), 'Column chart'),
        (build(ChartType.combo), 'Combo chart'),
      ]);
    }
    // Rule 4: many repeated labels → aggregated column.
    if (first.isText &&
        numericRest.length == 1 &&
        profile.rowCount > 30 &&
        first.distinctCount * 2 <= first.count) {
      return out([
        (
          build(ChartType.column, aggregate: ChartAggregate.sum),
          'Column chart',
        ),
        (build(ChartType.pie, aggregate: ChartAggregate.sum), 'Pie chart'),
        (build(ChartType.table), 'Table chart'),
      ]);
    }
    // Rule 3: categories + values.
    if (first.isText &&
        numericRest.isNotEmpty &&
        numericRest.length == rest.length) {
      if (profile.rowCount <= 30) {
        return out([
          (build(ChartType.column), 'Column chart'),
          (build(ChartType.bar), 'Bar chart'),
          (
            build(ChartType.column, stacking: ChartStacking.normal),
            'Stacked column chart',
          ),
          (build(ChartType.line), 'Line chart'),
        ]);
      }
    }
    // Rule 5: numeric X and Y.
    final numericAll = cols.where((c) => c.isNumeric).toList();
    if (textCols == 0 &&
        numericAll.length >= 2 &&
        numericAll.length == cols.length) {
      return out([
        (build(ChartType.scatter), 'Scatter chart'),
        (build(ChartType.line), 'Line chart'),
        if (numericAll.length == 3) (build(ChartType.bubble), 'Bubble chart'),
      ]);
    }
    // Rule 6: one numeric column.
    if (cols.length == 1 && first.isNumeric) {
      return out([
        (build(ChartType.histogram, domain: false), 'Histogram chart'),
        (build(ChartType.column, domain: false), 'Column chart'),
        (build(ChartType.scorecard, domain: false), 'Scorecard chart'),
      ]);
    }
    // Rule 9: mixed / text heavy.
    return out([
      (build(ChartType.table, series: rest), 'Table chart'),
      (build(ChartType.column), 'Column chart'),
    ]);
  }

  static const _ohlcNames = {
    'low': ['low', 'min', 'tief'],
    'open': ['open', 'start', 'eröffnung'],
    'close': ['close', 'end', 'schluss', 'last'],
    'high': ['high', 'max', 'hoch'],
  };

  static String? _ohlcRole(String header) {
    final h = header.toLowerCase();
    for (final e in _ohlcNames.entries) {
      if (e.value.any(h.contains)) return e.key;
    }
    return null;
  }

  static bool _isOhlc(List<ColumnProfile> cols) =>
      {for (final c in cols) ?_ohlcRole(c.header)}.length == 4;

  static List<ColumnProfile> _ohlcOrder(List<ColumnProfile> cols) => [
    for (final role in const ['low', 'open', 'close', 'high'])
      cols.firstWhere((c) => _ohlcRole(c.header) == role),
  ];

  /// The contiguous non-empty region around ([row], [col]) (used when nothing or a single cell
  /// is selected): grows the rectangle while any adjacent row/column has content.
  static GridRect contiguousRegion(
    String sheetId,
    int row,
    int col,
    CellSource values, {
    required int rowCount,
    required int columnCount,
  }) {
    bool filled(int r, int c) => values.valueAt(sheetId, r, c) is! FEmpty;
    var top = row, bottom = row, left = col, right = col;
    var grew = true;
    while (grew) {
      grew = false;
      bool rowHas(int r) {
        if (r < 0 || r >= rowCount) return false;
        for (var c = left - 1; c <= right + 1; c++) {
          if (c >= 0 && c < columnCount && filled(r, c)) return true;
        }
        return false;
      }

      bool colHas(int c) {
        if (c < 0 || c >= columnCount) return false;
        for (var r = top - 1; r <= bottom + 1; r++) {
          if (r >= 0 && r < rowCount && filled(r, c)) return true;
        }
        return false;
      }

      if (rowHas(top - 1)) {
        top--;
        grew = true;
      }
      if (rowHas(bottom + 1)) {
        bottom++;
        grew = true;
      }
      if (colHas(left - 1)) {
        left--;
        grew = true;
      }
      if (colHas(right + 1)) {
        right++;
        grew = true;
      }
    }
    return GridRect(top, left, bottom, right);
  }
}
