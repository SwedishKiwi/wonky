import 'dart:typed_data';

import 'package:wonky_sync_models/ids.dart';

import '../../addressing/column_letters.dart';
import '../../addressing/grid_geometry.dart';
import '../../formula/model/workbook_view.dart';
import '../../formula/values/format_hint.dart';
import '../../formula/values/fvalue.dart';
import '../../model/grid_range.dart';
import '../../model/workbook_model.dart';
import '../spec/chart_spec.dart';
import '../spec/chart_type.dart';
import 'chart_data.dart';
import 'data_algorithms.dart';
import 'value_formatter.dart';

/// One logical column (row when switched) of the chart's source table.
final class _Line {
  _Line(this.key, this.range, this.offset, this.sheetId, this.fixedIndex, this.isRowLine);

  /// Column id (row id when switched).
  final String key;
  final int range;
  final int offset;
  final String sheetId;

  /// Sheet column index (row index when switched).
  final int fixedIndex;
  final bool isRowLine;

  /// Cell values per point.
  final List<FValue> cells = [];

  /// Sheet row index (column index when switched) per point; -1 for padding.
  final List<int> varIndex = [];

  int get length => cells.length;

  (int, int) coord(int k) => isRowLine ? (fixedIndex, varIndex[k]) : (varIndex[k], fixedIndex);
}

/// Resolves a [ChartSpec]'s ranges into [ChartData] (08 §4.1).
final class ChartDataResolver {
  /// Creates a resolver.
  const ChartDataResolver();

  /// Maximum source cells per chart (08 §12).
  static const maxSourceCells = 1000000;

  /// Resolves [spec] against [model] with computed values from [values].
  static ChartData resolve(
    ChartSpec spec,
    WorkbookModel model,
    CellSource values, {
    String locale = 'en_US',
    ChartValueFormatter? fmt,
  }) => _Resolution(spec, model, values, fmt ?? DefaultChartValueFormatter(locale: locale)).run();
}

final class _Resolution {
  _Resolution(this.spec, this.model, this.values, this.fmt);

  final ChartSpec spec;
  final WorkbookModel model;
  final CellSource values;
  final ChartValueFormatter fmt;
  final List<ChartWarning> warnings = [];
  var _hash = 0x811c9dc5;
  var _cells = 0;

  bool get switched => spec.data.switchRowsColumns;

  ChartData run() {
    final data = spec.data;
    if (data.ranges.isEmpty) {
      return ChartData.empty(
        warnings: const [ChartWarning(ChartWarningCode.noData, 'No data range')],
      );
    }
    final lines = <_Line>[];
    final pointCounts = <int>[];
    for (var i = 0; i < data.ranges.length; i++) {
      final before = lines.length;
      final n = _readRange(i, data.ranges[i], lines);
      if (n != null && lines.length > before) pointCounts.add(n);
    }
    if (lines.isEmpty || pointCounts.isEmpty) {
      return ChartData.empty(
        warnings: [...warnings, const ChartWarning(ChartWarningCode.noData, 'No data')],
      );
    }
    var n = 0;
    for (final c in pointCounts) {
      if (c > n) n = c;
    }
    if (pointCounts.any((c) => c != n)) {
      warnings.add(
        const ChartWarning(ChartWarningCode.rangeSizeMismatch, 'Ranges have different sizes'),
      );
    }
    for (final l in lines) {
      while (l.cells.length < n) {
        l.cells.add(FEmpty.instance);
        l.varIndex.add(-1);
      }
    }

    // Headers.
    final h = (data.headerCount ?? HeaderDetection.detect([for (final l in lines) l.cells]))
        .clamp(0, n);
    final names = [for (final l in lines) _headerName(l, h)];

    // Domain.
    int? domainIdx;
    if (data.useFirstColumnAsLabels && spec.type != ChartType.histogram) {
      domainIdx = _findDomain(lines);
    }
    final points = n - h;

    // Series lines.
    final seriesIdx = <int>[];
    final seriesKeys = <String>[];
    final missing = <String>[];
    final claimed = <int>{?domainIdx};
    final refKeys = {for (final r in data.seriesRefs) _canon(r.key)};
    final byKey = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      byKey.putIfAbsent(_canon(lines[i].key), () => i);
    }
    final explicit = <(int line, String key)>[];
    for (final r in data.seriesRefs) {
      final k = _canon(r.key);
      var li = byKey[k];
      if (li == null && !_looksLikeId(r.key)) {
        final cand = _lineAt(lines, r.ref.range, r.ref.offset);
        if (cand != null &&
            !claimed.contains(cand) &&
            !refKeys.contains(_canon(lines[cand].key))) {
          li = cand;
        }
      }
      if (li == null) {
        if (!r.hidden) missing.add(r.key);
        continue;
      }
      if (claimed.contains(li)) continue;
      claimed.add(li);
      if (!r.hidden) explicit.add((li, r.key));
    }
    final isTable = spec.type == ChartType.table;
    // Unreferenced lines (new columns inside the range, or no refs at all) become series.
    final auto = <int>[
      for (var i = 0; i < lines.length; i++)
        if (!claimed.contains(i) && (isTable || _hasNumber(lines[i], h))) i,
    ];
    if (data.seriesRefs.isEmpty) {
      for (final i in auto) {
        seriesIdx.add(i);
        seriesKeys.add(lines[i].key);
      }
    } else {
      final merged = [...explicit];
      for (final i in auto) {
        var pos = 0;
        for (var k = 0; k < merged.length; k++) {
          if (merged[k].$1 < i) pos = k + 1;
        }
        merged.insert(pos, (i, lines[i].key));
      }
      for (final (i, key) in merged) {
        seriesIdx.add(i);
        seriesKeys.add(key);
      }
    }
    if (missing.isNotEmpty) {
      warnings.add(
        ChartWarning(
          ChartWarningCode.missingSeries,
          'Missing series (column deleted)',
          count: missing.length,
        ),
      );
    }

    // Domain values.
    var domain = domainIdx == null
        ? ChartDomain.synthetic(points)
        : _buildDomain(lines[domainIdx], names[domainIdx], h);
    final wantTexts = isTable || spec.type == ChartType.bubble;
    var series = <ChartSeries>[
      for (var s = 0; s < seriesIdx.length; s++)
        _buildSeries(lines[seriesIdx[s]], seriesKeys[s], names[seriesIdx[s]], h, wantTexts),
    ];

    if (spec.data.domain?.reverse ?? false) {
      domain = _reverseDomain(domain);
      series = [for (final s in series) _reverseSeries(s)];
    }

    final agg = data.aggregate;
    if (agg != null && !domain.isSynthetic && points > 0) {
      (domain, series) = ChartAggregation.aggregate(domain, series, agg);
    }

    if (spec.type == ChartType.pie && series.isNotEmpty) {
      final g = PieGrouping.group(domain, series.first, threshold: spec.pieOptions.otherThreshold);
      if (g != null) {
        warnings.add(
          ChartWarning(
            ChartWarningCode.pieOtherGrouped,
            'Smallest slices grouped into "Other"',
            count: domain.length - g.$1.length + 1,
          ),
        );
        domain = g.$1;
        series = [g.$2, ...series.skip(1).map((s) => s.withValues(Float64List(g.$1.length)..fillRange(0, g.$1.length, double.nan)))];
      }
    }

    HistogramData? histogram;
    if (spec.type == ChartType.histogram) {
      final o = spec.histogramOptions;
      histogram = HistogramBuckets.compute(
        series,
        bucketSize: o.bucketSize,
        outlierPercentile: o.outlierPercentile,
        collectItems: o.showItemDividers,
      );
    }

    ScorecardData? scorecard;
    if (spec.type == ChartType.scorecard) scorecard = _scorecard(series);

    ChartTableData? table;
    if (isTable) table = _table(lines, names, domainIdx, seriesIdx, h);

    return ChartData(
      domain: domain,
      series: series,
      warnings: List.unmodifiable(warnings),
      sourceCellCount: _cells,
      dataVersion: _finishHash(n, h),
      missingSeriesKeys: List.unmodifiable(missing),
      histogram: histogram,
      scorecard: scorecard,
      table: table,
    );
  }

  // ---------------------------------------------------------------------------
  // Reading.

  /// Reads range [ri] into [lines]; returns its point count or null when it resolves to
  /// nothing.
  int? _readRange(int ri, GridRange g, List<_Line> lines) {
    final sheet = model.sheet(g.sheetId);
    final rr = sheet?.resolve(g);
    if (sheet == null || rr == null) {
      warnings.add(
        ChartWarning(ChartWarningCode.rangeNotFound, 'Data range not found', count: ri),
      );
      return null;
    }
    var rect = rr.rect;
    if (rr.wholeColumns || rr.wholeRows) {
      final used = sheet.usedRect();
      if (used == null) return null;
      rect = GridRect(
        rect.top,
        rect.left,
        rr.wholeColumns && used.bottom < rect.bottom ? used.bottom : rect.bottom,
        rr.wholeRows && used.right < rect.right ? used.right : rect.right,
      );
      if (rect.bottom < rect.top || rect.right < rect.left) return null;
    }
    final include = spec.data.includeHidden;
    final rows = <int>[
      for (var r = rect.top; r <= rect.bottom; r++)
        if (include || !values.isHidden(sheet.id, GridDimension.rows, r)) r,
    ];
    final cols = <int>[
      for (var c = rect.left; c <= rect.right; c++)
        if (include || !values.isHidden(sheet.id, GridDimension.columns, c)) c,
    ];
    if (rows.isEmpty || cols.isEmpty) return null;
    if (_cells + rows.length * cols.length > ChartDataResolver.maxSourceCells) {
      warnings.add(
        const ChartWarning(ChartWarningCode.tooManyCells, 'Too many source cells; data truncated'),
      );
      final budget = ChartDataResolver.maxSourceCells - _cells;
      if (budget <= 0) return null;
      final maxRows = (budget ~/ cols.length).clamp(1, rows.length);
      rows.removeRange(maxRows, rows.length);
    }
    final first = lines.length;
    if (!switched) {
      for (var k = 0; k < cols.length; k++) {
        lines.add(_Line(sheet.columns.idAt(cols[k]), ri, k, sheet.id, cols[k], false));
      }
      for (final r in rows) {
        for (var k = 0; k < cols.length; k++) {
          final v = _read(sheet.id, r, cols[k]);
          lines[first + k]
            ..cells.add(v)
            ..varIndex.add(r);
        }
      }
      return rows.length;
    }
    for (var k = 0; k < rows.length; k++) {
      lines.add(_Line(sheet.rows.idAt(rows[k]), ri, k, sheet.id, rows[k], true));
    }
    for (var k = 0; k < rows.length; k++) {
      final line = lines[first + k];
      for (final c in cols) {
        line
          ..cells.add(_read(sheet.id, rows[k], c))
          ..varIndex.add(c);
      }
    }
    return cols.length;
  }

  FValue _read(String sheetId, int r, int c) {
    var v = values.valueAt(sheetId, r, c);
    if (v is FRich) v = v.scalar;
    if (v is FArray) v = v.topLeft;
    if (v is FRef) v = FEmpty.instance;
    _cells++;
    _mix(_valueHash(v));
    return v;
  }

  // ---------------------------------------------------------------------------
  // Hashing (deterministic, web-safe 32-bit FNV-1a).

  void _mix(int x) {
    var h = _hash;
    for (var i = 0; i < 4; i++) {
      h ^= (x >> (i * 8)) & 0xff;
      h = (h * 0x01000193) & 0xffffffff;
    }
    _hash = h;
  }

  int _valueHash(FValue v) {
    switch (v) {
      case FNumber(:final v):
        final bd = ByteData(8)..setFloat64(0, v);
        return (bd.getUint32(0) ^ (bd.getUint32(4) * 31)) & 0xffffffff;
      case FText(v: final t):
        var h = 7;
        for (final c in t.codeUnits) {
          h = (h * 31 + c) & 0x3fffffff;
        }
        return h ^ 0x5bd1e995;
      case FBool(:final v):
        return v ? 0x1001 : 0x1002;
      case FError(:final kind):
        return 0x2000 + kind.index;
      default:
        return 0;
    }
  }

  int _finishHash(int n, int h) {
    _mix(n);
    _mix(h);
    _mix(spec.data.switchRowsColumns ? 1 : 0);
    return _hash & 0x3fffffff;
  }

  // ---------------------------------------------------------------------------
  // Lines → domain / series.

  String _headerName(_Line l, int h) {
    final parts = <String>[];
    for (var k = 0; k < h && k < l.length; k++) {
      final t = _text(l, k).trim();
      if (t.isNotEmpty) parts.add(t);
    }
    if (parts.isNotEmpty) return parts.join(' ');
    return l.isRowLine ? 'Row ${l.fixedIndex + 1}' : 'Column ${ColumnLetters.fromIndex(l.fixedIndex)}';
  }

  String? _formatAt(_Line l, int k) {
    if (l.varIndex[k] < 0) return null;
    final (r, c) = l.coord(k);
    return values.numberFormatAt(l.sheetId, r, c);
  }

  String _text(_Line l, int k) {
    final v = l.cells[k];
    return switch (v) {
      FText(v: final t) => t,
      FNumber(v: final n) => fmt.format(n, _formatAt(l, k) ?? _hintPattern(v)),
      FBool(v: final b) => b ? 'TRUE' : 'FALSE',
      FError(:final kind) => kind.literal,
      _ => '',
    };
  }

  static String? _hintPattern(FNumber v) {
    if (v.hint.isNone) return null;
    return switch (v.hint.code) {
      'date' => 'preset:date',
      'time' => 'preset:time',
      'dateTime' => 'preset:dateTime',
      'percent' => '0.00%',
      _ => v.hint.detail,
    };
  }

  int? _findDomain(List<_Line> lines) {
    final d = spec.data.domain;
    if (d?.key != null) {
      final k = _canon(d!.key!);
      for (var i = 0; i < lines.length; i++) {
        if (_canon(lines[i].key) == k) return i;
      }
    }
    return _lineAt(lines, d?.ref.range ?? 0, d?.ref.offset ?? 0) ??
        (d == null ? null : _lineAt(lines, 0, 0));
  }

  static int? _lineAt(List<_Line> lines, int range, int offset) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].range == range && lines[i].offset == offset) return i;
    }
    return null;
  }

  static bool _hasNumber(_Line l, int h) {
    for (var k = h; k < l.length; k++) {
      if (l.cells[k] is FNumber) return true;
    }
    return false;
  }

  ChartDomain _buildDomain(_Line l, String name, int h) {
    final n = l.length - h;
    final vals = Float64List(n);
    final labels = List<String>.filled(n, '');
    var allNumbers = true;
    var anyNumber = false;
    var dateLike = true;
    String? firstFormat;
    for (var k = 0; k < n; k++) {
      final v = l.cells[h + k];
      labels[k] = _text(l, h + k);
      if (v is FNumber) {
        vals[k] = v.v;
        if (!anyNumber) {
          firstFormat = _formatAt(l, h + k) ?? _hintPattern(v);
        }
        anyNumber = true;
        if (dateLike) {
          final f = _formatAt(l, h + k);
          dateLike = v.hint.isDateLike ||
              v.hint.kind == FormatHintKind.time ||
              ChartFormats.isDateTime(f);
        }
      } else {
        vals[k] = double.nan;
        if (v is! FEmpty) allNumbers = false;
      }
    }
    final kind = !anyNumber || !allNumbers || spec.data.treatLabelsAsText
        ? DomainKind.categorical
        : (dateLike ? DomainKind.dateTime : DomainKind.numeric);
    return ChartDomain(
      kind: kind,
      values: vals,
      labels: labels,
      name: name,
      key: l.key,
      numberFormat: firstFormat,
    );
  }

  ChartSeries _buildSeries(_Line l, String key, String name, int h, bool wantTexts) {
    final n = l.length - h;
    final vals = Float64List(n);
    var errors = 0;
    String? format;
    var formatSet = false;
    for (var k = 0; k < n; k++) {
      final v = l.cells[h + k];
      if (v is FNumber) {
        vals[k] = v.v;
        if (!formatSet) {
          format = _formatAt(l, h + k) ?? _hintPattern(v);
          formatSet = true;
        }
      } else {
        vals[k] = double.nan;
        if (v is FError) errors++;
      }
    }
    if (errors > 0) {
      warnings.add(
        ChartWarning(
          ChartWarningCode.errorValuesIgnored,
          'Error values are shown as empty',
          count: errors,
          seriesKey: key,
        ),
      );
    }
    return ChartSeries(
      key: key,
      name: spec.series[key]?.labelOverride ?? name,
      values: vals,
      numberFormat: format,
      isPercent: ChartFormats.isPercent(format),
      texts: wantTexts ? [for (var k = 0; k < n; k++) _text(l, h + k)] : null,
    );
  }

  static ChartDomain _reverseDomain(ChartDomain d) => ChartDomain(
    kind: d.kind,
    values: Float64List.fromList(d.values.reversed.toList()),
    labels: d.labels.reversed.toList(),
    name: d.name,
    key: d.key,
    numberFormat: d.numberFormat,
    isSynthetic: d.isSynthetic,
  );

  static ChartSeries _reverseSeries(ChartSeries s) => s.withValues(
    Float64List.fromList(s.values.reversed.toList()),
    texts: s.texts?.reversed.toList(),
  );

  // ---------------------------------------------------------------------------
  // Scorecard and table.

  ScorecardData _scorecard(List<ChartSeries> series) {
    final o = spec.scorecardOptions;
    (double, String?) fromRange(GridRange g) {
      final sheet = model.sheet(g.sheetId);
      final rr = sheet?.resolve(g);
      if (sheet == null || rr == null) return (double.nan, null);
      final vs = <double>[];
      String? f;
      final rect = rr.rect;
      for (var r = rect.top; r <= rect.bottom; r++) {
        for (var c = rect.left; c <= rect.right; c++) {
          final v = _read(sheet.id, r, c);
          if (v is FNumber) {
            vs.add(v.v);
            f ??= values.numberFormatAt(sheet.id, r, c) ?? _hintPattern(v);
          }
        }
      }
      if (vs.length == 1) return (vs.first, f);
      return (ChartAggregation.apply(o.aggregate, vs), f);
    }

    double key;
    String? keyFormat;
    var label = '';
    if (o.keyValueRef != null) {
      (key, keyFormat) = fromRange(o.keyValueRef!);
    } else if (series.isNotEmpty) {
      final s = series.first;
      final vs = s.values.toList();
      final valid = vs.where((v) => !v.isNaN).length;
      key = valid == 1 ? vs.firstWhere((v) => !v.isNaN) : ChartAggregation.apply(o.aggregate, vs);
      keyFormat = s.numberFormat;
      label = s.name;
    } else {
      key = double.nan;
    }
    double? baseline;
    String? baselineFormat;
    if (o.baselineRef != null) {
      final (b, f) = fromRange(o.baselineRef!);
      if (!b.isNaN) baseline = b;
      baselineFormat = f;
    } else if (o.keyValueRef == null && series.length > 1) {
      final b = ChartAggregation.apply(o.aggregate, series[1].values.toList());
      if (!b.isNaN) baseline = b;
      baselineFormat = series[1].numberFormat;
    }
    return ScorecardData(
      keyValue: key,
      baseline: baseline,
      keyFormat: o.keyFormat ?? keyFormat,
      baselineFormat: o.baselineFormat ?? baselineFormat ?? o.keyFormat ?? keyFormat,
      label: label,
    );
  }

  ChartTableData _table(List<_Line> lines, List<String> names, int? domainIdx, List<int> seriesIdx, int h) {
    final order = <int>[?domainIdx, ...seriesIdx];
    final o = spec.tableOptions;
    final texts = <List<String>>[];
    final nums = <Float64List>[];
    for (final i in order) {
      final l = lines[i];
      final n = l.length - h;
      final t = List<String>.filled(n, '');
      final v = Float64List(n);
      for (var k = 0; k < n; k++) {
        final c = l.cells[h + k];
        v[k] = c is FNumber ? c.v : double.nan;
        t[k] = o.formatFromSource || c is! FNumber ? _text(l, h + k) : fmt.format(c.v, null);
      }
      texts.add(t);
      nums.add(v);
    }
    final reversed = spec.data.domain?.reverse ?? false;
    if (reversed) {
      for (var i = 0; i < texts.length; i++) {
        texts[i] = texts[i].reversed.toList();
        nums[i] = Float64List.fromList(nums[i].reversed.toList());
      }
    }
    return ChartTableData(headers: [for (final i in order) names[i]], texts: texts, values: nums);
  }

  // ---------------------------------------------------------------------------
  // Keys.

  static String _canon(String key) {
    if (key.length == Base62Uuid.length && !key.contains('-') && Base62Uuid.isValid(key)) {
      return Base62Uuid.decode(key);
    }
    return key.toLowerCase();
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _looksLikeId(String key) =>
      _uuid.hasMatch(key) ||
      (key.length == Base62Uuid.length && !key.contains('-') && Base62Uuid.isValid(key));
}
