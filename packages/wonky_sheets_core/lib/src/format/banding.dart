import 'dart:convert';

import 'theme.dart';

/// Alternating colors style (`Banding.styleJson`, 06 §14.1).
final class BandingStyle {
  /// Creates a style.
  const BandingStyle({
    this.header,
    this.firstBand = '#FFFFFF',
    this.secondBand = '#E8F0FE',
    this.footer,
    this.showHeader = true,
    this.showFooter = false,
    this.dimension = 'rows',
  });

  /// Header color (theme refs allowed).
  final String? header;
  final String firstBand;
  final String secondBand;
  final String? footer;
  final bool showHeader;
  final bool showFooter;

  /// `rows` (P0) or `columns` (P2).
  final String dimension;

  /// Parses `styleJson`.
  static BandingStyle parse(String? json) {
    if (json == null || json.isEmpty) return const BandingStyle();
    Object? m;
    try {
      m = jsonDecode(json);
    } on FormatException {
      return const BandingStyle();
    }
    if (m is! Map) return const BandingStyle();
    String? s(String k) => m is Map && m[k] is String ? m[k] as String : null;
    bool? b(String k) => m is Map && m[k] is bool ? m[k] as bool : null;
    return BandingStyle(
      header: s('header'),
      firstBand: s('firstBand') ?? '#FFFFFF',
      secondBand: s('secondBand') ?? '#E8F0FE',
      footer: s('footer'),
      showHeader: b('showHeader') ?? true,
      showFooter: b('showFooter') ?? false,
      dimension: s('dimension') ?? 'rows',
    );
  }

  /// `styleJson`.
  String toJson() => jsonEncode({
    'v': 1,
    'header': ?header,
    'firstBand': firstBand,
    'secondBand': secondBand,
    'footer': ?footer,
    'showHeader': showHeader,
    'showFooter': showFooter,
    'dimension': dimension,
  });

  /// Copy with changes.
  BandingStyle copyWith({
    String? header,
    String? firstBand,
    String? secondBand,
    String? footer,
    bool? showHeader,
    bool? showFooter,
  }) => BandingStyle(
    header: header ?? this.header,
    firstBand: firstBand ?? this.firstBand,
    secondBand: secondBand ?? this.secondBand,
    footer: footer ?? this.footer,
    showHeader: showHeader ?? this.showHeader,
    showFooter: showFooter ?? this.showFooter,
    dimension: dimension,
  );

  /// The 12 default styles derived from the theme accents (light and medium
  /// variants of accents 1–6, 06 §14.2).
  static List<BandingStyle> presets(SpreadsheetTheme theme) {
    final out = <BandingStyle>[];
    for (final variant in [0.85, 0.7]) {
      for (final accent in theme.accents) {
        out.add(
          BandingStyle(
            header: accent,
            firstBand: '#FFFFFF',
            secondBand: ColorUtil.lighten(accent, variant),
            footer: ColorUtil.lighten(accent, variant - 0.25),
          ),
        );
      }
    }
    return out;
  }

  /// The banding contribution for a cell whose row is the [visibleIndex]-th
  /// visible row of a banding range with [visibleCount] visible rows.
  ///
  /// Returns `(fillColor, bold)`; bold is true only for the header row.
  (String? fill, bool bold) contributionAt(int visibleIndex, int visibleCount) {
    if (visibleIndex < 0 || visibleIndex >= visibleCount) return (null, false);
    var i = visibleIndex;
    if (showHeader) {
      if (i == 0) return (header ?? secondBand, true);
      i -= 1;
    }
    if (showFooter && visibleIndex == visibleCount - 1 && visibleCount > 1) {
      return (footer ?? secondBand, false);
    }
    return (i.isEven ? firstBand : secondBand, false);
  }

  @override
  bool operator ==(Object other) =>
      other is BandingStyle && other.toJson() == toJson();

  @override
  int get hashCode => toJson().hashCode;
}
