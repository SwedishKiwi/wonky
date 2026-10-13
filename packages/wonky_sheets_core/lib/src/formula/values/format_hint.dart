/// Kinds of automatic result formats (05 §6.2).
enum FormatHintKind {
  none,
  date,
  time,
  dateTime,
  duration,
  percent,
  currency,
  scientific,
  fromCell,
}

/// Automatic display format of a formula result. Never synced; cached with computed values.
final class FormatHint {
  final FormatHintKind kind;

  /// Currency code for [FormatHintKind.currency] (null = locale default), or the source cell's
  /// number format pattern for [FormatHintKind.fromCell].
  final String? detail;

  const FormatHint._(this.kind, [this.detail]);

  static const FormatHint none = FormatHint._(FormatHintKind.none);
  static const FormatHint date = FormatHint._(FormatHintKind.date);
  static const FormatHint time = FormatHint._(FormatHintKind.time);
  static const FormatHint dateTime = FormatHint._(FormatHintKind.dateTime);
  static const FormatHint duration = FormatHint._(FormatHintKind.duration);
  static const FormatHint percent = FormatHint._(FormatHintKind.percent);
  static const FormatHint scientific = FormatHint._(FormatHintKind.scientific);
  static const FormatHint currencyDefault = FormatHint._(
    FormatHintKind.currency,
  );

  factory FormatHint.currency([String? code]) => code == null
      ? currencyDefault
      : FormatHint._(FormatHintKind.currency, code);

  /// Format of the source cell (bare references, lookups).
  factory FormatHint.fromCell(String numberFormat) =>
      FormatHint._(FormatHintKind.fromCell, numberFormat);

  bool get isNone => kind == FormatHintKind.none;

  /// Whether the hint denotes a date or date-time display.
  bool get isDateLike =>
      kind == FormatHintKind.date ||
      kind == FormatHintKind.dateTime ||
      (kind == FormatHintKind.fromCell && looksLikeDatePattern(detail ?? ''));

  /// Short code used in the computed value cache (`"date"`, `"cur:EUR"`, `"fmt:0.00"`).
  String get code => switch (kind) {
    FormatHintKind.none => '',
    FormatHintKind.date => 'date',
    FormatHintKind.time => 'time',
    FormatHintKind.dateTime => 'dateTime',
    FormatHintKind.duration => 'duration',
    FormatHintKind.percent => 'percent',
    FormatHintKind.scientific => 'scientific',
    FormatHintKind.currency => detail == null ? 'cur' : 'cur:$detail',
    FormatHintKind.fromCell => 'fmt:$detail',
  };

  /// Inverse of [code].
  static FormatHint fromCode(String code) {
    if (code.isEmpty) return none;
    if (code.startsWith('fmt:')) return FormatHint.fromCell(code.substring(4));
    if (code == 'cur') return currencyDefault;
    if (code.startsWith('cur:')) return FormatHint.currency(code.substring(4));
    return switch (code) {
      'date' => date,
      'time' => time,
      'dateTime' => dateTime,
      'duration' => duration,
      'percent' => percent,
      'scientific' => scientific,
      _ => none,
    };
  }

  /// Heuristic: pattern contains date tokens outside quotes (`yyyy-mm-dd`, `d.m.yy`, …).
  static bool looksLikeDatePattern(String pattern) {
    if (pattern.startsWith('preset:')) {
      return pattern.contains('date') || pattern.contains('Date');
    }
    var inQuote = false;
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == '"') {
        inQuote = !inQuote;
        continue;
      }
      if (inQuote) continue;
      if (c == '\\') {
        i++;
        continue;
      }
      if (c == '[') {
        final end = pattern.indexOf(']', i);
        if (end < 0) break;
        i = end;
        continue;
      }
      final l = c.toLowerCase();
      if (l == 'y' || l == 'd') return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is FormatHint && other.kind == kind && other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, detail);

  @override
  String toString() => 'FormatHint(${code.isEmpty ? 'none' : code})';
}
