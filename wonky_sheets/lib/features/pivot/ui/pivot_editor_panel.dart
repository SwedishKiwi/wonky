import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../commands/pivot_commands.dart' show pivotUpdateArgs;
import '../../../l10n/sheets_l10n.dart';
import '../../common/range_input.dart' show RangeInput;
import '../../sheet_editor/sheet_editor_controller.dart';
import '../pivot_controller.dart';
import '../pivot_formula_text.dart';
import '../pivot_overlay_service.dart';
import '../pivot_ranges.dart';
import '../pivot_spec_edit.dart';
import '../pivot_suggestions.dart';
import 'pivot_field_card.dart';
import 'pivot_field_list.dart';
import 'pivot_filter_editor.dart' show PivotFilterSupport;
import 'pivot_widgets.dart';

/// The pivot table editor side panel `sheets.panel.pivotEditor` (07 §7.3):
/// source range, suggestions, Rows / Columns / Values / Filters with field
/// cards (drag & drop between areas), every change one
/// `sheets.pivot.update` step.
class PivotEditorPanel extends StatefulWidget {
  const PivotEditorPanel({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  State<PivotEditorPanel> createState() => _PivotEditorPanelState();
}

class _PivotEditorPanelState extends State<PivotEditorPanel> {
  final _scroll = ScrollController();
  String? _rangeError;

  SheetEditorController get ed => widget.editor;
  PivotController get pivots => PivotController.of(ed);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _invoke(String id, Map<String, Object?> args) =>
      unawaited(ed.invokeCommand(id, args));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([pivots, pivots.editing, ed]),
      builder: (context, _) {
        final o = pivots.editingOutput ?? pivots.activeOutput;
        if (o == null) return _empty(context);
        return _body(context, o);
      },
    );
  }

  Widget _empty(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    return Padding(
      key: const ValueKey<String>('pivot.panel.empty'),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.table2,
            size: 24,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(height: 12),
          Text(
            l.pivotPanelEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.muted,
          ),
          const SizedBox(height: 12),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            enabled: ed.canEdit,
            onPressed: () => _invoke('sheets.insert.pivotTable', const {}),
            child: Text(l.cmdInsertPivotTable),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, PivotOutput o) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final spec = o.spec;
    final table = o.result?.source;
    final fields = table == null
        ? const <PivotSourceField>[]
        : PivotSourceField.of(table, locale: ed.locale);
    final enabled = ed.canEdit;
    final cardCtx = PivotCardContext(
      spec: spec,
      fields: fields,
      result: o.result,
      enabled: enabled,
      commit: (next) =>
          _invoke('sheets.pivot.update', pivotUpdateArgs(o.id, next)),
      group: (colId, g) => _invoke('sheets.pivot.createGroup', {
        'pivotId': o.id,
        'field': colId,
        'group': g?.toJson(),
      }),
      formulas: PivotFormulaText(
        fields: fields,
        hooks: ed.hooks,
        sheetId: o.sheetId,
        row: o.anchorRow,
        col: o.anchorCol,
        locale: ed.locale,
      ),
      filterSupport: table == null || o.source == null
          ? null
          : (column) => _filterSupport(o.source!.sheetId, table, column),
    );
    final source = o.source;
    final suggestions = spec.isEmpty && enabled
        ? suggestPivots(fields, table)
        : const <PivotSuggestion>[];
    return Column(
      key: ValueKey<String>('pivot.panel.${o.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.pivotPanelTitle,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              WonkyDropdownMenu(
                entries: () => [
                  WonkyMenuItem(
                    label: l.cmdPivotRefresh,
                    icon: LucideIcons.refreshCw,
                    onSelected: () =>
                        _invoke('sheets.pivot.refresh', {'pivotId': o.id}),
                  ),
                  WonkyMenuItem(
                    key: const ValueKey<String>('pivot.panel.delete'),
                    label: l.cmdPivotDelete,
                    icon: LucideIcons.trash2,
                    destructive: true,
                    enabled: enabled,
                    onSelected: () =>
                        _invoke('sheets.pivot.delete', {'pivotId': o.id}),
                  ),
                ],
                builder: (context, c) => ShadIconButton.ghost(
                  key: const ValueKey<String>('pivot.panel.menu'),
                  width: 28,
                  height: 28,
                  iconSize: 16,
                  semanticLabel: l.pivotPanelOptions,
                  icon: const Icon(LucideIcons.ellipsisVertical),
                  onPressed: c.toggle,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: WonkyScrollArea(
            controller: _scroll,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                PivotOptionRow(
                  label: l.pivotRange,
                  // Shared range picking (04 §13): select the source on
                  // the grid while the input is focused; written on commit.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RangeInput(
                        key: ValueKey<String>('pivot.panel.range.${o.id}'),
                        editor: ed,
                        keyName: 'pivot.panel.range',
                        multiple: false,
                        value: source == null
                            ? ''
                            : rangeToA1(ed.model, source),
                        enabled: enabled,
                        onChanged: (_, _) {},
                        onCommitted: (t, _) => _setRange(o, t),
                      ),
                      if (_rangeError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _rangeError!,
                            style: ShadTheme.of(context).textTheme.small
                                .copyWith(
                                  color: ShadTheme.of(
                                    context,
                                  ).colorScheme.destructive,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (o.error != null) _problem(context, o),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionTitle(context, l.pivotSuggested),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < suggestions.length; i++)
                        ShadButton.outline(
                          key: ValueKey<String>('pivot.suggestion.$i'),
                          size: ShadButtonSize.sm,
                          height: 28,
                          leading: const Icon(LucideIcons.sparkles, size: 14),
                          onPressed: () => cardCtx.commit(suggestions[i].spec),
                          child: Text(
                            suggestions[i].kind == 'count'
                                ? l.pivotSuggestionCount(suggestions[i].field)
                                : l.pivotSuggestionBy(
                                    suggestions[i].value,
                                    suggestions[i].field,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ],
                for (final area in PivotArea.values)
                  _PivotAreaSection(
                    key: ValueKey<String>('pivot.area.${area.name}'),
                    area: area,
                    ctx: cardCtx,
                    trailing: area == PivotArea.value && spec.values.length > 1
                        ? _valueLayout(context, l, cardCtx)
                        : null,
                  ),
                if (spec.rows.isNotEmpty || spec.columns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ShadCheckbox(
                    key: const ValueKey<String>('pivot.showEmptyGroups'),
                    value: spec.showEmptyGroups,
                    enabled: enabled,
                    onChanged: (v) =>
                        cardCtx.commit(spec.copyWith(showEmptyGroups: v)),
                    label: Text(l.pivotShowEmptyGroups),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Custom formulas relative to the field's first data cell and the
  /// colors of its cells (07 §3.2) for a filter card.
  PivotFilterSupport _filterSupport(
    String sheetId,
    SourceTable table,
    SourceColumn column,
  ) {
    final row = table.range.top + 1;
    final col = column.sheetCol;
    final formats = EffectiveFormatResolver(ed.model);
    final fills = <String>{};
    final texts = <String>{};
    final last = table.range.bottom < row + 20000
        ? table.range.bottom
        : row + 20000;
    for (var r = row; r <= last; r++) {
      final f = formats.resolve(sheetId, r, col);
      final fill = formats.color(f.fillColor);
      final text = formats.color(f.textColor);
      if (fill != null && fills.length < 24) fills.add(fill.toUpperCase());
      if (text != null && texts.length < 24) texts.add(text.toUpperCase());
    }
    return PivotFilterSupport(
      toStored: (a1) => ed.hooks.toStored(
        a1,
        sheetId: sheetId,
        row: row,
        col: col,
        locale: ed.locale,
      ),
      toA1: (stored) => ed.hooks.toA1(
        stored,
        sheetId: sheetId,
        row: row,
        col: col,
        locale: ed.locale,
      ),
      fillColors: fills.toList(),
      textColors: texts.toList(),
    );
  }

  Widget _valueLayout(
    BuildContext context,
    SheetsLocalizations l,
    PivotCardContext c,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        l.pivotDisplayValuesAs,
        style: ShadTheme.of(context).textTheme.muted.copyWith(fontSize: 12),
      ),
      const SizedBox(width: 6),
      PivotSelect<PivotValueLayout>(
        value: c.spec.valueLayout,
        minWidth: 100,
        enabled: c.enabled,
        options: {
          PivotValueLayout.columns: l.pivotValuesAsColumns,
          PivotValueLayout.rows: l.pivotValuesAsRows,
        },
        onChanged: (v) => c.commit(c.spec.copyWith(valueLayout: v)),
      ),
    ],
  );

  void _setRange(PivotOutput o, String text) {
    final l = ed.l10n;
    final t = text.trim();
    try {
      ed.model.parseA1(t, contextSheetId: ed.activeSheetId);
    } on InvalidRangeException {
      setState(() => _rangeError = l.pivotRangeInvalid);
      return;
    }
    setState(() => _rangeError = null);
    _invoke('sheets.pivot.update', {'pivotId': o.id, 'sourceRange': t});
  }

  Widget _problem(BuildContext context, PivotOutput o) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    final blocking = o.blocking;
    return Container(
      key: const ValueKey<String>('pivot.panel.problem'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.destructive.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                size: 14,
                color: theme.colorScheme.destructive,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  o.error?.message ?? '#REF!',
                  style: theme.textTheme.small.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          if (o.problem == PivotProblem.gridEdge && ed.canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 22),
              child: ShadButton.link(
                key: const ValueKey<String>('pivot.panel.expandGrid'),
                size: ShadButtonSize.sm,
                padding: EdgeInsets.zero,
                onPressed: () =>
                    _invoke('sheets.pivot.expandGrid', {'pivotId': o.id}),
                child: Text(l.pivotExpandGrid),
              ),
            ),
          if (o.problem == PivotProblem.collision && blocking != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 22),
              child: ShadButton.link(
                size: ShadButtonSize.sm,
                padding: EdgeInsets.zero,
                onPressed: () {
                  final s = ed.model.sheet(o.sheetId);
                  if (s == null) return;
                  _invoke('sheets.select.range', {
                    'a1':
                        '${sheetNameInA1(s.name)}!'
                        '${GridRect.cell(blocking.row, blocking.col).a1}',
                  });
                },
                child: Text(l.pivotSelectBlocking),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
    text,
    style: ShadTheme.of(
      context,
    ).textTheme.small.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
  );
}

/// One area of the editor: title, *Add ▾*, the cards and the drop zone.
class _PivotAreaSection extends StatefulWidget {
  const _PivotAreaSection({
    super.key,
    required this.area,
    required this.ctx,
    this.trailing,
  });

  final PivotArea area;
  final PivotCardContext ctx;
  final Widget? trailing;

  @override
  State<_PivotAreaSection> createState() => _PivotAreaSectionState();
}

class _PivotAreaSectionState extends State<_PivotAreaSection> {
  /// Insert position while a card is dragged over the section.
  int? _dropAt;

  PivotCardContext get ctx => widget.ctx;
  PivotArea get area => widget.area;

  bool _accepts(PivotFieldDrag d) {
    if (!ctx.enabled) return false;
    // Calculated values can't leave Values.
    if (d.area == PivotArea.value &&
        area != PivotArea.value &&
        ctx.spec.values[d.index].isCalculated) {
      return false;
    }
    return true;
  }

  void _drop(PivotFieldDrag d, int at) {
    setState(() => _dropAt = null);
    final f = ctx.field(ctx.spec.sourceOf(d.area, d.index));
    final next = ctx.spec.move(
      d.area,
      d.index,
      area,
      at,
      summarize: f?.defaultSummarize ?? PivotSummarize.counta,
    );
    if (next != ctx.spec) ctx.commit(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final n = ctx.spec.count(area);
    final title = pivotAreaLabel(l, area);
    Widget slot(int at, Widget child) => DragTarget<PivotFieldDrag>(
      onWillAcceptWithDetails: (d) {
        final ok = _accepts(d.data);
        if (ok) setState(() => _dropAt = at);
        return ok;
      },
      onLeave: (_) => setState(() => _dropAt = null),
      onAcceptWithDetails: (d) => _drop(d.data, at),
      builder: (context, candidates, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_dropAt == at && candidates.isNotEmpty)
            Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 4),
              color: theme.colorScheme.primary,
            ),
          child,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              PivotAddFieldButton(
                area: area,
                areaLabel: title,
                fields: ctx.fields,
                enabled: ctx.enabled,
                onPick: (f) => ctx.commit(
                  ctx.spec.addField(
                    area,
                    f.colId,
                    summarize: f.defaultSummarize,
                  ),
                ),
                onCalculated: area == PivotArea.value
                    ? () => ctx.commit(
                        ctx.spec.addCalculatedField(
                          ctx.fields.isEmpty
                              ? '=0'
                              : '=${PivotFormula.tokenOf(ctx.fields.first.colId)}',
                        ),
                      )
                    : null,
              ),
            ],
          ),
          if (widget.trailing != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: widget.trailing,
              ),
            ),
          const SizedBox(height: 6),
          for (var i = 0; i < n; i++)
            slot(
              i,
              PivotFieldCard(
                key: ValueKey<String>(
                  'pivot.field.${area.name}.$i.${ctx.spec.sourceOf(area, i)}',
                ),
                ctx: ctx,
                area: area,
                index: i,
              ),
            ),
          slot(
            n,
            Container(
              key: ValueKey<String>('pivot.drop.${area.name}'),
              height: n == 0 ? 36 : 12,
              alignment: Alignment.center,
              decoration: n == 0
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _dropAt == n
                            ? theme.colorScheme.primary
                            : theme.colorScheme.border,
                      ),
                    )
                  : null,
              child: n == 0
                  ? Text(
                      l.pivotAreaEmpty,
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
