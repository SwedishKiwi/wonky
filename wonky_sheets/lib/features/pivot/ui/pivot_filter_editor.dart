import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../../l10n/sheets_l10n.dart';
import 'pivot_widgets.dart';

/// Label of a filter condition type.
String pivotConditionLabel(SheetsLocalizations l, ConditionType t) =>
    switch (t) {
      ConditionType.blank => l.pivotCondBlank,
      ConditionType.notBlank => l.pivotCondNotBlank,
      ConditionType.textContains => l.pivotCondTextContains,
      ConditionType.textNotContains => l.pivotCondTextNotContains,
      ConditionType.textStartsWith => l.pivotCondTextStartsWith,
      ConditionType.textEndsWith => l.pivotCondTextEndsWith,
      ConditionType.textEq => l.pivotCondTextEq,
      ConditionType.dateEq => l.pivotCondDateEq,
      ConditionType.dateBefore => l.pivotCondDateBefore,
      ConditionType.dateAfter => l.pivotCondDateAfter,
      ConditionType.numberGreater => l.pivotCondNumberGreater,
      ConditionType.numberGreaterEq => l.pivotCondNumberGreaterEq,
      ConditionType.numberLess => l.pivotCondNumberLess,
      ConditionType.numberLessEq => l.pivotCondNumberLessEq,
      ConditionType.numberEq => l.pivotCondNumberEq,
      ConditionType.numberNotEq => l.pivotCondNumberNotEq,
      ConditionType.numberBetween => l.pivotCondNumberBetween,
      ConditionType.numberNotBetween => l.pivotCondNumberNotBetween,
      ConditionType.customFormula => l.pivotCondCustomFormula,
      _ => t.id,
    };

/// Condition types offered by pivot filters (07 §3.3 filter column).
final List<ConditionType> pivotFilterConditionTypes = [
  for (final t in ConditionType.values)
    if (t.usableIn(ConditionUse.filter)) t,
];

/// Formula and color support of a pivot filter: converts `=…` values
/// between A1 (shown) and stored form relative to the field's first data
/// cell, and lists the colors present in the field's column.
class PivotFilterSupport {
  const PivotFilterSupport({
    required this.toStored,
    required this.toA1,
    this.fillColors = const [],
    this.textColors = const [],
  });

  final String Function(String a1) toStored;
  final String Function(String stored) toA1;

  /// Distinct fill / text colors (`#RRGGBB`) of the field's cells.
  final List<String> fillColors;
  final List<String> textColors;
}

/// Distinct display values of a source column with their counts, blanks
/// first, then in natural order.
List<(String, int)> pivotDistinctValues(SourceColumn column) {
  final counts = <String, int>{};
  for (var i = 0; i < column.values.length; i++) {
    final t = column.displayText(i);
    counts[t] = (counts[t] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      if (a.isEmpty) return -1;
      if (b.isEmpty) return 1;
      final na = num.tryParse(a);
      final nb = num.tryParse(b);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return [for (final k in keys) (k, counts[k]!)];
}

/// The filter editor of a pivot *Filters* card (07 §7.3 → the filter
/// column popover of §3.5): *Filter by condition* and *Filter by values*
/// (search, Select all · Clear, checkboxes with counts). [onApply] gets the
/// new criteria.
class PivotFilterEditor extends StatefulWidget {
  const PivotFilterEditor({
    super.key,
    required this.criteria,
    required this.values,
    required this.onApply,
    required this.onCancel,
    this.support,
  });

  /// Custom formulas and color filters (null: values and literal
  /// conditions only).
  final PivotFilterSupport? support;

  final ColumnCriteria criteria;

  /// Distinct display values with counts.
  final List<(String, int)> values;
  final ValueChanged<ColumnCriteria> onApply;
  final VoidCallback onCancel;

  /// Values listed per search page.
  static const pageSize = 1000;

  @override
  State<PivotFilterEditor> createState() => _PivotFilterEditorState();
}

class _PivotFilterEditorState extends State<PivotFilterEditor> {
  late final Set<String> _hidden = {...widget.criteria.hiddenValues};
  late ConditionType? _type = widget.criteria.condition?.type;
  late String _fill = widget.criteria.visibleBackgroundColor ?? '';
  late String _textColor = widget.criteria.visibleForegroundColor ?? '';
  late final TextEditingController _v1 = TextEditingController(
    text: _valueText(0),
  );
  late final TextEditingController _v2 = TextEditingController(
    text: _valueText(1),
  );
  final _search = TextEditingController();

  String _valueText(int i) {
    final c = widget.criteria.condition;
    if (c == null || c.values.length <= i) return '';
    return switch (c.values[i]) {
      ConditionLiteral(:final text) => text,
      ConditionFormula(:final stored) => widget.support?.toA1(stored) ?? stored,
      _ => '',
    };
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _v1.dispose();
    _v2.dispose();
    _search.dispose();
    super.dispose();
  }

  void _apply() {
    final t = _type;
    Condition? condition;
    ConditionValue value(String text) {
      final t = text.trim();
      final support = widget.support;
      if (t.length > 1 && t.startsWith('=') && support != null) {
        try {
          return ConditionFormula(support.toStored(t));
        } on Object {
          return ConditionLiteral(t);
        }
      }
      return ConditionValue.text(t);
    }

    if (t != null) {
      condition = Condition.of(t, [
        if (t.arity >= 1) value(_v1.text),
        if (t.arity >= 2) value(_v2.text),
      ]);
    }
    widget.onApply(
      ColumnCriteria(
        hiddenValues: _hidden,
        condition: condition,
        visibleBackgroundColor: _fill.isEmpty ? null : _fill,
        visibleForegroundColor: _textColor.isEmpty ? null : _textColor,
      ),
    );
  }

  /// *Filter by color* (07 §3.2): fill and text colors present in the
  /// field, or null when the field has none.
  Widget? _colorSection(BuildContext context, TextStyle heading) {
    final support = widget.support;
    if (support == null) return null;
    final fills = {...support.fillColors, if (_fill.isNotEmpty) _fill};
    final texts = {
      ...support.textColors,
      if (_textColor.isNotEmpty) _textColor,
    };
    if (fills.isEmpty && texts.isEmpty) return null;
    final l = sheetsL10n(context);
    Widget select(
      String key,
      String label,
      Set<String> colors,
      String value,
      ValueChanged<String> onChanged,
    ) => Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: ShadTheme.of(context).textTheme.small),
        ),
        Expanded(
          child: PivotSelect<String>(
            key: ValueKey<String>(key),
            value: value,
            minWidth: 160,
            options: {'': l.pivotNoColorFilter, for (final c in colors) c: c},
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
        const SizedBox(width: 6),
        _Swatch(color: value),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.pivotFilterByColor, style: heading),
        const SizedBox(height: 6),
        if (fills.isNotEmpty)
          select(
            'pivot.filter.fill',
            l.pivotFillColor,
            fills,
            _fill,
            (v) => _fill = v,
          ),
        if (fills.isNotEmpty && texts.isNotEmpty) const SizedBox(height: 4),
        if (texts.isNotEmpty)
          select(
            'pivot.filter.textColor',
            l.pivotTextColor,
            texts,
            _textColor,
            (v) => _textColor = v,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final q = _search.text.trim().toLowerCase();
    final matches = [
      for (final v in widget.values)
        if (q.isEmpty ||
            (v.$1.isEmpty ? l.pivotBlanks : v.$1).toLowerCase().contains(q))
          v,
    ];
    final shown = matches.take(PivotFilterEditor.pageSize).toList();
    final t = _type;
    final heading = theme.textTheme.small.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.pivotFilterByCondition, style: heading),
          const SizedBox(height: 6),
          PivotSelect<String>(
            key: const ValueKey<String>('pivot.filter.condition'),
            value: t?.id ?? '',
            minWidth: 260,
            options: {
              '': l.pivotConditionNone,
              for (final c in pivotFilterConditionTypes)
                if (c != ConditionType.customFormula || widget.support != null)
                  c.id: pivotConditionLabel(l, c),
            },
            onChanged: (id) => setState(
              () => _type = ConditionType.byId(id.isEmpty ? null : id),
            ),
          ),
          if (t != null && t.arity >= 1) ...[
            const SizedBox(height: 6),
            ShadInput(
              key: const ValueKey<String>('pivot.filter.value1'),
              controller: _v1,
              placeholder: Text(
                t == ConditionType.customFormula
                    ? l.pivotFormulaValue
                    : l.pivotConditionValue,
              ),
            ),
          ],
          if (t != null && t.arity >= 2) ...[
            const SizedBox(height: 4),
            Text(l.pivotCondAnd, style: theme.textTheme.muted),
            const SizedBox(height: 4),
            ShadInput(
              key: const ValueKey<String>('pivot.filter.value2'),
              controller: _v2,
              placeholder: Text(l.pivotConditionValue),
            ),
          ],
          if (_colorSection(context, heading) case final colors?) ...[
            const SizedBox(height: 12),
            colors,
          ],
          const SizedBox(height: 12),
          Text(l.pivotFilterByValues, style: heading),
          const SizedBox(height: 6),
          ShadInput(
            key: const ValueKey<String>('pivot.filter.search'),
            controller: _search,
            placeholder: Text(l.pivotSearchFields),
            leading: const Icon(LucideIcons.search, size: 14),
          ),
          Row(
            children: [
              ShadButton.link(
                size: ShadButtonSize.sm,
                padding: EdgeInsets.zero,
                onPressed: () => setState(() {
                  for (final (v, _) in matches) {
                    _hidden.remove(v);
                  }
                }),
                child: Text(l.pivotSelectAll),
              ),
              const Text(' · '),
              ShadButton.link(
                size: ShadButtonSize.sm,
                padding: EdgeInsets.zero,
                onPressed: () => setState(() {
                  for (final (v, _) in matches) {
                    _hidden.add(v);
                  }
                }),
                child: Text(l.pivotClearAll),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final (v, n) = shown[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ShadCheckbox(
                    key: ValueKey<String>('pivot.filter.value.$i'),
                    value: !_hidden.contains(v),
                    onChanged: (on) => setState(() {
                      if (on) {
                        _hidden.remove(v);
                      } else {
                        _hidden.add(v);
                      }
                    }),
                    label: Text(
                      '${v.isEmpty ? l.pivotBlanks : v}  ($n)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
          if (matches.length > shown.length)
            Text(
              l.pivotFilterTooMany(shown.length, matches.length),
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: widget.onCancel,
                child: Text(l.pivotCancel),
              ),
              const SizedBox(width: 6),
              ShadButton(
                key: const ValueKey<String>('pivot.filter.apply'),
                size: ShadButtonSize.sm,
                onPressed: _apply,
                child: Text(l.pivotApply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small color dot (the chosen filter color).
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final String color;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    final v = int.tryParse(
      color.startsWith('#') ? color.substring(1) : color,
      radix: 16,
    );
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: v == null ? null : Color(0xFF000000 | v),
        shape: BoxShape.circle,
        border: Border.all(color: cs.border),
      ),
    );
  }
}
