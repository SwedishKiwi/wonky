import '../../content/cell_content.dart';
import '../../formula/values/numeric.dart';
import '../../input/input_parser.dart';
import '../conditions/value_text.dart';
import 'dv_criteria.dart';

/// Checked/unchecked values of a checkbox rule (07 §6.7): TRUE/FALSE, or the
/// custom texts parsed like typed input (numbers become numbers).
final class CheckboxValues {
  /// Creates the values.
  const CheckboxValues(this.checked, this.unchecked, {this.isCustom = false});

  /// The values of [criteria] in [locale].
  factory CheckboxValues.of(DvCheckboxCriteria criteria, {String locale = 'en_US', InputParser? parser}) {
    if (!criteria.hasCustomValues) {
      return const CheckboxValues(BoolContent(true), BoolContent(false));
    }
    CellContent parse(String? text, bool fallback) {
      if (text == null || text.isEmpty) return BoolContent(fallback);
      final p = (parser ?? InputParser.instance).parse(text, locale: locale);
      return p.content ?? TextContent(text);
    }

    return CheckboxValues(parse(criteria.checked, true), parse(criteria.unchecked, false), isCustom: true);
  }

  /// Content written when checking.
  final CellContent checked;

  /// Content written when unchecking (also written into empty cells by Insert › Checkbox).
  final CellContent unchecked;

  /// Whether custom values are used.
  final bool isCustom;

  static bool _same(CellValue v, CellContent c) {
    final w = c.literalValue;
    return switch ((v, w)) {
      (NumberValue(number: final a), NumberValue(number: final b)) => Numeric.approxEqual(a, b),
      (TextValue(text: final a), TextValue(text: final b)) => ValueText.fold(a) == ValueText.fold(b),
      (BoolValue(value: final a), BoolValue(value: final b)) => a == b,
      _ => false,
    };
  }

  /// true = checked, false = unchecked, null = neither (invalid for the rule).
  bool? stateOf(CellValue value) {
    if (_same(value, checked)) return true;
    if (_same(value, unchecked)) return false;
    return null;
  }

  /// The content after toggling a cell holding [value] (anything but checked becomes checked).
  CellContent toggle(CellValue value) => stateOf(value) == true ? unchecked : checked;

  /// Target state when toggling several cells (Space on a selection): all
  /// checked → uncheck all, otherwise check all.
  static bool toggleAllTarget(Iterable<bool?> states) => !states.every((s) => s == true);
}
