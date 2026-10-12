import 'package:petitparser/petitparser.dart';

import 'ast.dart';
import 'palette.dart';

/// An invalid number-format pattern (06 §5.2), shown in the custom format
/// dialog.
final class FormatParseError implements Exception {
  /// Creates an error at [position] (offset in the pattern).
  const FormatParseError(this.position, this.message);

  /// Offset in the pattern where the problem starts.
  final int position;

  /// Human-readable message.
  final String message;

  @override
  String toString() => 'FormatParseError($position): $message';
}

enum _RawKind {
  bracket,
  literal,
  repeat,
  spacer,
  general,
  ampm,
  exponent,
  dateRun,
  digit,
  number,
  point,
  comma,
  percent,
  permille,
  at,
  slash,
  semicolon,
}

final class _Raw {
  const _Raw(this.kind, this.text, this.start, this.end, [this.value = '']);

  final _RawKind kind;

  /// Source text of the token.
  final String text;
  final int start;
  final int end;

  /// Payload: literal text, bracket content, repeated/spaced char.
  final String value;

  /// Lower-case letter of a date run.
  String get letter => text[0].toLowerCase();
}

/// Parser of the number-format language (06 §5.2, implemented with
/// petitparser). Tokens are case-insensitive.
abstract final class NumberFormatParser {
  static final Parser<List<_Raw>> _parser = _build();

  static Parser<List<_Raw>> _build() {
    Parser<_Raw> tok(Parser<Object?> p, _Raw Function(String text, int start, int end) f) =>
        p.flatten().token().map((t) => f(t.value, t.start, t.stop));

    final bracket = seq3(
      char('['),
      noneOf(']').star().flatten(),
      char(']'),
    ).token().map((t) => _Raw(_RawKind.bracket, t.input, t.start, t.stop, t.value.$2));
    final quoted = seq3(
      char('"'),
      noneOf('"').star().flatten(),
      char('"'),
    ).token().map((t) => _Raw(_RawKind.literal, t.input, t.start, t.stop, t.value.$2));
    final escape = seq2(
      char(r'\'),
      any(),
    ).token().map((t) => _Raw(_RawKind.literal, t.input, t.start, t.stop, t.value.$2));
    final repeat = seq2(
      char('*'),
      any(),
    ).token().map((t) => _Raw(_RawKind.repeat, t.input, t.start, t.stop, t.value.$2));
    final spacer = seq2(
      char('_'),
      any(),
    ).token().map((t) => _Raw(_RawKind.spacer, t.input, t.start, t.stop, t.value.$2));
    final general = tok(
      string('General', ignoreCase: true),
      (s, a, b) => _Raw(_RawKind.general, s, a, b),
    );
    final ampm = tok(
      [string('AM/PM', ignoreCase: true), string('A/P', ignoreCase: true)].toChoiceParser(),
      (s, a, b) => _Raw(_RawKind.ampm, s, a, b),
    );
    final exponent = tok(
      seq2(anyOf('Ee'), anyOf('+-')),
      (s, a, b) => _Raw(_RawKind.exponent, s, a, b),
    );
    final dateRun = [
      for (final l in const ['d', 'm', 'y', 'h', 's'])
        tok(char(l, ignoreCase: true).plus(), (s, a, b) => _Raw(_RawKind.dateRun, s, a, b)),
    ].toChoiceParser();
    final digitPh = tok(anyOf('0#?'), (s, a, b) => _Raw(_RawKind.digit, s, a, b));
    final number = tok(
      seq2(pattern('1-9'), digit().star()),
      (s, a, b) => _Raw(_RawKind.number, s, a, b, s),
    );
    Parser<_Raw> single(String c, _RawKind kind) =>
        tok(char(c), (s, a, b) => _Raw(kind, s, a, b, s));
    final other = tok(noneOf('"[\\*_;'), (s, a, b) => _Raw(_RawKind.literal, s, a, b, s));
    final token = [
      bracket,
      quoted,
      escape,
      repeat,
      spacer,
      general,
      ampm,
      exponent,
      dateRun,
      digitPh,
      number,
      single('.', _RawKind.point),
      single(',', _RawKind.comma),
      single('%', _RawKind.percent),
      single('‰', _RawKind.permille),
      single('@', _RawKind.at),
      single('/', _RawKind.slash),
      single(';', _RawKind.semicolon),
      other,
    ].toChoiceParser();
    return token.star().end();
  }

  /// Parses [pattern]. Throws [FormatParseError] for invalid patterns.
  static NumberFormatAst parse(String pattern) {
    final result = _parser.parse(pattern);
    if (result is Failure) {
      throw _diagnose(pattern, result.position);
    }
    final raws = result.value;
    final sections = <List<_Raw>>[[]];
    final sectionStarts = <int>[0];
    for (final r in raws) {
      if (r.kind == _RawKind.semicolon) {
        if (sections.length == 4) {
          throw FormatParseError(r.start, 'A format can have at most 4 sections');
        }
        sections.add([]);
        sectionStarts.add(r.end);
      } else {
        sections.last.add(r);
      }
    }
    final out = <NfSection>[];
    for (var i = 0; i < sections.length; i++) {
      final end = i + 1 < sectionStarts.length ? sectionStarts[i + 1] - 1 : pattern.length;
      out.add(_section(sections[i], sectionStarts[i], end));
    }
    return NumberFormatAst(pattern, List.unmodifiable(out));
  }

  /// Parses [pattern], returning null when it is invalid.
  static NumberFormatAst? tryParse(String pattern) {
    try {
      return parse(pattern);
    } on FormatParseError {
      return null;
    }
  }

  /// The error of [pattern], or null when it is valid.
  static FormatParseError? validate(String pattern) {
    try {
      parse(pattern);
      return null;
    } on FormatParseError catch (e) {
      return e;
    }
  }

  static FormatParseError _diagnose(String pattern, int position) {
    if (position >= pattern.length) {
      return FormatParseError(position, 'Unexpected end of format');
    }
    return switch (pattern[position]) {
      '"' => FormatParseError(position, 'Unterminated quoted text'),
      '[' => FormatParseError(position, 'Missing closing bracket "]"'),
      r'\' => FormatParseError(position, 'Escape character at the end of the format'),
      '*' => FormatParseError(position, 'Missing character after "*"'),
      '_' => FormatParseError(position, 'Missing character after "_"'),
      final c => FormatParseError(position, 'Unexpected character "$c"'),
    };
  }

  static final RegExp _conditionRe = RegExp(
    r'^\s*(<=|>=|<>|<|>|=)\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*$',
  );
  static final RegExp _elapsedRe = RegExp(r'^(h+|m+|s+)$', caseSensitive: false);

  static NfSection _section(List<_Raw> raws, int start, int end) {
    NfCondition? condition;
    int? color;
    int? lcid;
    final content = <_Raw>[];
    for (final r in raws) {
      if (r.kind != _RawKind.bracket) {
        content.add(r);
        continue;
      }
      final inner = r.value;
      if (inner.startsWith(r'$')) {
        content.add(r);
        final tagLcid = _localeTag(inner).$2;
        if (tagLcid != null) lcid ??= tagLcid;
        continue;
      }
      if (_elapsedRe.hasMatch(inner)) {
        content.add(r);
        continue;
      }
      final cm = _conditionRe.firstMatch(inner);
      if (cm != null) {
        if (condition != null) {
          throw FormatParseError(r.start, 'A section can have only one condition');
        }
        condition = NfCondition(
          NfConditionOp.values.firstWhere((o) => o.symbol == cm.group(1)),
          double.parse(cm.group(2)!),
        );
        continue;
      }
      final c = NumberFormatPalette.lookup(inner);
      if (c != null) {
        color ??= c;
        continue;
      }
      if (inner.toLowerCase().startsWith('color')) {
        throw FormatParseError(r.start, 'Unknown color "[$inner]" (use Color1 to Color56)');
      }
      throw FormatParseError(r.start, 'Unknown color or condition "[$inner]"');
    }
    if (content.isEmpty) {
      return NfSection(
        tokens: const [],
        kind: NfSectionKind.empty,
        start: start,
        end: end,
        condition: condition,
        colorArgb: color,
        lcid: lcid,
      );
    }
    final hasGeneral = content.any((r) => r.kind == _RawKind.general);
    final isDate =
        !hasGeneral &&
        content.any(
          (r) =>
              r.kind == _RawKind.dateRun ||
              r.kind == _RawKind.ampm ||
              (r.kind == _RawKind.bracket && _elapsedRe.hasMatch(r.value)),
        );
    final hasDigits = content.any((r) => r.kind == _RawKind.digit);
    final List<NfToken> tokens;
    NfSectionKind kind;
    NfNumberLayout? layout;
    if (hasGeneral) {
      kind = NfSectionKind.general;
      tokens = [for (final r in content) _generic(r)];
    } else if (isDate) {
      kind = NfSectionKind.dateTime;
      tokens = _dateTokens(content);
    } else if (hasDigits) {
      final built = _numberTokens(content);
      tokens = built.tokens;
      kind = built.kind;
      layout = built.layout;
    } else if (content.any((r) => r.kind == _RawKind.at)) {
      kind = NfSectionKind.text;
      tokens = [for (final r in content) _generic(r)];
    } else {
      kind = NfSectionKind.literal;
      tokens = [for (final r in content) _generic(r)];
    }
    return NfSection(
      tokens: List.unmodifiable(tokens),
      kind: kind,
      start: start,
      end: end,
      condition: condition,
      colorArgb: color,
      lcid: lcid,
      layout: layout,
    );
  }

  static (String, int?) _localeTag(String inner) {
    final body = inner.substring(1);
    final dash = body.lastIndexOf('-');
    if (dash < 0) return (body, null);
    final hex = body.substring(dash + 1);
    final v = int.tryParse(hex, radix: 16);
    if (v == null) return (body.substring(0, dash), null);
    return (body.substring(0, dash), v & 0xFFFF);
  }

  /// Token for literal-ish contexts (General/text/literal sections).
  static NfToken _generic(_Raw r) => switch (r.kind) {
    _RawKind.literal => NfLiteral(r.value, r.start, r.end),
    _RawKind.repeat => NfRepeat(r.value, r.start, r.end),
    _RawKind.spacer => NfSpacer(r.value, r.start, r.end),
    _RawKind.general => NfGeneral(r.start, r.end),
    _RawKind.at => NfTextPlaceholder(r.start, r.end),
    _RawKind.bracket when r.value.startsWith(r'$') => () {
      final (sym, lcid) = _localeTag(r.value);
      return NfLocaleTag(sym, lcid, r.start, r.end);
    }(),
    _ => NfLiteral(r.text, r.start, r.end),
  };

  static List<NfToken> _dateTokens(List<_Raw> raws) {
    final out = <NfToken>[];
    // Index into [out] of ambiguous m/mm tokens to resolve later.
    final ambiguous = <int>[];
    var i = 0;
    while (i < raws.length) {
      final r = raws[i];
      switch (r.kind) {
        case _RawKind.dateRun:
          final n = r.text.length;
          switch (r.letter) {
            case 'd':
              out.add(
                n <= 2
                    ? NfDatePart(NfDateUnit.day, n, r.start, r.end)
                    : NfDatePart(NfDateUnit.weekday, n == 3 ? 3 : 4, r.start, r.end),
              );
            case 'y':
              out.add(NfDatePart(NfDateUnit.year, n <= 2 ? 2 : 4, r.start, r.end));
            case 'h':
              out.add(NfDatePart(NfDateUnit.hour, n >= 2 ? 2 : 1, r.start, r.end));
            case 's':
              out.add(NfDatePart(NfDateUnit.second, n >= 2 ? 2 : 1, r.start, r.end));
              // Fractional seconds: `.0`, `.00`, `.000` directly after.
              if (i + 2 < raws.length &&
                  raws[i + 1].kind == _RawKind.point &&
                  raws[i + 2].kind == _RawKind.digit &&
                  raws[i + 2].text == '0') {
                var j = i + 2;
                while (j < raws.length && raws[j].kind == _RawKind.digit && raws[j].text == '0') {
                  j++;
                }
                out.add(NfFractionalSeconds(j - i - 2, raws[i + 1].start, raws[j - 1].end));
                i = j;
                continue;
              }
            default: // m
              if (n >= 3) {
                out.add(NfDatePart(NfDateUnit.month, n >= 5 ? 5 : n, r.start, r.end));
              } else {
                ambiguous.add(out.length);
                out.add(NfDatePart(NfDateUnit.month, n, r.start, r.end));
              }
          }
        case _RawKind.bracket when _elapsedRe.hasMatch(r.value):
          final unit = switch (r.value[0].toLowerCase()) {
            'h' => NfElapsedUnit.hours,
            'm' => NfElapsedUnit.minutes,
            _ => NfElapsedUnit.seconds,
          };
          out.add(NfElapsed(unit, r.value.length, r.start, r.end));
          if (unit == NfElapsedUnit.seconds &&
              i + 2 < raws.length &&
              raws[i + 1].kind == _RawKind.point &&
              raws[i + 2].kind == _RawKind.digit &&
              raws[i + 2].text == '0') {
            var j = i + 2;
            while (j < raws.length && raws[j].kind == _RawKind.digit && raws[j].text == '0') {
              j++;
            }
            out.add(NfFractionalSeconds(j - i - 2, raws[i + 1].start, raws[j - 1].end));
            i = j;
            continue;
          }
        case _RawKind.ampm:
          out.add(NfAmPm(r.text, r.start, r.end));
        default:
          out.add(_generic(r));
      }
      i++;
    }
    for (final idx in ambiguous) {
      final t = out[idx] as NfDatePart;
      if (_isMinuteContext(out, idx)) {
        out[idx] = NfDatePart(NfDateUnit.minute, t.length, t.start, t.end);
      }
    }
    return out;
  }

  static bool _isMinuteContext(List<NfToken> tokens, int idx) {
    for (var j = idx - 1; j >= 0; j--) {
      final t = tokens[j];
      if (t is NfDatePart) {
        if (t.unit == NfDateUnit.hour) return true;
        break;
      }
      if (t is NfElapsed) {
        if (t.unit == NfElapsedUnit.hours) return true;
        break;
      }
    }
    for (var j = idx + 1; j < tokens.length; j++) {
      final t = tokens[j];
      if (t is NfDatePart) return t.unit == NfDateUnit.second;
      if (t is NfElapsed) return t.unit == NfElapsedUnit.seconds;
    }
    return false;
  }

  static ({List<NfToken> tokens, NfSectionKind kind, NfNumberLayout layout}) _numberTokens(
    List<_Raw> raws,
  ) {
    final n = raws.length;
    final expIdx = raws.indexWhere((r) => r.kind == _RawKind.exponent);
    final mantissaEnd = expIdx < 0 ? n : expIdx;
    // Fraction slash: digit placeholder directly before, placeholder or
    // fixed number directly after.
    var slashIdx = -1;
    if (expIdx < 0) {
      for (var i = 1; i + 1 < n; i++) {
        if (raws[i].kind == _RawKind.slash &&
            raws[i - 1].kind == _RawKind.digit &&
            (raws[i + 1].kind == _RawKind.digit || raws[i + 1].kind == _RawKind.number)) {
          slashIdx = i;
          break;
        }
      }
    }
    final roles = List<NfDigitRole?>.filled(n, null);
    var pointIdx = -1;
    var fractionHasInteger = false;
    if (slashIdx >= 0) {
      var numStart = slashIdx - 1;
      while (numStart > 0 && raws[numStart - 1].kind == _RawKind.digit) {
        numStart--;
      }
      for (var i = 0; i < n; i++) {
        if (raws[i].kind != _RawKind.digit) continue;
        if (i < numStart) {
          roles[i] = NfDigitRole.integer;
          fractionHasInteger = true;
        } else if (i < slashIdx) {
          roles[i] = NfDigitRole.numerator;
        } else {
          roles[i] = NfDigitRole.denominator;
        }
      }
    } else {
      for (var i = 0; i < mantissaEnd; i++) {
        if (raws[i].kind == _RawKind.point) {
          pointIdx = i;
          break;
        }
      }
      for (var i = 0; i < n; i++) {
        if (raws[i].kind != _RawKind.digit) continue;
        if (expIdx >= 0 && i > expIdx) {
          roles[i] = NfDigitRole.exponent;
        } else if (pointIdx >= 0 && i > pointIdx) {
          roles[i] = NfDigitRole.decimal;
        } else {
          roles[i] = NfDigitRole.integer;
        }
      }
    }
    final tokens = <NfToken>[];
    var intCount = 0;
    var decCount = 0;
    var expCount = 0;
    var numCount = 0;
    var denCount = 0;
    int? fixedDen;
    var grouping = false;
    var scale = 0;
    for (var i = 0; i < n; i++) {
      final r = raws[i];
      switch (r.kind) {
        case _RawKind.digit:
          final role = roles[i]!;
          final kind = switch (r.text) {
            '0' => NfDigitKind.zero,
            '#' => NfDigitKind.hash,
            _ => NfDigitKind.question,
          };
          tokens.add(NfDigit(kind, role, r.start, r.end));
          switch (role) {
            case NfDigitRole.integer:
              intCount++;
            case NfDigitRole.decimal:
              decCount++;
            case NfDigitRole.exponent:
              expCount++;
            case NfDigitRole.numerator:
              numCount++;
            case NfDigitRole.denominator:
              denCount++;
          }
        case _RawKind.point when i == pointIdx:
          tokens.add(NfDecimalPoint(r.start, r.end));
        case _RawKind.exponent when i == expIdx:
          tokens.add(NfExponent(r.text[0], r.start, r.end, alwaysSign: r.text[1] == '+'));
        case _RawKind.slash when i == slashIdx:
          tokens.add(NfFractionSlash(r.start, r.end));
        case _RawKind.number when slashIdx >= 0 && i == slashIdx + 1:
          fixedDen = int.parse(r.text);
          tokens.add(NfFixedDenominator(fixedDen, r.start, r.end));
        case _RawKind.percent || _RawKind.permille:
          final permille = r.kind == _RawKind.permille;
          tokens.add(NfPercent(r.start, r.end, permille: permille));
          scale += permille ? 3 : 2;
        case _RawKind.comma:
          final limit = slashIdx >= 0 ? slashIdx : mantissaEnd;
          var intBefore = false;
          var intAfter = false;
          var digitAfter = false;
          for (var j = 0; j < i; j++) {
            if (roles[j] == NfDigitRole.integer) intBefore = true;
          }
          for (var j = i + 1; j < limit; j++) {
            if (roles[j] == null) continue;
            digitAfter = true;
            if (roles[j] == NfDigitRole.integer) intAfter = true;
          }
          if (intBefore && intAfter) {
            grouping = true;
            tokens.add(NfGroupComma(r.start, r.end));
          } else if (!digitAfter &&
              slashIdx < 0 &&
              expIdx < 0 &&
              roles.sublist(0, i).any((x) => x != null)) {
            scale -= 3;
            tokens.add(NfScaleComma(r.start, r.end));
          } else {
            tokens.add(NfLiteral(',', r.start, r.end));
          }
        case _RawKind.at:
          tokens.add(NfTextPlaceholder(r.start, r.end));
        default:
          tokens.add(_generic(r));
      }
    }
    final kind = slashIdx >= 0
        ? NfSectionKind.fraction
        : expIdx >= 0
        ? NfSectionKind.scientific
        : NfSectionKind.number;
    return (
      tokens: tokens,
      kind: kind,
      layout: NfNumberLayout(
        integerPlaceholders: intCount,
        decimalPlaceholders: decCount,
        grouping: grouping,
        scaleExponent: scale,
        exponentPlaceholders: expCount,
        numeratorPlaceholders: numCount,
        denominatorPlaceholders: denCount,
        fixedDenominator: fixedDen,
        fractionHasInteger: fractionHasInteger,
      ),
    );
  }
}
