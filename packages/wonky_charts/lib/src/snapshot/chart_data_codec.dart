import 'dart:convert';
import 'dart:typed_data';

import '../data/chart_data.dart';

/// The JSON form of [ChartData] (Slides 08 §2.7, §3.4): the `data` of a chart snapshot.
///
/// Exact round trip: numeric arrays are base64 of little-endian IEEE 754 doubles (NaN gaps
/// and every bit of every value survive), single numbers are JSON numbers when finite and
/// `"NaN"`, `"Infinity"`, `"-Infinity"` otherwise, and [ChartData.dataVersion] is a decimal
/// string (64-bit hashes don't fit a JavaScript number). Shape:
///
/// ```jsonc
/// {
///   "domain": {"kind": "categorical", "length": 3, "values": "<b64>", "labels": ["Q1", …],
///              "name": "Quarter", "key": "c1", "format": "0", "synthetic": true},
///   "series": [{"key": "c2", "name": "Revenue", "values": "<b64>", "format": "#,##0",
///               "percent": true, "texts": ["1", …]}],
///   "warnings": [{"code": "downsampled", "message": "…", "count": 2, "series": "c2"}],
///   "sourceCellCount": 39, "dataVersion": "123", "missingSeriesKeys": ["c9"],
///   "histogram": {"start": 0, "bucketSize": 5, "counts": [[1, 2]], "seriesKeys": ["c2"]},
///   "scorecard": {"keyValue": 12, "baseline": 10, "keyFormat": "0", "baselineFormat": "0",
///                 "label": "Revenue"},
///   "table": {"headers": ["A"], "texts": [["1"]], "values": ["<b64>"]}
/// }
/// ```
///
/// Keys with default values are left out. [decode] is lenient: unknown keys are ignored,
/// malformed parts fall back to empty values (a snapshot from a newer version still renders
/// what it can).
abstract final class ChartDataCodec {
  /// [data] as JSON.
  static Map<String, Object?> encode(ChartData data) {
    final d = data.domain;
    return {
      'domain': {
        'kind': d.kind.name,
        'length': d.length,
        'values': doubles(d.values),
        'labels': d.labels,
        if (d.name.isNotEmpty) 'name': d.name,
        'key': ?d.key,
        'format': ?d.numberFormat,
        if (d.isSynthetic) 'synthetic': true,
      },
      'series': [
        for (final s in data.series)
          {
            'key': s.key,
            'name': s.name,
            'values': doubles(s.values),
            'format': ?s.numberFormat,
            if (s.isPercent) 'percent': true,
            'texts': ?s.texts,
          },
      ],
      if (data.warnings.isNotEmpty)
        'warnings': [
          for (final w in data.warnings)
            {
              'code': w.code.name,
              'message': w.message,
              if (w.count != 0) 'count': w.count,
              'series': ?w.seriesKey,
            },
        ],
      if (data.sourceCellCount != 0) 'sourceCellCount': data.sourceCellCount,
      if (data.dataVersion != 0) 'dataVersion': '${data.dataVersion}',
      if (data.missingSeriesKeys.isNotEmpty)
        'missingSeriesKeys': data.missingSeriesKeys,
      if (data.histogram case final h?)
        'histogram': {
          'start': number(h.start),
          'bucketSize': number(h.bucketSize),
          'counts': [for (final c in h.counts) c.toList()],
          'seriesKeys': h.seriesKeys,
        },
      if (data.scorecard case final s?)
        'scorecard': {
          'keyValue': number(s.keyValue),
          if (s.baseline != null) 'baseline': number(s.baseline!),
          'keyFormat': ?s.keyFormat,
          'baselineFormat': ?s.baselineFormat,
          if (s.label.isNotEmpty) 'label': s.label,
        },
      if (data.table case final t?)
        'table': {
          'headers': t.headers,
          'texts': t.texts,
          'values': [for (final v in t.values) doubles(v)],
        },
    };
  }

  /// Parses JSON written by [encode] (a map or a JSON string).
  static ChartData decode(Object? json) {
    final m = _map(json is String ? _tryDecode(json) : json);
    final dm = _map(m['domain']);
    final labels = _strings(dm['labels']);
    var dValues = parseDoubles(dm['values']);
    if (dValues.length != labels.length) {
      dValues = Float64List(labels.length)
        ..fillRange(0, labels.length, double.nan);
    }
    final domain = ChartDomain(
      kind: _enum(dm['kind'], DomainKind.values, DomainKind.categorical),
      values: dValues,
      labels: labels,
      name: dm['name'] is String ? dm['name']! as String : '',
      key: dm['key'] is String ? dm['key']! as String : null,
      numberFormat: dm['format'] is String ? dm['format']! as String : null,
      isSynthetic: dm['synthetic'] == true,
    );
    final series = <ChartSeries>[];
    for (final (i, raw) in _list(m['series']).indexed) {
      if (raw is! Map) continue;
      final s = _map(raw);
      final values = parseDoubles(s['values']);
      final texts = s['texts'] is List ? _strings(s['texts']) : null;
      series.add(
        ChartSeries(
          key: s['key'] is String ? s['key']! as String : 's$i',
          name: s['name'] is String ? s['name']! as String : '',
          values: values,
          numberFormat: s['format'] is String ? s['format']! as String : null,
          isPercent: s['percent'] == true,
          texts: texts != null && texts.length == values.length ? texts : null,
        ),
      );
    }
    final warnings = <ChartWarning>[
      for (final raw in _list(m['warnings']))
        if (_map(raw) case final w
            when _enumOrNull(w['code'], ChartWarningCode.values) != null)
          ChartWarning(
            _enumOrNull(w['code'], ChartWarningCode.values)!,
            w['message'] is String ? w['message']! as String : '',
            count: w['count'] is num ? (w['count']! as num).toInt() : 0,
            seriesKey: w['series'] is String ? w['series']! as String : null,
          ),
    ];
    HistogramData? histogram;
    if (m['histogram'] is Map) {
      final h = _map(m['histogram']);
      histogram = HistogramData(
        start: parseNumber(h['start']) ?? 0,
        bucketSize: parseNumber(h['bucketSize']) ?? 1,
        counts: [
          for (final c in _list(h['counts']))
            Int32List.fromList([
              for (final v in _list(c)) v is num ? v.toInt() : 0,
            ]),
        ],
        seriesKeys: _strings(h['seriesKeys']),
      );
    }
    ScorecardData? scorecard;
    if (m['scorecard'] is Map) {
      final s = _map(m['scorecard']);
      scorecard = ScorecardData(
        keyValue: parseNumber(s['keyValue']) ?? double.nan,
        baseline: parseNumber(s['baseline']),
        keyFormat: s['keyFormat'] is String ? s['keyFormat']! as String : null,
        baselineFormat: s['baselineFormat'] is String
            ? s['baselineFormat']! as String
            : null,
        label: s['label'] is String ? s['label']! as String : '',
      );
    }
    ChartTableData? table;
    if (m['table'] is Map) {
      final t = _map(m['table']);
      table = ChartTableData(
        headers: _strings(t['headers']),
        texts: [for (final c in _list(t['texts'])) _strings(c)],
        values: [for (final v in _list(t['values'])) parseDoubles(v)],
      );
    }
    final dv = m['dataVersion'];
    return ChartData(
      domain: domain,
      series: series,
      warnings: warnings,
      sourceCellCount: m['sourceCellCount'] is num
          ? (m['sourceCellCount']! as num).toInt()
          : 0,
      dataVersion: dv is num
          ? dv.toInt()
          : (dv is String ? int.tryParse(dv) ?? 0 : 0),
      missingSeriesKeys: _strings(m['missingSeriesKeys']),
      histogram: histogram,
      scorecard: scorecard,
      table: table,
    );
  }

  /// Base64 of the little-endian doubles of [values].
  static String doubles(Float64List values) {
    final bytes = ByteData(values.length * 8);
    for (var i = 0; i < values.length; i++) {
      bytes.setFloat64(i * 8, values[i], Endian.little);
    }
    return base64Encode(bytes.buffer.asUint8List());
  }

  /// Parses [doubles] output; also accepts a JSON list of numbers (null = NaN). Anything else
  /// gives an empty list.
  static Float64List parseDoubles(Object? v) {
    if (v is List) {
      return Float64List.fromList([
        for (final x in v) parseNumber(x) ?? double.nan,
      ]);
    }
    if (v is! String) return Float64List(0);
    final Uint8List bytes;
    try {
      bytes = base64Decode(v);
    } on FormatException {
      return Float64List(0);
    }
    final bd = ByteData.sublistView(bytes);
    final out = Float64List(bytes.length ~/ 8);
    for (var i = 0; i < out.length; i++) {
      out[i] = bd.getFloat64(i * 8, Endian.little);
    }
    return out;
  }

  /// A JSON number, or `"NaN"`/`"Infinity"`/`"-Infinity"`.
  static Object number(double v) {
    if (v.isNaN) return 'NaN';
    if (v.isInfinite) return v > 0 ? 'Infinity' : '-Infinity';
    return v == v.truncateToDouble() && v.abs() < 1e15 ? v.toInt() : v;
  }

  /// Parses [number] output (null for anything else).
  static double? parseNumber(Object? v) => switch (v) {
    num() => v.toDouble(),
    'NaN' => double.nan,
    'Infinity' => double.infinity,
    '-Infinity' => double.negativeInfinity,
    _ => null,
  };

  static Object? _tryDecode(String s) {
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  static Map<String, Object?> _map(Object? v) =>
      v is Map ? v.map((k, v) => MapEntry('$k', v)) : const <String, Object?>{};

  static List<Object?> _list(Object? v) => v is List ? v : const [];

  static List<String> _strings(Object? v) => [
    for (final x in _list(v)) x is String ? x : (x == null ? '' : '$x'),
  ];

  static T _enum<T extends Enum>(Object? v, List<T> values, T def) =>
      _enumOrNull(v, values) ?? def;

  static T? _enumOrNull<T extends Enum>(Object? v, List<T> values) {
    for (final e in values) {
      if (e.name == v) return e;
    }
    return null;
  }
}
