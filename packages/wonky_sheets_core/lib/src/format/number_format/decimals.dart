import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../../content/cell_content.dart';

/// Increase / decrease decimals (06 §5.10, `sheets.format.increaseDecimals`
/// / `decreaseDecimals`).
abstract final class DecimalsAdjuster {
  /// Maximum number of decimals.
  static const int maxDecimals = 30;

  /// Maximum fractional-second digits.
  static const int maxFractionalSeconds = 3;

  /// Returns [pattern] (a pattern, preset id or null for Automatic) with
  /// decimals changed by [delta] steps (+1 increase, −1 decrease).
  ///
  /// Automatic derives the displayed decimals of [activeValue] and returns
  /// `#,##0` plus that many ±[delta] decimals (Google behavior). Presets are
  /// resolved for [locale] first. Fractions and text sections are untouched;
  /// date/time sections adjust fractional seconds. Invalid patterns are
  /// returned unchanged.
  static String adjust(
    String? pattern,
    int delta, {
    CellValue? activeValue,
    String locale = 'en_US',
  }) {
    final resolved = NumberFormatPresets.isAutomatic(pattern)
        ? null
        : NumberFormatPresets.resolve(pattern, locale);
    if (resolved == null) return _automatic(delta, activeValue);
    var result = resolved;
    final steps = delta.abs();
    for (var i = 0; i < steps; i++) {
      final next = _step(result, delta > 0);
      if (next == null) break;
      result = next;
    }
    return result;
  }

  static String _automatic(int delta, CellValue? active) {
    final x = active is NumberValue ? active.number : 0.0;
    final d = AutomaticFormatter.displayedDecimals(x);
    var n = d + delta;
    if (n < 0) n = 0;
    if (n > maxDecimals) n = maxDecimals;
    final decimals = n > 0 ? '.${'0' * n}' : '';
    if (AutomaticFormatter.isScientificDisplay(x)) return '0${decimals}E+00';
    return '#,##0$decimals';
  }

  /// One step; null when nothing changes.
  static String? _step(String pattern, bool increase) {
    final NumberFormatAst ast;
    try {
      ast = NumberFormatParser.parse(pattern);
    } on FormatParseError {
      return null;
    }
    final edits = <(int, int, String)>[];
    for (final s in ast.sections) {
      switch (s.kind) {
        case NfSectionKind.number || NfSectionKind.scientific:
          _numberEdit(s, increase, edits);
        case NfSectionKind.dateTime:
          _timeEdit(s, increase, edits);
        default:
          break;
      }
    }
    if (edits.isEmpty) return null;
    edits.sort((a, b) => b.$1.compareTo(a.$1));
    var out = pattern;
    for (final (at, len, text) in edits) {
      out = out.replaceRange(at, at + len, text);
    }
    return out;
  }

  static void _numberEdit(
    NfSection s,
    bool increase,
    List<(int, int, String)> edits,
  ) {
    NfDigit? lastDecimal;
    NfDigit? lastInteger;
    NfDecimalPoint? point;
    var decimals = 0;
    for (final t in s.tokens) {
      switch (t) {
        case NfDigit(role: NfDigitRole.decimal):
          lastDecimal = t;
          decimals++;
        case NfDigit(role: NfDigitRole.integer):
          lastInteger = t;
        case NfDecimalPoint():
          point = t;
        default:
          break;
      }
    }
    if (increase) {
      if (decimals >= maxDecimals) return;
      if (lastDecimal != null) {
        edits.add((lastDecimal.end, 0, '0'));
      } else if (point != null) {
        edits.add((point.end, 0, '0'));
      } else if (lastInteger != null) {
        edits.add((lastInteger.end, 0, '.0'));
      }
    } else {
      if (lastDecimal == null) return;
      edits.add((lastDecimal.start, lastDecimal.end - lastDecimal.start, ''));
      if (decimals == 1 && point != null) {
        edits.add((point.start, point.end - point.start, ''));
      }
    }
  }

  static void _timeEdit(
    NfSection s,
    bool increase,
    List<(int, int, String)> edits,
  ) {
    NfFractionalSeconds? frac;
    NfToken? seconds;
    for (final t in s.tokens) {
      if (t is NfFractionalSeconds) frac = t;
      if (t is NfDatePart && t.unit == NfDateUnit.second) seconds = t;
      if (t is NfElapsed && t.unit == NfElapsedUnit.seconds) seconds = t;
    }
    if (increase) {
      if (frac != null) {
        if (frac.digits < maxFractionalSeconds) edits.add((frac.end, 0, '0'));
      } else if (seconds != null) {
        edits.add((seconds.end, 0, '.0'));
      }
    } else if (frac != null) {
      if (frac.digits > 1) {
        edits.add((frac.end - 1, 1, ''));
      } else {
        edits.add((frac.start, frac.end - frac.start, ''));
      }
    }
  }
}
