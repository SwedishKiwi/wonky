import '../../addressing/column_letters.dart';
import '../../content/cell_content.dart';
import '../../engine_bridge/formula_hooks.dart';
import '../../format/attributes.dart';
import '../../formula/model/workbook_view.dart';
import '../../input/input_parser.dart';
import '../../model/records.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';
import '../conditions/condition_evaluator.dart';
import '../conditions/display_text.dart';
import '../conditions/relative_dates.dart';
import 'checkbox_values.dart';
import 'dv_criteria.dart';
import 'list_source.dart';
import 'validation_engine.dart';

/// What happens to typed input in a validated cell (07 §6.6).
enum DvInputVerdict {
  /// No rule, or the value satisfies the rule.
  accept,

  /// Invalid under a warning rule: committed and marked invalid.
  warn,

  /// Invalid under a strict rule: rejected with the "Invalid entry" dialog.
  reject,
}

/// Result of [DvEvaluator.checkValue] / [DvEvaluator.checkInput].
final class DvInputCheck {
  /// Creates a result.
  const DvInputCheck(this.verdict, {this.ruleId, this.message});

  /// Accepted input.
  static const DvInputCheck accepted = DvInputCheck(DvInputVerdict.accept);

  /// The verdict.
  final DvInputVerdict verdict;

  /// The effective rule, when the input is invalid.
  final String? ruleId;

  /// Help text of the rule, or the default message of 07 §6.2.
  final String? message;

  /// Whether the input is committed (valid or warning).
  bool get isCommitted => verdict != DvInputVerdict.reject;

  /// Whether the input violates the rule (warning or rejected).
  bool get isInvalid => verdict != DvInputVerdict.accept;

  /// Text of the reject dialog (07 §6.6) for the cell [cellA1] (`B4`).
  String dialogMessage(String cellA1) =>
      'The data you entered in cell $cellA1 violates the data validation '
      'rules set on this cell.${message == null ? '' : ' $message'}';

  @override
  bool operator ==(Object other) =>
      other is DvInputCheck &&
      other.verdict == verdict &&
      other.ruleId == ruleId &&
      other.message == message;

  @override
  int get hashCode => Object.hash(verdict, ruleId, message);

  @override
  String toString() =>
      'DvInputCheck(${verdict.name}${message == null ? '' : ': $message'})';
}

/// One item of a dropdown (07 §6.7): the text and its chip colors.
final class DvItem {
  /// Creates an item.
  const DvItem(this.value, {this.colors = const DvChipColors()});

  /// The item text (written as typed input when picked).
  final String value;

  /// Chip colors (empty = no color).
  final DvChipColors colors;

  @override
  bool operator ==(Object other) =>
      other is DvItem && other.value == value && other.colors == colors;

  @override
  int get hashCode => Object.hash(value, colors);

  @override
  String toString() => 'DvItem($value)';
}

final class _DvState {
  _DvState(this.record, this.generation, this.rule);

  final DvRuleRecord record;
  final (int, int) generation;
  final DvRule rule;
  CompiledCondition? compiled;
  List<DvItem>? items;
}

/// Data validation of cells for the app and the server (07 §6.5–6.7):
/// effective rules, invalid markers, typed-input enforcement, dropdown items
/// and checkbox values.
///
/// Parsed rules, compiled conditions and `oneOfRange` items are cached per
/// rule; call [invalidate] after rule edits, recalc batches touching rule
/// precedents or source-range changes (and at midnight for relative dates).
final class DvEvaluator {
  /// Creates the evaluator over [model]; [values] supplies computed values
  /// (formula results included) and [display] the display texts.
  DvEvaluator(
    this.model,
    this.values,
    this.display, {
    FormulaHooks? hooks,
    SpreadsheetDates? dates,
    String? locale,
    this.engine = const ValidationEngine(),
  }) : conditions = ConditionEvaluator(
         locale: locale ?? model.spreadsheet.locale,
         dates: dates ?? SpreadsheetDates(timeZone: model.spreadsheet.timeZone),
         hooks: hooks,
       ),
       reader = CellTextReader(values, display);

  /// The workbook.
  final WorkbookModel model;

  /// Computed values.
  final CellSource values;

  /// Display formatting.
  final DisplayTextProvider display;

  /// The validation engine.
  final ValidationEngine engine;

  /// The shared condition evaluator (locale, dates, formula hooks).
  final ConditionEvaluator conditions;

  /// Value/display reader over [values] and [display].
  final CellTextReader reader;

  final Map<String, _DvState> _states = {};

  /// Drops cached rules (all, or only [ruleId]).
  void invalidate({String? ruleId}) {
    if (ruleId == null) {
      _states.clear();
    } else {
      _states.remove(ruleId);
    }
  }

  _DvState? _state(SheetModel sheet, DvRuleRecord record) {
    final gen = (sheet.rows.generation, sheet.columns.generation);
    final cached = _states[record.id];
    if (cached != null &&
        identical(cached.record, record) &&
        cached.generation == gen) {
      return cached;
    }
    final rule = DvRule.fromRecord(record, sheet);
    if (rule == null) {
      _states.remove(record.id);
      return null;
    }
    return _states[record.id] = _DvState(record, gen, rule);
  }

  DvDraftPreview? _draft;

  /// The panel's draft rule previewed on the grid (null: none).
  DvDraftPreview? get draft => _draft;
  set draft(DvDraftPreview? d) {
    final old = _draft;
    if (old != null) _states.remove(old.record.id);
    if (d != null) _states.remove(d.record.id);
    _draft = d;
  }

  _DvState? _stateAt(String sheetId, int row, int col) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return null;
    final record = DvRuleResolver.effectiveRuleAt(
      sheet,
      row,
      col,
      draft: _draft,
    );
    if (record == null) return null;
    return _state(sheet, record);
  }

  /// The effective rule at the cell (07 §6.4), or null.
  DvRule? ruleAt(String sheetId, int row, int col) =>
      _stateAt(sheetId, row, col)?.rule;

  ValidationContext _context(
    _DvState st,
    String sheetId,
    int row,
    int col,
    String? numberFormat,
  ) {
    final rule = st.rule;
    final criteria = rule.criteria;
    return ValidationContext(
      sheetId: sheetId,
      row: row,
      col: col,
      conditions: conditions,
      numberFormat: numberFormat,
      rangeItems: (_) => [for (final i in _items(sheetId, st)) i.value],
      compiled: criteria is DvConditionCriteria
          ? st.compiled ??= conditions.compile(
              criteria.condition,
              sheetId: sheetId,
              anchorRow: rule.anchor.row,
              anchorCol: rule.anchor.col,
            )
          : null,
    );
  }

  /// Validates the cell's computed value (invalid markers, 07 §6.5). Cells
  /// without a rule and empty cells are valid.
  ValidationResult validateCell(String sheetId, int row, int col) {
    final st = _stateAt(sheetId, row, col);
    if (st == null) return ValidationResult.ok;
    final value = reader.valueAt(sheetId, row, col);
    if (value.isBlank()) return ValidationResult.ok;
    final format = reader.numberFormatAt(sheetId, row, col);
    return engine.validate(
      value,
      display.displayText(value, format),
      st.rule,
      _context(st, sheetId, row, col, format),
    );
  }

  /// Checks [value] about to be written into the cell by typing, the formula
  /// bar or `sheets.cell.setInput` (07 §6.6). [numberFormat] is the format
  /// the value will be displayed with (default: the cell's explicit format).
  DvInputCheck checkValue(
    String sheetId,
    int row,
    int col,
    CellValue value, {
    String? numberFormat,
  }) {
    final st = _stateAt(sheetId, row, col);
    if (st == null || value.isBlank()) return DvInputCheck.accepted;
    final format = numberFormat ?? _explicitFormat(sheetId, row, col);
    final r = engine.validate(
      value,
      display.displayText(value, format),
      st.rule,
      _context(st, sheetId, row, col, format),
    );
    if (r.valid) return DvInputCheck.accepted;
    return DvInputCheck(
      st.rule.strict ? DvInputVerdict.reject : DvInputVerdict.warn,
      ruleId: st.rule.id,
      message: r.message,
    );
  }

  /// Checks parsed typed input (`InputParser.parse`). Clearing is always
  /// accepted. Formulas are checked with [formulaResult] (e.g. a detached
  /// evaluation); without it they are accepted and validated by the invalid
  /// markers after recalculation.
  DvInputCheck checkInput(
    String sheetId,
    int row,
    int col,
    ParsedInput input, {
    CellValue? formulaResult,
  }) {
    if (input.isClear) return DvInputCheck.accepted;
    final explicit = _explicitFormat(sheetId, row, col);
    final format = explicit ?? input.autoNumberFormat;
    final CellValue value;
    if (input.isFormula) {
      if (formulaResult == null) return DvInputCheck.accepted;
      value = formulaResult;
    } else {
      value = input.content!.literalValue;
    }
    return checkValue(sheetId, row, col, value, numberFormat: format);
  }

  String? _explicitFormat(String sheetId, int row, int col) =>
      model.explicitFormatChain(sheetId, row, col)[FormatAttr.numberFormat]
          as String?;

  List<DvItem> _items(String sheetId, _DvState st) {
    final cached = st.items;
    if (cached != null) return cached;
    final sheet = model.sheet(sheetId);
    final items = switch (st.rule.criteria) {
      final DvListCriteria c => [
        for (final o in c.options) DvItem(o.value, colors: o.colors),
      ],
      final DvRangeCriteria c => _rangeItems(c),
      _ => const <DvItem>[],
    };
    if (sheet != null) st.items = items;
    return items;
  }

  List<DvItem> _rangeItems(DvRangeCriteria c) {
    final source = model.sheet(c.range.sheetId);
    if (source == null) return const [];
    return [
      for (final v in ListSource.rangeItems(c, source, reader))
        DvItem(v, colors: c.colors[v] ?? const DvChipColors()),
    ];
  }

  /// Items of the dropdown at the cell (empty when the cell has no dropdown
  /// rule). `oneOfRange` items are the distinct display values of the source
  /// range (≤ 1,000, 07 §6.5).
  List<DvItem> dropdownItems(String sheetId, int row, int col) {
    final st = _stateAt(sheetId, row, col);
    if (st == null || !st.rule.criteria.isDropdown) return const [];
    return _items(sheetId, st);
  }

  /// The chip colors of the cell's current value, or null (no dropdown rule
  /// or the value is not an item).
  DvChipColors? chipColorsAt(String sheetId, int row, int col) {
    final st = _stateAt(sheetId, row, col);
    if (st == null || !st.rule.criteria.isDropdown) return null;
    final text = reader.displayTextAt(sheetId, row, col);
    for (final i in _items(sheetId, st)) {
      if (i.value == text) return i.colors;
    }
    return null;
  }

  /// The checkbox values of the cell's rule, or null when it has no
  /// checkbox rule.
  CheckboxValues? checkboxAt(String sheetId, int row, int col) {
    final criteria = ruleAt(sheetId, row, col)?.criteria;
    if (criteria is! DvCheckboxCriteria) return null;
    return CheckboxValues.of(criteria, locale: conditions.locale);
  }

  /// Checkbox state of the cell: true checked, false unchecked, null when
  /// the cell has no checkbox rule or holds neither value.
  bool? checkboxStateAt(String sheetId, int row, int col) =>
      checkboxAt(sheetId, row, col)?.stateOf(reader.valueAt(sheetId, row, col));

  /// The A1 address of a cell (`B4`) for [DvInputCheck.dialogMessage].
  static String cellA1(int row, int col) =>
      '${ColumnLetters.fromIndex(col)}${row + 1}';
}
