import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'data_tools.dart';

/// The Column stats panel (`sheets.panel.columnStats`, 07 §15): counts,
/// distribution (histogram / top values, with a table alternative),
/// frequency table and numeric summary of one column.
class ColumnStatsPanel extends StatefulWidget {
  const ColumnStatsPanel({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  State<ColumnStatsPanel> createState() => _ColumnStatsPanelState();
}

class _ColumnStatsPanelState extends State<ColumnStatsPanel> {
  final _scroll = ScrollController();
  bool? _ignoreHeader;
  bool _table = false;
  int _shown = 10;
  Timer? _debounce;
  ColumnStatsResult? _result;
  (String, int, bool, int)? _key;

  SheetEditorController get ed => widget.editor;
  DataTools get tools => DataTools.of(ed);

  @override
  void initState() {
    super.initState();
    ed.addListener(_schedule);
    tools.statsColumn.addListener(_now);
    WidgetsBinding.instance.addPostFrameCallback((_) => _compute());
  }

  @override
  void dispose() {
    ed.removeListener(_schedule);
    tools.statsColumn.removeListener(_now);
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _now() {
    _shown = 10;
    _compute();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _compute);
  }

  int get _col {
    final s = ed.activeSheet!;
    final id = tools.statsColumn.value;
    final i = id == null ? -1 : s.columns.indexOf(id);
    return i >= 0 ? i : ed.selection.resolved.activeCol;
  }

  (int, int)? get _rows {
    final used = ed.activeSheet?.usedRect();
    if (used == null) return null;
    return (used.top, used.bottom);
  }

  bool _headerDefault(int col, int top, int bottom) {
    final sid = ed.activeSheetId;
    final v = ed.engine.valueAt(sid, top, col).toCellValue();
    if (v is! TextValue) return false;
    for (var r = top + 1; r <= math.min(bottom, top + 50); r++) {
      final x = ed.engine.valueAt(sid, r, col).toCellValue();
      if (!x.isBlank() && x is! TextValue) return true;
    }
    return false;
  }

  void _compute() {
    if (!mounted || ed.activeSheet == null) return;
    final col = _col;
    final rows = _rows;
    if (rows == null) {
      setState(() => _result = null);
      return;
    }
    final (top, bottom) = rows;
    final header = _ignoreHeader ?? _headerDefault(col, top, bottom);
    final key = (ed.activeSheetId, col, header, ed.model.version);
    if (key == _key) return;
    _key = key;
    final from = header ? top + 1 : top;
    final r = from > bottom
        ? null
        : ColumnStats.fromSheet(
            CellTextReader(ed.engine, FormatterDisplayText(locale: ed.locale)),
            ed.activeSheetId,
            col,
            from,
            bottom,
          );
    setState(() => _result = r);
  }

  void _select(int col) {
    final s = ed.activeSheet!;
    if (col < 0 || col >= s.columns.length) return;
    unawaited(
      ed.invokeCommand('sheets.columnStats.selectColumn', {
        'colId': s.columns.idAt(col),
      }),
    );
  }

  String _num(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      return FormatterDisplayText(
        locale: ed.locale,
      ).displayText(NumberValue(v), '#,##0');
    }
    return FormatterDisplayText(
      locale: ed.locale,
    ).displayText(NumberValue(v), '#,##0.##');
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    if (ed.activeSheet == null) return const SizedBox.shrink();
    final col = _col;
    final rows = _rows;
    final header = rows == null
        ? false
        : (_ignoreHeader ?? _headerDefault(col, rows.$1, rows.$2));
    final headerText = rows == null
        ? ''
        : (ed.cells.displayAt(ed.activeSheetId, rows.$1, col)?.text ?? '');
    final title =
        '${ColumnLetters.fromIndex(col)}'
        '${header && headerText.isNotEmpty ? ' · $headerText' : ''}';
    final r = _result;
    return Column(
      key: const ValueKey<String>('sheets.panel.columnStats'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(l.cmdDataColumnStats, style: theme.textTheme.large),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
          child: Row(
            children: [
              ShadIconButton.ghost(
                key: const ValueKey<String>('columnStats.prev'),
                width: 30,
                height: 30,
                icon: const Icon(LucideIcons.chevronLeft, size: 16),
                onPressed: col > 0 ? () => _select(col - 1) : null,
              ),
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey<String>('columnStats.column'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ShadIconButton.ghost(
                key: const ValueKey<String>('columnStats.next'),
                width: 30,
                height: 30,
                icon: const Icon(LucideIcons.chevronRight, size: 16),
                onPressed: () => _select(col + 1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ShadCheckbox(
            key: const ValueKey<String>('columnStats.ignoreHeader'),
            value: header,
            onChanged: (v) {
              _ignoreHeader = v;
              _key = null;
              _compute();
            },
            label: Text(l.columnStatsIgnoreHeader),
          ),
        ),
        const ShadSeparator.horizontal(margin: EdgeInsets.zero),
        Expanded(
          child: WonkyScrollArea(
            controller: _scroll,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: r == null
                  ? Text(l.columnStatsEmpty, style: theme.textTheme.muted)
                  : _body(context, r),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, Widget child) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ColumnStatsResult r) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final muted = theme.textTheme.muted.copyWith(fontSize: 12);
    final bars = r.histogram.isNotEmpty
        ? [
            for (final b in r.histogram)
              (b.label ?? '${_num(b.start)} – ${_num(b.end)}', b.count),
          ]
        : [for (final e in r.top()) (e.text, e.count)];
    final numeric = r.numeric;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          l.columnStatsCount,
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                l.columnStatsValues(r.valueCount),
                key: const ValueKey<String>('columnStats.values'),
              ),
              Text(l.columnStatsEmptyCount(r.emptyCount)),
              Text(l.columnStatsUnique(r.uniqueCount)),
            ],
          ),
        ),
        if (bars.isNotEmpty)
          _section(
            l.columnStatsDistribution,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Text(l.columnStatsTable, style: muted),
                    const SizedBox(width: 6),
                    ShadSwitch(
                      key: const ValueKey<String>('columnStats.tableSwitch'),
                      value: _table,
                      onChanged: (v) => setState(() => _table = v),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_table)
                  _table2(context, bars)
                else
                  _Histogram(bars: bars, color: theme.colorScheme.primary),
              ],
            ),
          ),
        _section(
          l.columnStatsFrequency,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in r.frequencies.take(_shown))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.text.isEmpty ? l.filterBlanks : e.text,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text('${e.count}', textAlign: TextAlign.end),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${(e.share * 100).round()} %',
                          textAlign: TextAlign.end,
                          style: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (r.frequencies.length > _shown)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ShadButton.link(
                    key: const ValueKey<String>('columnStats.more'),
                    size: ShadButtonSize.sm,
                    onPressed: () => setState(() => _shown += 50),
                    child: Text(l.columnStatsShowMore),
                  ),
                ),
            ],
          ),
        ),
        if (numeric != null)
          _section(
            l.columnStatsSummary,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (k, v) in [
                  if (r.kind != ColumnKind.date) ...[
                    (l.columnStatsSum, numeric.sum),
                    (l.columnStatsAverage, numeric.average),
                    (l.columnStatsMedian, numeric.median),
                  ],
                  (l.columnStatsMin, numeric.min),
                  (l.columnStatsMax, numeric.max),
                ])
                  Row(
                    children: [
                      Expanded(child: Text(k, style: muted)),
                      Text(_num(v)),
                    ],
                  ),
              ],
            ),
          )
        else if (r.minTextLength != null)
          _section(
            l.columnStatsSummary,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.columnStatsShortest, style: muted)),
                    Text('${r.minTextLength}'),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text(l.columnStatsLongest, style: muted)),
                    Text('${r.maxTextLength}'),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _table2(BuildContext context, List<(String, int)> bars) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (label, n) in bars)
        Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            Text('$n'),
          ],
        ),
    ],
  );
}

/// Horizontal bar chart of `(label, count)` (accessible: each bar has a
/// semantics label "label: count").
class _Histogram extends StatelessWidget {
  const _Histogram({required this.bars, required this.color});

  final List<(String, int)> bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final max = bars.fold(1, (m, b) => b.$2 > m ? b.$2 : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, n) in bars)
          Semantics(
            label: '$label: $n',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          height: 12,
                          width: math.max(2, c.maxWidth * n / max),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$n',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
