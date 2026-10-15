import 'dart:convert';

import 'package:wonky_charts/wonky_charts.dart';

/// Where a chart element's data comes from (Slides 08 §3.1).
enum SlideChartSource {
  /// Linked to a chart in a spreadsheet (`ChartLink` row, snapshot refreshed by *Update*).
  linked,

  /// A former linked chart (unlinked, or inserted with *Link* off): a frozen snapshot in
  /// `dataJson.snapshot`.
  static,

  /// Created in Slides from a small data table (P1).
  native,
}

/// `dataJson.style` (Slides 08 §3.2): the deck-side look of a chart.
final class SlideChartStyle {
  /// Creates a style.
  const SlideChartStyle({this.useDeckTheme = true, this.palette, this.font});

  /// Parses the object (lenient).
  factory SlideChartStyle.fromJson(Object? json) {
    if (json is! Map) return const SlideChartStyle();
    final p = json['palette'];
    return SlideChartStyle(
      useDeckTheme: json['useDeckTheme'] is bool
          ? json['useDeckTheme']! as bool
          : true,
      palette: p is List
          ? [
              for (final c in p)
                if (c is String) c,
            ]
          : null,
      font: json['font'] is String ? json['font']! as String : null,
    );
  }

  /// true: restyle to the deck theme; false: keep the sheet's look (08 §3.5).
  final bool useDeckTheme;

  /// Explicit series colors (`#hex`, `theme:<key>`), or null.
  final List<String>? palette;

  /// Font reference (`@body`, `@heading`, `@mono` or a family), or null.
  final String? font;

  /// JSON.
  Map<String, Object?> toJson() => {
    'useDeckTheme': useDeckTheme,
    'palette': palette,
    'font': font,
  };
}

/// `dataJson.interactive` (Slides 08 §10.5).
final class SlideChartInteractive {
  /// Creates the options.
  const SlideChartInteractive({
    this.hoverTooltips = false,
    this.orbitInPresent = false,
  });

  /// Parses the object (lenient).
  factory SlideChartInteractive.fromJson(Object? json) => json is Map
      ? SlideChartInteractive(
          hoverTooltips: json['hoverTooltips'] == true,
          orbitInPresent: json['orbitInPresent'] == true,
        )
      : const SlideChartInteractive();

  final bool hoverTooltips;
  final bool orbitInPresent;

  /// JSON.
  Map<String, Object?> toJson() => {
    'hoverTooltips': hoverTooltips,
    'orbitInPresent': orbitInPresent,
  };
}

/// The `dataJson` of a chart element (Slides 08 §3.2, 02 §6.8):
///
/// ```jsonc
/// {"v": 1, "source": "linked" | "static" | "native",
///  "style": {"useDeckTheme": true, "palette": null, "font": null},
///  "camera": null | {"azimuth", "elevation", "perspective"},
///  "overrides": {…},          // allowlisted merge patch over the source spec (ChartOverrides)
///  "snapshot": null | {"sourceSpec", "dataSnapshot"},   // static
///  "spec": null, "data": null, // native (P1)
///  "background": "transparent" | "theme" | "#hex",       // absent = the style mode's default
///  "interactive": {"hoverTooltips": false, "orbitInPresent": false}}
/// ```
///
/// Reading is lenient and also accepts the static charts written before SL-27 (pasted from
/// Sheets unlinked: `spec` without data; unlinked by the M9 planner: `spec` + `data` holding
/// the data snapshot). Unknown keys are kept ([extras]).
final class ChartElementData {
  /// Creates element data.
  const ChartElementData({
    this.source = SlideChartSource.linked,
    this.style = const SlideChartStyle(),
    this.camera,
    this.overrides = const {},
    this.snapshot,
    this.spec,
    this.data,
    this.background,
    this.interactive = const SlideChartInteractive(),
    this.extras = const {},
  });

  /// Parses `dataJson` (a map, a JSON string or null).
  factory ChartElementData.fromJson(Object? json) {
    Object? m = json;
    if (json is String) {
      try {
        m = jsonDecode(json);
      } on FormatException {
        m = null;
      }
    }
    if (m is! Map) return const ChartElementData();
    final map = m.map((k, v) => MapEntry('$k', v));
    final source = switch (map['source']) {
      'static' => SlideChartSource.static,
      'native' => SlideChartSource.native,
      _ => SlideChartSource.linked,
    };
    var snapshot = ChartSourceSnapshot.fromJson(map['snapshot']);
    Map<String, Object?>? spec = _obj(map['spec']);
    Map<String, Object?>? data = _obj(map['data']);
    if (source == SlideChartSource.static && snapshot == null && spec != null) {
      // Pre-SL-27 static charts: `spec` (+ the data snapshot in `data`).
      snapshot = ChartSourceSnapshot.fromJson({
        'sourceSpec': spec,
        'dataSnapshot': data ?? const {'v': 1},
      });
      spec = null;
      data = null;
    }
    return ChartElementData(
      source: source,
      style: SlideChartStyle.fromJson(map['style']),
      camera: Chart3DView.fromJson(map['camera']),
      overrides: _obj(map['overrides']) ?? const {},
      snapshot: snapshot,
      spec: spec,
      data: data,
      background: map['background'] is String
          ? map['background']! as String
          : null,
      interactive: SlideChartInteractive.fromJson(map['interactive']),
      extras: {
        for (final e in map.entries)
          if (!_keys.contains(e.key)) e.key: e.value,
      },
    );
  }

  static const _keys = {
    'v',
    'source',
    'style',
    'camera',
    'overrides',
    'snapshot',
    'spec',
    'data',
    'background',
    'interactive',
  };

  static Map<String, Object?>? _obj(Object? v) =>
      v is Map ? v.map((k, v) => MapEntry('$k', v)) : null;

  final SlideChartSource source;
  final SlideChartStyle style;

  /// 3D camera override, or null (the source spec's view).
  final Chart3DView? camera;

  /// Allowlisted RFC 7386 merge patch over the source spec (08 §8.2).
  final Map<String, Object?> overrides;

  /// Static charts: the frozen snapshot.
  final ChartSourceSnapshot? snapshot;

  /// Native charts (P1): the full spec without data ranges.
  final Map<String, Object?>? spec;

  /// Native charts (P1): the `ChartTable` (08 §11).
  final Map<String, Object?>? data;

  /// `transparent`, `theme` or `#hex`; null = the default of the style mode (08 §3.5).
  final String? background;
  final SlideChartInteractive interactive;

  /// Unknown keys (kept on write).
  final Map<String, Object?> extras;

  /// The canonical `dataJson`.
  Map<String, Object?> toJson() => {
    ...extras,
    'v': 1,
    'source': source.name,
    'style': style.toJson(),
    'camera': camera?.toJson(),
    if (overrides.isNotEmpty) 'overrides': overrides,
    if (snapshot != null) 'snapshot': snapshot!.toJson(),
    if (spec != null) 'spec': spec,
    if (data != null) 'data': data,
    'background': ?background,
    'interactive': interactive.toJson(),
  };

  /// [toJson] as a string.
  String encode() => jsonEncode(toJson());

  /// Copy with changes ([clearCamera], [clearBackground] reset to null).
  ChartElementData copyWith({
    SlideChartSource? source,
    SlideChartStyle? style,
    Chart3DView? camera,
    bool clearCamera = false,
    Map<String, Object?>? overrides,
    ChartSourceSnapshot? snapshot,
    String? background,
    bool clearBackground = false,
    SlideChartInteractive? interactive,
  }) => ChartElementData(
    source: source ?? this.source,
    style: style ?? this.style,
    camera: clearCamera ? null : (camera ?? this.camera),
    overrides: overrides ?? this.overrides,
    snapshot: snapshot ?? this.snapshot,
    spec: spec,
    data: data,
    background: clearBackground ? null : (background ?? this.background),
    interactive: interactive ?? this.interactive,
    extras: extras,
  );
}
