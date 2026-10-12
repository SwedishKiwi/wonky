import '../../content/cell_content.dart';
import '../../engine_bridge/formula_hooks.dart';
import '../../formula/parser/formula_locale.dart';
import '../../formula/values/format_hint.dart';
import '../../formula/values/fvalue.dart';
import '../../formula/values/numeric.dart';
import '../../input/input_parser.dart';
import 'condition.dart';
import 'relative_dates.dart';
import 'value_text.dart';

/// Evaluates [Condition]s against computed cell values (06 §15.2–15.3,
/// 07 §3.3). One evaluator serves CF, data validation, filters, slicers and
/// pivot filters.
///
/// Conditions are [compile]d once per rule (literal values parsed per locale,
/// relative dates resolved against "today") and then tested per cell.
/// Formula values and custom formulas are evaluated through
/// [FormulaHooks.evaluateRelative] relative to the rule's anchor cell; without
/// [hooks] they never match.
final class ConditionEvaluator {
  /// Creates an evaluator.
  ConditionEvaluator({
    this.locale = 'en_US',
    SpreadsheetDates? dates,
    this.hooks,
    InputParser? inputParser,
  }) : dates = dates ?? SpreadsheetDates(),
       _parser = inputParser ?? InputParser.instance;

  /// Spreadsheet locale used to parse literal values and to convert numbers to text.
  final String locale;

  /// Time zone + clock for relative dates.
  final SpreadsheetDates dates;

  /// Formula services; null disables formula values.
  final FormulaHooks? hooks;
  final InputParser _parser;

  /// Compiles [condition] for a rule anchored at ([anchorRow], [anchorCol]) on
  /// [sheetId] (top-left cell of the rule's first range; for filters the
  /// first data cell of the column). [today] overrides the current date serial.
  CompiledCondition compile(
    Condition condition, {
    required String sheetId,
    int anchorRow = 0,
    int anchorCol = 0,
    int? today,
  }) {
    final t = condition.type.family == ConditionFamily.date ? (today ?? dates.todaySerial()) : 0;
    final decimal = FormulaLocale.forId(locale).decimal;
    return CompiledCondition._(
      condition,
      sheetId,
      anchorRow,
      anchorCol,
      t,
      decimal,
      this,
      [for (final v in condition.values) _compileOperand(condition.type.family, v, t)],
    );
  }

  /// Convenience: compiles and tests in one step.
  bool evaluate(
    Condition condition,
    CellValue value, {
    required String sheetId,
    required int row,
    required int col,
    int? anchorRow,
    int? anchorCol,
    String? numberFormat,
  }) => compile(
    condition,
    sheetId: sheetId,
    anchorRow: anchorRow ?? row,
    anchorCol: anchorCol ?? col,
  ).test(value, row: row, col: col, numberFormat: numberFormat);

  _Operand _compileOperand(ConditionFamily family, ConditionValue v, int today) {
    switch (v) {
      case ConditionFormula(:final stored):
        return _Operand.formula(stored);
      case ConditionRelativeDate(:final date):
        final r = SpreadsheetDates.range(date, today);
        return _Operand.literal(text: '', number: r.lo.toDouble(), hiDay: r.hi);
      case ConditionLiteral(:final text):
        switch (family) {
          case ConditionFamily.number:
            return _Operand.literal(text: text, number: ValueText.parseNumber(text, locale: locale, parser: _parser));
          case ConditionFamily.date:
            final d = ValueText.parseDate(text, locale: locale, parser: _parser);
            return _Operand.literal(text: text, number: d?.floorToDouble(), hiDay: d?.floor());
          default:
            return _Operand.literal(text: text);
        }
    }
  }
}

final class _Operand {
  _Operand.literal({required this.text, this.number, this.hiDay}) : formula = null;
  _Operand.formula(this.formula) : text = '', number = null, hiDay = null;

  final String? formula;
  final String text;

  /// Number (number family) or first day (date family).
  final double? number;

  /// Last day of a relative period (date family).
  final int? hiDay;
}

/// A [Condition] prepared for one rule; [test] evaluates it for a cell.
final class CompiledCondition {
  CompiledCondition._(
    this.condition,
    this.sheetId,
    this.anchorRow,
    this.anchorCol,
    this.today,
    this._decimal,
    this._evaluator,
    this._operands,
  ) : _foldedText = [for (final o in _operands) ValueText.fold(o.text)];

  /// The condition.
  final Condition condition;

  /// Sheet of the rule (formula host sheet).
  final String sheetId;

  /// Anchor cell of relative formulas.
  final int anchorRow;
  final int anchorCol;

  /// Date serial "today" used for relative dates.
  final int today;
  final String _decimal;
  final ConditionEvaluator _evaluator;
  final List<_Operand> _operands;
  final List<String> _foldedText;

  /// Whether the result can change without the cell changing (formulas,
  /// relative dates): such rules re-evaluate after recalcs / at midnight.
  bool get isVolatile => condition.isVolatile;

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$');
  static final RegExp _url = RegExp(
    r'^(?:(?:https?|ftp)://[^\s/?#.]+(?:\.[^\s/?#.]+)*(?::\d+)?(?:[/?#]\S*)?|www\.[^\s/?#.]+(?:\.[^\s/?#.]+)+(?::\d+)?(?:[/?#]\S*)?)$',
    caseSensitive: false,
  );

  /// Whether the cell at ([row], [col]) holding [value] satisfies the
  /// condition. [numberFormat] is the cell's effective number format (used by
  /// `dateIsValid`).
  bool test(CellValue value, {required int row, required int col, String? numberFormat}) {
    final type = condition.type;
    switch (type.family) {
      case ConditionFamily.emptiness:
        final blank = value.isBlank();
        return type == ConditionType.blank ? blank : !blank;
      case ConditionFamily.text:
        final hay = ValueText.fold(ValueText.automatic(value, decimal: _decimal));
        final needle = _textOperand(0, row, col);
        if (needle == null) return false;
        return switch (type) {
          ConditionType.textContains => hay.contains(needle),
          ConditionType.textNotContains => !hay.contains(needle),
          ConditionType.textStartsWith => hay.startsWith(needle),
          ConditionType.textEndsWith => hay.endsWith(needle),
          _ => hay == needle,
        };
      case ConditionFamily.textPattern:
        if (value is! TextValue) return false;
        final t = value.text.trim();
        return type == ConditionType.textIsEmail ? _email.hasMatch(t) : _url.hasMatch(t);
      case ConditionFamily.dateValidity:
        return switch (value) {
          NumberValue() => numberFormat != null && FormatHint.looksLikeDatePattern(numberFormat),
          TextValue(:final text) => ValueText.isDateText(text, locale: _evaluator.locale),
          _ => false,
        };
      case ConditionFamily.date:
        if (value is! NumberValue) return false;
        return _testDate(value.number.floor(), row, col);
      case ConditionFamily.number:
        if (value is! NumberValue) return type == ConditionType.numberNotEq;
        return _testNumber(value.number, row, col);
      case ConditionFamily.custom:
        final c = condition as CustomFormulaCondition;
        final r = _eval(c.formula, row, col);
        return r != null && ValueText.truthy(r);
    }
  }

  FValue? _eval(String stored, int row, int col) {
    final hooks = _evaluator.hooks;
    if (hooks == null || stored.length < 2) return null;
    return hooks.evaluateRelative(
      stored,
      sheetId: sheetId,
      anchorRow: anchorRow,
      anchorCol: anchorCol,
      row: row,
      col: col,
    );
  }

  String? _textOperand(int i, int row, int col) {
    if (i >= _operands.length) return null;
    final o = _operands[i];
    final f = o.formula;
    if (f == null) return _foldedText[i];
    final r = _eval(f, row, col);
    if (r == null || r is FError) return null;
    final t = ValueText.textOf(r, locale: _evaluator.locale);
    return t == null ? null : ValueText.fold(t);
  }

  double? _numberOperand(int i, int row, int col) {
    if (i >= _operands.length) return null;
    final o = _operands[i];
    final f = o.formula;
    if (f == null) return o.number;
    final r = _eval(f, row, col);
    if (r == null || r is FError) return null;
    return ValueText.numberOf(r, locale: _evaluator.locale);
  }

  /// `(lo, hi)` day range of date operand [i].
  (int, int)? _dayOperand(int i, int row, int col) {
    if (i >= _operands.length) return null;
    final o = _operands[i];
    final f = o.formula;
    if (f == null) {
      final n = o.number;
      if (n == null) return null;
      return (n.floor(), o.hiDay ?? n.floor());
    }
    final r = _eval(f, row, col);
    if (r == null || r is FError) return null;
    final n = r is FText ? ValueText.parseDate(r.v, locale: _evaluator.locale) : ValueText.numberOf(r);
    if (n == null) return null;
    return (n.floor(), n.floor());
  }

  bool _testDate(int day, int row, int col) {
    final type = condition.type;
    final a = _dayOperand(0, row, col);
    if (a == null) return false;
    switch (type) {
      case ConditionType.dateEq:
        return day >= a.$1 && day <= a.$2;
      case ConditionType.dateBefore:
        return day < a.$1;
      case ConditionType.dateAfter:
        return day > a.$1;
      case ConditionType.dateOnOrBefore:
        return day <= a.$1;
      case ConditionType.dateOnOrAfter:
        return day >= a.$1;
      case ConditionType.dateBetween:
      case ConditionType.dateNotBetween:
        final b = _dayOperand(1, row, col);
        if (b == null) return false;
        final lo = a.$1 < b.$1 ? a.$1 : b.$1;
        final hi = a.$1 < b.$1 ? b.$1 : a.$1;
        final inside = day >= lo && day <= hi;
        return type == ConditionType.dateBetween ? inside : !inside;
      default:
        return false;
    }
  }

  bool _testNumber(double v, int row, int col) {
    final type = condition.type;
    final a = _numberOperand(0, row, col);
    if (a == null) return false;
    switch (type) {
      case ConditionType.numberGreater:
        return Numeric.compare(v, a) > 0;
      case ConditionType.numberGreaterEq:
        return Numeric.compare(v, a) >= 0;
      case ConditionType.numberLess:
        return Numeric.compare(v, a) < 0;
      case ConditionType.numberLessEq:
        return Numeric.compare(v, a) <= 0;
      case ConditionType.numberEq:
        return Numeric.approxEqual(v, a);
      case ConditionType.numberNotEq:
        return !Numeric.approxEqual(v, a);
      case ConditionType.numberBetween:
      case ConditionType.numberNotBetween:
        final b = _numberOperand(1, row, col);
        if (b == null) return false;
        final lo = a < b ? a : b;
        final hi = a < b ? b : a;
        final inside = Numeric.compare(v, lo) >= 0 && Numeric.compare(v, hi) <= 0;
        return type == ConditionType.numberBetween ? inside : !inside;
      default:
        return false;
    }
  }
}
