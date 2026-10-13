import 'dart:convert';

import 'package:collection/collection.dart';

/// Keys allowed in a rich text run's format (06 §11).
abstract final class RichRunKeys {
  static const bold = 'bold';
  static const italic = 'italic';
  static const underline = 'underline';
  static const strikethrough = 'strikethrough';
  static const textColor = 'textColor';
  static const fontFamily = 'fontFamily';
  static const fontSize = 'fontSize';
  static const link = 'link';
  static const chip = 'chip';

  /// All known keys.
  static const all = {
    bold,
    italic,
    underline,
    strikethrough,
    textColor,
    fontFamily,
    fontSize,
    link,
    chip,
  };
}

/// One formatted run `[start, end)` in UTF-16 code units.
final class RichRun {
  /// Creates a run.
  const RichRun(this.start, this.end, this.format);

  /// Inclusive start offset.
  final int start;

  /// Exclusive end offset.
  final int end;

  /// Format keys ([RichRunKeys]) → values.
  final Map<String, Object?> format;

  /// Link of this run, if any.
  String? get link => format[RichRunKeys.link] as String?;

  /// Length in code units.
  int get length => end - start;

  /// JSON `{"s","e","f"}`.
  Map<String, Object?> toJson() => {'s': start, 'e': end, 'f': format};

  /// Copy with other bounds/format.
  RichRun copyWith({int? start, int? end, Map<String, Object?>? format}) =>
      RichRun(start ?? this.start, end ?? this.end, format ?? this.format);

  static const _mapEq = MapEquality<String, Object?>();

  @override
  bool operator ==(Object other) =>
      other is RichRun &&
      other.start == start &&
      other.end == end &&
      _mapEq.equals(other.format, format);

  @override
  int get hashCode => Object.hash(start, end, _mapEq.hash(format));

  @override
  String toString() => 'RichRun($start, $end, $format)';
}

/// Rich text cell content `{"t": text, "runs": [...]}` (02 §2, 06 §11).
final class RichText {
  /// Creates rich text. Runs must be sorted and non-overlapping.
  const RichText(this.text, this.runs);

  /// The plain text.
  final String text;

  /// Formatted runs (sorted, non-overlapping).
  final List<RichRun> runs;

  /// Parses the JSON body after `r:`; null when malformed.
  static RichText? tryParseJson(String json) {
    try {
      final m = jsonDecode(json);
      if (m is! Map) return null;
      return fromJson(m.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }

  /// From a decoded JSON map.
  static RichText? fromJson(Map<String, Object?> m) {
    final t = m['t'];
    if (t is! String) return null;
    final runs = <RichRun>[];
    final raw = m['runs'];
    if (raw is List) {
      for (final r in raw) {
        if (r is! Map) continue;
        final s = r['s'];
        final e = r['e'];
        final f = r['f'];
        if (s is! num || e is! num) continue;
        runs.add(
          RichRun(
            s.toInt().clamp(0, t.length),
            e.toInt().clamp(0, t.length),
            f is Map
                ? Map<String, Object?>.from(f.cast<String, Object?>())
                : const {},
          ),
        );
      }
    }
    runs.sort((a, b) => a.start.compareTo(b.start));
    return RichText(t, runs);
  }

  /// JSON map.
  Map<String, Object?> toJson() => {
    't': text,
    'runs': [for (final r in runs) r.toJson()],
  };

  /// Distinct links in the runs.
  Iterable<String> get links =>
      runs.map((r) => r.link).whereType<String>().toSet();

  /// The format applying at [offset], or an empty map.
  Map<String, Object?> formatAt(int offset) {
    for (final r in runs) {
      if (offset >= r.start && offset < r.end) return r.format;
    }
    return const {};
  }

  /// Normalizes per 06 §11: merges adjacent runs with equal formats, drops empty
  /// runs, removes keys whose value equals [cellFormat] (the cell-level value of
  /// that key) and keys with null values.
  ///
  /// The result's [RichNormalizeResult.rich] is null when no run remains (store
  /// plain text). A single link run covering the whole text becomes
  /// [RichNormalizeResult.wholeCellLink] (store `linkUrl` + plain text) when it has
  /// no other keys.
  RichNormalizeResult normalize({Map<String, Object?> cellFormat = const {}}) {
    final cleaned = <RichRun>[];
    for (final r in runs) {
      final s = r.start.clamp(0, text.length);
      final e = r.end.clamp(0, text.length);
      if (e <= s) continue;
      final f = <String, Object?>{};
      r.format.forEach((k, v) {
        if (v == null) return;
        if (cellFormat.containsKey(k) && cellFormat[k] == v) return;
        if (v == false &&
            !cellFormat.containsKey(k) &&
            k != RichRunKeys.underline) {
          // false for bold/italic/strike equals the default.
          return;
        }
        f[k] = v;
      });
      if (f.isEmpty) continue;
      if (cleaned.isNotEmpty) {
        final last = cleaned.last;
        if (last.end == s &&
            const MapEquality<String, Object?>().equals(last.format, f)) {
          cleaned[cleaned.length - 1] = last.copyWith(end: e);
          continue;
        }
      }
      cleaned.add(RichRun(s, e, f));
    }
    if (cleaned.isEmpty) return const RichNormalizeResult(null, null);
    if (cleaned.length == 1) {
      final only = cleaned.single;
      if (only.start == 0 &&
          only.end == text.length &&
          only.format.length == 1 &&
          only.link != null) {
        return RichNormalizeResult(null, only.link);
      }
    }
    return RichNormalizeResult(RichText(text, cleaned), null);
  }

  /// Removes [key] from every run (used when a cell-level text format is set, 06 §11).
  RichText withoutKey(String key) => RichText(text, [
    for (final r in runs)
      if (r.format.containsKey(key))
        r.copyWith(format: Map.of(r.format)..remove(key))
      else
        r,
  ]);

  /// Keeps only link keys (clear formatting keeps link runs, 06 §3).
  RichText onlyLinks() => RichText(text, [
    for (final r in runs)
      if (r.link != null) r.copyWith(format: {RichRunKeys.link: r.link}),
  ]);

  /// Applies [format] to `[start, end)`, splitting runs as needed (in-editor
  /// formatting). Null values remove the key.
  RichText applyFormat(int start, int end, Map<String, Object?> format) {
    if (end <= start) return this;
    // Build per-boundary segments.
    final bounds = <int>{0, text.length, start, end};
    for (final r in runs) {
      bounds
        ..add(r.start)
        ..add(r.end);
    }
    final sorted = bounds.where((b) => b >= 0 && b <= text.length).toList()
      ..sort();
    final out = <RichRun>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      final s = sorted[i];
      final e = sorted[i + 1];
      if (e <= s) continue;
      final f = Map<String, Object?>.of(formatAt(s));
      if (s >= start && e <= end) {
        format.forEach((k, v) {
          if (v == null) {
            f.remove(k);
          } else {
            f[k] = v;
          }
        });
      }
      if (f.isNotEmpty) out.add(RichRun(s, e, f));
    }
    return RichText(text, out);
  }

  /// Re-offsets runs after replacing the text with [newText] where [mapOffset]
  /// maps old offsets to new ones (trim whitespace, 07 §12.2).
  RichText remap(String newText, int Function(int oldOffset) mapOffset) {
    final out = <RichRun>[];
    for (final r in runs) {
      final s = mapOffset(r.start).clamp(0, newText.length);
      final e = mapOffset(r.end).clamp(0, newText.length);
      if (e > s) out.add(RichRun(s, e, r.format));
    }
    return RichText(newText, out);
  }

  static const _listEq = ListEquality<RichRun>();

  @override
  bool operator ==(Object other) =>
      other is RichText &&
      other.text == text &&
      _listEq.equals(other.runs, runs);

  @override
  int get hashCode => Object.hash(text, _listEq.hash(runs));

  @override
  String toString() => 'RichText($text, $runs)';
}

/// Result of [RichText.normalize].
final class RichNormalizeResult {
  /// Creates a result.
  const RichNormalizeResult(this.rich, this.wholeCellLink);

  /// Remaining rich text, or null for plain text.
  final RichText? rich;

  /// A link covering the whole text (to be stored as `linkUrl`).
  final String? wholeCellLink;
}
