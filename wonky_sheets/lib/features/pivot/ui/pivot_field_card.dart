import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/sheets_l10n.dart';
import '../pivot_formula_text.dart';
import '../pivot_spec_edit.dart';
import 'pivot_dialogs.dart';
import 'pivot_filter_editor.dart';
import 'pivot_widgets.dart';

/// What a card is dragged as.
@immutable
class PivotFieldDrag {
  const PivotFieldDrag(this.area, this.index);
  final PivotArea area;
  final int index;
}

/// Everything the editor cards need: the spec, the source fields, the
/// computed result (value names, filter values) and the commit callbacks.
class PivotCardContext {
  PivotCardContext({
    required this.spec,
    required this.fields,
    required this.result,
    required this.enabled,
    required this.commit,
    required this.group,
    required this.formulas,
    this.filterSupport,
  });

  /// Formula values and colors of a filter on [SourceColumn] (null: none).
  final PivotFilterSupport? Function(SourceColumn column)? filterSupport;

  final PivotSpec spec;
  final List<PivotSourceField> fields;
  final PivotResult? result;
  final bool enabled;

  /// Commits a new spec (`sheets.pivot.update`, one undo step).
  final ValueChanged<PivotSpec> commit;

  /// Sets the grouping of a Rows/Columns field (`sheets.pivot.createGroup`).
  final void Function(String colId, PivotGrouping? group) group;

  /// Converts calculated field formulas.
  final PivotFormulaText formulas;

  PivotSourceField? field(String? colId) {
    if (colId == null) return null;
    for (final f in fields) {
      if (f.colId == colId) return f;
    }
    return null;
  }

  /// The display name of value [index].
  String valueName(int index) {
    final r = result;
    if (r != null) {
      final i = r.valueIndexOfSpec(index);
      if (i >= 0) return r.valueFields[i].name;
    }
    final v = spec.values[index];
    var calc = 0;
    for (var k = 0; k <= index; k++) {
      if (spec.values[k].isCalculated) calc++;
    }
    return v.displayName(field(v.source)?.header, calculatedIndex: calc);
  }
}

/// Label of an area.
String pivotAreaLabel(SheetsLocalizations l, PivotArea a) => switch (a) {
  PivotArea.row => l.pivotRows,
  PivotArea.column => l.pivotColumns,
  PivotArea.value => l.pivotValues,
  PivotArea.filter => l.pivotFilters,
};

/// Label of a date grouping unit (07 §7.7).
String pivotDateUnitLabel(SheetsLocalizations l, PivotDateUnit u) =>
    switch (u) {
      PivotDateUnit.second => l.pivotDateSecond,
      PivotDateUnit.minute => l.pivotDateMinute,
      PivotDateUnit.hour => l.pivotDateHour,
      PivotDateUnit.hourMinute => l.pivotDateHourMinute,
      PivotDateUnit.hourMinuteAmPm => l.pivotDateHourMinuteAmPm,
      PivotDateUnit.dayOfWeek => l.pivotDateDayOfWeek,
      PivotDateUnit.dayOfYear => l.pivotDateDayOfYear,
      PivotDateUnit.dayOfMonth => l.pivotDateDayOfMonth,
      PivotDateUnit.dayMonth => l.pivotDateDayMonth,
      PivotDateUnit.month => l.pivotDateMonth,
      PivotDateUnit.quarter => l.pivotDateQuarter,
      PivotDateUnit.year => l.pivotDateYear,
      PivotDateUnit.yearMonth => l.pivotDateYearMonth,
      PivotDateUnit.yearQuarter => l.pivotDateYearQuarter,
      PivotDateUnit.yearMonthDay => l.pivotDateYearMonthDay,
    };

/// Label of *Summarize by*.
String pivotSummarizeLabel(SheetsLocalizations l, PivotSummarize s) =>
    s == PivotSummarize.custom ? l.pivotSummarizeCustom : s.label;

/// One field of the pivot editor (07 §7.3 `PivotFieldCard`): drag handle,
/// name, ⋮ menu (move, grouping, rename, remove), ✕ and the options of its
/// area.
class PivotFieldCard extends StatelessWidget {
  const PivotFieldCard({
    super.key,
    required this.ctx,
    required this.area,
    required this.index,
  });

  final PivotCardContext ctx;
  final PivotArea area;
  final int index;

  PivotSpec get spec => ctx.spec;

  String? get _source => spec.sourceOf(area, index);

  bool get _calculated =>
      area == PivotArea.value && spec.values[index].isCalculated;

  String _title(SheetsLocalizations l) {
    if (area == PivotArea.value) return ctx.valueName(index);
    final f = ctx.field(_source);
    if (f != null) {
      if (area.isGroup) {
        final g = area == PivotArea.row
            ? spec.rows[index]
            : spec.columns[index];
        if (g.label != null && g.label!.isNotEmpty) return g.label!;
      }
      return f.header;
    }
    return _source ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final title = _title(l);
    final missing = !_calculated && ctx.field(_source) == null;
    final header = Row(
      children: [
        _handle(context, l, title),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        if (missing)
          ShadTooltip(
            builder: (_) => Text(l.pivotFieldMissing),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                LucideIcons.triangleAlert,
                key: const ValueKey<String>('pivot.card.missing'),
                size: 14,
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
        _menu(context, l, title),
        ShadIconButton.ghost(
          key: ValueKey<String>('pivot.card.remove.${area.name}.$index'),
          width: 26,
          height: 26,
          iconSize: 14,
          enabled: ctx.enabled,
          semanticLabel: l.pivotRemoveField,
          icon: const Icon(LucideIcons.x),
          onPressed: () => ctx.commit(spec.removeAt(area, index)),
        ),
      ],
    );
    final options = switch (area) {
      PivotArea.row || PivotArea.column => _groupOptions(context, l),
      PivotArea.value => _valueOptions(context, l),
      PivotArea.filter => _filterOptions(context, l),
    };
    return Container(
      key: ValueKey<String>('pivot.card.${area.name}.$index'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 6, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: options,
            ),
          ),
        ],
      ),
    );
  }

  Widget _handle(BuildContext context, SheetsLocalizations l, String title) {
    final theme = ShadTheme.of(context);
    final icon = Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(
        LucideIcons.gripVertical,
        size: 14,
        color: theme.colorScheme.mutedForeground,
      ),
    );
    if (!ctx.enabled) return icon;
    return Semantics(
      label: l.pivotDragHandle(title),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Draggable<PivotFieldDrag>(
          data: PivotFieldDrag(area, index),
          feedback: _DragChip(title: title),
          childWhenDragging: Opacity(opacity: 0.4, child: icon),
          child: icon,
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, SheetsLocalizations l, String title) {
    final f = ctx.field(_source);
    final n = spec.count(area);
    PivotGrouping? grouping;
    if (area.isGroup) {
      grouping =
          (area == PivotArea.row ? spec.rows : spec.columns)[index].group;
    }
    return WonkyDropdownMenu(
      entries: () => [
        for (final to in PivotArea.values)
          if (to != area && !_calculated)
            WonkyMenuItem(
              key: ValueKey<String>('pivot.card.moveTo.${to.name}'),
              label: l.pivotMoveTo(pivotAreaLabel(l, to)),
              enabled: ctx.enabled,
              onSelected: () => ctx.commit(
                spec.move(
                  area,
                  index,
                  to,
                  spec.count(to),
                  summarize: f?.defaultSummarize ?? PivotSummarize.counta,
                ),
              ),
            ),
        if (index > 0)
          WonkyMenuItem(
            label: l.pivotMoveUp,
            icon: LucideIcons.arrowUp,
            enabled: ctx.enabled,
            onSelected: () =>
                ctx.commit(spec.move(area, index, area, index - 1)),
          ),
        if (index < n - 1)
          WonkyMenuItem(
            label: l.pivotMoveDown,
            icon: LucideIcons.arrowDown,
            enabled: ctx.enabled,
            onSelected: () =>
                ctx.commit(spec.move(area, index, area, index + 2)),
          ),
        if (area.isGroup && f != null) ...[
          const WonkyMenuSeparator(),
          if (f.kind == PivotFieldKind.date || f.kind == PivotFieldKind.number)
            WonkyMenuSubmenu(
              label: l.pivotDateGroup,
              children: [
                for (final u in PivotDateUnit.values)
                  WonkyMenuRadioItem(
                    key: ValueKey<String>('pivot.card.dateGroup.${u.name}'),
                    label: pivotDateUnitLabel(l, u),
                    selected:
                        grouping is PivotDateGrouping && grouping.unit == u,
                    enabled: ctx.enabled,
                    onSelected: () => ctx.group(f.colId, PivotDateGrouping(u)),
                  ),
              ],
            ),
          if (f.kind == PivotFieldKind.number)
            WonkyMenuItem(
              key: const ValueKey<String>('pivot.card.histogram'),
              label: l.pivotHistogramGroup,
              enabled: ctx.enabled,
              onSelected: () async {
                final g = await showPivotHistogramDialog(
                  context,
                  initial: grouping is PivotHistogramGrouping ? grouping : null,
                );
                if (g != null) ctx.group(f.colId, g);
              },
            ),
          if (grouping != null)
            WonkyMenuItem(
              key: const ValueKey<String>('pivot.card.removeGroup'),
              label: l.pivotRemoveGroup,
              enabled: ctx.enabled,
              onSelected: () => ctx.group(f.colId, null),
            ),
        ],
        if (area == PivotArea.value && !_calculated)
          WonkyMenuItem(
            label: l.pivotRenameField,
            enabled: ctx.enabled,
            onSelected: () async {
              final name = await showPivotRenameDialog(context, title);
              if (name == null) return;
              ctx.commit(
                spec.withValue(
                  index,
                  valueWith(spec.values[index], {
                    'name': name.trim().isEmpty ? null : name.trim(),
                  }),
                ),
              );
            },
          ),
        const WonkyMenuSeparator(),
        WonkyMenuItem(
          label: l.pivotRemoveField,
          icon: LucideIcons.trash2,
          enabled: ctx.enabled,
          onSelected: () => ctx.commit(spec.removeAt(area, index)),
        ),
      ],
      builder: (context, c) => ShadIconButton.ghost(
        key: ValueKey<String>('pivot.card.menu.${area.name}.$index'),
        width: 26,
        height: 26,
        iconSize: 14,
        semanticLabel: l.pivotFieldOptions(title),
        icon: const Icon(LucideIcons.ellipsisVertical),
        onPressed: c.toggle,
      ),
    );
  }

  List<Widget> _groupOptions(BuildContext context, SheetsLocalizations l) {
    final isRow = area == PivotArea.row;
    final g = (isRow ? spec.rows : spec.columns)[index];
    void set(Map<String, Object?> changes) =>
        ctx.commit(spec.withGroup(area, index, groupWith(g, changes)));
    final sortBy = <String, String>{
      '': ctx.field(g.source)?.header ?? g.source,
      for (var i = 0; i < spec.values.length; i++) '$i': ctx.valueName(i),
    };
    final grouping = g.group;
    return [
      PivotOptionRow(
        label: l.pivotOrder,
        child: PivotSelect<bool>(
          value: g.ascending,
          enabled: ctx.enabled,
          options: {true: l.pivotAscending, false: l.pivotDescending},
          onChanged: (asc) => set({'order': asc ? 'asc' : 'desc'}),
        ),
      ),
      PivotOptionRow(
        label: l.pivotSortBy,
        child: PivotSelect<String>(
          value:
              g.sortByValueIndex == null ||
                  g.sortByValueIndex! >= spec.values.length
              ? ''
              : '${g.sortByValueIndex}',
          enabled: ctx.enabled,
          options: sortBy,
          onChanged: (v) => set({
            'sortByValue': v.isEmpty ? null : {'valueIndex': int.parse(v)},
          }),
        ),
      ),
      if (grouping != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.pivotGroupedBy(_groupingLabel(l, grouping)),
                  key: const ValueKey<String>('pivot.card.grouping'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShadTheme.of(
                    context,
                  ).textTheme.muted.copyWith(fontSize: 12),
                ),
              ),
              ShadIconButton.ghost(
                width: 22,
                height: 22,
                iconSize: 12,
                enabled: ctx.enabled,
                semanticLabel: l.pivotRemoveGroup,
                icon: const Icon(LucideIcons.x),
                onPressed: () => ctx.group(g.source, null),
              ),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          ShadCheckbox(
            key: ValueKey<String>('pivot.card.totals.${area.name}.$index'),
            value: g.showTotals,
            enabled: ctx.enabled,
            onChanged: (v) => set({'showTotals': v}),
            label: Text(l.pivotShowTotals),
          ),
          if (isRow)
            ShadCheckbox(
              key: ValueKey<String>('pivot.card.repeat.$index'),
              value: g.repeatLabels,
              enabled: ctx.enabled,
              onChanged: (v) => set({'repeatLabels': v}),
              label: Text(l.pivotRepeatLabels),
            ),
        ],
      ),
    ];
  }

  String _groupingLabel(SheetsLocalizations l, PivotGrouping g) => switch (g) {
    PivotDateGrouping(:final unit) => pivotDateUnitLabel(l, unit),
    PivotHistogramGrouping(:final size) => l.pivotHistogramLabel(
      size == size.roundToDouble() ? '${size.toInt()}' : '$size',
    ),
    PivotManualGrouping(:final groups) => l.pivotManualGroupLabel(
      groups.length,
    ),
  };

  List<Widget> _valueOptions(BuildContext context, SheetsLocalizations l) {
    final v = spec.values[index];
    void set(Map<String, Object?> changes) =>
        ctx.commit(spec.withValue(index, valueWith(v, changes)));
    final summarize = _calculated
        ? [PivotSummarize.sum, PivotSummarize.custom]
        : [
            for (final s in PivotSummarize.values)
              if (s != PivotSummarize.custom) s,
          ];
    return [
      if (_calculated) ...[
        PivotOptionRow(
          label: l.pivotValueName,
          child: PivotCommitInput(
            key: ValueKey<String>('pivot.card.calcName.$index'),
            value: ctx.valueName(index),
            enabled: ctx.enabled,
            semanticLabel: l.pivotValueName,
            onCommit: (t) => set({'name': t.trim().isEmpty ? null : t.trim()}),
          ),
        ),
        PivotOptionRow(
          label: l.pivotFormula,
          child: PivotCommitInput(
            key: ValueKey<String>('pivot.card.formula.$index'),
            value: ctx.formulas.toA1(v.formula ?? ''),
            enabled: ctx.enabled,
            mono: true,
            placeholder: "='Unit price' * Quantity",
            semanticLabel: l.pivotFormula,
            onCommit: (t) {
              final text = t.trim();
              if (text.isEmpty) return;
              set({'formula': ctx.formulas.toStored(text)});
            },
          ),
        ),
      ],
      PivotOptionRow(
        label: l.pivotSummarizeBy,
        child: PivotSelect<PivotSummarize>(
          value: v.summarizeBy,
          enabled: ctx.enabled,
          options: {for (final s in summarize) s: pivotSummarizeLabel(l, s)},
          onChanged: (s) => set({'summarizeBy': s.id}),
        ),
      ),
      PivotOptionRow(
        label: l.pivotShowAs,
        child: PivotSelect<PivotShowAs>(
          value: v.showAs,
          enabled: ctx.enabled,
          options: {
            PivotShowAs.defaultValue: l.pivotShowAsDefault,
            PivotShowAs.percentOfRowTotal: l.pivotShowAsRow,
            PivotShowAs.percentOfColumnTotal: l.pivotShowAsColumn,
            PivotShowAs.percentOfGrandTotal: l.pivotShowAsGrandTotal,
          },
          onChanged: (s) => set({'showAs': s.id}),
        ),
      ),
      if (_calculated)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            l.pivotFormulaHint,
            style: ShadTheme.of(context).textTheme.muted.copyWith(fontSize: 11),
          ),
        ),
    ];
  }

  List<Widget> _filterOptions(BuildContext context, SheetsLocalizations l) {
    final f = spec.filters[index];
    final column = ctx.result?.source.column(f.source);
    return [
      PivotOptionRow(
        label: l.pivotFilterStatus,
        child: _FilterButton(
          ctx: ctx,
          index: index,
          criteria: f.criteria,
          column: column,
        ),
      ),
    ];
  }
}

class _FilterButton extends StatefulWidget {
  const _FilterButton({
    required this.ctx,
    required this.index,
    required this.criteria,
    required this.column,
  });

  final PivotCardContext ctx;
  final int index;
  final ColumnCriteria criteria;
  final SourceColumn? column;

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  final _popover = ShadPopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final c = widget.criteria;
    final values = widget.column == null
        ? const <(String, int)>[]
        : pivotDistinctValues(widget.column!);
    final hidden = values.where((v) => c.hiddenValues.contains(v.$1)).length;
    final label = c.condition != null
        ? l.pivotFilterCondition
        : hidden == 0
        ? l.pivotFilterAll
        : l.pivotFilterSome(values.length - hidden, values.length);
    return ShadPopover(
      controller: _popover,
      padding: const EdgeInsets.all(12),
      popover: (context) => PivotFilterEditor(
        criteria: c,
        values: values,
        support: widget.column == null
            ? null
            : widget.ctx.filterSupport?.call(widget.column!),
        onCancel: _popover.hide,
        onApply: (criteria) {
          _popover.hide();
          final spec = widget.ctx.spec;
          final f = spec.filters[widget.index];
          widget.ctx.commit(
            spec.withFilter(widget.index, PivotFilterSpec(f.source, criteria)),
          );
        },
      ),
      child: ShadButton.outline(
        key: ValueKey<String>('pivot.filterButton.${widget.index}'),
        size: ShadButtonSize.sm,
        height: 30,
        enabled: widget.ctx.enabled,
        trailing: const Icon(LucideIcons.chevronDown, size: 14),
        onPressed: _popover.toggle,
        child: Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _DragChip extends StatelessWidget {
  const _DragChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.popover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.primary),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Color(0x33000000))],
      ),
      child: Text(
        title,
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.popoverForeground,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
