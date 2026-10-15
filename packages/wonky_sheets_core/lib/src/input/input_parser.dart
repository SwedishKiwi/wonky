// Signatures are a contract used by the planner, CSV import, clipboard paste,
// split text and MCP: keep them stable (03 §8.4, §8.6; 06 §5.9).

import 'package:clock/clock.dart';
import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../content/cell_content.dart';
import '../format/number_format/inference.dart';
import 'date_input.dart';
import 'number_input.dart';

/// Result of parsing typed input.
final class ParsedInput {
  /// Creates a result.
  const ParsedInput({
    this.content,
    this.formulaA1,
    this.autoNumberFormat,
    this.autoLinkUrl,
  });

  /// Literal content to store; null with [formulaA1] null = clear the value.
  final CellContent? content;

  /// The formula as typed (A1 form, starting with `=`, in the input locale);
  /// the caller converts it with `FormulaHooks.toStored`.
  final String? formulaA1;

  /// Number format to write when the target cell's effective format is
  /// Automatic (06 §5.9), e.g. `0%`, `"$"#,##0.00`, `preset:date`.
  final String? autoNumberFormat;

  /// Whole-cell link detected from a URL/email input (03 §14.4).
  final String? autoLinkUrl;

  /// Whether the input is a formula.
  bool get isFormula => formulaA1 != null;

  /// Whether the input clears the value.
  bool get isClear => content == null && formulaA1 == null;

  @override
  bool operator ==(Object other) =>
      other is ParsedInput &&
      other.content == content &&
      other.formulaA1 == formulaA1 &&
      other.autoNumberFormat == autoNumberFormat &&
      other.autoLinkUrl == autoLinkUrl;

  @override
  int get hashCode =>
      Object.hash(content, formulaA1, autoNumberFormat, autoLinkUrl);

  @override
  String toString() =>
      'ParsedInput(${content ?? formulaA1 ?? 'clear'}'
      '${autoNumberFormat == null ? '' : ', format: $autoNumberFormat'}'
      '${autoLinkUrl == null ? '' : ', link: $autoLinkUrl'})';
}

/// What [InputParser.parseValue] recognized.
enum RecognizedKind {
  /// Plain or grouped number.
  number,

  /// Percent.
  percent,

  /// Currency amount.
  currency,

  /// Scientific notation.
  scientific,

  /// Date.
  date,

  /// Time of day.
  time,

  /// Date and time.
  dateTime,

  /// Elapsed duration.
  duration,

  /// TRUE / FALSE.
  boolean,

  /// Error literal.
  error,
}

/// A non-text value recognized in input (numbers, dates, booleans, errors).
final class RecognizedValue {
  /// Creates a recognized value.
  const RecognizedValue(this.content, this.kind, [this.detectedFormat]);

  /// The literal content.
  final CellContent content;

  /// What was recognized.
  final RecognizedKind kind;

  /// The auto-detected format (06 §5.9), or null for Automatic.
  final String? detectedFormat;

  @override
  String toString() =>
      'RecognizedValue($content, ${kind.name}, $detectedFormat)';
}

/// Parses user-entered text like typing into a cell (03 §8.4 classify +
/// §8.6 values).
final class InputParser {
  /// Creates a parser.
  InputParser();

  /// Shared instance.
  static final InputParser instance = InputParser();

  static const Set<CellErrorKind> _typableErrors = {
    CellErrorKind.nullRef,
    CellErrorKind.div0,
    CellErrorKind.value,
    CellErrorKind.ref, //
    CellErrorKind.name,
    CellErrorKind.num,
    CellErrorKind.na,
    CellErrorKind.parse, //
    CellErrorKind.spill, CellErrorKind.calc,
  };

  /// Localized boolean literals accepted in addition to TRUE/FALSE.
  static const Map<String, (String, String)> localizedBooleans = {
    'de': ('WAHR', 'FALSCH'),
  };

  /// Parses [input] in [locale]. [targetNumberFormat] is the target cell's
  /// effective number format (`@` forces text; non-Automatic formats suppress
  /// auto-detection). [today] is used for partial dates (`1/2` → Jan 2 of
  /// the current year); inject it for determinism (default: `clock.now()`).
  ///
  /// [isFormula] (optional, e.g. backed by `FormulaHooks`) decides whether
  /// input starting with `+`/`-` that is not a number parses as a formula;
  /// such input becomes `=` + input. Formulas get missing closing
  /// parentheses appended.
  ParsedInput parse(
    String input, {
    String locale = 'en_US',
    String? targetNumberFormat,
    DateTime? today,
    bool Function(String formulaA1)? isFormula,
  }) {
    if (input.isEmpty) return const ParsedInput();
    if (targetNumberFormat == '@') {
      return ParsedInput(
        content: TextContent(input),
        autoLinkUrl: detectLink(input),
      );
    }
    if (input.startsWith("'")) {
      return ParsedInput(content: TextContent(input.substring(1)));
    }
    if (input.startsWith('=') && input.length > 1) {
      return ParsedInput(formulaA1: closeParentheses(input));
    }
    final t = trimAscii(input);
    if (t.isNotEmpty) {
      final v = parseValue(t, locale: locale, today: today);
      if (v != null) {
        return ParsedInput(
          content: v.content,
          autoNumberFormat: FormatInference.appliesTo(targetNumberFormat)
              ? v.detectedFormat
              : null,
        );
      }
      if ((t.startsWith('+') || t.startsWith('-')) &&
          t.length > 1 &&
          isFormula != null) {
        final f = closeParentheses('=$t');
        if (isFormula(f)) return ParsedInput(formulaA1: f);
      }
    }
    return ParsedInput(
      content: TextContent(input),
      autoLinkUrl: detectLink(input),
    );
  }

  /// Recognizes a non-text value in [text] (already trimmed): boolean,
  /// error literal, number (grouping, percent, currency, scientific,
  /// parentheses), date, time, date time or duration. Null for text.
  RecognizedValue? parseValue(
    String text, {
    String locale = 'en_US',
    DateTime? today,
  }) {
    if (text.isEmpty) return null;
    final loc = LocaleFormatData.forId(locale);
    final upper = text.toUpperCase();
    if (upper == 'TRUE') {
      return const RecognizedValue(BoolContent(true), RecognizedKind.boolean);
    }
    if (upper == 'FALSE') {
      return const RecognizedValue(BoolContent(false), RecognizedKind.boolean);
    }
    final localized = localizedBooleans[loc.language];
    if (localized != null) {
      if (upper == localized.$1) {
        return const RecognizedValue(BoolContent(true), RecognizedKind.boolean);
      }
      if (upper == localized.$2) {
        return const RecognizedValue(
          BoolContent(false),
          RecognizedKind.boolean,
        );
      }
    }
    if (text.startsWith('#')) {
      final err = CellErrorKind.tryParse(text);
      if (err != null && _typableErrors.contains(err)) {
        return RecognizedValue(ErrorContent(err), RecognizedKind.error);
      }
      return null;
    }
    final n = NumberInputRecognizer.forLocale(loc).match(text);
    if (n != null) {
      return RecognizedValue(NumberContent(n.value), switch (n.kind) {
        NumberInputKind.plain => RecognizedKind.number,
        NumberInputKind.percent => RecognizedKind.percent,
        NumberInputKind.currency => RecognizedKind.currency,
        NumberInputKind.scientific => RecognizedKind.scientific,
      }, n.format);
    }
    final d = DateInputRecognizer.forLocale(
      loc,
    ).match(text, today ?? clock.now());
    if (d != null) {
      return RecognizedValue(NumberContent(d.serial), switch (d.kind) {
        DateInputKind.date => RecognizedKind.date,
        DateInputKind.time => RecognizedKind.time,
        DateInputKind.dateTime => RecognizedKind.dateTime,
        DateInputKind.duration => RecognizedKind.duration,
      }, d.format);
    }
    return null;
  }

  /// [s] without leading/trailing ASCII spaces (and tabs/newlines).
  static String trimAscii(String s) {
    var a = 0;
    var b = s.length;
    bool ws(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;
    while (a < b && ws(s.codeUnitAt(a))) {
      a++;
    }
    while (b > a && ws(s.codeUnitAt(b - 1))) {
      b--;
    }
    return a == 0 && b == s.length ? s : s.substring(a, b);
  }

  /// Appends missing closing parentheses to [formula] (Google behavior);
  /// parentheses inside string literals and quoted sheet names are ignored.
  static String closeParentheses(String formula) {
    var depth = 0;
    var inString = false;
    var inQuote = false;
    for (var i = 0; i < formula.length; i++) {
      final c = formula.codeUnitAt(i);
      if (inString) {
        if (c == 0x22) inString = false;
        continue;
      }
      if (inQuote) {
        if (c == 0x27) inQuote = false;
        continue;
      }
      switch (c) {
        case 0x22:
          inString = true;
        case 0x27:
          inQuote = true;
        case 0x28:
          depth++;
        case 0x29:
          if (depth > 0) depth--;
      }
    }
    if (inString || inQuote || depth == 0) return formula;
    return formula + ')' * depth;
  }

  static final RegExp _urlRe = RegExp(
    r'^(?:https?|ftp)://[^\s/$.?#][^\s]*$',
    caseSensitive: false,
  );
  static final RegExp _wwwRe = RegExp(
    r'^www\.[^\s.]+(?:\.[^\s.]+)+[^\s]*$',
    caseSensitive: false,
  );
  static final RegExp _mailtoRe = RegExp(
    r'^mailto:[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );
  static final RegExp _emailRe = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
  );

  /// The link URL when the whole [text] is a URL (`http(s)://`, `ftp://`,
  /// `www.`) or e-mail address (03 §14.4), else null. `www.` links get
  /// `https://`, e-mail addresses `mailto:`.
  static String? detectLink(String text) {
    final t = trimAscii(text);
    if (t.isEmpty || t.length > 2048) return null;
    if (_urlRe.hasMatch(t)) return t;
    if (_mailtoRe.hasMatch(t)) return t;
    if (_wwwRe.hasMatch(t)) return 'https://$t';
    if (_emailRe.hasMatch(t)) return 'mailto:$t';
    return null;
  }
}
