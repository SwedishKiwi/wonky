part of 'chart_editor_panel.dart';

/// Chart editor fields of phase 4 (08 §8.2): *Format data point*, error
/// bars and custom trendline labels in *Series*, the *Pie slice* section,
/// waterfall subtotals and scorecard key/baseline cells.
extension _ChartEditorMore on _ChartEditorPanelState {
  /// A short label of domain point [i] ("3 · March").
  String _pointLabel(ChartData data, int i) {
    final labels = data.domain.labels;
    final name = i < labels.length ? labels[i].trim() : '';
    return name.isEmpty ? '${i + 1}' : '${i + 1} · $name';
  }

  /// Options of a domain point select (capped for huge domains).
  Map<int, String> _pointOptions(ChartData data) => {
    for (var i = 0; i < math.min(data.domain.length, 500); i++)
      i: _pointLabel(data, i),
  };

  /// *Series* extras: custom trendline label, error bars and *Format data
  /// point* (one series selected).
  List<Widget> _seriesExtras(
    SheetsLocalizations l,
    ChartController c,
    String id,
    String target,
    SeriesStyle style,
    void Function(Map<String, Object?> m, [String? key]) set,
  ) {
    final t = c.spec.type;
    final tl = style.trendline;
    final stacked =
        c.spec.stacking != ChartStacking.none &&
        (t == ChartType.column ||
            t == ChartType.bar ||
            t == ChartType.area ||
            t == ChartType.combo);
    final errorBarsOk =
        !stacked &&
        (t == ChartType.column ||
            t == ChartType.bar ||
            t == ChartType.line ||
            t == ChartType.scatter ||
            t == ChartType.combo);
    final eb = ErrorBarsSpec.fromJson(style.errorBars);
    final data = c.data;
    final pointsOk =
        target.isNotEmpty &&
        data.domain.length > 0 &&
        t != ChartType.pie &&
        t.isCartesian;
    final formatted = style.points.keys.toList()..sort();
    final pick = _pointIndex != null && _pointIndex! < data.domain.length
        ? _pointIndex!
        : null;
    return [
      if (tl != null && tl.label == TrendlineLabel.custom)
        EditorField(
          label: l.chartEditorTrendlineCustomLabel,
          child: CommitTextField(
            keyName: 'trendCustomLabel',
            value: tl.customLabel,
            placeholder: l.chartEditorTrendlineCustomLabelHint,
            onCommit: (v) => set({
              'trendline': {'customLabel': v.trim().isEmpty ? null : v},
            }),
          ),
        ),
      if (errorBarsOk) ...[
        EditorCheck(
          keyName: 'errorBars',
          label: l.chartEditorErrorBars,
          value: eb != null,
          onChanged: (v) => set({
            'errorBars': v ? {'type': 'constant', 'value': 10} : null,
          }),
        ),
        if (eb != null)
          EditorPair(
            left: EditorField(
              label: l.chartEditorErrorBarsType,
              child: PanelSelect<ErrorBarType>(
                keyName: 'chartEditor.errorBarsType',
                value: eb.type,
                options: {
                  ErrorBarType.constant: l.chartErrorBarsConstant,
                  ErrorBarType.percent: l.chartErrorBarsPercent,
                  ErrorBarType.stdev: l.chartErrorBarsStdev,
                },
                onChanged: (v) => set({
                  'errorBars': {
                    'type': v.name,
                    'value': v == ErrorBarType.stdev ? 1 : 10,
                  },
                }),
              ),
            ),
            right: EditorField(
              label: l.chartEditorErrorBarsValue,
              child: NumberCommitField(
                keyName: 'errorBarsValue',
                value: eb.value,
                onCommit: (v) => set({
                  'errorBars': {'value': v == null || v < 0 ? 0 : v},
                }),
              ),
            ),
          ),
      ],
      if (pointsOk) ...[
        EditorField(
          label: l.chartEditorFormatDataPoint,
          child: Row(
            children: [
              Expanded(
                child: PanelSelect<int>(
                  keyName: 'chartEditor.pointPick',
                  value: pick ?? -1,
                  options: {-1: l.chartEditorPickPoint, ..._pointOptions(data)},
                  onChanged: (v) => _setPointIndex(v < 0 ? null : v),
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                key: const ValueKey<String>('chartEditor.pointAdd'),
                size: ShadButtonSize.sm,
                enabled: pick != null && !style.points.containsKey(pick),
                onPressed: () {
                  final i = pick;
                  if (i == null) return;
                  set({
                    'points': {
                      '$i': {'color': _defaultPointColor(c, target)},
                    },
                  });
                },
                child: Text(l.chartEditorAdd),
              ),
            ],
          ),
        ),
        for (final i in formatted)
          Padding(
            key: ValueKey<String>('chartEditor.point.$i'),
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _pointLabel(data, i),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: EditorColorButton(
                    keyName: 'pointColor.$i',
                    value: style.points[i]?.color,
                    resetLabel: l.colorAutomatic,
                    onChanged: (v) => set({
                      'points': {
                        '$i': v == null ? null : {'color': v},
                      },
                    }),
                  ),
                ),
                ShadIconButton.ghost(
                  key: ValueKey<String>('chartEditor.pointRemove.$i'),
                  width: 28,
                  height: 28,
                  iconSize: 14,
                  semanticLabel: l.chartEditorRemove,
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => set({
                    'points': {'$i': null},
                  }),
                ),
              ],
            ),
          ),
      ],
    ];
  }

  /// The series' current color as `#RRGGBB` (start color of a new point
  /// format).
  String _defaultPointColor(ChartController c, String key) {
    final own = c.spec.seriesStyle(key).color;
    if (own != null) return own;
    final i = c.data.series.indexWhere((s) => s.key == key);
    final palette = ChartTheme.from(ed.model.theme).palette;
    final argb = palette[(i < 0 ? 0 : i) % palette.length];
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// *Pie slice* (08 §8.2): slice select, color, distance from center.
  Widget _pieSlices(SheetsLocalizations l, ChartController c, String id) {
    final data = c.data;
    final p = c.spec.pieOptions;
    final n = data.domain.length;
    final slice = n == 0 ? 0 : _slice.clamp(0, n - 1);
    final st = p.slices[slice];
    Map<String, Object?> wrap(Map<String, Object?>? m) => {
      'typeOptions': {
        'slices': {'$slice': m},
      },
    };
    return _section(
      'pieSlice',
      l.chartSectionPieSlice,
      [
        EditorField(
          label: l.chartEditorSlice,
          child: PanelSelect<int>(
            keyName: 'chartEditor.slice',
            value: slice,
            options: n == 0 ? {0: '—'} : _pointOptions(data),
            onChanged: _setSlice,
          ),
        ),
        EditorField(
          label: l.chartEditorSliceColor,
          child: EditorColorButton(
            keyName: 'sliceColor',
            value: st?.color,
            resetLabel: l.colorAutomatic,
            onChanged: (v) => _patch(
              id,
              wrap(
                v == null && (st?.offset ?? 0) == 0
                    ? null
                    : {
                        'color': v,
                        if ((st?.offset ?? 0) > 0) 'offset': st!.offset,
                      },
              ),
            ),
          ),
        ),
        EditorField(
          label: l.chartEditorSliceDistance,
          child: EditorStepper(
            keyName: 'sliceOffset',
            value: ((st?.offset ?? 0) * 100).round(),
            max: 100,
            step: 5,
            suffix: '%',
            onChanged: (v) => _patch(
              id,
              wrap(
                v == 0 && st?.color == null
                    ? null
                    : {'offset': v == 0 ? null : v / 100, 'color': ?st?.color},
              ),
              'slice.$slice.offset',
            ),
          ),
        ),
      ],
      onReset: () => _patch(id, {
        'typeOptions': {'slices': null},
      }),
    );
  }

  /// Waterfall subtotals (08 §8.2): one row per subtotal (after which
  /// point, label) and *Add subtotal*.
  List<Widget> _waterfallSubtotals(
    SheetsLocalizations l,
    ChartController c,
    String id,
  ) {
    final w = c.spec.waterfallOptions;
    final data = c.data;
    final subs = w.subtotals;
    void write(List<WaterfallSubtotal> next) => _patch(id, {
      'typeOptions': {
        'subtotals': next.isEmpty ? null : [for (final s in next) s.toJson()],
      },
    });
    final used = {for (final s in subs) s.afterIndex};
    final free = [
      for (var i = 0; i < data.domain.length; i++)
        if (!used.contains(i)) i,
    ];
    return [
      EditorField(
        label: l.chartEditorSubtotals,
        child: subs.isEmpty
            ? Text(
                l.chartEditorNoSubtotals,
                style: ShadTheme.of(context).textTheme.muted,
              )
            : const SizedBox.shrink(),
      ),
      for (var k = 0; k < subs.length; k++)
        Padding(
          key: ValueKey<String>('chartEditor.subtotal.$k'),
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PanelSelect<int>(
                  keyName: 'chartEditor.subtotalAfter.$k',
                  value: subs[k].afterIndex,
                  options: {
                    for (final i in [subs[k].afterIndex, ...free]..sort())
                      if (i < data.domain.length || i == subs[k].afterIndex)
                        i: l.chartEditorSubtotalAfter(_pointLabel(data, i)),
                  },
                  onChanged: (v) => write([
                    for (var j = 0; j < subs.length; j++)
                      j == k
                          ? WaterfallSubtotal(
                              afterIndex: v,
                              label: subs[j].label,
                            )
                          : subs[j],
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CommitTextField(
                  keyName: 'subtotalLabel.$k',
                  value: subs[k].label,
                  placeholder: l.chartEditorSubtotalLabel,
                  onCommit: (v) => write([
                    for (var j = 0; j < subs.length; j++)
                      j == k
                          ? WaterfallSubtotal(
                              afterIndex: subs[j].afterIndex,
                              label: v.trim(),
                            )
                          : subs[j],
                  ]),
                ),
              ),
              ShadIconButton.ghost(
                key: ValueKey<String>('chartEditor.subtotalRemove.$k'),
                width: 28,
                height: 28,
                iconSize: 14,
                semanticLabel: l.chartEditorRemove,
                icon: const Icon(LucideIcons.x),
                onPressed: () => write([
                  for (var j = 0; j < subs.length; j++)
                    if (j != k) subs[j],
                ]),
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: const ValueKey<String>('chartEditor.subtotalAdd'),
            size: ShadButtonSize.sm,
            enabled: free.isNotEmpty,
            leading: const Icon(LucideIcons.plus, size: 14),
            onPressed: () =>
                write([...subs, WaterfallSubtotal(afterIndex: free.last)]),
            child: Text(l.chartEditorAddSubtotal),
          ),
        ),
      ),
    ];
  }

  /// Scorecard key value and baseline cells (08 §8.2): A1 of a cell
  /// (empty = from the data range).
  List<Widget> _scorecardRefs(
    SheetsLocalizations l,
    ChartController c,
    String id,
  ) {
    final s = c.spec.scorecardOptions;
    String a1(GridRange? g) {
      if (g == null) return '';
      final rr = ed.model.sheet(g.sheetId)?.resolve(g);
      return rr == null
          ? ''
          : ed.model.a1Of(rr, includeSheet: g.sheetId != ed.activeSheetId);
    }

    void commit(String key, String text) {
      final t = text.trim();
      if (t.isEmpty) {
        _patch(id, {
          'typeOptions': {key: null},
        });
        return;
      }
      try {
        final g = ChartInsert.rangesFromA1(ed, [t]);
        if (g.isEmpty) return;
        _patch(id, {
          'typeOptions': {key: g.first.toJson()},
        });
      } catch (_) {
        widget.services.toasts.error(l.chartEditorInvalidCell);
      }
    }

    return [
      EditorField(
        label: l.chartEditorKeyValueCell,
        child: CommitTextField(
          keyName: 'scoreKeyRef',
          value: a1(s.keyValueRef),
          placeholder: l.chartEditorFromDataRange,
          onCommit: (v) => commit('keyValueRef', v),
        ),
      ),
      EditorField(
        label: l.chartEditorBaselineCell,
        child: CommitTextField(
          keyName: 'scoreBaselineRef',
          value: a1(s.baselineRef),
          placeholder: l.chartEditorFromDataRange,
          onCommit: (v) => commit('baselineRef', v),
        ),
      ),
    ];
  }
}
