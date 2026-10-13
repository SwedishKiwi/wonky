import '../../content/cell_content.dart';
import 'ast.dart';
import 'automatic.dart';
import 'decimal_digits.dart';
import 'locale_data.dart';
import 'number_formatter.dart';
import 'serial_calendar.dart';

/// Renders cell values with a parsed [NumberFormatAst] (06 §5.3–5.8).
/// Stateless and uncached; `NumberFormatter` adds caching.
abstract final class NumberFormatRenderer {
  static const FormattedValue _empty = FormattedValue([]);

  /// Renders [value] with [ast] in [locale].
  static FormattedValue render(
    NumberFormatAst ast,
    CellValue value,
    LocaleFormatData locale,
  ) {
    switch (value) {
      case EmptyValue():
        return _empty;
      case BoolValue(:final value):
        return FormattedValue.text(value ? 'TRUE' : 'FALSE');
      case ErrorValue(:final kind):
        return FormattedValue.text(kind.literal);
      case TextValue(:final text):
        return renderText(ast, text, locale);
      case NumberValue(:final number):
        return renderNumber(ast, number, locale);
    }
  }

  /// Renders a text value: the text section (`@`) if any, else the text as is.
  static FormattedValue renderText(
    NumberFormatAst ast,
    String text,
    LocaleFormatData locale,
  ) {
    final s = ast.textSection;
    if (s == null) return FormattedValue.text(text);
    if (s.kind == NfSectionKind.empty) return _empty;
    final out = _Out();
    for (final t in s.tokens) {
      if (t is NfTextPlaceholder) {
        out.text(text);
      } else {
        _common(t, out, locale);
      }
    }
    return out.build(s.colorArgb, overflow: false);
  }

  /// Automatic display of a number.
  static FormattedValue automatic(double x, LocaleFormatData locale) =>
      FormattedValue.text(
        AutomaticFormatter.formatWith(x, locale),
        overflowHashes: true,
      );

  /// Renders a number.
  static FormattedValue renderNumber(
    NumberFormatAst ast,
    double x,
    LocaleFormatData locale,
  ) {
    if (!x.isFinite) return FormattedValue.text('#NUM!');
    if (x == 0) x = 0; // normalize -0.0
    final sections = ast.numberSections;
    if (sections.isEmpty) return automatic(x, locale);
    NfSection? section;
    var signed = true;
    var v = x;
    if (ast.hasConditions) {
      for (final s in sections) {
        final c = s.condition;
        if (c == null) {
          section = s;
          break;
        }
        if (c.matches(x)) {
          section = s;
          break;
        }
      }
      if (section == null) return automatic(x, locale);
    } else if (sections.length == 1) {
      section = sections[0];
    } else if (sections.length == 2) {
      section = x >= 0 ? sections[0] : sections[1];
      signed = x >= 0;
      v = x.abs();
    } else {
      section = x > 0 ? sections[0] : (x < 0 ? sections[1] : sections[2]);
      signed = x > 0;
      v = x.abs();
    }
    return renderSection(section, v, locale, signed: signed);
  }

  /// Renders [v] with one [section]. When [signed] is true a negative [v]
  /// shows a leading minus (dates: dates before 1899; durations: `-`).
  static FormattedValue renderSection(
    NfSection section,
    double v,
    LocaleFormatData locale, {
    bool signed = true,
  }) {
    switch (section.kind) {
      case NfSectionKind.empty:
        return _empty;
      case NfSectionKind.dateTime:
        return _date(section, v, locale) ?? automatic(v, locale);
      case NfSectionKind.general:
        final out = _Out();
        for (final t in section.tokens) {
          if (t is NfGeneral) {
            out.text(AutomaticFormatter.formatWith(v, locale));
          } else {
            _common(t, out, locale);
          }
        }
        return out.build(section.colorArgb);
      case NfSectionKind.text || NfSectionKind.literal:
        final out = _Out();
        for (final t in section.tokens) {
          if (t is NfTextPlaceholder) {
            out.text(AutomaticFormatter.formatWith(v.abs(), locale));
          } else {
            _common(t, out, locale);
          }
        }
        if (v < 0) out.insertMinus(locale.minus);
        return out.build(section.colorArgb);
      case NfSectionKind.number:
        return _number(section, v, locale);
      case NfSectionKind.scientific:
        return _scientific(section, v, locale);
      case NfSectionKind.fraction:
        return _fraction(section, v, locale);
    }
  }

  /// Literal-like tokens shared by all section kinds.
  static void _common(NfToken t, _Out out, LocaleFormatData locale) {
    switch (t) {
      case NfLiteral(:final text):
        out.text(text);
      case NfSpacer(:final char):
        out.spacer(char);
      case NfRepeat(:final char):
        out.repeat(char);
      case NfLocaleTag(:final symbol):
        out.text(symbol);
      case NfPercent(:final permille):
        out.text(permille ? locale.permille : locale.percent);
      case NfDecimalPoint():
        out.text(locale.decimal);
      default:
        break;
    }
  }

  static bool _isGroupBoundary(int r, bool indian) {
    if (r <= 0) return false;
    if (!indian) return r % 3 == 0;
    return r == 3 || (r > 3 && (r - 3) % 2 == 0);
  }

  /// Emits the integer digits [digits] into the integer placeholders of
  /// [tokens] (by index), returning per-placeholder chunks.
  static Map<int, List<FormatSegment>> _integerChunks(
    List<NfToken> tokens,
    String digits,
    bool grouping,
    LocaleFormatData locale, {
    NfDigitRole role = NfDigitRole.integer,
  }) {
    final idx = <int>[
      for (var i = 0; i < tokens.length; i++)
        if (tokens[i] case NfDigit(role: final r) when r == role) i,
    ];
    final p = idx.length;
    final l = digits.length;
    final chunks = <int, List<FormatSegment>>{};
    final indian = locale.indianGrouping;
    // Total emitted digit count (digits + zero pads) for grouping positions.
    void emitDigit(StringBuffer b, String d, int r) {
      b.write(d);
      if (grouping && _isGroupBoundary(r, indian)) b.write(locale.group);
    }

    for (var k = 0; k < p; k++) {
      final q = p - 1 - k; // position from the right
      final segs = <FormatSegment>[];
      final b = StringBuffer();
      if (k == 0 && l > p) {
        for (var j = 0; j < l - p; j++) {
          emitDigit(b, digits[j], l - 1 - j);
        }
      }
      final di = l - 1 - q;
      final kind = (tokens[idx[k]] as NfDigit).kind;
      if (di >= 0) {
        emitDigit(b, digits[di], q);
      } else {
        switch (kind) {
          case NfDigitKind.zero:
            emitDigit(b, '0', q);
          case NfDigitKind.question:
            if (b.isNotEmpty) segs.add(TextSegment(b.toString()));
            b.clear();
            segs.add(const SpacerSegment('0'));
          case NfDigitKind.hash:
            break;
        }
      }
      if (b.isNotEmpty) segs.add(TextSegment(b.toString()));
      chunks[idx[k]] = segs;
    }
    return chunks;
  }

  /// Decimal placeholder outputs (trailing zeros dropped for `#`, blanked
  /// for `?`).
  static Map<int, FormatSegment?> _decimalChunks(
    List<NfToken> tokens,
    String frac, {
    NfDigitRole role = NfDigitRole.decimal,
  }) {
    final idx = <int>[
      for (var i = 0; i < tokens.length; i++)
        if (tokens[i] case NfDigit(role: final r) when r == role) i,
    ];
    final out = <int, FormatSegment?>{};
    var trailing = true;
    for (var j = idx.length - 1; j >= 0; j--) {
      final kind = (tokens[idx[j]] as NfDigit).kind;
      final d = j < frac.length ? frac[j] : '0';
      if (trailing && d == '0' && kind != NfDigitKind.zero) {
        out[idx[j]] = kind == NfDigitKind.question
            ? const SpacerSegment('0')
            : null;
        continue;
      }
      trailing = false;
      out[idx[j]] = TextSegment(d);
    }
    return out;
  }

  static FormattedValue _number(
    NfSection s,
    double v,
    LocaleFormatData locale,
  ) {
    final l = s.layout!;
    final dec = DecimalDigits.of(
      v,
    ).shift(l.scaleExponent).roundToDecimals(l.decimalPlaceholders);
    final intStr = dec.integerString();
    final frac = dec.fractionString(l.decimalPlaceholders);
    final tokens = s.tokens;
    final ints = _integerChunks(tokens, intStr, l.grouping, locale);
    final decs = _decimalChunks(tokens, frac);
    final out = _Out();
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      switch (t) {
        case NfDigit(role: NfDigitRole.integer):
          out.addAll(ints[i]!);
        case NfDigit():
          final seg = decs[i];
          if (seg != null) out.add(seg);
        case NfDecimalPoint():
          if (l.integerPlaceholders == 0) {
            out.text(_grouped(intStr, l.grouping, locale));
          }
          out.text(locale.decimal);
        case NfTextPlaceholder():
          break;
        default:
          _common(t, out, locale);
      }
    }
    if (v < 0) out.insertMinus(locale.minus);
    return out.build(s.colorArgb);
  }

  static String _grouped(
    String digits,
    bool grouping,
    LocaleFormatData locale,
  ) {
    if (!grouping) return digits;
    final b = StringBuffer();
    for (var j = 0; j < digits.length; j++) {
      b.write(digits[j]);
      if (_isGroupBoundary(digits.length - 1 - j, locale.indianGrouping)) {
        b.write(locale.group);
      }
    }
    return b.toString();
  }

  static FormattedValue _scientific(
    NfSection s,
    double v,
    LocaleFormatData locale,
  ) {
    final l = s.layout!;
    final base = DecimalDigits.of(v).shift(l.scaleExponent);
    final n = l.integerPlaceholders < 1 ? 1 : l.integerPlaceholders;
    var exp = 0;
    var m = DecimalDigits.zero;
    if (!base.isZero) {
      final e10 = base.leadingExponent;
      exp = _floorDiv(e10, n) * n;
      m = base.shift(-exp).roundToDecimals(l.decimalPlaceholders);
      if (m.integerDigitCount > n) {
        exp += n;
        m = base.shift(-exp).roundToDecimals(l.decimalPlaceholders);
      }
    }
    final tokens = s.tokens;
    final intStr = m.integerString();
    final ints = _integerChunks(tokens, intStr, false, locale);
    final decs = _decimalChunks(
      tokens,
      m.fractionString(l.decimalPlaceholders),
    );
    var zeroPad = 0;
    for (final t in tokens) {
      if (t is NfDigit &&
          t.role == NfDigitRole.exponent &&
          t.kind == NfDigitKind.zero) {
        zeroPad++;
      }
    }
    final out = _Out();
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      switch (t) {
        case NfDigit(role: NfDigitRole.integer):
          out.addAll(ints[i]!);
        case NfDigit(role: NfDigitRole.decimal):
          final seg = decs[i];
          if (seg != null) out.add(seg);
        case NfDigit():
          break;
        case NfDecimalPoint():
          if (l.integerPlaceholders == 0) out.text(intStr);
          out.text(locale.decimal);
        case NfExponent(:final letter, :final alwaysSign):
          out.text(letter);
          if (exp < 0) {
            out.text('-');
          } else if (alwaysSign) {
            out.text('+');
          }
          out.text(exp.abs().toString().padLeft(zeroPad, '0'));
        case NfTextPlaceholder():
          break;
        default:
          _common(t, out, locale);
      }
    }
    if (v < 0) out.insertMinus(locale.minus);
    return out.build(s.colorArgb);
  }

  static int _floorDiv(int a, int b) {
    final q = a ~/ b;
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
  }

  /// Best rational approximation of [x] ≥ 0 with denominator ≤ [maxDen]
  /// (continued fractions with semiconvergents).
  static (int, int) bestRational(double x, int maxDen) {
    if (maxDen < 1) maxDen = 1;
    if (x <= 0) return (0, 1);
    var p0 = 0, q0 = 1, p1 = 1, q1 = 0;
    var r = x;
    for (var iter = 0; iter < 64; iter++) {
      final a = r.floor();
      final p2 = a * p1 + p0;
      final q2 = a * q1 + q0;
      if (q2 > maxDen) {
        if (q1 == 0) return (x.round(), 1);
        final k = (maxDen - q0) ~/ q1;
        final ps = p0 + k * p1;
        final qs = q0 + k * q1;
        final e1 = (ps / qs - x).abs();
        final e2 = (p1 / q1 - x).abs();
        return e1 < e2 ? (ps, qs) : (p1, q1);
      }
      p0 = p1;
      q0 = q1;
      p1 = p2;
      q1 = q2;
      final f = r - a;
      if (f < 1e-12 || (p1 / q1 - x).abs() < 1e-15) break;
      r = 1 / f;
      if (!r.isFinite || r > 1e15) break;
    }
    return (p1, q1);
  }

  static FormattedValue _fraction(
    NfSection s,
    double v,
    LocaleFormatData locale,
  ) {
    final l = s.layout!;
    final a = roundToSignificantDigits(v.abs());
    var whole = 0;
    var f = a;
    if (l.fractionHasInteger) {
      whole = a.floor();
      f = a - whole;
    }
    int num;
    int den;
    final fixed = l.fixedDenominator;
    if (fixed != null && fixed > 0) {
      den = fixed;
      num = roundHalfAwayFromZero(f * fixed, 0).toInt();
    } else {
      var maxDen = 1;
      for (var i = 0; i < l.denominatorPlaceholders; i++) {
        maxDen *= 10;
      }
      (num, den) = bestRational(f, maxDen - 1 < 1 ? 1 : maxDen - 1);
    }
    if (l.fractionHasInteger && num >= den && den > 0) {
      whole += num ~/ den;
      num = num % den;
    }
    final hideFraction = l.fractionHasInteger && num == 0;
    final tokens = s.tokens;
    var wholeStr = whole == 0 ? '' : whole.toString();
    if (whole == 0 && num == 0) wholeStr = '0';
    final ints = _integerChunks(tokens, wholeStr, l.grouping, locale);
    final numChunks = _integerChunks(
      tokens,
      num == 0 && !l.fractionHasInteger ? '0' : num.toString(),
      false,
      locale,
      role: NfDigitRole.numerator,
    );
    final denStr = den.toString();
    final denIdx = <int>[
      for (var i = 0; i < tokens.length; i++)
        if (tokens[i] case NfDigit(role: NfDigitRole.denominator)) i,
    ];
    final out = _Out();
    var denWritten = false;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      switch (t) {
        case NfDigit(role: NfDigitRole.integer):
          out.addAll(ints[i]!);
        case NfDigit(role: NfDigitRole.numerator):
          if (hideFraction) {
            out.spacer('0');
          } else {
            out.addAll(numChunks[i]!);
          }
        case NfDigit(role: NfDigitRole.denominator, :final kind):
          final pos = denIdx.indexOf(i);
          if (hideFraction) {
            out.spacer('0');
            break;
          }
          if (!denWritten) {
            // Left-aligned: zero placeholders pad on the left.
            final zeros = denIdx
                .skip(denStr.length)
                .where((j) => (tokens[j] as NfDigit).kind == NfDigitKind.zero)
                .length;
            out.text('${'0' * zeros}$denStr');
            denWritten = true;
          } else if (pos >= denStr.length && kind == NfDigitKind.question) {
            out.spacer('0');
          }
        case NfFixedDenominator(:final value):
          if (hideFraction) {
            for (var k = 0; k < value.toString().length; k++) {
              out.spacer('0');
            }
          } else {
            out.text(value.toString());
          }
        case NfFractionSlash():
          if (hideFraction) {
            out.spacer('/');
          } else {
            out.text('/');
          }
        case NfDigit():
          break;
        case NfTextPlaceholder():
          break;
        default:
          _common(t, out, locale);
      }
    }
    if (v < 0) out.insertMinus(locale.minus);
    return out.build(s.colorArgb);
  }

  static String _pad(int v, int width) => v.toString().padLeft(width, '0');

  static FormattedValue? _date(NfSection s, double x, LocaleFormatData locale) {
    var hasDate = false;
    var elapsed = false;
    var fracDigits = 0;
    var hasDay = false;
    for (final t in s.tokens) {
      switch (t) {
        case NfDatePart(:final unit):
          if (unit == NfDateUnit.day) hasDay = true;
          if (unit == NfDateUnit.day ||
              unit == NfDateUnit.weekday ||
              unit == NfDateUnit.month ||
              unit == NfDateUnit.year) {
            hasDate = true;
          }
        case NfElapsed():
          elapsed = true;
        case NfFractionalSeconds(:final digits):
          if (digits > fracDigits) fracDigits = digits;
        default:
          break;
      }
    }
    if (hasDate && !SerialCalendar.inRange(x)) return null;
    if (!x.isFinite || x.abs() > 1e10) return null;
    var negative = false;
    if (elapsed && x < 0) {
      negative = true;
      x = -x;
    }
    final k = fracDigits > 3 ? 3 : fracDigits;
    var scale = 1;
    for (var i = 0; i < k; i++) {
      scale *= 10;
    }
    final units = roundHalfAwayFromZero(x * 86400 * scale, 0).toInt();
    final dayUnits = 86400 * scale;
    final day = _floorDiv(units, dayUnits);
    final rem = units - day * dayUnits;
    final fracUnits = rem % scale;
    final secOfDay = rem ~/ scale;
    final hour = secOfDay ~/ 3600;
    final minute = (secOfDay % 3600) ~/ 60;
    final second = secOfDay % 60;
    final totalSeconds = _floorDiv(units, scale);
    final names = s.lcid != null
        ? (LocaleFormatData.forLcid(s.lcid!) ?? locale)
        : locale;
    final ampm = s.hasAmPm;
    ({int year, int month, int day})? ymd;
    if (hasDate) ymd = SerialCalendar.dateOf(day);
    final out = _Out();
    for (final t in s.tokens) {
      switch (t) {
        case NfDatePart(:final unit, :final length):
          switch (unit) {
            case NfDateUnit.day:
              out.text(length == 1 ? '${ymd!.day}' : _pad(ymd!.day, 2));
            case NfDateUnit.weekday:
              final w = SerialCalendar.weekdayOf(day);
              out.text(
                length == 3 ? names.shortWeekdays[w] : names.weekdays[w],
              );
            case NfDateUnit.month:
              final m = ymd!.month;
              out.text(switch (length) {
                1 => '$m',
                2 => _pad(m, 2),
                3 =>
                  (hasDay ? names.shortMonths : names.standaloneShortMonths)[m -
                      1],
                4 => (hasDay ? names.months : names.standaloneMonths)[m - 1],
                _ => String.fromCharCode(
                  names.standaloneMonths[m - 1].runes.first,
                ),
              });
            case NfDateUnit.year:
              out.text(
                length == 2 ? _pad(ymd!.year % 100, 2) : _pad(ymd!.year, 4),
              );
            case NfDateUnit.hour:
              var h = hour;
              if (ampm) h = h % 12 == 0 ? 12 : h % 12;
              out.text(length == 1 ? '$h' : _pad(h, 2));
            case NfDateUnit.minute:
              out.text(length == 1 ? '$minute' : _pad(minute, 2));
            case NfDateUnit.second:
              out.text(length == 1 ? '$second' : _pad(second, 2));
          }
        case NfFractionalSeconds(:final digits):
          final f = k == 0 ? '' : _pad(fracUnits, k);
          final shown = f.length >= digits
              ? f.substring(0, digits)
              : f.padRight(digits, '0');
          out.text('${locale.decimal}$shown');
        case NfElapsed(:final unit, :final length):
          final value = switch (unit) {
            NfElapsedUnit.hours => totalSeconds ~/ 3600,
            NfElapsedUnit.minutes => totalSeconds ~/ 60,
            NfElapsedUnit.seconds => totalSeconds,
          };
          out.text(_pad(value, length));
        case NfAmPm(:final text, :final isShort):
          final pm = hour >= 12;
          if (isShort) {
            out.text(pm ? text[2] : text[0]);
          } else {
            final word = pm ? names.pm : names.am;
            if (text == text.toLowerCase()) {
              out.text(word.toLowerCase());
            } else if (text == text.toUpperCase()) {
              out.text(word.toUpperCase());
            } else {
              out.text(word);
            }
          }
        default:
          _common(t, out, locale);
      }
    }
    if (negative) out.insertMinus(locale.minus);
    return out.build(s.colorArgb);
  }
}

/// Segment builder merging adjacent text.
final class _Out {
  final List<FormatSegment> _segs = [];
  final StringBuffer _buf = StringBuffer();
  bool _repeatSeen = false;

  void text(String t) {
    if (t.isNotEmpty) _buf.write(t);
  }

  void _flush() {
    if (_buf.isNotEmpty) {
      _segs.add(TextSegment(_buf.toString()));
      _buf.clear();
    }
  }

  void add(FormatSegment s) {
    switch (s) {
      case TextSegment(:final text):
        this.text(text);
      case SpacerSegment(:final char):
        spacer(char);
      case RepeatSegment(:final char):
        repeat(char);
    }
  }

  void addAll(List<FormatSegment> segs) {
    for (final s in segs) {
      add(s);
    }
  }

  void spacer(String c) {
    _flush();
    _segs.add(SpacerSegment(c));
  }

  void repeat(String c) {
    if (_repeatSeen) return;
    _repeatSeen = true;
    _flush();
    _segs.add(RepeatSegment(c));
  }

  /// Inserts [minus] before the first text segment.
  void insertMinus(String minus) {
    _flush();
    for (var i = 0; i < _segs.length; i++) {
      final s = _segs[i];
      if (s is TextSegment) {
        _segs[i] = TextSegment('$minus${s.text}');
        return;
      }
    }
    _segs.insert(0, TextSegment(minus));
  }

  FormattedValue build(int? color, {bool overflow = true}) {
    _flush();
    return FormattedValue(
      List.unmodifiable(_segs),
      colorArgb: color,
      overflowHashes: overflow,
    );
  }
}
