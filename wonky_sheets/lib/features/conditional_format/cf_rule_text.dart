import 'dart:convert';

import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';

/// Rewrites every formula value (`"v": "=…"` of conditions, `"value": "=…"`
/// of thresholds) of a rule JSON tree with [f].
Object? mapRuleFormulas(Object? node, String Function(String formula) f) {
  if (node is Map) {
    return {
      for (final e in node.entries)
        e.key:
            (e.key == 'v' || e.key == 'value') &&
                e.value is String &&
                (e.value as String).length > 1 &&
                (e.value as String).startsWith('=')
            ? f(e.value as String)
            : mapRuleFormulas(e.value, f),
    };
  }
  if (node is List) return [for (final v in node) mapRuleFormulas(v, f)];
  return node;
}

/// Converts a rule with A1 formulas (what users and MCP type) to the stored
/// form; relative references are relative to the rule's anchor, the top-left
/// cell of its first range (06 §15.3).
String cfRuleToStored(
  Object rule, {
  required FormulaHooks hooks,
  required String sheetId,
  required int anchorRow,
  required int anchorCol,
  required String locale,
}) {
  final json = rule is String ? jsonDecode(rule) : rule;
  return jsonEncode(
    mapRuleFormulas(
      json,
      (a1) => hooks.toStored(
        a1,
        sheetId: sheetId,
        row: anchorRow,
        col: anchorCol,
        locale: locale,
      ),
    ),
  );
}

/// The reverse of [cfRuleToStored] (editor display, MCP reads).
String cfRuleToA1(
  String storedJson, {
  required FormulaHooks hooks,
  required String sheetId,
  required int anchorRow,
  required int anchorCol,
  required String locale,
}) {
  Object? json;
  try {
    json = jsonDecode(storedJson);
  } on FormatException {
    return storedJson;
  }
  return jsonEncode(
    mapRuleFormulas(
      json,
      (stored) => hooks.toA1(
        stored,
        sheetId: sheetId,
        row: anchorRow,
        col: anchorCol,
        locale: locale,
      ),
    ),
  );
}

/// Condition types offered by the CF editor, grouped (06 §15.2).
const cfConditionGroups = <(String, List<ConditionType>)>[
  ('empty', [ConditionType.blank, ConditionType.notBlank]),
  (
    'text',
    [
      ConditionType.textContains,
      ConditionType.textNotContains,
      ConditionType.textStartsWith,
      ConditionType.textEndsWith,
      ConditionType.textEq,
    ],
  ),
  (
    'date',
    [ConditionType.dateEq, ConditionType.dateBefore, ConditionType.dateAfter],
  ),
  (
    'number',
    [
      ConditionType.numberGreater,
      ConditionType.numberGreaterEq,
      ConditionType.numberLess,
      ConditionType.numberLessEq,
      ConditionType.numberEq,
      ConditionType.numberNotEq,
      ConditionType.numberBetween,
      ConditionType.numberNotBetween,
    ],
  ),
  ('custom', [ConditionType.customFormula]),
];

/// Localized label of a condition group.
String cfGroupLabel(SheetsLocalizations l, String group) => switch (group) {
  'empty' => l.cfGroupEmpty,
  'text' => l.cfGroupText,
  'date' => l.cfGroupDate,
  'number' => l.cfGroupNumber,
  _ => l.cfGroupCustom,
};

/// Localized label of a condition type (06 §15.2 "UI label").
String cfConditionLabel(SheetsLocalizations l, ConditionType t) => switch (t) {
  ConditionType.blank => l.cfCondBlank,
  ConditionType.notBlank => l.cfCondNotBlank,
  ConditionType.textContains => l.cfCondTextContains,
  ConditionType.textNotContains => l.cfCondTextNotContains,
  ConditionType.textStartsWith => l.cfCondTextStartsWith,
  ConditionType.textEndsWith => l.cfCondTextEndsWith,
  ConditionType.textEq => l.cfCondTextEq,
  ConditionType.dateEq => l.cfCondDateEq,
  ConditionType.dateBefore => l.cfCondDateBefore,
  ConditionType.dateAfter => l.cfCondDateAfter,
  ConditionType.numberGreater => l.cfCondNumberGreater,
  ConditionType.numberGreaterEq => l.cfCondNumberGreaterEq,
  ConditionType.numberLess => l.cfCondNumberLess,
  ConditionType.numberLessEq => l.cfCondNumberLessEq,
  ConditionType.numberEq => l.cfCondNumberEq,
  ConditionType.numberNotEq => l.cfCondNumberNotEq,
  ConditionType.numberBetween => l.cfCondNumberBetween,
  ConditionType.numberNotBetween => l.cfCondNumberNotBetween,
  ConditionType.customFormula => l.cfCondCustomFormula,
  _ => t.id,
};

/// Localized label of a relative date.
String cfRelativeDateLabel(SheetsLocalizations l, RelativeDate d) =>
    switch (d) {
      RelativeDate.today => l.cfDateToday,
      RelativeDate.tomorrow => l.cfDateTomorrow,
      RelativeDate.yesterday => l.cfDateYesterday,
      RelativeDate.pastWeek => l.cfDatePastWeek,
      RelativeDate.pastMonth => l.cfDatePastMonth,
      RelativeDate.pastYear => l.cfDatePastYear,
    };

String _valueText(SheetsLocalizations l, ConditionValue v) => switch (v) {
  ConditionLiteral(:final text) => text,
  ConditionFormula(:final stored) => stored,
  ConditionRelativeDate(:final date) => cfRelativeDateLabel(l, date),
};

/// One-line summary of a rule in A1 form for the rule list ("Greater than
/// 100", "Color scale").
String cfRuleSummary(SheetsLocalizations l, CfRule rule) {
  switch (rule) {
    case CfBooleanRule(:final condition):
      final label = cfConditionLabel(l, condition.type);
      if (condition is CustomFormulaCondition) {
        return '$label ${condition.formula}';
      }
      final vals = [for (final v in condition.values) _valueText(l, v)];
      if (vals.isEmpty) return label;
      if (vals.length == 2) {
        return l.cfSummaryTwoValues(label, vals[0], vals[1]);
      }
      return '$label ${vals.first}';
    case CfColorScaleRule():
      return l.cfKindColorScale;
    case CfDataBarRule():
      return l.cfKindDataBar;
    case CfIconSetRule():
      return l.cfKindIconSet;
    case CfUnknownRule():
      return l.cfKindUnsupported;
  }
}

/// Localized names of the icon sets.
String cfIconSetLabel(SheetsLocalizations l, IconSetKind k) => switch (k) {
  IconSetKind.arrows3 => l.cfIconArrows(3),
  IconSetKind.arrowsGray3 => l.cfIconArrowsGray(3),
  IconSetKind.triangles3 => l.cfIconTriangles(3),
  IconSetKind.trafficLights3 => l.cfIconTrafficLights(3),
  IconSetKind.signs3 => l.cfIconSigns(3),
  IconSetKind.symbols3 => l.cfIconSymbols(3),
  IconSetKind.flags3 => l.cfIconFlags(3),
  IconSetKind.stars3 => l.cfIconStars(3),
  IconSetKind.arrows4 => l.cfIconArrows(4),
  IconSetKind.ratings4 => l.cfIconRatings(4),
  IconSetKind.trafficLights4 => l.cfIconTrafficLights(4),
  IconSetKind.arrows5 => l.cfIconArrows(5),
  IconSetKind.ratings5 => l.cfIconRatings(5),
  IconSetKind.quarters5 => l.cfIconQuarters(5),
};

/// Localized threshold kind label.
String cfValueKindLabel(SheetsLocalizations l, CfValueKind k) => switch (k) {
  CfValueKind.min => l.cfKindMin,
  CfValueKind.max => l.cfKindMax,
  CfValueKind.number => l.cfKindNumber,
  CfValueKind.percent => l.cfKindPercent,
  CfValueKind.percentile => l.cfKindPercentile,
  CfValueKind.formula => l.cfKindFormula,
};
