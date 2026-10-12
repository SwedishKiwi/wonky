/// Heading number labels (06 §2.4 `headings.numbering`, §6.3).
library;

import '../model/style_enums.dart';
import '../resolve/resolved_theme.dart';
import 'list_markers.dart';

/// Computes heading labels such as `"1.2. "` for a sequence of headings.
///
/// Counters behave like CSS counters: a heading of level `n` increments the
/// counter of level `n` and resets all deeper counters; a skipped level
/// contributes `0` to outline paths (`H1, H3` → `1`, `1.0.1`).
///
/// Label core per style (depth = level − fromLevel):
/// - `decimal`: own counter + `"."` (`"2."`),
/// - `outline`: counters `fromLevel…level` joined by `"."` (`"1.2.1"`),
/// - `legal`: like outline with a trailing dot (`"1.2.1."`),
/// - `upperRoman-upperAlpha-decimal`: own counter as `I.`, `A.`, `1.`, then
///   `a.`, `i.`, `1.` for deeper levels.
///
/// The label is the core followed by the configured suffix; when the core
/// ends with `"."` a leading `"."` of the suffix is dropped (so the suffix
/// `". "` never doubles the dot).
final class HeadingNumberer {
  /// Creates a numberer for [config].
  HeadingNumberer(this.config);

  /// The numbering configuration.
  final ResolvedHeadingNumbering config;

  final List<int> _counters = List.filled(6, 0);

  static const _romanCycle = [
    ListNumberStyle.upperRoman,
    ListNumberStyle.upperAlpha,
    ListNumberStyle.decimal,
    ListNumberStyle.lowerAlpha,
    ListNumberStyle.lowerRoman,
    ListNumberStyle.decimal,
  ];

  /// Resets all counters (start of a document).
  void reset() => _counters.fillRange(0, 6, 0);

  /// Advances the counters for a heading of [level] (1–6) and returns its
  /// label including suffix, or `null` when the level is not numbered.
  String? next(int level) {
    final l = level.clamp(1, 6);
    _counters[l - 1]++;
    for (var i = l; i < 6; i++) {
      _counters[i] = 0;
    }
    if (!config.numbers(l)) return null;
    final core = _core(l);
    var suffix = config.suffix;
    if (core.endsWith('.') && suffix.startsWith('.')) {
      suffix = suffix.substring(1);
    }
    return core + suffix;
  }

  String _core(int level) {
    final from = config.fromLevel;
    switch (config.style) {
      case HeadingNumberingStyle.decimal:
        return '${_counters[level - 1]}.';
      case HeadingNumberingStyle.outline:
        return _path(from, level);
      case HeadingNumberingStyle.legal:
        return '${_path(from, level)}.';
      case HeadingNumberingStyle.upperRomanUpperAlphaDecimal:
        final depth = (level - from).clamp(0, 5);
        return '${ListMarkers.ordinal(_counters[level - 1], _romanCycle[depth])}.';
    }
  }

  String _path(int from, int level) =>
      [for (var i = from; i <= level; i++) _counters[i - 1]].join('.');

  /// Labels for a whole document's heading [levels] in order (`null` for
  /// unnumbered headings). Does not change this numberer's state.
  static List<String?> labelsFor(
    ResolvedHeadingNumbering config,
    Iterable<int> levels,
  ) {
    final n = HeadingNumberer(config);
    return [for (final l in levels) n.next(l)];
  }
}
