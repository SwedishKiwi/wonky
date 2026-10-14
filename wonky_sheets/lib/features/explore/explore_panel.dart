import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../ai/sheets_a1.dart';
import '../ai/sheets_ai_controller.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../status/selection_stats.dart';
import '../status/selection_stats_button.dart' show statLabel;
import 'explore_chart_thumbnail.dart';

/// Panel id of Explore (04 §10).
const explorePanelId = 'sheets.panel.explore';

/// The Explore side panel (04 §7, Sheets 12 §6.7).
SidePanelSpec explorePanelSpec(
  ShellServices services,
  SheetEditorController editor,
) => SidePanelSpec(
  id: explorePanelId,
  title: sheetsL10nOf(services).explorePanelTitle,
  icon: LucideIcons.telescope,
  builder: (context) => ExplorePanel(ai: SheetsAiController.of(editor)),
);

/// The data Explore looks at: the selection when it is more than a cell,
/// else the contiguous region around the active cell.
class ExploreScope {
  const ExploreScope(this.sheetId, this.rect, {required this.fromSelection});

  final String sheetId;
  final GridRect rect;
  final bool fromSelection;

  static ExploreScope? of(SheetEditorController ed) {
    final sheet = ed.activeSheet;
    if (sheet == null || sheet.rows.length == 0 || sheet.columns.length == 0) {
      return null;
    }
    final sel = ed.selection.resolved;
    if (!sel.isSingleCell) {
      var rect = sel.activeRange.rect;
      final used = sheet.usedRect();
      if (used != null) rect = rect.intersection(used) ?? rect;
      return ExploreScope(sheet.id, rect, fromSelection: true);
    }
    final rect = ChartRecommender.contiguousRegion(
      sheet.id,
      sel.activeRow,
      sel.activeCol,
      ed.engine,
      rowCount: sheet.rows.length,
      columnCount: sheet.columns.length,
    );
    if (rect.isSingleCell &&
        ed.engine
            .valueAt(sheet.id, rect.top, rect.left)
            .toCellValue()
            .isBlank()) {
      return null;
    }
    return ExploreScope(sheet.id, rect, fromSelection: false);
  }

  String a1(SheetEditorController ed) =>
      qualifiedA1(ed.sheetName(sheetId), rectA1(rect));

  @override
  bool operator ==(Object other) =>
      other is ExploreScope && other.sheetId == sheetId && other.rect == rect;

  @override
  int get hashCode => Object.hash(sheetId, rect);
}

/// Explore: quick statistics of the selection, suggested charts and pivot
/// tables for the data region (click to insert), insights that open the
/// assistant, and "Ask a question about this data".
class ExplorePanel extends StatefulWidget {
  const ExplorePanel({super.key, required this.ai});

  final SheetsAiController ai;

  @override
  State<ExplorePanel> createState() => _ExplorePanelState();
}

class _ExplorePanelState extends State<ExplorePanel> {
  final _question = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  Timer? _chipsDebounce;
  ExploreScope? _scope;
  SelectionStats _stats = SelectionStats.empty;
  List<ChartSuggestion> _charts = const [];
  List<String> _chips = const [];
  bool _chipsLoading = false;
  ExploreScope? _chipsFor;

  SheetsAiController get ai => widget.ai;
  SheetEditorController get ed => ai.editor;

  @override
  void initState() {
    super.initState();
    ed.selection.addListener(_schedule);
    ed.contentSignal.addListener(_schedule);
    ed.addListener(_schedule);
    _compute();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _chipsDebounce?.cancel();
    ed.selection.removeListener(_schedule);
    ed.contentSignal.removeListener(_schedule);
    ed.removeListener(_schedule);
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _compute);
  }

  void _compute() {
    if (!mounted) return;
    final scope = ExploreScope.of(ed);
    final stats = selectionIsMulti(ed)
        ? SelectionStats.of(ed, cap: 200000)
        : SelectionStats.empty;
    var charts = _charts;
    if (scope != _scope) {
      charts = _chartsFor(scope);
      _chipsDebounce?.cancel();
      if (scope != null) {
        _chipsDebounce = Timer(
          const Duration(milliseconds: 500),
          () => unawaited(_loadChips(scope)),
        );
      }
    }
    setState(() {
      _scope = scope;
      _stats = stats;
      _charts = charts;
      if (scope == null) _chips = const [];
    });
  }

  List<ChartSuggestion> _chartsFor(ExploreScope? scope) {
    if (scope == null) return const [];
    final sheet = ed.model.sheet(scope.sheetId);
    if (sheet == null) return const [];
    try {
      final profile = SelectionProfile.fromRanges(
        [sheet.gridRange(scope.rect)],
        ed.model,
        ed.engine,
      );
      return ChartRecommender.recommend(profile).take(4).toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _loadChips(ExploreScope scope) async {
    if (_chipsFor == scope) return;
    setState(() => _chipsLoading = true);
    List<String> chips;
    try {
      chips = await ai.api.analyzeChips(ai.itemUuid, scope.a1(ed));
    } on Object {
      chips = const [];
    }
    if (!mounted || _scope != scope) return;
    setState(() {
      _chips = chips;
      _chipsFor = scope;
      _chipsLoading = false;
    });
  }

  bool _commandEnabled(String id, [Map<String, Object?> args = const {}]) {
    final s = ai.services;
    if (s.registry.byId(id) == null) return false;
    return s.dispatcher.stateOf(id, args).enabled;
  }

  Future<void> _run(String id, Map<String, Object?> args) async {
    await ed.invokeCommand(id, args);
  }

  Future<void> _ask(String prompt) async {
    final chat = ai.chat;
    if (chat == null || !ai.available) return;
    ai.services.panels.open(ShellPanels.assistant);
    await chat.send(prompt);
  }

  String _withScope(String q) {
    final scope = _scope;
    if (scope == null || scope.fromSelection) return q;
    return 'About the data in ${scope.a1(ed)}: $q';
  }

  String _format(SelectionStat s) {
    final v = _stats.valueOf(s);
    final pattern = s == SelectionStat.count || s == SelectionStat.countNumbers
        ? '#,##0'
        : (_stats.numberFormat ?? '#,##0.##');
    return NumberFormatter.instance.formatText(
      NumberValue(v),
      pattern,
      locale: ed.locale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final scope = _scope;
    return ListenableBuilder(
      listenable: Listenable.merge([
        ai.services.registry,
        ?ai.assistant?.status,
      ]),
      builder: (context, _) => WonkyScrollArea(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          child: Padding(
            key: const ValueKey<String>('sheets.explore'),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.telescope,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l.explorePanelTitle,
                          key: const ValueKey<String>('sheets.explore.title'),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.large.copyWith(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
                if (scope == null)
                  WonkyEmptyState(
                    key: const ValueKey<String>('sheets.explore.empty'),
                    illustration: EmptyIllustration.search,
                    title: l.exploreEmptyTitle,
                    description: l.exploreEmptyBody,
                    size: 72,
                  )
                else ...[
                  Row(
                    children: [
                      Icon(
                        LucideIcons.squareDashedMousePointer,
                        size: 14,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          scope.a1(ed),
                          key: const ValueKey<String>('sheets.explore.scope'),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small,
                        ),
                      ),
                    ],
                  ),
                  if (_stats.count > 0) _statsSection(context),
                  _chartsSection(context, scope),
                  _insightsSection(context, scope),
                ],
                _askSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          title,
          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
        ),
        ...children,
      ],
    );
  }

  Widget _statsSection(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final shown = [
      if (_stats.countNumbers > 0) ...[
        SelectionStat.sum,
        SelectionStat.average,
        SelectionStat.min,
        SelectionStat.max,
      ],
      SelectionStat.count,
      if (_stats.countNumbers > 0) SelectionStat.countNumbers,
    ];
    return _section(context, l.exploreSelectionStats, [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in shown)
            Container(
              key: ValueKey<String>('sheets.explore.stat.${s.name}'),
              width: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.muted.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statLabel(l, s),
                    style: theme.textTheme.muted.copyWith(fontSize: 11),
                  ),
                  Text(
                    _format(s),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ]);
  }

  Widget _chartsSection(BuildContext context, ExploreScope scope) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final range = scope.a1(ed);
    final canInsert = _commandEnabled('sheets.chart.insert', {
      'ranges': [range],
    });
    final canPivot = _commandEnabled('sheets.insert.pivotTable', {
      'range': range,
    });
    return _section(context, l.exploreSuggestedCharts, [
      if (_charts.isEmpty)
        Text(l.exploreNoCharts, style: theme.textTheme.muted)
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, c) in _charts.indexed)
              ShadTooltip(
                builder: (_) => Text(c.label),
                child: ShadButton.outline(
                  key: ValueKey<String>('sheets.explore.chart.$i'),
                  enabled: canInsert,
                  width: 148,
                  height: 124,
                  padding: const EdgeInsets.all(7),
                  onPressed: () => unawaited(
                    _run('sheets.chart.insert', {
                      'ranges': [range],
                      'type': c.type.name,
                    }),
                  ),
                  child: SizedBox(
                    width: 132,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 6,
                      children: [
                        ExploreChartThumbnail(editor: ed, spec: c.spec),
                        Row(
                          children: [
                            Icon(_chartIcon(c.type), size: 13),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                c.label,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      if (canPivot)
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.ghost(
            key: const ValueKey<String>('sheets.explore.pivot'),
            size: ShadButtonSize.sm,
            leading: const Icon(LucideIcons.table2, size: 14),
            onPressed: () =>
                unawaited(_run('sheets.insert.pivotTable', {'range': range})),
            child: Flexible(
              child: Text(
                l.exploreCreatePivot,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
    ]);
  }

  static IconData _chartIcon(ChartType t) => switch (t) {
    ChartType.line || ChartType.timeline => LucideIcons.chartLine,
    ChartType.area => LucideIcons.chartArea,
    ChartType.bar => LucideIcons.chartBarBig,
    ChartType.pie => LucideIcons.chartPie,
    ChartType.scatter || ChartType.bubble => LucideIcons.chartScatter,
    _ => LucideIcons.chartColumnBig,
  };

  Widget _insightsSection(BuildContext context, ExploreScope scope) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final reason = ai.unavailableReason;
    return _section(context, l.exploreInsights, [
      if (_chipsLoading && _chips.isEmpty)
        const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 16, height: 16, child: ShadSpinner()),
        )
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in _chips)
              ShadButton.secondary(
                key: ValueKey<String>('sheets.explore.insight.$c'),
                size: ShadButtonSize.sm,
                enabled: reason == null,
                leading: const Icon(LucideIcons.sparkles, size: 13),
                onPressed: () => unawaited(_ask(_withScope(c))),
                child: Flexible(
                  child: Text(c, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
        ),
      if (reason != null)
        Text(
          reason,
          key: const ValueKey<String>('sheets.explore.aiUnavailable'),
          style: theme.textTheme.muted.copyWith(fontSize: 12),
        ),
    ]);
  }

  Widget _askSection(BuildContext context) {
    final l = sheetsL10n(context);
    final enabled = ai.available && _scope != null;
    void submit() {
      final q = _question.text.trim();
      if (q.isEmpty || !enabled) return;
      _question.clear();
      unawaited(_ask(_withScope(q)));
    }

    return _section(context, l.exploreAskTitle, [
      CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.enter): submit},
        child: ShadInput(
          key: const ValueKey<String>('sheets.explore.question'),
          controller: _question,
          enabled: enabled,
          placeholder: Text(l.exploreAskPlaceholder),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: ShadButton(
          key: const ValueKey<String>('sheets.explore.ask'),
          size: ShadButtonSize.sm,
          enabled: enabled,
          leading: const Icon(LucideIcons.sendHorizontal, size: 13),
          onPressed: submit,
          child: Text(l.exploreAsk),
        ),
      ),
    ]);
  }
}
