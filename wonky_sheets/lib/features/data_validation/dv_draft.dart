import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';

/// The criteria choices of the data validation editor (07 §6.3), in menu
/// order.
enum DvKind {
  dropdown,
  dropdownRange,
  textContains(ConditionType.textContains),
  textNotContains(ConditionType.textNotContains),
  textEq(ConditionType.textEq),
  textIsEmail(ConditionType.textIsEmail),
  textIsUrl(ConditionType.textIsUrl),
  dateIsValid(ConditionType.dateIsValid),
  dateEq(ConditionType.dateEq),
  dateBefore(ConditionType.dateBefore),
  dateAfter(ConditionType.dateAfter),
  dateOnOrBefore(ConditionType.dateOnOrBefore),
  dateOnOrAfter(ConditionType.dateOnOrAfter),
  dateBetween(ConditionType.dateBetween),
  dateNotBetween(ConditionType.dateNotBetween),
  numberGreater(ConditionType.numberGreater),
  numberGreaterEq(ConditionType.numberGreaterEq),
  numberLess(ConditionType.numberLess),
  numberLessEq(ConditionType.numberLessEq),
  numberEq(ConditionType.numberEq),
  numberNotEq(ConditionType.numberNotEq),
  numberBetween(ConditionType.numberBetween),
  numberNotBetween(ConditionType.numberNotBetween),
  checkbox,
  customFormula(ConditionType.customFormula);

  const DvKind([this.condition]);

  /// The condition type of condition-based kinds.
  final ConditionType? condition;

  /// Number of values (0–2).
  int get arity => condition?.arity ?? 0;

  bool get isDate => condition?.family == ConditionFamily.date;
  bool get isNumber => condition?.family == ConditionFamily.number;
  bool get isDropdown => this == dropdown || this == dropdownRange;

  static DvKind? ofCondition(ConditionType t) {
    for (final k in values) {
      if (k.condition == t) return k;
    }
    return null;
  }

  String label(SheetsLocalizations l) => switch (this) {
    dropdown => l.dvCritDropdown,
    dropdownRange => l.dvCritDropdownRange,
    textContains => l.dvCritTextContains,
    textNotContains => l.dvCritTextNotContains,
    textEq => l.dvCritTextEq,
    textIsEmail => l.dvCritTextIsEmail,
    textIsUrl => l.dvCritTextIsUrl,
    dateIsValid => l.dvCritDateIsValid,
    dateEq => l.dvCritDateEq,
    dateBefore => l.dvCritDateBefore,
    dateAfter => l.dvCritDateAfter,
    dateOnOrBefore => l.dvCritDateOnOrBefore,
    dateOnOrAfter => l.dvCritDateOnOrAfter,
    dateBetween => l.dvCritDateBetween,
    dateNotBetween => l.dvCritDateNotBetween,
    numberGreater => l.dvCritNumberGreater,
    numberGreaterEq => l.dvCritNumberGreaterEq,
    numberLess => l.dvCritNumberLess,
    numberLessEq => l.dvCritNumberLessEq,
    numberEq => l.dvCritNumberEq,
    numberNotEq => l.dvCritNumberNotEq,
    numberBetween => l.dvCritNumberBetween,
    numberNotBetween => l.dvCritNumberNotBetween,
    checkbox => l.dvCritCheckbox,
    customFormula => l.dvCritCustomFormula,
  };
}

/// "Exact date" or a relative date of a one-value date criterion.
enum DvDateChoice {
  exact,
  today,
  tomorrow,
  yesterday,
  pastWeek,
  pastMonth,
  pastYear;

  RelativeDate? get relative => RelativeDate.byName(name);

  String label(SheetsLocalizations l) => switch (this) {
    exact => l.dvDateExact,
    today => l.dvDateToday,
    tomorrow => l.dvDateTomorrow,
    yesterday => l.dvDateYesterday,
    pastWeek => l.dvDatePastWeek,
    pastMonth => l.dvDatePastMonth,
    pastYear => l.dvDatePastYear,
  };
}

/// One dropdown item being edited.
@immutable
class DvOptionDraft {
  const DvOptionDraft(this.value, {this.colors = const DvChipColors()});

  final String value;
  final DvChipColors colors;

  DvOptionDraft copyWith({String? value, DvChipColors? colors}) =>
      DvOptionDraft(value ?? this.value, colors: colors ?? this.colors);
}

/// Converts formulas between the A1 text shown in the editor and the stored
/// form saved in the rule (relative to the rule's anchor, 07 §6.1).
abstract interface class DvFormulaCodec {
  String toStored(
    String a1, {
    required String sheetId,
    required int row,
    required int col,
  });
  String toA1(
    String stored, {
    required String sheetId,
    required int row,
    required int col,
  });
}

/// The rule being added or edited in the data validation panel (07 §6.3):
/// everything the editor shows, convertible to and from the rule's
/// `criteriaJson`.
@immutable
class DvDraft {
  const DvDraft({
    this.ruleId,
    required this.sheetId,
    this.rangesText = '',
    this.kind = DvKind.dropdown,
    this.options = const [DvOptionDraft(''), DvOptionDraft('')],
    this.sourceRange = '',
    this.customCheckbox = false,
    this.checked = '',
    this.unchecked = '',
    this.values = const ['', ''],
    this.dateChoice = DvDateChoice.exact,
    this.strict = false,
    this.helpEnabled = false,
    this.helpText = '',
    this.style = DvDisplayStyle.chip,
    this.allowMultiple = false,
  });

  final String? ruleId;
  final String sheetId;

  /// A1 list of the ranges (`A2:A500, C2:C9`).
  final String rangesText;
  final DvKind kind;
  final List<DvOptionDraft> options;

  /// A1 of the `oneOfRange` source.
  final String sourceRange;
  final bool customCheckbox;
  final String checked;
  final String unchecked;

  /// Condition values as typed (`=…` formulas in A1).
  final List<String> values;

  /// For one-value date kinds: exact date or a relative date.
  final DvDateChoice dateChoice;

  /// Reject invalid input (else warn).
  final bool strict;
  final bool helpEnabled;
  final String helpText;
  final DvDisplayStyle style;
  final bool allowMultiple;

  bool get isNew => ruleId == null;

  DvDraft copyWith({
    String? rangesText,
    DvKind? kind,
    List<DvOptionDraft>? options,
    String? sourceRange,
    bool? customCheckbox,
    String? checked,
    String? unchecked,
    List<String>? values,
    DvDateChoice? dateChoice,
    bool? strict,
    bool? helpEnabled,
    String? helpText,
    DvDisplayStyle? style,
    bool? allowMultiple,
  }) => DvDraft(
    ruleId: ruleId,
    sheetId: sheetId,
    rangesText: rangesText ?? this.rangesText,
    kind: kind ?? this.kind,
    options: options ?? this.options,
    sourceRange: sourceRange ?? this.sourceRange,
    customCheckbox: customCheckbox ?? this.customCheckbox,
    checked: checked ?? this.checked,
    unchecked: unchecked ?? this.unchecked,
    values: values ?? this.values,
    dateChoice: dateChoice ?? this.dateChoice,
    strict: strict ?? this.strict,
    helpEnabled: helpEnabled ?? this.helpEnabled,
    helpText: helpText ?? this.helpText,
    style: style ?? this.style,
    allowMultiple: allowMultiple ?? this.allowMultiple,
  );

  /// The draft of an existing rule; [anchor] is the top-left cell of its
  /// first range (formula values are shown in A1 relative to it).
  static DvDraft fromRule(
    DvRuleRecord record,
    SheetModel sheet, {
    required String rangesText,
    required DvFormulaCodec codec,
    String Function(GridRange range)? rangeA1,
  }) {
    final rects = sheet.ruleRects(RuleKind.dataValidation, record.id);
    final anchor = rects.isEmpty ? null : rects.first;
    String a1(ConditionValue v) => switch (v) {
      ConditionFormula(:final stored) =>
        anchor == null
            ? stored
            : codec.toA1(
                stored,
                sheetId: sheet.id,
                row: anchor.top,
                col: anchor.left,
              ),
      ConditionLiteral(:final text) => text,
      ConditionRelativeDate() => '',
    };
    final style = record.displayStyle == null
        ? (record.showDropdown ? DvDisplayStyle.chip : DvDisplayStyle.plainText)
        : DvDisplayStyle.parse(record.displayStyle);
    final base = DvDraft(
      ruleId: record.id,
      sheetId: sheet.id,
      rangesText: rangesText,
      strict: record.strict,
      helpEnabled: (record.helpText ?? '').isNotEmpty,
      helpText: record.helpText ?? '',
      style: style,
    );
    final criteria = DvCriteria.tryParse(record.criteriaJson);
    switch (criteria) {
      case DvListCriteria(:final options, :final allowMultiple):
        return base.copyWith(
          kind: DvKind.dropdown,
          options: [
            for (final o in options) DvOptionDraft(o.value, colors: o.colors),
          ],
          allowMultiple: allowMultiple,
        );
      case DvRangeCriteria(:final range, :final allowMultiple):
        return base.copyWith(
          kind: DvKind.dropdownRange,
          sourceRange: rangeA1?.call(range) ?? '',
          allowMultiple: allowMultiple,
        );
      case DvCheckboxCriteria(:final checked, :final unchecked):
        return base.copyWith(
          kind: DvKind.checkbox,
          customCheckbox: checked != null || unchecked != null,
          checked: checked ?? '',
          unchecked: unchecked ?? '',
        );
      case DvConditionCriteria(:final condition):
        final kind = DvKind.ofCondition(condition.type) ?? DvKind.textContains;
        final vals = condition.values;
        final rel = vals.isNotEmpty && vals.first is ConditionRelativeDate
            ? (vals.first as ConditionRelativeDate).date
            : null;
        return base.copyWith(
          kind: kind,
          values: [
            if (vals.isNotEmpty) a1(vals[0]) else '',
            if (vals.length > 1) a1(vals[1]) else '',
          ],
          dateChoice: rel == null
              ? DvDateChoice.exact
              : DvDateChoice.values.byName(rel.name),
        );
      case null:
        return base;
    }
  }

  /// Errors of the criteria (null when valid). Ranges are validated by the
  /// panel.
  String? criteriaError(SheetsLocalizations l) {
    switch (kind) {
      case DvKind.dropdown:
        return options.any((o) => o.value.trim().isNotEmpty)
            ? null
            : l.dvErrorNoItems;
      case DvKind.dropdownRange:
        return sourceRange.trim().isEmpty ? l.dvErrorRange : null;
      case DvKind.checkbox:
        return customCheckbox && checked.trim().isEmpty ? l.dvErrorValue : null;
      case DvKind.customFormula:
        final v = values.first.trim();
        return v.length < 2 || !v.startsWith('=') ? l.dvErrorFormula : null;
      default:
        final n = kind.arity;
        if (kind.isDate && n == 1 && dateChoice != DvDateChoice.exact) {
          return null;
        }
        for (var i = 0; i < n; i++) {
          final v = values[i].trim();
          if (v.isEmpty) return l.dvErrorValue;
          if (kind.isNumber &&
              !v.startsWith('=') &&
              num.tryParse(v.replaceAll(',', '')) == null) {
            return l.dvErrorNumber;
          }
        }
        return null;
    }
  }

  /// `criteriaJson` of the draft; formulas are converted to stored form
  /// relative to [anchor] (top-left of the first range).
  Map<String, Object?> criteriaJson({
    required DvFormulaCodec codec,
    required GridRect anchor,
    GridRange? source,
  }) {
    ConditionValue value(String text) {
      final t = text.trim();
      if (t.length > 1 && t.startsWith('=')) {
        return ConditionFormula(
          codec.toStored(
            t,
            sheetId: sheetId,
            row: anchor.top,
            col: anchor.left,
          ),
        );
      }
      return ConditionLiteral(t);
    }

    switch (kind) {
      case DvKind.dropdown:
        final seen = <String>{};
        return DvListCriteria([
          for (final o in options)
            if (o.value.trim().isNotEmpty && seen.add(o.value.trim()))
              DvOption(o.value.trim(), colors: o.colors),
        ], allowMultiple: allowMultiple).toJson();
      case DvKind.dropdownRange:
        return DvRangeCriteria(source!, allowMultiple: allowMultiple).toJson();
      case DvKind.checkbox:
        return DvCheckboxCriteria(
          checked: customCheckbox ? checked.trim() : null,
          unchecked: customCheckbox && unchecked.trim().isNotEmpty
              ? unchecked.trim()
              : null,
        ).toJson();
      default:
        final type = kind.condition!;
        final List<ConditionValue> vals;
        if (kind.isDate && kind.arity == 1 && dateChoice.relative != null) {
          vals = [ConditionRelativeDate(dateChoice.relative!)];
        } else {
          vals = [for (var i = 0; i < kind.arity; i++) value(values[i])];
        }
        return Condition.of(type, vals).toJson();
    }
  }
}
