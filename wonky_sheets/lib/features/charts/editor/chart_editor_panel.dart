import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../charts3d/editor/chart3d_section.dart';
import '../../../l10n/sheets_l10n.dart';
import '../../common/range_input.dart';
import '../../formatting/panel_widgets.dart';
import '../../objects/objects_controller.dart';
import '../../sheet_editor/sheet_editor_controller.dart';
import '../../toolbar/command_ui.dart';
import '../chart_insert.dart';
import '../controller/chart_controller.dart';
import 'chart_editor_widgets.dart';
import 'chart_type_picker.dart';

part 'chart_editor_more.dart';

/// The chart editor side panel (08 §8) for the shell's panel host.
SidePanelSpec chartEditorPanelSpec(
  BuildContext context,
  ShellServices services,
  SheetEditorController editor,
) => SidePanelSpec(
  id: chartEditorPanelId,
  title: sheetsL10n(context).panelChartEditor,
  icon: LucideIcons.chartColumn,
  showAsTab: false,
  builder: (context) => ChartEditorPanel(services: services, editor: editor),
);

/// A column of the chart's data ranges (series candidate).
@immutable
class _Column {
  const _Column(this.key, this.range, this.offset, this.name);
  final String key;
  final int range;
  final int offset;
  final String name;
}

/// Body of the chart editor (08 §8): *Setup* and *Customize* tabs for the
/// selected chart; follows the object selection. Every change dispatches a
/// `sheets.chart.*` command (one undo step; live controls coalesce).
class ChartEditorPanel extends StatefulWidget {
  const ChartEditorPanel({
    super.key,
    required this.services,
    required this.editor,
  });

  final ShellServices services;
  final SheetEditorController editor;

  @override
  State<ChartEditorPanel> createState() => _ChartEditorPanelState();
}

class _ChartEditorPanelState extends State<ChartEditorPanel> {
  final _scroll = ScrollController();
  final _rangeDebounce = Debouncer(const Duration(milliseconds: 600));
  String _tab = 'setup';
  final Set<String> _open = {'style'};
  String _seriesTarget = '';
  String _titleTarget = 'title';
  String _gridTarget = 'v';
  String _rangeText = '';
  String? _rangeFor;
  int _jumpSerial = 0;

  /// The domain point picked in *Format data point*.
  int? _pointIndex;

  /// The slice shown in *Pie slice*.
  int _slice = 0;

  void _setPointIndex(int? i) => setState(() => _pointIndex = i);

  void _setSlice(int i) => setState(() => _slice = i);

  SheetEditorController get ed => widget.editor;
  ObjectsController get objects => ObjectsController.of(ed);

  @override
  void initState() {
    super.initState();
    objects.editorJump.addListener(_onJump);
    _onJump();
  }

  @override
  void dispose() {
    objects.editorJump.removeListener(_onJump);
    _scroll.dispose();
    _rangeDebounce.dispose();
    super.dispose();
  }

  void _onJump() {
    final j = objects.editorJump.value;
    if (j.serial == _jumpSerial) return;
    _jumpSerial = j.serial;
    final section = j.section;
    setState(() {
      if (section == null || section == 'type') {
        _tab = 'setup';
      } else {
        _tab = 'customize';
        _open.add(section);
        if (section == 'series') _seriesTarget = j.seriesKey ?? '';
      }
    });
  }

  EmbeddedObjectRecord? get _target {
    final o = objects.selected;
    if (o == null || o.kind != EmbeddedObjectKind.chart) return null;
    return o;
  }

  void _run(String id, Map<String, Object?> args) =>
      CommandUi(context, widget.services).run(id, args, InvocationSource.ui);

  void _patch(String objectId, Map<String, Object?> patch, [String? key]) =>
      _run('sheets.chart.update', {
        'objectId': objectId,
        'patch': patch,
        'coalesceKey': ?key,
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([objects, ed]),
      builder: (context, _) {
        final o = _target;
        final l = sheetsL10n(context);
        final theme = ShadTheme.of(context);
        if (o == null) {
          return Center(
            key: const ValueKey<String>('chartEditor.empty'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.chartColumn,
                    size: 24,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.chartEditorEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.muted,
                  ),
                ],
              ),
            ),
          );
        }
        final c = objects.chartOf(o);
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => _editor(context, o, c),
        );
      },
    );
  }

  Widget _editor(
    BuildContext context,
    EmbeddedObjectRecord o,
    ChartController c,
  ) {
    final l = sheetsL10n(context);
    final readOnly = !ed.canEdit || c.spec.isFromNewerVersion;
    final body = _tab == 'setup'
        ? _setup(context, o, c)
        : _customize(context, o, c);
    return Column(
      key: ValueKey<String>('chartEditor.${o.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: ShadTabs<String>(
            value: _tab,
            onChanged: (v) => setState(() => _tab = v),
            tabs: [
              ShadTab(
                key: const ValueKey<String>('chartEditor.tab.setup'),
                value: 'setup',
                child: Text(l.chartEditorSetup),
              ),
              ShadTab(
                key: const ValueKey<String>('chartEditor.tab.customize'),
                value: 'customize',
                child: Text(l.chartEditorCustomize),
              ),
            ],
          ),
        ),
        Expanded(
          child: WonkyScrollArea(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: IgnorePointer(
                ignoring: readOnly,
                child: Opacity(
                  opacity: readOnly ? 0.6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: body,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Setup (08 §8.1).

  List<_Column> _columns(ChartSpec spec) {
    final out = <_Column>[];
    final d = spec.data;
    for (var ri = 0; ri < d.ranges.length; ri++) {
      final g = d.ranges[ri];
      final sheet = ed.model.sheet(g.sheetId);
      final rr = sheet?.resolve(g);
      if (sheet == null || rr == null) continue;
      var rect = rr.rect;
      final used = sheet.usedRect();
      if ((rr.wholeColumns || rr.wholeRows) && used != null) {
        rect = rect.intersection(used) ?? rect;
      }
      if (!d.switchRowsColumns) {
        var k = 0;
        for (var col = rect.left; col <= rect.right; col++) {
          if (sheet.columns.isHidden(col) && !d.includeHidden) continue;
          final header = (d.headerCount ?? 1) > 0
              ? ed.cells.displayAt(sheet.id, rect.top, col)?.text ?? ''
              : '';
          out.add(
            _Column(
              sheet.columns.idAt(col),
              ri,
              k++,
              header.isNotEmpty ? header : ColumnLetters.fromIndex(col),
            ),
          );
        }
      } else {
        var k = 0;
        for (var row = rect.top; row <= rect.bottom; row++) {
          if (sheet.rows.isHidden(row) && !d.includeHidden) continue;
          final header = (d.headerCount ?? 1) > 0
              ? ed.cells.displayAt(sheet.id, row, rect.left)?.text ?? ''
              : '';
          out.add(
            _Column(
              sheet.rows.idAt(row),
              ri,
              k++,
              header.isNotEmpty ? header : '${row + 1}',
            ),
          );
        }
      }
    }
    return out;
  }

  /// The explicit series list (materialized from the automatic one).
  List<SeriesRef> _seriesRefs(ChartSpec spec, ChartData data) {
    if (spec.data.seriesRefs.isNotEmpty) return spec.data.seriesRefs;
    final cols = {for (final c in _columns(spec)) c.key: c};
    return [
      for (final s in data.series)
        if (cols[s.key] case final c?)
          SeriesRef(
            key: s.key,
            ref: DataRef(range: c.range, offset: c.offset),
          ),
    ];
  }

  void _setRefs(String id, List<SeriesRef> refs) => _patch(id, {
    'data': {
      'seriesRefs': [for (final r in refs) r.toJson()],
    },
  });

  List<Widget> _setup(
    BuildContext context,
    EmbeddedObjectRecord o,
    ChartController c,
  ) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final spec = c.spec;
    final d = spec.data;
    final data = c.data;
    final variant = variantOf(spec);
    final suggestions = [
      for (final s in ChartInsert.suggestions(ed, d.ranges))
        variantOfSuggestion(s),
    ];
    final rangeA1 = ChartInsert.a1Of(ed, d.ranges).join(', ');
    if (_rangeFor != '${o.id}|$rangeA1') {
      _rangeFor = '${o.id}|$rangeA1';
      _rangeText = rangeA1;
    }
    final cols = _columns(spec);
    final refs = _seriesRefs(spec, data);
    final shown = [
      for (final r in refs)
        if (!r.hidden) r,
    ];
    final used = {for (final r in shown) r.key, ?data.domain.key};
    final available = [
      for (final col in cols)
        if (!used.contains(col.key)) col,
    ];
    final names = {for (final s in data.series) s.key: s.name};
    final colors = ChartTheme.from(
      ed.model.theme,
      dark: chartDarkOf(context),
      tokens: chartUiTokensOf(context),
    );
    final firstCol = _firstLetter(d);
    final firstRow = _firstRow(d);
    final cartesianLine =
        spec.type == ChartType.line ||
        spec.type == ChartType.area ||
        spec.type == ChartType.scatter ||
        spec.type == ChartType.combo;
    return [
      EditorField(
        label: l.chartEditorChartType,
        child: ChartTypePicker(
          value: variant,
          suggestions: suggestions,
          onSelected: (v) => _run('sheets.chart.setType', v.args(o.id)),
        ),
      ),
      if (spec.type.supportsStacking)
        EditorField(
          label: l.chartEditorStacking,
          child: PanelSelect<ChartStacking>(
            keyName: 'chartEditor.stacking',
            value: spec.stacking,
            options: {
              ChartStacking.none: l.chartStackingNone,
              ChartStacking.normal: l.chartStackingNormal,
              ChartStacking.percent: l.chartStackingPercent,
            },
            onChanged: (v) => _run('sheets.chart.setType', {
              'objectId': o.id,
              'type': spec.type.id,
              'stacking': v.name,
            }),
          ),
        ),
      EditorField(
        label: l.chartEditorDataRange,
        child: RangeInput(
          key: ValueKey<String>('chartEditor.range.${o.id}'),
          editor: ed,
          value: _rangeText,
          keyName: 'chartEditor.range',
          onChanged: (text, ranges) {
            _rangeText = text;
            if (ranges == null) return;
            _rangeDebounce(() {
              if (!mounted) return;
              final a1 = ChartInsert.a1Of(
                ed,
                ChartInsert.rangesFromA1(ed, [text]),
              ).join(', ');
              if (a1 == ChartInsert.a1Of(ed, c.spec.data.ranges).join(', ')) {
                return;
              }
              _run('sheets.chart.setDataRanges', {
                'objectId': o.id,
                'ranges': [text],
                'coalesceKey': 'ranges',
              });
            });
          },
        ),
      ),
      if (spec.type != ChartType.scorecard &&
          spec.type != ChartType.table &&
          spec.type != ChartType.histogram) ...[
        PanelSection(
          label: l.chartEditorXAxis,
          child: d.useFirstColumnAsLabels && !data.domain.isSynthetic
              ? _Chip(
                  keyName: 'chartEditor.domain',
                  label: data.domain.name.isEmpty
                      ? l.chartEditorDomainUnnamed
                      : data.domain.name,
                  icon: LucideIcons.rows3,
                  menu: [
                    WonkyMenuCheckItem(
                      label: l.chartEditorAggregate,
                      checked: d.aggregate != null,
                      onSelected: () => _patch(o.id, {
                        'data': {
                          'aggregate': d.aggregate == null ? 'sum' : null,
                        },
                      }),
                    ),
                    WonkyMenuCheckItem(
                      label: l.chartEditorTreatLabelsAsText,
                      checked: d.treatLabelsAsText,
                      onSelected: () => _patch(o.id, {
                        'data': {
                          'treatLabelsAsText': d.treatLabelsAsText
                              ? null
                              : true,
                        },
                      }),
                    ),
                    WonkyMenuItem(
                      label: l.chartEditorRemove,
                      icon: LucideIcons.trash2,
                      onSelected: () => _patch(o.id, {
                        'data': {'useFirstColumnAsLabels': false},
                      }),
                    ),
                  ],
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: ShadButton.ghost(
                    key: const ValueKey<String>('chartEditor.addDomain'),
                    size: ShadButtonSize.sm,
                    leading: const Icon(LucideIcons.plus, size: 14),
                    onPressed: () => _patch(o.id, {
                      'data': {'useFirstColumnAsLabels': null},
                    }),
                    child: Text(l.chartEditorAddXAxis),
                  ),
                ),
        ),
      ],
      PanelSection(
        label: l.chartEditorSeries,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < shown.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _Chip(
                  keyName: 'chartEditor.series.$i',
                  label: names[shown[i].key] ?? _colName(cols, shown[i].key),
                  swatch: Color(
                    colors.color(
                      spec.seriesStyle(shown[i].key).color,
                      colors.seriesColor(i),
                    ),
                  ),
                  menu: [
                    if (i > 0)
                      WonkyMenuItem(
                        label: l.chartEditorMoveUp,
                        icon: LucideIcons.arrowUp,
                        onSelected: () {
                          final all = [...refs];
                          final a = all.indexOf(shown[i]);
                          final b = all.indexOf(shown[i - 1]);
                          all[a] = shown[i - 1];
                          all[b] = shown[i];
                          _setRefs(o.id, all);
                        },
                      ),
                    if (i < shown.length - 1)
                      WonkyMenuItem(
                        label: l.chartEditorMoveDown,
                        icon: LucideIcons.arrowDown,
                        onSelected: () {
                          final all = [...refs];
                          final a = all.indexOf(shown[i]);
                          final b = all.indexOf(shown[i + 1]);
                          all[a] = shown[i + 1];
                          all[b] = shown[i];
                          _setRefs(o.id, all);
                        },
                      ),
                    WonkyMenuItem(
                      label: l.chartEditorCustomizeSeries,
                      icon: LucideIcons.paintbrush,
                      onSelected: () => setState(() {
                        _tab = 'customize';
                        _open.add('series');
                        _seriesTarget = shown[i].key;
                      }),
                    ),
                    WonkyMenuItem(
                      label: l.chartEditorRemove,
                      icon: LucideIcons.trash2,
                      onSelected: () => _setRefs(o.id, [
                        for (final r in refs)
                          r.key == shown[i].key ? r.copyWith(hidden: true) : r,
                      ]),
                    ),
                  ],
                ),
              ),
            for (final key in data.missingSeriesKeys)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l.chartEditorMissingSeries,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.destructive,
                    fontSize: 12,
                  ),
                  key: ValueKey<String>('chartEditor.missing.$key'),
                ),
              ),
            if (available.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: _AddSeriesButton(
                  label: l.chartEditorAddSeries,
                  columns: available,
                  onAdd: (col) {
                    final existing = refs.indexWhere((r) => r.key == col.key);
                    final all = [...refs];
                    if (existing >= 0) {
                      all[existing] = all[existing].copyWith(hidden: false);
                    } else {
                      all.add(
                        SeriesRef(
                          key: col.key,
                          ref: DataRef(range: col.range, offset: col.offset),
                        ),
                      );
                    }
                    _setRefs(o.id, all);
                  },
                ),
              ),
          ],
        ),
      ),
      EditorCheck(
        keyName: 'switchRowsColumns',
        label: l.chartEditorSwitchRowsColumns,
        value: d.switchRowsColumns,
        onChanged: (v) => _patch(o.id, {
          'data': {
            'switchRowsColumns': v ? true : null,
            'seriesRefs': const <Object?>[],
            'domain': null,
          },
        }),
      ),
      Row(
        children: [
          Expanded(
            child: EditorCheck(
              keyName: 'useHeaders',
              label: l.chartEditorUseRowAsHeaders(firstRow),
              value: (d.headerCount ?? 0) > 0,
              onChanged: (v) => _patch(o.id, {
                'data': {'headerCount': v ? 1 : 0},
              }),
            ),
          ),
          if ((d.headerCount ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: 96,
                child: EditorStepper(
                  keyName: 'headerCount',
                  value: d.headerCount,
                  min: 1,
                  max: 9,
                  onChanged: (v) => _patch(o.id, {
                    'data': {'headerCount': v.toInt()},
                  }, 'headerCount'),
                ),
              ),
            ),
        ],
      ),
      EditorCheck(
        keyName: 'useFirstColumn',
        label: d.switchRowsColumns
            ? l.chartEditorUseRowAsLabels(firstRow)
            : l.chartEditorUseColumnAsLabels(firstCol),
        value: d.useFirstColumnAsLabels,
        onChanged: (v) => _patch(o.id, {
          'data': {'useFirstColumnAsLabels': v ? null : false},
        }),
      ),
      Row(
        children: [
          Expanded(
            child: EditorCheck(
              keyName: 'aggregate',
              label: l.chartEditorAggregate,
              value: d.aggregate != null,
              onChanged: (v) => _patch(o.id, {
                'data': {'aggregate': v ? 'sum' : null},
              }),
            ),
          ),
          if (d.aggregate != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: 130,
                child: PanelSelect<ChartAggregate>(
                  keyName: 'chartEditor.aggregateFn',
                  value: d.aggregate!,
                  options: {
                    for (final a in ChartAggregate.values)
                      a: _aggregateLabel(l, a),
                  },
                  onChanged: (v) => _patch(o.id, {
                    'data': {'aggregate': v.name},
                  }),
                ),
              ),
            ),
        ],
      ),
      EditorCheck(
        keyName: 'includeHidden',
        label: l.chartEditorIncludeHidden,
        value: d.includeHidden,
        onChanged: (v) => _patch(o.id, {
          'data': {'includeHidden': v ? true : null},
        }),
      ),
      if (cartesianLine)
        EditorField(
          label: l.chartEditorEmptyCells,
          child: PanelSelect<EmptyCellMode>(
            keyName: 'chartEditor.emptyCells',
            value: d.emptyCells,
            options: {
              EmptyCellMode.gap: l.chartEmptyCellsGap,
              EmptyCellMode.zero: l.chartEmptyCellsZero,
              EmptyCellMode.connect: l.chartEmptyCellsConnect,
            },
            onChanged: (v) => _patch(o.id, {
              'data': {'emptyCells': v == EmptyCellMode.gap ? null : v.name},
            }),
          ),
        ),
      for (final w in c.warnings)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                size: 14,
                color: theme.colorScheme.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _warning(l, w),
                  style: theme.textTheme.small.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  String _colName(List<_Column> cols, String key) {
    for (final c in cols) {
      if (c.key == key) return c.name;
    }
    return key;
  }

  String _firstLetter(ChartDataSpec d) {
    if (d.ranges.isEmpty) return 'A';
    final rr = ed.model.sheet(d.ranges.first.sheetId)?.resolve(d.ranges.first);
    return rr == null ? 'A' : ColumnLetters.fromIndex(rr.rect.left);
  }

  int _firstRow(ChartDataSpec d) {
    if (d.ranges.isEmpty) return 1;
    final rr = ed.model.sheet(d.ranges.first.sheetId)?.resolve(d.ranges.first);
    return rr == null ? 1 : rr.rect.top + 1;
  }

  String _aggregateLabel(SheetsLocalizations l, ChartAggregate a) =>
      switch (a) {
        ChartAggregate.sum => l.chartAggregateSum,
        ChartAggregate.average => l.chartAggregateAverage,
        ChartAggregate.count => l.chartAggregateCount,
        ChartAggregate.max => l.chartAggregateMax,
        ChartAggregate.min => l.chartAggregateMin,
        ChartAggregate.median => l.chartAggregateMedian,
      };

  String _warning(SheetsLocalizations l, ChartWarning w) => switch (w.code) {
    ChartWarningCode.noData => l.chartWarnNoData,
    ChartWarningCode.rangeNotFound => l.chartWarnRangeNotFound,
    ChartWarningCode.rangeSizeMismatch => l.chartWarnRangeSizeMismatch,
    ChartWarningCode.tooManyCategories => l.chartWarnTooManyCategories,
    ChartWarningCode.missingSeries => l.chartEditorMissingSeries,
    ChartWarningCode.logNonPositiveSkipped => l.chartWarnLogSkipped(w.count),
    ChartWarningCode.trendlineInvalidPoints => l.chartWarnTrendlineIgnored(
      w.count,
    ),
    _ => w.message,
  };

  // ---------------------------------------------------------------------------
  // Customize (08 §8.2).

  EditorSection _section(
    String id,
    String title,
    List<Widget> children, {
    VoidCallback? onReset,
  }) => EditorSection(
    id: id,
    title: title,
    open: _open.contains(id),
    onToggle: () => setState(() {
      if (!_open.remove(id)) _open.add(id);
    }),
    onReset: onReset,
    children: children,
  );

  List<Widget> _customize(
    BuildContext context,
    EmbeddedObjectRecord o,
    ChartController c,
  ) {
    final l = sheetsL10n(context);
    final spec = c.spec;
    final t = spec.type;
    final id = o.id;
    final auto = l.colorAutomatic;
    final cartesian = t.isCartesian || t == ChartType.radar;
    return [
      _section('style', l.chartSectionStyle, [
        EditorPair(
          left: EditorField(
            label: l.chartEditorBackground,
            child: EditorColorButton(
              keyName: 'background',
              value: spec.style.background,
              resetLabel: auto,
              onChanged: (v) => _patch(id, {
                'style': {'background': v},
              }),
            ),
          ),
          right: EditorField(
            label: l.chartEditorBorderColor,
            child: EditorColorButton(
              keyName: 'border',
              value: spec.style.border,
              resetLabel: l.colorNone,
              onChanged: (v) => _patch(id, {
                'style': {'border': v},
              }),
            ),
          ),
        ),
        EditorField(
          label: l.chartEditorFont,
          child: PanelSelect<String>(
            keyName: 'chartEditor.font',
            value: spec.style.fontFamily ?? '',
            options: {
              '': auto,
              'Inter': 'Inter',
              'Geist': 'Geist',
              'Geist Mono': 'Geist Mono',
            },
            onChanged: (v) => _patch(id, {
              'style': {'fontFamily': v.isEmpty ? null : v},
            }),
          ),
        ),
        EditorCheck(
          keyName: 'maximize',
          label: l.chartEditorMaximize,
          value: spec.style.maximize,
          onChanged: (v) => _patch(id, {
            'style': {'maximize': v ? true : null},
          }),
        ),
        if (t == ChartType.line || t == ChartType.area || t == ChartType.combo)
          EditorCheck(
            keyName: 'smooth',
            label: l.chartEditorSmooth,
            value: spec.style.smooth,
            onChanged: (v) => _patch(id, {
              'style': {'smooth': v ? true : null},
            }),
          ),
        if (cartesian)
          EditorCheck(
            keyName: 'plotNull',
            label: l.chartEditorPlotNullValues,
            value: spec.style.plotNullValues,
            onChanged: (v) => _patch(id, {
              'style': {'plotNullValues': v ? true : null},
            }),
          ),
        EditorField(
          label: l.chartEditorCompareMode,
          child: PanelSelect<CompareMode>(
            keyName: 'chartEditor.compareMode',
            value: spec.style.compareMode,
            options: {
              CompareMode.off: l.chartCompareOff,
              CompareMode.datum: l.chartCompareDatum,
              CompareMode.category: l.chartCompareCategory,
            },
            onChanged: (v) => _patch(id, {
              'style': {'compareMode': v == CompareMode.datum ? null : v.name},
            }),
          ),
        ),
      ], onReset: () => _patch(id, {'style': null})),
      _titles(l, spec, id),
      if (t != ChartType.scorecard && t != ChartType.table)
        _series(context, l, c, id),
      if (t != ChartType.scorecard && t != ChartType.table)
        _legend(l, spec, id),
      if (cartesian && t != ChartType.radar) ...[
        _axis(l, spec, id, 'h', l.chartSectionHAxis),
        _axis(l, spec, id, 'v', l.chartSectionVAxis),
        _gridlines(l, spec, id),
      ],
      if (t == ChartType.pie) _pie(l, spec, id),
      if (t == ChartType.pie) _pieSlices(l, c, id),
      if (t.supports3D)
        _section(
          'threeD',
          l.chartSection3D,
          chart3DControls(l, spec, (p, [k]) => _patch(id, p, k)),
          onReset: () => _patch(id, {'threeD': null}),
        ),
      if (t == ChartType.histogram) _histogram(l, spec, id),
      if (t == ChartType.waterfall) _waterfall(l, spec, id, c),
      if (t == ChartType.candlestick) _candlestick(l, spec, id),
      if (t == ChartType.scorecard) _scorecard(l, spec, id, c),
      if (t == ChartType.table) _table(l, spec, id),
    ];
  }

  Widget _fontRow(
    SheetsLocalizations l,
    String keyName,
    ChartFont font,
    Map<String, Object?> Function(Map<String, Object?> font) wrap, {
    num defaultSize = 12,
  }) {
    final id = _target!.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EditorPair(
          left: EditorField(
            label: l.chartEditorFontSize,
            child: EditorStepper(
              keyName: '$keyName.size',
              value: font.size ?? defaultSize,
              min: 6,
              max: 72,
              onChanged: (v) => _patch(id, wrap({'size': v}), '$keyName.size'),
            ),
          ),
          right: EditorField(
            label: l.chartEditorTextColor,
            child: EditorColorButton(
              keyName: '$keyName.color',
              value: font.color,
              resetLabel: l.colorAutomatic,
              onChanged: (v) => _patch(id, wrap({'color': v})),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              PanelIconToggle(
                icon: LucideIcons.bold,
                label: l.chartEditorBold,
                value: font.bold,
                onChanged: (v) => _patch(id, wrap({'bold': v ? true : null})),
              ),
              PanelIconToggle(
                icon: LucideIcons.italic,
                label: l.chartEditorItalic,
                value: font.italic,
                onChanged: (v) => _patch(id, wrap({'italic': v ? true : null})),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _titles(SheetsLocalizations l, ChartSpec spec, String id) {
    final target = _titleTarget;
    final ChartTitle title;
    Map<String, Object?> wrap(Map<String, Object?> m) => switch (target) {
      'title' => {'title': m},
      'subtitle' => {'subtitle': m},
      _ => {
        'axes': {
          target: {'title': m},
        },
      },
    };
    switch (target) {
      case 'title':
        title = spec.title;
      case 'subtitle':
        title = spec.subtitle;
      case 'h':
        title = spec.axes.h.title;
      case 'v':
        title = spec.axes.v.title;
      default:
        title = spec.axes.v2.title;
    }
    final axes = spec.type.isCartesian;
    return _section(
      'titles',
      l.chartSectionTitles,
      [
        EditorField(
          label: l.chartEditorTitleTarget,
          child: PanelSelect<String>(
            keyName: 'chartEditor.titleTarget',
            value: target,
            options: {
              'title': l.chartTitleChart,
              'subtitle': l.chartTitleSubtitle,
              if (axes) 'h': l.chartTitleHAxis,
              if (axes) 'v': l.chartTitleVAxis,
              if (axes) 'v2': l.chartTitleV2Axis,
            },
            onChanged: (v) => setState(() => _titleTarget = v),
          ),
        ),
        EditorField(
          label: l.chartEditorTitleText,
          child: CommitTextField(
            key: ValueKey<String>('chartEditor.titleText.$target'),
            keyName: 'titleText',
            value: title.text,
            placeholder: l.chartEditorTitlePlaceholder,
            onCommit: (v) => _patch(id, wrap({'text': v.isEmpty ? null : v})),
          ),
        ),
        _fontRow(
          l,
          'titleFont.$target',
          title.font,
          (f) => wrap({'font': f}),
          defaultSize: target == 'title' ? 16 : 12,
        ),
        EditorField(
          label: l.chartEditorAlign,
          child: PanelSelect<TitleAlign>(
            keyName: 'chartEditor.titleAlign',
            value: title.align,
            options: {
              TitleAlign.auto: l.chartAlignAuto,
              TitleAlign.left: l.chartAlignLeft,
              TitleAlign.center: l.chartAlignCenter,
              TitleAlign.right: l.chartAlignRight,
            },
            onChanged: (v) => _patch(
              id,
              wrap({'align': v == TitleAlign.auto ? null : v.name}),
            ),
          ),
        ),
      ],
      onReset: () =>
          _patch(id, wrap({'text': null, 'font': null, 'align': null})),
    );
  }

  Widget _series(
    BuildContext context,
    SheetsLocalizations l,
    ChartController c,
    String id,
  ) {
    final spec = c.spec;
    final data = c.data;
    final keys = [for (final s in data.series) s.key];
    final target = keys.contains(_seriesTarget) ? _seriesTarget : '';
    final targets = target.isEmpty ? keys : [target];
    final style = target.isEmpty
        ? (keys.isEmpty ? SeriesStyle.standard : spec.seriesStyle(keys.first))
        : spec.seriesStyle(target);
    Map<String, Object?> wrap(Map<String, Object?> m) => {
      'series': {for (final k in targets) k: m},
    };
    void set(Map<String, Object?> m, [String? key]) =>
        _patch(id, wrap(m), key == null ? null : 'series.$target.$key');
    final t = spec.type;
    final lines =
        t == ChartType.line ||
        t == ChartType.area ||
        t == ChartType.combo ||
        t == ChartType.scatter ||
        t == ChartType.radar;
    final points = lines || t == ChartType.bubble;
    final tl = style.trendline;
    final trend = t.supportsTrendlines && spec.stacking == ChartStacking.none;
    return _section('series', l.chartSectionSeries, [
      EditorField(
        label: l.chartEditorSeriesTarget,
        child: PanelSelect<String>(
          keyName: 'chartEditor.seriesTarget',
          value: target,
          options: {
            '': l.chartEditorAllSeries,
            for (final s in data.series) s.key: s.name,
          },
          onChanged: (v) => setState(() => _seriesTarget = v),
        ),
      ),
      EditorPair(
        left: EditorField(
          label: l.chartEditorFillColor,
          child: EditorColorButton(
            keyName: 'seriesColor',
            value: target.isEmpty ? null : style.color,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => set({'color': v}),
          ),
        ),
        right: EditorField(
          label: l.chartEditorFillOpacity,
          child: EditorStepper(
            keyName: 'fillOpacity',
            value: ((style.fillOpacity ?? 1) * 100).round(),
            max: 100,
            step: 10,
            suffix: '%',
            onChanged: (v) => set({'fillOpacity': v / 100}, 'fillOpacity'),
          ),
        ),
      ),
      if (lines) ...[
        EditorPair(
          left: EditorField(
            label: l.chartEditorLineThickness,
            child: EditorStepper(
              keyName: 'lineWidth',
              value: style.lineWidth ?? 2,
              max: 8,
              onChanged: (v) => set({'lineWidth': v}, 'lineWidth'),
            ),
          ),
          right: EditorField(
            label: l.chartEditorLineDash,
            child: PanelSelect<LineDash>(
              keyName: 'chartEditor.lineDash',
              value: style.lineDash,
              options: {
                LineDash.solid: l.chartDashSolid,
                LineDash.dash: l.chartDashDash,
                LineDash.dot: l.chartDashDot,
                LineDash.dashDot: l.chartDashDashDot,
                LineDash.longDash: l.chartDashLong,
              },
              onChanged: (v) =>
                  set({'lineDash': v == LineDash.solid ? null : v.name}),
            ),
          ),
        ),
      ],
      if (points)
        EditorPair(
          left: EditorField(
            label: l.chartEditorPointSize,
            child: EditorStepper(
              keyName: 'pointSize',
              value: style.pointSize ?? (t == ChartType.scatter ? 7 : 0),
              max: 24,
              onChanged: (v) => set({'pointSize': v}, 'pointSize'),
            ),
          ),
          right: EditorField(
            label: l.chartEditorPointShape,
            child: PanelSelect<PointShape>(
              keyName: 'chartEditor.pointShape',
              value: style.pointShape,
              options: {
                for (final p in PointShape.values) p: _shapeLabel(l, p),
              },
              onChanged: (v) =>
                  set({'pointShape': v == PointShape.circle ? null : v.name}),
            ),
          ),
        ),
      if (t.isCartesian && t != ChartType.histogram)
        EditorField(
          label: l.chartEditorAxis,
          child: PanelSelect<SeriesAxis>(
            keyName: 'chartEditor.seriesAxis',
            value: style.axis,
            options: {
              SeriesAxis.left: l.chartAxisLeft,
              SeriesAxis.right: l.chartAxisRight,
            },
            onChanged: (v) =>
                set({'axis': v == SeriesAxis.left ? null : v.name}),
          ),
        ),
      if (t == ChartType.combo)
        EditorField(
          label: l.chartEditorSeriesType,
          child: PanelSelect<SeriesChartType>(
            keyName: 'chartEditor.seriesType',
            value: style.type ?? SeriesChartType.column,
            options: {
              SeriesChartType.column: l.chartTypeColumn,
              SeriesChartType.line: l.chartTypeLine,
              SeriesChartType.area: l.chartTypeArea,
            },
            onChanged: (v) => set({'type': v.name}),
          ),
        ),
      EditorCheck(
        keyName: 'dataLabels',
        label: l.chartEditorDataLabels,
        value: style.dataLabels.show,
        onChanged: (v) => set({
          'dataLabels': {'show': v ? true : null},
        }),
      ),
      if (style.dataLabels.show)
        EditorField(
          label: l.chartEditorPosition,
          child: PanelSelect<DataLabelPosition>(
            keyName: 'chartEditor.dataLabelPosition',
            value: style.dataLabels.position,
            options: {
              for (final p in DataLabelPosition.values) p: _positionLabel(l, p),
            },
            onChanged: (v) => set({
              'dataLabels': {
                'position': v == DataLabelPosition.auto ? null : v.name,
              },
            }),
          ),
        ),
      if (trend) ...[
        EditorCheck(
          keyName: 'trendline',
          label: l.chartEditorTrendline,
          value: tl != null,
          onChanged: (v) => set({
            'trendline': v ? {'type': 'linear'} : null,
          }),
        ),
        if (tl != null) ...[
          EditorField(
            label: l.chartEditorTrendlineType,
            child: PanelSelect<TrendlineType>(
              keyName: 'chartEditor.trendlineType',
              value: tl.type,
              options: {
                for (final x in TrendlineType.values) x: _trendLabel(l, x),
              },
              onChanged: (v) => set({
                'trendline': {'type': v.name},
              }),
            ),
          ),
          if (tl.type == TrendlineType.polynomial)
            EditorField(
              label: l.chartEditorTrendlineDegree,
              child: EditorStepper(
                keyName: 'trendDegree',
                value: tl.degree,
                min: 2,
                max: 10,
                onChanged: (v) => set({
                  'trendline': {'degree': v.toInt()},
                }, 'trendDegree'),
              ),
            ),
          if (tl.type == TrendlineType.movingAverage)
            EditorField(
              label: l.chartEditorTrendlinePeriod,
              child: EditorStepper(
                keyName: 'trendPeriod',
                value: tl.period,
                min: 2,
                max: 100,
                onChanged: (v) => set({
                  'trendline': {'period': v.toInt()},
                }, 'trendPeriod'),
              ),
            ),
          EditorField(
            label: l.chartEditorTrendlineLabel,
            child: PanelSelect<TrendlineLabel>(
              keyName: 'chartEditor.trendlineLabel',
              value: tl.label,
              options: {
                TrendlineLabel.none: l.chartTrendLabelNone,
                TrendlineLabel.equation: l.chartTrendLabelEquation,
                TrendlineLabel.custom: l.chartTrendLabelCustom,
              },
              onChanged: (v) => set({
                'trendline': {
                  'label': v == TrendlineLabel.none ? null : v.name,
                },
              }),
            ),
          ),
          if (tl.type != TrendlineType.movingAverage)
            EditorCheck(
              keyName: 'showR2',
              label: l.chartEditorShowR2,
              value: tl.showR2,
              onChanged: (v) => set({
                'trendline': {'showR2': v ? true : null},
              }),
            ),
          EditorField(
            label: l.chartEditorTrendlineColor,
            child: EditorColorButton(
              keyName: 'trendColor',
              value: tl.color,
              resetLabel: l.colorAutomatic,
              onChanged: (v) => set({
                'trendline': {'color': v},
              }),
            ),
          ),
        ],
      ],
      ..._seriesExtras(l, c, id, target, style, set),
    ], onReset: () => _patch(id, {'series': null}));
  }

  Widget _legend(SheetsLocalizations l, ChartSpec spec, String id) {
    final lg = spec.legend;
    return _section('legend', l.chartSectionLegend, [
      EditorField(
        label: l.chartEditorPosition,
        child: PanelSelect<LegendPosition>(
          keyName: 'chartEditor.legendPosition',
          value: lg.position,
          options: {
            LegendPosition.auto: l.chartLegendAuto,
            LegendPosition.top: l.chartLegendTop,
            LegendPosition.bottom: l.chartLegendBottom,
            LegendPosition.left: l.chartLegendLeft,
            LegendPosition.right: l.chartLegendRight,
            LegendPosition.inside: l.chartLegendInside,
            LegendPosition.none: l.chartLegendNone,
          },
          onChanged: (v) => _patch(id, {
            'legend': {'position': v == LegendPosition.auto ? null : v.name},
          }),
        ),
      ),
      _fontRow(
        l,
        'legendFont',
        lg.font,
        (f) => {
          'legend': {'font': f},
        },
      ),
    ], onReset: () => _patch(id, {'legend': null}));
  }

  Widget _axis(
    SheetsLocalizations l,
    ChartSpec spec,
    String id,
    String which,
    String title,
  ) {
    final a = which == 'h' ? spec.axes.h : spec.axes.v;
    Map<String, Object?> wrap(Map<String, Object?> m) => {
      'axes': {which: m},
    };
    // Bar charts: the value axis is horizontal (08 §3.5).
    final valueAxis = spec.type == ChartType.bar
        ? which == 'h'
        : which == 'v' ||
              spec.type == ChartType.scatter ||
              spec.type == ChartType.bubble;
    return _section(
      '${which}Axis',
      title,
      [
        _fontRow(
          l,
          '$which.labels',
          a.labels.font,
          (f) => wrap({
            'labels': {'font': f},
          }),
        ),
        EditorCheck(
          keyName: '$which.showLabels',
          label: l.chartEditorShowLabels,
          value: a.labels.show,
          onChanged: (v) => _patch(
            id,
            wrap({
              'labels': {'show': v ? null : false},
            }),
          ),
        ),
        EditorCheck(
          keyName: '$which.showLine',
          label: l.chartEditorShowAxisLine,
          value: a.showLine,
          onChanged: (v) => _patch(id, wrap({'showLine': v ? null : false})),
        ),
        EditorCheck(
          keyName: '$which.reverse',
          label: l.chartEditorReverseAxis,
          value: a.reverse,
          onChanged: (v) => _patch(id, wrap({'reverse': v ? true : null})),
        ),
        EditorField(
          label: l.chartEditorSlant,
          child: PanelSelect<LabelSlant>(
            keyName: 'chartEditor.$which.slant',
            value: a.labels.slant,
            options: {
              LabelSlant.auto: l.chartAlignAuto,
              LabelSlant.none: l.chartSlantNone,
              LabelSlant.custom: l.chartSlantCustom,
            },
            onChanged: (v) => _patch(
              id,
              wrap({
                'labels': {
                  'slant': v == LabelSlant.auto ? null : v.name,
                  if (v == LabelSlant.custom) 'angle': 45,
                },
              }),
            ),
          ),
        ),
        if (valueAxis) ...[
          EditorPair(
            left: EditorField(
              label: l.chartEditorMin,
              child: NumberCommitField(
                keyName: '$which.min',
                value: a.min,
                placeholder: l.chartAlignAuto,
                onCommit: (v) => _patch(id, wrap({'min': v})),
              ),
            ),
            right: EditorField(
              label: l.chartEditorMax,
              child: NumberCommitField(
                keyName: '$which.max',
                value: a.max,
                placeholder: l.chartAlignAuto,
                onCommit: (v) => _patch(id, wrap({'max': v})),
              ),
            ),
          ),
          EditorCheck(
            keyName: '$which.log',
            label: l.chartEditorLogScale,
            value: a.logScale,
            onChanged: (v) => _patch(id, wrap({'logScale': v ? true : null})),
          ),
          EditorField(
            label: l.chartEditorNumberFormat,
            child: CommitTextField(
              keyName: '$which.numberFormat',
              value: a.numberFormat ?? '',
              placeholder: l.chartEditorNumberFormatFromSource,
              onCommit: (v) => _patch(
                id,
                wrap({'numberFormat': v.trim().isEmpty ? null : v.trim()}),
              ),
            ),
          ),
        ],
      ],
      onReset: () => _patch(id, {
        'axes': {
          which: {
            'labels': null,
            'showLine': null,
            'reverse': null,
            'min': null,
            'max': null,
            'logScale': null,
            'numberFormat': null,
          },
        },
      }),
    );
  }

  Widget _gridlines(SheetsLocalizations l, ChartSpec spec, String id) {
    final which = _gridTarget;
    final g = which == 'h' ? spec.gridlines.h : spec.gridlines.v;
    Map<String, Object?> wrap(Map<String, Object?> m) => {
      'gridlines': {which: m},
    };
    return _section('gridlines', l.chartSectionGridlines, [
      EditorField(
        label: l.chartEditorAxis,
        child: PanelSelect<String>(
          keyName: 'chartEditor.gridTarget',
          value: which,
          options: {'v': l.chartTitleVAxis, 'h': l.chartTitleHAxis},
          onChanged: (v) => setState(() => _gridTarget = v),
        ),
      ),
      EditorCheck(
        keyName: 'grid.$which.major',
        label: l.chartEditorMajorGridlines,
        value: g.major.show ?? (which == 'v'),
        onChanged: (v) => _patch(
          id,
          wrap({
            'major': {'show': v},
          }),
        ),
      ),
      EditorPair(
        left: EditorField(
          label: l.chartEditorGridCount,
          child: NumberCommitField(
            keyName: 'grid.$which.count',
            value: g.major.count,
            placeholder: l.chartAlignAuto,
            onCommit: (v) => _patch(
              id,
              wrap({
                'major': {'count': v?.toInt().clamp(1, 20)},
              }),
            ),
          ),
        ),
        right: EditorField(
          label: l.chartEditorGridColor,
          child: EditorColorButton(
            keyName: 'grid.$which.color',
            value: g.major.color,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => _patch(
              id,
              wrap({
                'major': {'color': v},
              }),
            ),
          ),
        ),
      ),
      EditorCheck(
        keyName: 'grid.$which.minor',
        label: l.chartEditorMinorGridlines,
        value: g.minor.show ?? false,
        onChanged: (v) => _patch(
          id,
          wrap({
            'minor': {'show': v ? true : null},
          }),
        ),
      ),
      EditorPair(
        left: EditorField(
          label: l.chartEditorMajorTicks,
          child: PanelSelect<TickMark>(
            keyName: 'chartEditor.grid.$which.ticksMajor',
            value: g.ticks.major,
            options: _tickOptions(l),
            onChanged: (v) => _patch(
              id,
              wrap({
                'ticks': {'major': v == TickMark.none ? null : v.name},
              }),
            ),
          ),
        ),
        right: EditorField(
          label: l.chartEditorMinorTicks,
          child: PanelSelect<TickMark>(
            keyName: 'chartEditor.grid.$which.ticksMinor',
            value: g.ticks.minor,
            options: _tickOptions(l),
            onChanged: (v) => _patch(
              id,
              wrap({
                'ticks': {'minor': v == TickMark.none ? null : v.name},
              }),
            ),
          ),
        ),
      ),
    ], onReset: () => _patch(id, {'gridlines': null}));
  }

  Map<TickMark, String> _tickOptions(SheetsLocalizations l) => {
    TickMark.none: l.chartTickNone,
    TickMark.inside: l.chartTickInside,
    TickMark.outside: l.chartTickOutside,
  };

  Map<String, Object?> _opts(Map<String, Object?> m) => {'typeOptions': m};

  Widget _pie(SheetsLocalizations l, ChartSpec spec, String id) {
    final p = spec.pieOptions;
    final hole = (p.pieHole * 100).round();
    return _section('pie', l.chartSectionPie, [
      EditorField(
        label: l.chartEditorDoughnutHole,
        child: EditorStepper(
          keyName: 'pieHole',
          value: hole,
          max: 90,
          step: 5,
          suffix: '%',
          onChanged: (v) => _patch(
            id,
            _opts({'pieHole': v == 0 ? null : v / 100}),
            'pieHole',
          ),
        ),
      ),
      EditorField(
        label: l.chartEditorBorderColor,
        child: EditorColorButton(
          keyName: 'pieBorder',
          value: p.borderColor,
          resetLabel: l.colorAutomatic,
          onChanged: (v) => _patch(id, _opts({'borderColor': v})),
        ),
      ),
      EditorField(
        label: l.chartEditorSliceLabel,
        child: PanelSelect<SliceLabel>(
          keyName: 'chartEditor.sliceLabel',
          value: p.sliceLabel,
          options: {
            SliceLabel.none: l.chartSliceLabelNone,
            SliceLabel.label: l.chartSliceLabelLabel,
            SliceLabel.value: l.chartSliceLabelValue,
            SliceLabel.percentage: l.chartSliceLabelPercentage,
            SliceLabel.valueAndPercentage: l.chartSliceLabelBoth,
          },
          onChanged: (v) => _patch(id, _opts({'sliceLabel': v.name})),
        ),
      ),
    ], onReset: () => _patch(id, {'typeOptions': null}));
  }

  Widget _histogram(SheetsLocalizations l, ChartSpec spec, String id) {
    final h = spec.histogramOptions;
    return _section('histogram', l.chartSectionHistogram, [
      EditorField(
        label: l.chartEditorBucketSize,
        child: NumberCommitField(
          keyName: 'bucketSize',
          value: h.bucketSize,
          placeholder: l.chartAlignAuto,
          onCommit: (v) => _patch(id, _opts({'bucketSize': v})),
        ),
      ),
      EditorField(
        label: l.chartEditorOutlierPercentile,
        child: EditorStepper(
          keyName: 'outlier',
          value: h.outlierPercentile,
          max: 25,
          suffix: '%',
          onChanged: (v) =>
              _patch(id, _opts({'outlierPercentile': v}), 'outlier'),
        ),
      ),
      EditorCheck(
        keyName: 'itemDividers',
        label: l.chartEditorItemDividers,
        value: h.showItemDividers,
        onChanged: (v) =>
            _patch(id, _opts({'showItemDividers': v ? true : null})),
      ),
    ], onReset: () => _patch(id, {'typeOptions': null}));
  }

  Widget _waterfall(
    SheetsLocalizations l,
    ChartSpec spec,
    String id,
    ChartController c,
  ) {
    final w = spec.waterfallOptions;
    return _section('waterfall', l.chartSectionWaterfall, [
      EditorCheck(
        keyName: 'firstSubtotal',
        label: l.chartEditorFirstValueSubtotal,
        value: w.firstValueIsSubtotal,
        onChanged: (v) =>
            _patch(id, _opts({'firstValueIsSubtotal': v ? true : null})),
      ),
      EditorCheck(
        keyName: 'connectors',
        label: l.chartEditorConnectorLines,
        value: w.connectorShow,
        onChanged: (v) => _patch(
          id,
          _opts({
            'connectorLines': {'show': v},
          }),
        ),
      ),
      EditorPair(
        left: EditorField(
          label: l.chartEditorPositiveColor,
          child: EditorColorButton(
            keyName: 'positiveColor',
            value: w.positiveColor,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => _patch(id, _opts({'positiveColor': v})),
          ),
        ),
        right: EditorField(
          label: l.chartEditorNegativeColor,
          child: EditorColorButton(
            keyName: 'negativeColor',
            value: w.negativeColor,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => _patch(id, _opts({'negativeColor': v})),
          ),
        ),
      ),
      EditorField(
        label: l.chartEditorSubtotalColor,
        child: EditorColorButton(
          keyName: 'subtotalColor',
          value: w.subtotalColor,
          resetLabel: l.colorAutomatic,
          onChanged: (v) => _patch(id, _opts({'subtotalColor': v})),
        ),
      ),
      ..._waterfallSubtotals(l, c, id),
    ], onReset: () => _patch(id, {'typeOptions': null}));
  }

  Widget _candlestick(SheetsLocalizations l, ChartSpec spec, String id) {
    final c = spec.candlestickOptions;
    return _section('candlestick', l.chartSectionCandlestick, [
      EditorPair(
        left: EditorField(
          label: l.chartEditorRisingColor,
          child: EditorColorButton(
            keyName: 'risingColor',
            value: c.risingColor,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => _patch(id, _opts({'risingColor': v})),
          ),
        ),
        right: EditorField(
          label: l.chartEditorFallingColor,
          child: EditorColorButton(
            keyName: 'fallingColor',
            value: c.fallingColor,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => _patch(id, _opts({'fallingColor': v})),
          ),
        ),
      ),
      EditorCheck(
        keyName: 'risingFilled',
        label: l.chartEditorRisingFilled,
        value: c.risingFilled,
        onChanged: (v) => _patch(id, _opts({'risingFilled': v ? true : null})),
      ),
      EditorCheck(
        keyName: 'fallingFilled',
        label: l.chartEditorFallingFilled,
        value: c.fallingFilled,
        onChanged: (v) =>
            _patch(id, _opts({'fallingFilled': v ? null : false})),
      ),
    ], onReset: () => _patch(id, {'typeOptions': null}));
  }

  Widget _scorecard(
    SheetsLocalizations l,
    ChartSpec spec,
    String id,
    ChartController c,
  ) {
    final s = spec.scorecardOptions;
    return _section('scorecard', l.chartSectionScorecard, [
      EditorField(
        label: l.chartEditorCompareMode,
        child: PanelSelect<ScorecardCompareMode>(
          keyName: 'chartEditor.scoreCompare',
          value: s.compareMode,
          options: {
            ScorecardCompareMode.absolute: l.chartScoreAbsolute,
            ScorecardCompareMode.percent: l.chartScorePercent,
          },
          onChanged: (v) => _patch(id, _opts({'compareMode': v.name})),
        ),
      ),
      EditorField(
        label: l.chartEditorAggregate,
        child: PanelSelect<ChartAggregate>(
          keyName: 'chartEditor.scoreAggregate',
          value: s.aggregate,
          options: {
            for (final a in ChartAggregate.values) a: _aggregateLabel(l, a),
          },
          onChanged: (v) => _patch(id, _opts({'aggregate': v.name})),
        ),
      ),
      EditorPair(
        left: EditorField(
          label: l.chartEditorPositiveColor,
          child: EditorColorButton(
            keyName: 'scorePositive',
            value: s.positiveColor,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => _patch(id, _opts({'positiveColor': v})),
          ),
        ),
        right: EditorField(
          label: l.chartEditorNegativeColor,
          child: EditorColorButton(
            keyName: 'scoreNegative',
            value: s.negativeColor,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => _patch(id, _opts({'negativeColor': v})),
          ),
        ),
      ),
      EditorField(
        label: l.chartEditorNumberFormat,
        child: CommitTextField(
          keyName: 'keyFormat',
          value: s.keyFormat ?? '',
          placeholder: l.chartEditorNumberFormatFromSource,
          onCommit: (v) =>
              _patch(id, _opts({'keyFormat': v.trim().isEmpty ? null : v})),
        ),
      ),
      ..._scorecardRefs(l, c, id),
    ], onReset: () => _patch(id, {'typeOptions': null}));
  }

  Widget _table(SheetsLocalizations l, ChartSpec spec, String id) {
    final t = spec.tableOptions;
    return _section('table', l.chartSectionTable, [
      EditorField(
        label: l.chartEditorPageSize,
        child: EditorStepper(
          keyName: 'pageSize',
          value: t.pageSize,
          max: 500,
          step: 5,
          onChanged: (v) =>
              _patch(id, _opts({'pageSize': v == 0 ? null : v}), 'pageSize'),
        ),
      ),
      EditorCheck(
        keyName: 'rowNumbers',
        label: l.chartEditorRowNumbers,
        value: t.showRowNumbers,
        onChanged: (v) =>
            _patch(id, _opts({'showRowNumbers': v ? true : null})),
      ),
      EditorCheck(
        keyName: 'alternating',
        label: l.chartEditorAlternatingColors,
        value: t.alternatingColors,
        onChanged: (v) =>
            _patch(id, _opts({'alternatingColors': v ? null : false})),
      ),
      EditorCheck(
        keyName: 'formatFromSource',
        label: l.chartEditorFormatFromSource,
        value: t.formatFromSource,
        onChanged: (v) =>
            _patch(id, _opts({'formatFromSource': v ? null : false})),
      ),
    ], onReset: () => _patch(id, {'typeOptions': null}));
  }

  String _shapeLabel(SheetsLocalizations l, PointShape p) => switch (p) {
    PointShape.circle => l.chartShapeCircle,
    PointShape.triangle => l.chartShapeTriangle,
    PointShape.square => l.chartShapeSquare,
    PointShape.diamond => l.chartShapeDiamond,
    PointShape.star => l.chartShapeStar,
    PointShape.polygon => l.chartShapePolygon,
  };

  String _positionLabel(SheetsLocalizations l, DataLabelPosition p) =>
      switch (p) {
        DataLabelPosition.auto => l.chartAlignAuto,
        DataLabelPosition.center => l.chartAlignCenter,
        DataLabelPosition.insideEnd => l.chartLabelInsideEnd,
        DataLabelPosition.insideBase => l.chartLabelInsideBase,
        DataLabelPosition.outsideEnd => l.chartLabelOutsideEnd,
        DataLabelPosition.above => l.chartLabelAbove,
        DataLabelPosition.below => l.chartLabelBelow,
        DataLabelPosition.left => l.chartAlignLeft,
        DataLabelPosition.right => l.chartAlignRight,
      };

  String _trendLabel(SheetsLocalizations l, TrendlineType t) => switch (t) {
    TrendlineType.linear => l.chartTrendLinear,
    TrendlineType.exponential => l.chartTrendExponential,
    TrendlineType.polynomial => l.chartTrendPolynomial,
    TrendlineType.logarithmic => l.chartTrendLogarithmic,
    TrendlineType.power => l.chartTrendPower,
    TrendlineType.movingAverage => l.chartTrendMovingAverage,
  };
}

/// A series / X-axis chip with a ⋮ menu (08 §8.1).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.keyName,
    required this.label,
    required this.menu,
    this.swatch,
    this.icon,
  });

  final String keyName;
  final String label;
  final List<WonkyMenuEntry> menu;
  final Color? swatch;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      key: ValueKey<String>(keyName),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (swatch != null)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else if (icon != null)
            Icon(icon, size: 14, color: theme.colorScheme.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.small,
            ),
          ),
          WonkyDropdownMenu(
            entries: () => menu,
            builder: (context, controller) => ShadIconButton.ghost(
              key: ValueKey<String>('$keyName.menu'),
              width: 28,
              height: 28,
              iconSize: 15,
              icon: const Icon(LucideIcons.ellipsisVertical),
              onPressed: controller.toggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSeriesButton extends StatelessWidget {
  const _AddSeriesButton({
    required this.label,
    required this.columns,
    required this.onAdd,
  });

  final String label;
  final List<_Column> columns;
  final ValueChanged<_Column> onAdd;

  @override
  Widget build(BuildContext context) => WonkyDropdownMenu(
    entries: () => [
      for (final c in columns)
        WonkyMenuItem(
          key: ValueKey<String>('chartEditor.addSeries.${c.key}'),
          label: c.name,
          onSelected: () => onAdd(c),
        ),
    ],
    builder: (context, controller) => ShadButton.ghost(
      key: const ValueKey<String>('chartEditor.addSeries'),
      size: ShadButtonSize.sm,
      leading: const Icon(LucideIcons.plus, size: 14),
      onPressed: controller.toggle,
      child: Text(label),
    ),
  );
}
