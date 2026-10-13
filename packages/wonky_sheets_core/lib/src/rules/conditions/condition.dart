import 'dart:convert';

/// Groups of [ConditionType]s sharing value semantics (06 §15.2, 07 §3.3).
enum ConditionFamily {
  /// `blank` / `notBlank`.
  emptiness,

  /// Text comparisons on the Automatic text of the value.
  text,

  /// `textIsEmail` / `textIsUrl` (data validation only).
  textPattern,

  /// Date comparisons (numeric values only).
  date,

  /// `dateIsValid` (data validation only).
  dateValidity,

  /// Number comparisons (numeric values only).
  number,

  /// `customFormula`.
  custom,
}

/// Where a condition type may be used (07 §3.3 table).
enum ConditionUse {
  /// Basic filters, filter views, slicers and pivot filters.
  filter,

  /// Conditional formatting (06 §15.2).
  conditionalFormat,

  /// Data validation (07 §6).
  dataValidation,
}

const _all = {
  ConditionUse.filter,
  ConditionUse.conditionalFormat,
  ConditionUse.dataValidation,
};
const _filterCf = {ConditionUse.filter, ConditionUse.conditionalFormat};
const _dvOnly = {ConditionUse.dataValidation};

/// The `type` of a [Condition] (JSON id, number of values, family, uses).
enum ConditionType {
  blank('blank', 0, ConditionFamily.emptiness, _filterCf),
  notBlank('notBlank', 0, ConditionFamily.emptiness, _filterCf),
  textContains('textContains', 1, ConditionFamily.text, _all),
  textNotContains('textNotContains', 1, ConditionFamily.text, _all),
  textStartsWith('textStartsWith', 1, ConditionFamily.text, _filterCf),
  textEndsWith('textEndsWith', 1, ConditionFamily.text, _filterCf),
  textEq('textEq', 1, ConditionFamily.text, _all),
  textIsEmail('textIsEmail', 0, ConditionFamily.textPattern, _dvOnly),
  textIsUrl('textIsUrl', 0, ConditionFamily.textPattern, _dvOnly),
  dateEq('dateEq', 1, ConditionFamily.date, _all),
  dateBefore('dateBefore', 1, ConditionFamily.date, _all),
  dateAfter('dateAfter', 1, ConditionFamily.date, _all),
  dateOnOrBefore('dateOnOrBefore', 1, ConditionFamily.date, _dvOnly),
  dateOnOrAfter('dateOnOrAfter', 1, ConditionFamily.date, _dvOnly),
  dateBetween('dateBetween', 2, ConditionFamily.date, _dvOnly),
  dateNotBetween('dateNotBetween', 2, ConditionFamily.date, _dvOnly),
  dateIsValid('dateIsValid', 0, ConditionFamily.dateValidity, _dvOnly),
  numberGreater('numberGreater', 1, ConditionFamily.number, _all),
  numberGreaterEq('numberGreaterEq', 1, ConditionFamily.number, _all),
  numberLess('numberLess', 1, ConditionFamily.number, _all),
  numberLessEq('numberLessEq', 1, ConditionFamily.number, _all),
  numberEq('numberEq', 1, ConditionFamily.number, _all),
  numberNotEq('numberNotEq', 1, ConditionFamily.number, _all),
  numberBetween('numberBetween', 2, ConditionFamily.number, _all),
  numberNotBetween('numberNotBetween', 2, ConditionFamily.number, _all),
  customFormula('customFormula', 1, ConditionFamily.custom, _all);

  const ConditionType(this.id, this.arity, this.family, this.uses);

  /// JSON `type` value.
  final String id;

  /// Number of values the type takes.
  final int arity;

  /// Value semantics family.
  final ConditionFamily family;

  /// Features that offer the type.
  final Set<ConditionUse> uses;

  static final Map<String, ConditionType> _byId = {
    for (final t in values) t.id: t,
  };

  /// The type with JSON id [id], or null.
  static ConditionType? byId(String? id) => id == null ? null : _byId[id];

  /// Whether [use] offers this type.
  bool usableIn(ConditionUse use) => uses.contains(use);

  /// Whether the type accepts relative dates (`{"rel": …}`) as values.
  bool get acceptsRelativeDates => family == ConditionFamily.date;
}

/// Relative date values (06 §15.2): resolved in `Spreadsheet.timeZone`.
enum RelativeDate {
  today,
  tomorrow,
  yesterday,
  pastWeek,
  pastMonth,
  pastYear;

  static RelativeDate? byName(String? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// Label used in messages ("today", "the past week").
  String get label => switch (this) {
    today => 'today',
    tomorrow => 'tomorrow',
    yesterday => 'yesterday',
    pastWeek => 'the past week',
    pastMonth => 'the past month',
    pastYear => 'the past year',
  };
}

/// One entry of `Condition.values`.
sealed class ConditionValue {
  const ConditionValue();

  /// Parses `{"v": "100"}`, `{"v": "=…"}` or `{"rel": "pastWeek"}`. Malformed
  /// entries become an empty literal (the condition is then never satisfied).
  factory ConditionValue.fromJson(Object? json) {
    if (json is Map) {
      final rel = json['rel'];
      if (rel is String) {
        final r = RelativeDate.byName(rel);
        if (r != null) return ConditionRelativeDate(r);
      }
      final v = json['v'];
      if (v is String) return ConditionValue.text(v);
      if (v is num || v is bool) return ConditionLiteral(v.toString());
    } else if (json is String) {
      return ConditionValue.text(json);
    }
    return const ConditionLiteral('');
  }

  /// A literal, or a formula when [text] starts with `=` (stored form).
  factory ConditionValue.text(String text) =>
      text.length > 1 && text.startsWith('=')
      ? ConditionFormula(text)
      : ConditionLiteral(text);

  /// JSON map.
  Map<String, Object?> toJson();
}

/// A literal value as typed (parsed per locale when evaluated).
final class ConditionLiteral extends ConditionValue {
  /// Creates a literal.
  const ConditionLiteral(this.text);

  /// The literal text.
  final String text;

  @override
  Map<String, Object?> toJson() => {'v': text};

  @override
  bool operator ==(Object other) =>
      other is ConditionLiteral && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'ConditionLiteral($text)';
}

/// A formula value in stored-reference form, including the leading `=`.
final class ConditionFormula extends ConditionValue {
  /// Creates a formula value; [stored] starts with `=`.
  const ConditionFormula(this.stored);

  /// Stored formula text.
  final String stored;

  @override
  Map<String, Object?> toJson() => {'v': stored};

  @override
  bool operator ==(Object other) =>
      other is ConditionFormula && other.stored == stored;

  @override
  int get hashCode => stored.hashCode;

  @override
  String toString() => 'ConditionFormula($stored)';
}

/// A relative date (`{"rel": "pastWeek"}`).
final class ConditionRelativeDate extends ConditionValue {
  /// Creates a relative date value.
  const ConditionRelativeDate(this.date);

  /// The relative date.
  final RelativeDate date;

  @override
  Map<String, Object?> toJson() => {'rel': date.name};

  @override
  bool operator ==(Object other) =>
      other is ConditionRelativeDate && other.date == date;

  @override
  int get hashCode => date.hashCode;

  @override
  String toString() => 'ConditionRelativeDate(${date.name})';
}

/// The shared condition model of conditional formatting, data validation,
/// filters, filter views, slicers and pivot filters (06 §15.1, 07 §3.3):
/// `{"type": "numberGreater", "values": [{"v": "100"}]}`.
///
/// Subclasses group the types by value semantics; [Condition.of] picks the
/// right one for a [ConditionType].
sealed class Condition {
  const Condition(this.type, this.values);

  /// Creates the condition of [type] with [values].
  factory Condition.of(
    ConditionType type, [
    List<ConditionValue> values = const [],
  ]) {
    switch (type.family) {
      case ConditionFamily.emptiness:
        return EmptinessCondition(type);
      case ConditionFamily.text:
        return TextCondition(
          type,
          values.isEmpty ? const ConditionLiteral('') : values.first,
        );
      case ConditionFamily.textPattern:
        return TextPatternCondition(type);
      case ConditionFamily.date:
        return DateCondition(type, values);
      case ConditionFamily.dateValidity:
        return const DateValidCondition();
      case ConditionFamily.number:
        return NumberCondition(type, values);
      case ConditionFamily.custom:
        final v = values.isEmpty ? null : values.first;
        return CustomFormulaCondition(switch (v) {
          ConditionFormula(:final stored) => stored,
          ConditionLiteral(:final text) => text,
          _ => '',
        });
    }
  }

  /// Parses a JSON map or string; null when the type is unknown or the input
  /// is malformed.
  static Condition? tryParse(Object? json) {
    Object? m = json;
    if (m is String) {
      if (m.isEmpty) return null;
      try {
        m = jsonDecode(m);
      } on FormatException {
        return null;
      }
    }
    if (m is! Map) return null;
    final type = ConditionType.byId(m['type'] as String?);
    if (type == null) return null;
    final raw = m['values'];
    final values = <ConditionValue>[
      if (raw is List)
        for (final v in raw) ConditionValue.fromJson(v),
    ];
    return Condition.of(type, values);
  }

  /// The type.
  final ConditionType type;

  /// The values (length = [ConditionType.arity] for valid conditions).
  final List<ConditionValue> values;

  /// Whether a formula or a relative date is involved (re-evaluation after
  /// recalcs / at midnight).
  bool get isVolatile =>
      values.any((v) => v is ConditionFormula || v is ConditionRelativeDate) ||
      this is CustomFormulaCondition;

  /// Whether any value is a formula (or the condition is a custom formula).
  bool get usesFormulas =>
      this is CustomFormulaCondition ||
      values.any((v) => v is ConditionFormula);

  /// JSON map (`values` omitted for types without values).
  Map<String, Object?> toJson() => {
    'type': type.id,
    if (values.isNotEmpty) 'values': [for (final v in values) v.toJson()],
  };

  /// JSON string.
  String encode() => jsonEncode(toJson());

  /// The first validation error for the editor (07 §1.3 inline messages), or null.
  String? validate() {
    if (values.length < type.arity) {
      return type.arity == 2
          ? 'Please enter two values.'
          : 'Please enter a value.';
    }
    for (var i = 0; i < type.arity; i++) {
      final v = values[i];
      switch (v) {
        case ConditionLiteral(:final text):
          if (text.trim().isEmpty) return 'Please enter a value.';
        case ConditionFormula(:final stored):
          if (stored.trim().length <= 1) return 'Please enter a formula.';
        case ConditionRelativeDate():
          if (!type.acceptsRelativeDates) return 'Please enter a value.';
      }
    }
    if (this case CustomFormulaCondition(
      :final formula,
    ) when !formula.startsWith('=')) {
      return 'Custom formulas must start with "=".';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Condition &&
      other.type == type &&
      other.values.length == values.length &&
      _valuesEqual(other.values, values);

  static bool _valuesEqual(List<ConditionValue> a, List<ConditionValue> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(type, Object.hashAll(values));

  @override
  String toString() => 'Condition(${encode()})';
}

/// `blank` / `notBlank`.
final class EmptinessCondition extends Condition {
  /// Creates an emptiness condition.
  const EmptinessCondition(ConditionType type) : super(type, const []);
}

/// `textContains`, `textNotContains`, `textStartsWith`, `textEndsWith`, `textEq`.
final class TextCondition extends Condition {
  /// Creates a text condition.
  TextCondition(ConditionType type, ConditionValue value)
    : super(type, [value]);

  /// The compared value.
  ConditionValue get value => values.first;
}

/// `textIsEmail` / `textIsUrl`.
final class TextPatternCondition extends Condition {
  /// Creates a text pattern condition.
  const TextPatternCondition(ConditionType type) : super(type, const []);
}

/// Date comparisons: `dateEq`, `dateBefore`, `dateAfter`, `dateOnOrBefore`,
/// `dateOnOrAfter`, `dateBetween`, `dateNotBetween`.
final class DateCondition extends Condition {
  /// Creates a date condition.
  const DateCondition(super.type, super.values);
}

/// `dateIsValid`.
final class DateValidCondition extends Condition {
  /// Creates the condition.
  const DateValidCondition() : super(ConditionType.dateIsValid, const []);
}

/// Number comparisons (`numberGreater` … `numberNotBetween`).
final class NumberCondition extends Condition {
  /// Creates a number condition.
  const NumberCondition(super.type, super.values);
}

/// `customFormula`: truthy result passes (06 §15.3).
final class CustomFormulaCondition extends Condition {
  /// Creates a custom formula condition; [formula] is in stored form with `=`.
  CustomFormulaCondition(this.formula)
    : super(ConditionType.customFormula, [ConditionValue.text(formula)]);

  /// The stored formula (with the leading `=`).
  final String formula;
}
