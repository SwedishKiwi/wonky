import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../formatting/formula_field.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The label of a filter condition type (Google wording, 07 §3.3).
String conditionTypeLabel(SheetsLocalizations l, ConditionType t) =>
    switch (t) {
      ConditionType.blank => l.condBlank,
      ConditionType.notBlank => l.condNotBlank,
      ConditionType.textContains => l.condTextContains,
      ConditionType.textNotContains => l.condTextNotContains,
      ConditionType.textStartsWith => l.condTextStartsWith,
      ConditionType.textEndsWith => l.condTextEndsWith,
      ConditionType.textEq => l.condTextEq,
      ConditionType.dateEq => l.condDateEq,
      ConditionType.dateBefore => l.condDateBefore,
      ConditionType.dateAfter => l.condDateAfter,
      ConditionType.numberGreater => l.condNumberGreater,
      ConditionType.numberGreaterEq => l.condNumberGreaterEq,
      ConditionType.numberLess => l.condNumberLess,
      ConditionType.numberLessEq => l.condNumberLessEq,
      ConditionType.numberEq => l.condNumberEq,
      ConditionType.numberNotEq => l.condNumberNotEq,
      ConditionType.numberBetween => l.condNumberBetween,
      ConditionType.numberNotBetween => l.condNumberNotBetween,
      ConditionType.customFormula => l.condCustomFormula,
      _ => t.id,
    };

String _relLabel(SheetsLocalizations l, RelativeDate? r) => switch (r) {
  null => l.condExactDate,
  RelativeDate.today => l.condToday,
  RelativeDate.tomorrow => l.condTomorrow,
  RelativeDate.yesterday => l.condYesterday,
  RelativeDate.pastWeek => l.condPastWeek,
  RelativeDate.pastMonth => l.condPastMonth,
  RelativeDate.pastYear => l.condPastYear,
};

/// The condition editor of the filter popover (07 §1.3 `ConditionEditor`,
/// filter subset): a type select, then 0–2 value inputs; date types offer
/// relative dates; values starting with `=` are formulas relative to the
/// first data cell of the column ([anchorRow], [anchorCol]).
class FilterConditionEditor extends StatefulWidget {
  const FilterConditionEditor({
    super.key,
    required this.editor,
    required this.sheetId,
    required this.anchorRow,
    required this.anchorCol,
    required this.initial,
    required this.onChanged,
  });

  final SheetEditorController editor;
  final String sheetId;
  final int anchorRow;
  final int anchorCol;
  final Condition? initial;
  final ValueChanged<Condition?> onChanged;

  @override
  State<FilterConditionEditor> createState() => _FilterConditionEditorState();
}

class _FilterConditionEditorState extends State<FilterConditionEditor> {
  static final _types = [
    for (final t in ConditionType.values)
      if (t.usableIn(ConditionUse.filter)) t,
  ];

  ConditionType? _type;
  RelativeDate? _rel;
  final _v1 = TextEditingController();
  final _v2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    if (c != null) {
      _type = c.type;
      final vals = c.values;
      if (vals.isNotEmpty) _load(vals[0], _v1);
      if (vals.length > 1) _load(vals[1], _v2);
    }
  }

  void _load(ConditionValue v, TextEditingController t) {
    switch (v) {
      case ConditionLiteral(:final text):
        t.text = text;
      case ConditionFormula(:final stored):
        t.text = widget.editor.hooks.toA1(
          stored,
          sheetId: widget.sheetId,
          row: widget.anchorRow,
          col: widget.anchorCol,
          locale: widget.editor.locale,
        );
      case ConditionRelativeDate(:final date):
        _rel = date;
    }
  }

  @override
  void dispose() {
    _v1.dispose();
    _v2.dispose();
    super.dispose();
  }

  ConditionValue _value(String text) {
    final t = text.trim();
    if (t.length > 1 && t.startsWith('=')) {
      try {
        final stored = widget.editor.hooks.toStored(
          t,
          sheetId: widget.sheetId,
          row: widget.anchorRow,
          col: widget.anchorCol,
          locale: widget.editor.locale,
        );
        return ConditionFormula(stored.startsWith('=') ? stored : '=$stored');
      } catch (_) {
        return ConditionLiteral(t);
      }
    }
    return ConditionLiteral(t);
  }

  void _emit() {
    final t = _type;
    if (t == null) {
      widget.onChanged(null);
      return;
    }
    final values = <ConditionValue>[];
    if (t.arity >= 1) {
      if (t.acceptsRelativeDates && _rel != null) {
        values.add(ConditionRelativeDate(_rel!));
      } else {
        if (_v1.text.trim().isEmpty) {
          widget.onChanged(null);
          return;
        }
        values.add(_value(_v1.text));
      }
    }
    if (t.arity >= 2) {
      if (_v2.text.trim().isEmpty) {
        widget.onChanged(null);
        return;
      }
      values.add(_value(_v2.text));
    }
    widget.onChanged(Condition.of(t, values));
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final t = _type;
    String label(String id) {
      if (id == 'none') return l.condNone;
      final ct = ConditionType.byId(id);
      return ct == null ? id : conditionTypeLabel(l, ct);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadSelect<String>(
          key: const ValueKey<String>('filter.condition.type'),
          initialValue: t?.id ?? 'none',
          maxHeight: 280,
          options: [
            ShadOption(value: 'none', child: Text(l.condNone)),
            for (final ct in _types)
              ShadOption(value: ct.id, child: Text(conditionTypeLabel(l, ct))),
          ],
          selectedOptionBuilder: (context, v) =>
              Text(label(v), overflow: TextOverflow.ellipsis),
          onChanged: (v) {
            setState(() => _type = v == null ? null : ConditionType.byId(v));
            _emit();
          },
        ),
        if (t != null && t.arity >= 1) ...[
          const SizedBox(height: 6),
          if (t.acceptsRelativeDates) ...[
            ShadSelect<String>(
              key: const ValueKey<String>('filter.condition.relative'),
              initialValue: _rel?.name ?? 'exact',
              options: [
                ShadOption(value: 'exact', child: Text(l.condExactDate)),
                for (final r in RelativeDate.values)
                  ShadOption(value: r.name, child: Text(_relLabel(l, r))),
              ],
              selectedOptionBuilder: (context, v) =>
                  Text(_relLabel(l, RelativeDate.byName(v))),
              onChanged: (v) {
                setState(() => _rel = RelativeDate.byName(v));
                _emit();
              },
            ),
            const SizedBox(height: 6),
          ],
          if (t == ConditionType.customFormula)
            FormulaField(
              keyName: 'filter.condition.value1',
              editor: widget.editor,
              value: _v1.text,
              placeholder: l.condFormulaPlaceholder,
              onChanged: (v) {
                _v1.text = v;
                _emit();
              },
            )
          else if (!t.acceptsRelativeDates || _rel == null)
            ShadInput(
              key: const ValueKey<String>('filter.condition.value1'),
              controller: _v1,
              placeholder: Text(
                t == ConditionType.customFormula
                    ? l.condFormulaPlaceholder
                    : l.condValuePlaceholder,
              ),
              onChanged: (_) => _emit(),
            ),
          if (t.arity >= 2) ...[
            const SizedBox(height: 6),
            ShadInput(
              key: const ValueKey<String>('filter.condition.value2'),
              controller: _v2,
              placeholder: Text(l.condValuePlaceholder),
              onChanged: (_) => _emit(),
            ),
          ],
        ],
      ],
    );
  }
}
