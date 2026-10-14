import 'package:wonky_sheets_core/formula.dart'
    show FormulaLocale, validateFormula;
import 'package:wonky_sheets_core/model.dart';

/// Rule kinds of the CF editor tabs (06 §15.9).
enum CfEditKind { single, colorScale, dataBar, iconSet }

/// One color-scale point being edited (`kind == null` = no midpoint).
class CfPointEdit {
  CfPointEdit(this.kind, this.value, this.color);

  CfValueKind? kind;
  String value;
  String color;

  CfPointEdit copy() => CfPointEdit(kind, value, color);
}

/// One icon-set threshold being edited.
class CfIconThresholdEdit {
  CfIconThresholdEdit(this.kind, this.value, {this.inclusive = true});

  CfValueKind kind;
  String value;
  bool inclusive;
}

/// The mutable draft of the CF rule editor (06 §15.9) in **A1 form**
/// (formulas as the user types them). [toRule] builds the `CfRule`; the
/// panel converts it to stored form for the preview and the commands.
class CfEditState {
  CfEditState({
    required this.rangeText,
    this.ruleId,
    this.sortKey,
    this.kind = CfEditKind.single,
  });

  /// A new rule (06 §15.9 "+ Add another rule": condition `notBlank`, default
  /// style).
  factory CfEditState.newRule(String rangeText) =>
      CfEditState(rangeText: rangeText)..resetFormat();

  /// Loads an existing rule (A1 form).
  factory CfEditState.fromRule(
    CfRule rule, {
    required String rangeText,
    required String ruleId,
    required String sortKey,
  }) {
    final s = CfEditState(
      rangeText: rangeText,
      ruleId: ruleId,
      sortKey: sortKey,
    )..resetFormat();
    switch (rule) {
      case CfBooleanRule(:final condition, :final format, :final stopIfTrue):
        s.kind = CfEditKind.single;
        s.type = condition.type;
        s.values = [
          for (final v in condition.values)
            switch (v) {
              ConditionLiteral(:final text) => text,
              ConditionFormula(:final stored) => stored,
              ConditionRelativeDate() => '',
            },
        ];
        if (condition is CustomFormulaCondition) {
          s.values = [condition.formula];
        }
        final rel = condition.values.whereType<ConditionRelativeDate>();
        s.relativeDate = rel.isEmpty ? null : rel.first.date;
        s.format = {
          for (final a in format.attrs)
            if (format[a] != null) a: format[a]!,
        };
        s.stopIfTrue = stopIfTrue;
      case CfColorScaleRule(:final points):
        s.kind = CfEditKind.colorScale;
        s.points = _points(points);
      case CfDataBarRule():
        s.kind = CfEditKind.dataBar;
        s.bar = rule;
        s.barMin = CfPointEdit(rule.min.kind, rule.min.value ?? '', '');
        s.barMax = CfPointEdit(rule.max.kind, rule.max.value ?? '', '');
      case CfIconSetRule():
        s.kind = CfEditKind.iconSet;
        s.iconSet = rule.set;
        s.iconThresholds = [
          for (final t in rule.thresholds)
            CfIconThresholdEdit(
              t.threshold.kind,
              t.threshold.value ?? '',
              inclusive: t.inclusive,
            ),
        ];
        s.iconReverse = rule.reverse;
        s.iconShowValue = rule.showValue;
      case CfUnknownRule():
        break;
    }
    return s;
  }

  static List<CfPointEdit> _points(List<ColorScalePoint> pts) {
    final min = pts.first;
    final max = pts.last;
    final mid = pts.length == 3 ? pts[1] : null;
    return [
      CfPointEdit(min.threshold.kind, min.threshold.value ?? '', min.color),
      CfPointEdit(
        mid?.threshold.kind,
        mid?.threshold.value ?? (mid == null ? '50' : ''),
        mid?.color ?? CfPresets.yellow,
      ),
      CfPointEdit(max.threshold.kind, max.threshold.value ?? '', max.color),
    ];
  }

  /// Existing rule id (null for a new rule).
  final String? ruleId;
  final String? sortKey;

  /// The *Apply to range* text.
  String rangeText;
  CfEditKind kind;

  // Single color.
  ConditionType type = ConditionType.notBlank;

  /// Value texts (A1 formulas start with `=`).
  List<String> values = ['', ''];

  /// Relative date of date conditions (null = exact date in [values]).
  RelativeDate? relativeDate = RelativeDate.today;
  Map<FormatAttr, Object> format = {};
  bool stopIfTrue = true;

  // Color scale (min, mid (kind null = none), max).
  List<CfPointEdit> points = _points(CfPresets.colorScales().first.points);

  // Data bar.
  CfDataBarRule bar = const CfDataBarRule();
  CfPointEdit barMin = CfPointEdit(CfValueKind.min, '', '');
  CfPointEdit barMax = CfPointEdit(CfValueKind.max, '', '');

  // Icon set.
  IconSetKind iconSet = IconSetKind.arrows3;
  List<CfIconThresholdEdit> iconThresholds = defaultIconThresholds(
    IconSetKind.arrows3,
  );
  bool iconReverse = false;
  bool iconShowValue = true;

  /// Default thresholds of a set: equal percent steps (67/33 for 3 icons).
  static List<CfIconThresholdEdit> defaultIconThresholds(IconSetKind set) {
    final n = set.iconCount;
    return [
      for (var i = 1; i < n; i++)
        CfIconThresholdEdit(
          CfValueKind.percent,
          '${(100 * (n - i) / n).round()}',
        ),
    ];
  }

  /// The default single-color style.
  void resetFormat() =>
      format = Map.of(CfPresets.formattingStyles.first.values);

  /// Applies a color scale preset.
  void applyScale(ColorScalePreset p) => points = _points(p.points);

  /// Changes the icon set, keeping thresholds when the icon count matches.
  void setIconSet(IconSetKind set) {
    if (set.iconCount != iconSet.iconCount) {
      iconThresholds = defaultIconThresholds(set);
    }
    iconSet = set;
  }

  static ConditionValue _value(String text) {
    final t = text.trim();
    return ConditionValue.text(t);
  }

  /// The condition of the single-color rule.
  Condition condition() {
    if (type == ConditionType.customFormula) {
      final f = values.first.trim();
      return Condition.of(type, [ConditionValue.text(f)]);
    }
    if (type.family == ConditionFamily.date) {
      final rel = relativeDate;
      return Condition.of(type, [
        if (rel != null) ConditionRelativeDate(rel) else _value(values.first),
      ]);
    }
    return Condition.of(type, [
      for (var i = 0; i < type.arity; i++)
        _value(i < values.length ? values[i] : ''),
    ]);
  }

  static CfThreshold _threshold(CfValueKind kind, String value) =>
      switch (kind) {
        CfValueKind.min || CfValueKind.max => CfThreshold(kind),
        _ => CfThreshold(kind, value.trim()),
      };

  /// The rule in A1 form.
  CfRule toRule() {
    switch (kind) {
      case CfEditKind.single:
        return CfBooleanRule(
          condition: condition(),
          format: CellFormat(format),
          stopIfTrue: stopIfTrue,
        );
      case CfEditKind.colorScale:
        return CfColorScaleRule([
          for (final p in points)
            if (p.kind != null)
              ColorScalePoint(_threshold(p.kind!, p.value), p.color),
        ]);
      case CfEditKind.dataBar:
        return CfDataBarRule(
          min: _threshold(barMin.kind ?? CfValueKind.min, barMin.value),
          max: _threshold(barMax.kind ?? CfValueKind.max, barMax.value),
          color: bar.color,
          negativeColor: bar.negativeColor,
          gradient: bar.gradient,
          axis: bar.axis,
          direction: bar.direction,
          showValue: bar.showValue,
        );
      case CfEditKind.iconSet:
        return CfIconSetRule(
          set: iconSet,
          thresholds: [
            for (final t in iconThresholds)
              IconThreshold(
                _threshold(t.kind, t.value),
                inclusive: t.inclusive,
              ),
          ],
          reverse: iconReverse,
          showValue: iconShowValue,
        );
    }
  }

  /// The first validation problem (06 §15.9 inline errors), or null.
  /// [rangesValid] reflects the *Apply to range* input.
  CfEditError? validate({
    required bool rangesValid,
    String locale = 'en_US',
    FormulaLocale? formulaLocale,
  }) {
    if (!rangesValid) return const CfEditError(CfEditErrorKind.range);
    String? formulaError(String text) {
      final t = text.trim();
      if (!t.startsWith('=')) return null;
      final v = validateFormula(
        t,
        locale: formulaLocale ?? FormulaLocale.forId(locale),
      );
      return v.ok ? null : (v.error?.message ?? 'Invalid formula');
    }

    switch (kind) {
      case CfEditKind.single:
        if (type == ConditionType.customFormula) {
          final f = values.first.trim();
          if (f.isEmpty || f == '=') {
            return const CfEditError(CfEditErrorKind.emptyValue);
          }
          final err = formulaError(f.startsWith('=') ? f : '=$f');
          if (err != null) return CfEditError(CfEditErrorKind.formula, err);
          return null;
        }
        if (type.family == ConditionFamily.date && relativeDate != null) {
          return null;
        }
        for (var i = 0; i < type.arity; i++) {
          final v = i < values.length ? values[i] : '';
          if (v.trim().isEmpty) {
            return const CfEditError(CfEditErrorKind.emptyValue);
          }
          final err = formulaError(v);
          if (err != null) return CfEditError(CfEditErrorKind.formula, err);
        }
        if (format.isEmpty) return const CfEditError(CfEditErrorKind.noFormat);
        return null;
      case CfEditKind.colorScale:
        for (final p in points) {
          final k = p.kind;
          if (k == null || k == CfValueKind.min || k == CfValueKind.max) {
            continue;
          }
          if (p.value.trim().isEmpty) {
            return const CfEditError(CfEditErrorKind.emptyValue);
          }
          final err = formulaError(p.value);
          if (err != null) return CfEditError(CfEditErrorKind.formula, err);
        }
        return null;
      case CfEditKind.dataBar:
        for (final p in [barMin, barMax]) {
          final k = p.kind;
          if (k == null || k == CfValueKind.min || k == CfValueKind.max) {
            continue;
          }
          if (p.value.trim().isEmpty) {
            return const CfEditError(CfEditErrorKind.emptyValue);
          }
          final err = formulaError(p.value);
          if (err != null) return CfEditError(CfEditErrorKind.formula, err);
        }
        return null;
      case CfEditKind.iconSet:
        for (final t in iconThresholds) {
          if (t.value.trim().isEmpty) {
            return const CfEditError(CfEditErrorKind.emptyValue);
          }
          final err = formulaError(t.value);
          if (err != null) return CfEditError(CfEditErrorKind.formula, err);
        }
        return null;
    }
  }
}

/// Kinds of editor validation errors.
enum CfEditErrorKind { range, emptyValue, formula, noFormat }

/// A validation error of the CF editor.
class CfEditError {
  const CfEditError(this.kind, [this.message]);

  final CfEditErrorKind kind;

  /// Parser message of [CfEditErrorKind.formula].
  final String? message;
}
