import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../engine_bridge/formula_hooks.dart';
import '../../formula/values/numeric.dart';
import '../../model/events.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/sheet_model.dart';
import '../conditions/condition.dart';
import '../conditions/condition_evaluator.dart';
import '../conditions/value_text.dart';
import 'checkbox_values.dart';
import 'dv_criteria.dart';
import 'list_source.dart';

/// A parsed `DataValidationRule` (07 §6.1).
final class DvRule {
  /// Creates a rule.
  DvRule({
    required this.id,
    required this.criteria,
    this.strict = false,
    this.helpText,
    this.displayStyle = DvDisplayStyle.chip,
    DateTime? createdAt,
    this.anchor = const CellPos(0, 0),
    this.rects = const [],
  }) : createdAt = createdAt ?? DateTime.utc(1970);

  /// Parses a record; [sheet] resolves its ranges (anchor = top-left of the
  /// first range). Null when the criteria are malformed.
  static DvRule? fromRecord(DvRuleRecord record, SheetModel sheet) {
    final criteria = DvCriteria.tryParse(record.criteriaJson);
    if (criteria == null) return null;
    final rects = [
      for (final r in GridRange.parseList(record.rangesJson))
        if (sheet.resolve(r) case final ResolvedRange rr) rr.rect,
    ];
    return DvRule(
      id: record.id,
      criteria: criteria,
      strict: record.strict,
      helpText: (record.helpText?.isEmpty ?? true) ? null : record.helpText,
      displayStyle: record.displayStyle == null
          ? (record.showDropdown
                ? DvDisplayStyle.chip
                : DvDisplayStyle.plainText)
          : DvDisplayStyle.parse(record.displayStyle),
      createdAt: record.createdAt,
      anchor: rects.isEmpty ? const CellPos(0, 0) : rects.first.topLeft,
      rects: rects,
    );
  }

  final String id;
  final DvCriteria criteria;

  /// Reject invalid typed input (else warn).
  final bool strict;
  final String? helpText;
  final DvDisplayStyle displayStyle;
  final DateTime createdAt;

  /// Anchor of relative formulas.
  final CellPos anchor;

  /// Resolved rectangles.
  final List<GridRect> rects;
}

/// Result of [ValidationEngine.validate].
final class ValidationResult {
  /// Creates a result.
  const ValidationResult(this.valid, [this.message, this.defaultMessage]);

  /// A valid result.
  static const ValidationResult ok = ValidationResult(true);

  /// Whether the value satisfies the rule.
  final bool valid;

  /// Message to show when invalid: the help text, else [defaultMessage].
  final String? message;

  /// The default invalid message of 07 §6.2.
  final String? defaultMessage;

  @override
  bool operator ==(Object other) =>
      other is ValidationResult &&
      other.valid == valid &&
      other.message == message;

  @override
  int get hashCode => Object.hash(valid, message);

  @override
  String toString() =>
      valid ? 'ValidationResult(valid)' : 'ValidationResult(invalid: $message)';
}

/// Per-cell context of [ValidationEngine.validate].
final class ValidationContext {
  /// Creates a context.
  const ValidationContext({
    required this.sheetId,
    required this.row,
    required this.col,
    required this.conditions,
    this.rangeItems,
    this.numberFormat,
  });

  final String sheetId;
  final int row;
  final int col;

  /// Condition evaluator (locale, dates, formula hooks).
  final ConditionEvaluator conditions;

  /// Items of `oneOfRange` criteria (usually [ListSource.rangeItems]).
  final List<String> Function(DvRangeCriteria criteria)? rangeItems;

  /// The cell's effective number format (for `dateIsValid`).
  final String? numberFormat;
}

/// Validates computed values against data validation rules (07 §6.2, §6.5).
final class ValidationEngine {
  /// Creates the engine.
  const ValidationEngine();

  /// Validates [value] (computed value) with [displayText] (formatted value)
  /// against [rule]. Empty cells are always valid.
  ValidationResult validate(
    CellValue value,
    String displayText,
    DvRule rule,
    ValidationContext ctx,
  ) {
    if (value.isBlank()) return ValidationResult.ok;
    final valid = switch (rule.criteria) {
      final DvListCriteria c => _listMatch(
        value,
        displayText,
        ListSource.listItems(c),
        c.allowMultiple,
        ctx,
      ),
      final DvRangeCriteria c => _listMatch(
        value,
        displayText,
        ctx.rangeItems?.call(c) ?? const [],
        c.allowMultiple,
        ctx,
      ),
      final DvCheckboxCriteria c =>
        CheckboxValues.of(c, locale: ctx.conditions.locale).stateOf(value) !=
            null,
      DvConditionCriteria(:final condition) =>
        ctx.conditions
            .compile(
              condition,
              sheetId: ctx.sheetId,
              anchorRow: rule.anchor.row,
              anchorCol: rule.anchor.col,
            )
            .test(
              value,
              row: ctx.row,
              col: ctx.col,
              numberFormat: ctx.numberFormat,
            ),
    };
    if (valid) return ValidationResult.ok;
    final def = defaultMessage(
      rule.criteria,
      hooks: ctx.conditions.hooks,
      sheetId: ctx.sheetId,
      anchor: rule.anchor,
    );
    return ValidationResult(false, rule.helpText ?? def, def);
  }

  bool _listMatch(
    CellValue value,
    String display,
    List<String> items,
    bool multiple,
    ValidationContext ctx,
  ) {
    if (multiple && value is TextValue) {
      final parts = display.split(', ');
      return parts.every((p) => _itemMatch(TextValue(p), p, items, ctx));
    }
    return _itemMatch(value, display, items, ctx);
  }

  bool _itemMatch(
    CellValue value,
    String display,
    List<String> items,
    ValidationContext ctx,
  ) {
    for (final item in items) {
      if (item == display) return true;
    }
    if (value is NumberValue) {
      for (final item in items) {
        final n = ValueText.parseNumber(item, locale: ctx.conditions.locale);
        if (n != null && Numeric.approxEqual(n, value.number)) return true;
      }
    }
    return false;
  }

  /// The default invalid message of [criteria] (07 §6.2). Formula values are
  /// shown in A1 form when [hooks] are given.
  static String defaultMessage(
    DvCriteria criteria, {
    FormulaHooks? hooks,
    String sheetId = '',
    CellPos anchor = const CellPos(0, 0),
  }) {
    switch (criteria) {
      case DvListCriteria():
      case DvRangeCriteria():
        return 'Input must be an item on the specified list';
      case DvCheckboxCriteria(:final checked, :final unchecked):
        if (!criteria.hasCustomValues) return 'Input must be TRUE or FALSE';
        return 'Input must be "${checked ?? 'TRUE'}" or "${unchecked ?? 'FALSE'}"';
      case DvConditionCriteria(:final condition):
        String v(int i) {
          if (i >= condition.values.length) return '';
          return switch (condition.values[i]) {
            ConditionLiteral(:final text) => text,
            ConditionRelativeDate(:final date) => date.label,
            ConditionFormula(:final stored) =>
              hooks?.toA1(
                    stored,
                    sheetId: sheetId,
                    row: anchor.row,
                    col: anchor.col,
                  ) ??
                  stored,
          };
        }

        return switch (condition.type) {
          ConditionType.numberBetween =>
            'Input must be a number between ${v(0)} and ${v(1)}',
          ConditionType.numberNotBetween =>
            'Input must be a number not between ${v(0)} and ${v(1)}',
          ConditionType.numberGreater => 'Input must be greater than ${v(0)}',
          ConditionType.numberGreaterEq =>
            'Input must be greater than or equal to ${v(0)}',
          ConditionType.numberLess => 'Input must be less than ${v(0)}',
          ConditionType.numberLessEq =>
            'Input must be less than or equal to ${v(0)}',
          ConditionType.numberEq => 'Input must be equal to ${v(0)}',
          ConditionType.numberNotEq => 'Input must be not equal to ${v(0)}',
          ConditionType.textContains => 'Input must contain "${v(0)}"',
          ConditionType.textNotContains => 'Input must not contain "${v(0)}"',
          ConditionType.textEq => 'Input must be exactly "${v(0)}"',
          ConditionType.textStartsWith => 'Input must start with "${v(0)}"',
          ConditionType.textEndsWith => 'Input must end with "${v(0)}"',
          ConditionType.textIsEmail => 'Input must be a valid email address',
          ConditionType.textIsUrl => 'Input must be a valid URL',
          ConditionType.dateIsValid => 'Input must be a valid date',
          ConditionType.dateEq => 'Input must be a date on ${v(0)}',
          ConditionType.dateBefore => 'Input must be a date before ${v(0)}',
          ConditionType.dateAfter => 'Input must be a date after ${v(0)}',
          ConditionType.dateOnOrBefore =>
            'Input must be a date on or before ${v(0)}',
          ConditionType.dateOnOrAfter =>
            'Input must be a date on or after ${v(0)}',
          ConditionType.dateBetween =>
            'Input must be a date between ${v(0)} and ${v(1)}',
          ConditionType.dateNotBetween =>
            'Input must be a date not between ${v(0)} and ${v(1)}',
          ConditionType.customFormula =>
            'Input must satisfy the specified formula',
          ConditionType.blank || ConditionType.notBlank =>
            'Input must satisfy the specified condition',
        };
    }
  }
}

/// Effective rule resolution for overlapping rules (07 §6.4).
abstract final class DvRuleResolver {
  static int _cmp(DvRuleRecord a, DvRuleRecord b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  /// The rule effective at a cell: the containing rule with the greatest
  /// `(createdAt, id)`, or null.
  static DvRuleRecord? effectiveRuleAt(SheetModel sheet, int row, int col) {
    DvRuleRecord? best;
    for (final id in sheet.rulesAt(RuleKind.dataValidation, row, col)) {
      final r = sheet.dvRules[id];
      if (r == null) continue;
      if (best == null || _cmp(r, best) > 0) best = r;
    }
    return best;
  }

  /// Ids of rules that are (at least partly) shadowed by a greater rule (warning icon in the panel).
  static Set<String> shadowedRuleIds(SheetModel sheet) {
    final out = <String>{};
    final rules = sheet.dvRules.values.toList();
    final rects = {
      for (final r in rules)
        r.id: sheet.ruleRects(RuleKind.dataValidation, r.id),
    };
    for (final a in rules) {
      for (final rect in rects[a.id]!) {
        for (final id in sheet.rulesIntersecting(
          RuleKind.dataValidation,
          rect,
        )) {
          final b = sheet.dvRules[id];
          if (b == null || b.id == a.id) continue;
          if (_cmp(b, a) > 0 && rects[b.id]!.any((q) => q.intersects(rect))) {
            out.add(a.id);
          }
        }
      }
    }
    return out;
  }
}
