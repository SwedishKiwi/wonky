import 'package:wonky_charts/wonky_charts.dart';

import '../model/grid_range.dart';

/// The chart engine's opaque range references read as Sheets ranges (08 §24): a chart spec
/// stores GridRange JSON in `data.ranges` and the scorecard refs.
extension ChartDataSpecGridRanges on ChartDataSpec {
  /// [ranges] as [GridRange]s.
  List<GridRange> get gridRanges => [
    for (final r in ranges) GridRange.fromRef(r),
  ];
}

/// Scorecard refs as Sheets ranges.
extension ScorecardOptionsGridRanges on ScorecardOptions {
  /// [keyValueRef] as a [GridRange].
  GridRange? get keyValueRange =>
      keyValueRef == null ? null : GridRange.fromRef(keyValueRef!);

  /// [baselineRef] as a [GridRange].
  GridRange? get baselineRange =>
      baselineRef == null ? null : GridRange.fromRef(baselineRef!);
}

/// Sheets ranges as the chart engine's references.
extension GridRangesToRefs on Iterable<GridRange> {
  /// Each range as a [DataRangeRef] (`ChartDataSpec.ranges`).
  List<DataRangeRef> toRefs() => [for (final r in this) r.toRef()];
}
