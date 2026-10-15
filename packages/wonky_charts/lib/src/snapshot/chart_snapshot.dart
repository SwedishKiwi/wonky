import 'dart:convert';

import 'package:archive/archive.dart' show GZipDecoder, GZipEncoder;

import '../data/chart_data.dart';
import '../layout/chart_theme_source.dart';
import '../spec/chart_spec.dart';

/// The look of the source document a chart was resolved in (Slides 08 §3.4 `sourceTheme`):
/// accents 1–6, the text font and every named theme color, so *Keep source style* renders the
/// chart exactly like the spreadsheet.
final class ChartSourceTheme implements ChartThemeSource {
  /// Creates a source theme (colors are opaque ARGB).
  const ChartSourceTheme({
    required this.accentArgbs,
    this.textFont = 'Arial',
    this.colors = const {},
  });

  /// Captures [source]'s accents and font plus the named [colors] (`#RRGGBB` or ARGB ints;
  /// e.g. a spreadsheet theme's color map).
  factory ChartSourceTheme.of(
    ChartThemeSource source, {
    Map<String, Object?> colors = const {},
  }) => ChartSourceTheme(
    accentArgbs: List.unmodifiable(source.accentArgbs),
    textFont: source.textFont,
    colors: {for (final e in colors.entries) e.key: ?_argb(e.value)},
  );

  /// Parses `{"accents": ["#4285F4", …], "textFont": "Inter", "colors": {"text": "#000000"}}`
  /// (null when [json] has no accents).
  static ChartSourceTheme? fromJson(Object? json) {
    if (json is! Map) return null;
    final accents = [
      for (final a in json['accents'] is List ? json['accents']! as List : [])
        ?_argb(a),
    ];
    if (accents.isEmpty) return null;
    final colors = json['colors'];
    return ChartSourceTheme(
      accentArgbs: accents,
      textFont: json['textFont'] is String
          ? json['textFont']! as String
          : 'Arial',
      colors: {
        if (colors is Map)
          for (final e in colors.entries) '${e.key}': ?_argb(e.value),
      },
    );
  }

  @override
  final List<int> accentArgbs;

  @override
  final String textFont;

  /// Named theme colors for `theme:<key>`.
  final Map<String, int> colors;

  @override
  int? resolveArgb(String? color) => ChartThemeColors(
    accentArgbs: accentArgbs,
    textFont: textFont,
    colors: colors,
  ).resolveArgb(color);

  /// Snapshot JSON.
  Map<String, Object?> toJson() => {
    'accents': [for (final a in accentArgbs) _hex(a)],
    'textFont': textFont,
    if (colors.isNotEmpty)
      'colors': {
        for (final k in colors.keys.toList()..sort()) k: _hex(colors[k]!),
      },
  };

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static int? _argb(Object? v) {
    if (v is int) return 0xFF000000 | (v & 0xFFFFFF);
    if (v is! String) return null;
    var hex = v;
    if (hex.length == 4 && hex.startsWith('#')) {
      hex = '#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}';
    }
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
    return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
  }
}

/// Display information about a snapshot's source (Slides 08 §3.4 `source`), refreshed on
/// every update. Never used to resolve anything.
final class ChartSourceInfo {
  /// Creates source info.
  const ChartSourceInfo({
    this.spreadsheetTitle = '',
    this.sheetName = '',
    this.chartTitle = '',
    this.rangesA1 = const [],
  });

  /// Parses the `source` object.
  factory ChartSourceInfo.fromJson(Object? json) {
    if (json is! Map) return const ChartSourceInfo();
    String s(String k) => json[k] is String ? json[k]! as String : '';
    return ChartSourceInfo(
      spreadsheetTitle: s('spreadsheetTitle'),
      sheetName: s('sheetName'),
      chartTitle: s('chartTitle'),
      rangesA1: [
        for (final r
            in json['rangesA1'] is List ? json['rangesA1']! as List : [])
          if (r is String) r,
      ],
    );
  }

  final String spreadsheetTitle;
  final String sheetName;
  final String chartTitle;

  /// The data ranges in A1 form (`Q3!A1:D13`).
  final List<String> rangesA1;

  /// Snapshot JSON.
  Map<String, Object?> toJson() => {
    'spreadsheetTitle': spreadsheetTitle,
    'sheetName': sheetName,
    'chartTitle': chartTitle,
    'rangesA1': rangesA1,
  };
}

/// The `dataSnapshotJson` of a linked chart (Slides 08 §3.4): the resolved [data], the
/// source's theme and locale, display info and the [version] token it was resolved at.
///
/// Only resolved series are stored: no cell values beyond what the chart shows, no formulas
/// and no ranges other than the display strings in [source] (08 §6).
final class ChartDataSnapshot {
  /// Creates a snapshot.
  const ChartDataSnapshot({
    required this.data,
    this.sourceTheme,
    this.locale = 'en_US',
    this.source = const ChartSourceInfo(),
    this.version = '',
    this.formatVersion = currentVersion,
  });

  /// Parses snapshot JSON (a map or a string, `gz:` columns included). Lenient: a missing or
  /// malformed `data` gives empty data.
  factory ChartDataSnapshot.fromJson(Object? json) {
    Object? m = json;
    if (json is String) m = _decodeJson(ChartSnapshotColumns.decode(json));
    if (m is! Map) {
      return ChartDataSnapshot(data: ChartData.empty(), formatVersion: 0);
    }
    return ChartDataSnapshot(
      data: m['data'] is Map
          ? ChartData.fromJson(m['data'])
          : ChartData.empty(),
      sourceTheme: ChartSourceTheme.fromJson(m['sourceTheme']),
      locale: m['locale'] is String ? m['locale']! as String : 'en_US',
      source: ChartSourceInfo.fromJson(m['source']),
      version: m['version'] is String ? m['version']! as String : '',
      formatVersion: m['v'] is num ? (m['v']! as num).toInt() : 0,
    );
  }

  /// The format version this code writes.
  static const int currentVersion = 1;

  final ChartData data;

  /// The spreadsheet's theme (null: unknown, the deck theme is used).
  final ChartSourceTheme? sourceTheme;

  /// Spreadsheet locale (labels and ticks).
  final String locale;
  final ChartSourceInfo source;

  /// The `sourceVersion` token (= `ChartLink.sourceVersion`).
  final String version;

  /// `v` of the JSON (0 = missing: a placeholder snapshot written before the first resolve).
  final int formatVersion;

  /// Whether the snapshot was written by a newer version of the format.
  bool get isFromNewerVersion => formatVersion > currentVersion;

  /// Whether the snapshot holds no resolved data yet (a link pasted before its first
  /// resolve, `{"v":1}`).
  bool get isPlaceholder =>
      data.series.isEmpty &&
      data.table == null &&
      data.scorecard == null &&
      data.histogram == null &&
      data.domain.length == 0;

  /// Snapshot JSON.
  Map<String, Object?> toJson() => {
    'v': formatVersion == 0 ? currentVersion : formatVersion,
    'data': data.toJson(),
    if (sourceTheme != null) 'sourceTheme': sourceTheme!.toJson(),
    'locale': locale,
    'source': source.toJson(),
    'version': version,
  };

  /// [toJson] as a string.
  String encode() => jsonEncode(toJson());
}

/// A chart snapshot as rendered by Slides (Slides 08 §3.4): the source [spec] plus the
/// [dataSnapshot], read from the two `ChartLink` columns of a linked chart ([fromColumns]) or
/// from `dataJson.snapshot` of a static chart ([fromJson]).
///
/// (The spec's in-memory pair `ChartSnapshot`; named `ChartSourceSnapshot` because the Slides
/// core's operations already have a `ChartSnapshot` — the column values of a link update.)
final class ChartSourceSnapshot {
  /// Creates a snapshot.
  const ChartSourceSnapshot({required this.spec, required this.dataSnapshot});

  /// Reads the `ChartLink.sourceSpecJson` and `dataSnapshotJson` columns (either may carry
  /// the `gz:` prefix).
  factory ChartSourceSnapshot.fromColumns(
    String sourceSpecJson,
    String dataSnapshotJson,
  ) => ChartSourceSnapshot(
    spec: _spec(ChartSnapshotColumns.decode(sourceSpecJson)),
    dataSnapshot: ChartDataSnapshot.fromJson(dataSnapshotJson),
  );

  /// Reads `{"sourceSpec": {…}, "dataSnapshot": {…}}` (a static chart's `dataJson.snapshot`);
  /// null when [json] is not such an object.
  static ChartSourceSnapshot? fromJson(Object? json) {
    if (json is! Map || json['sourceSpec'] == null) return null;
    final spec = json['sourceSpec'];
    return ChartSourceSnapshot(
      spec: _spec(spec is String ? ChartSnapshotColumns.decode(spec) : spec),
      dataSnapshot: ChartDataSnapshot.fromJson(json['dataSnapshot']),
    );
  }

  /// The source chart spec (its `data.ranges` are opaque display references).
  final ChartSpec spec;
  final ChartDataSnapshot dataSnapshot;

  /// The resolved data.
  ChartData get data => dataSnapshot.data;

  /// `{"sourceSpec", "dataSnapshot"}` (the static form).
  Map<String, Object?> toJson() => {
    'sourceSpec': spec.toJson(),
    'dataSnapshot': dataSnapshot.toJson(),
  };

  /// The two column values (`gz:`-compressed beyond [ChartSnapshotColumns.compressAbove]).
  (String sourceSpecJson, String dataSnapshotJson) toColumns() => (
    ChartSnapshotColumns.encode(spec.encode()),
    ChartSnapshotColumns.encode(dataSnapshot.encode()),
  );

  static ChartSpec _spec(Object? json) {
    try {
      return ChartSpec.fromJson(json is String ? _decodeJson(json) : json);
    } on Object {
      return ChartSpec.fromJson(const <String, Object?>{});
    }
  }
}

Object? _decodeJson(String s) {
  try {
    return jsonDecode(s);
  } on FormatException {
    return null;
  }
}

/// The storage form of the snapshot columns (Slides 08 §3.3): JSON as is, or `gz:` +
/// base64(gzip(UTF-8 JSON)) when the JSON is larger than [compressAbove] bytes.
abstract final class ChartSnapshotColumns {
  /// JSON larger than this (UTF-8 bytes) is compressed: 32 KB.
  static const int compressAbove = 32 * 1024;

  /// Largest compressed snapshot a deck accepts (08 §3.4, `chart_too_large`): 512 KB.
  static const int maxCompressedBytes = 512 * 1024;

  /// The prefix of compressed values.
  static const String gzPrefix = 'gz:';

  /// [json] in storage form.
  static String encode(String json, {int threshold = compressAbove}) {
    final bytes = utf8.encode(json);
    if (bytes.length <= threshold) return json;
    return '$gzPrefix${base64Encode(const GZipEncoder().encodeBytes(bytes))}';
  }

  /// The JSON of a stored value (compressed or not). A corrupt `gz:` value gives `{}`.
  static String decode(String stored) {
    if (!stored.startsWith(gzPrefix)) return stored;
    try {
      return utf8.decode(
        const GZipDecoder().decodeBytes(
          base64Decode(stored.substring(gzPrefix.length)),
        ),
      );
    } on Object {
      return '{}';
    }
  }

  /// Whether [stored] is compressed.
  static bool isCompressed(String stored) => stored.startsWith(gzPrefix);

  /// The compressed size of [json] in bytes (the limit check of 08 §3.4).
  static int compressedSize(String json) =>
      const GZipEncoder().encodeBytes(utf8.encode(json)).length;
}

/// The `sourceVersion` token of a snapshot (Slides 08 §5.1):
/// `<changeLog>:<specHash>:<dataVersion>`.
final class ChartSourceVersion {
  /// Creates a token.
  const ChartSourceVersion({
    required this.changeLog,
    required this.specHash,
    required this.dataVersion,
  });

  /// Parses a token (null when it doesn't have three parts).
  static ChartSourceVersion? tryParse(String? token) {
    if (token == null) return null;
    final parts = token.split(':');
    if (parts.length != 3) return null;
    return ChartSourceVersion(
      changeLog: parts[0],
      specHash: parts[1],
      dataVersion: parts[2],
    );
  }

  /// Marker of the spreadsheet's change log when resolved (the cheap "anything changed?"
  /// check); empty when the spreadsheet had no change log rows.
  final String changeLog;

  /// First 16 hex digits of the SHA-256 of the canonical spec JSON.
  final String specHash;

  /// `ChartData.dataVersion` as a decimal string.
  final String dataVersion;

  /// Whether the chart (spec and data) is the same as in [other], whatever the change logs.
  bool sameChartAs(ChartSourceVersion other) =>
      specHash == other.specHash && dataVersion == other.dataVersion;

  @override
  String toString() => '$changeLog:$specHash:$dataVersion';

  @override
  bool operator ==(Object other) =>
      other is ChartSourceVersion && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}
