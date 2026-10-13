part of 'chart_layout_engine.dart';

void _layoutCartesian(_Ctx c, ChartRect region) => _Cartesian(c, region).run();

/// A value axis being laid out.
final class _ValueAxis {
  _ValueAxis(this.id, this.spec, this.grid);

  /// `v`, `v2` (vertical charts) or `h` (bar charts).
  final String id;
  final ChartAxis spec;
  final AxisGridlines grid;
  double lo = double.infinity;
  double hi = -double.infinity;
  bool includeZero = false;
  bool percent = false;
  bool integer = false;
  String? sourceFormat;
  late ChartScale scale;
  late String pattern;
  List<String> labels = const [];
  double labelWidth = 0;
  double labelHeight = 0;

  bool get used => lo <= hi;

  void add(double v) {
    if (v.isNaN || v.isInfinite) return;
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
}

/// A waterfall bar.
final class _WaterfallItem {
  _WaterfallItem(this.label, this.from, this.to, this.kind, this.pointIndex);

  final String label;
  final double from;
  final double to;

  /// 'pos', 'neg', 'total'.
  final String kind;
  final int pointIndex;
}

final class _Cartesian {
  _Cartesian(this.c, this.region);

  final _Ctx c;
  final ChartRect region;

  ChartSpec get spec => c.spec;
  ChartData get data => c.data;
  ChartType get type => spec.type;
  bool get horizontal => type == ChartType.bar;

  List<_SeriesInfo> get series => c.seriesInfos;

  // Domain axis state.
  late final bool band;
  late int count;
  late List<String> domainLabels;
  double domLo = 0, domHi = 1;
  bool timeDomain = false;
  late Float64List domainValues;
  ChartScale? domScale;
  BandScale? bandScale;
  String domPattern = '';
  Float64List domTicks = Float64List(0);
  final List<ScenePrimitive> domLabelPrims = [];

  // Value axes.
  late final _ValueAxis left;
  late final _ValueAxis right;

  // Stacking.
  final Map<String, Float64List> base = {};
  final Map<String, Float64List> top = {};

  // Waterfall / histogram.
  List<_WaterfallItem> waterfall = const [];

  late ChartRect plot;

  ChartAxis get domainAxisSpec => horizontal ? spec.axes.v : spec.axes.h;
  AxisGridlines get domainGrid =>
      horizontal ? spec.gridlines.v : spec.gridlines.h;

  void run() {
    _prepareDomain();
    _prepareValues();
    _layoutAxes();
    c.plotArea = plot;
    _drawGridlines();
    final body = <ScenePrimitive>[];
    switch (type) {
      case ChartType.histogram:
        _drawHistogram(body);
      case ChartType.candlestick:
        _drawCandlesticks(body);
      case ChartType.waterfall:
        _drawWaterfall(body);
      case ChartType.bubble:
        _drawBubbles(body);
      default:
        _drawSeries(body);
    }
    c.out.add(
      SClip(plot.inflate(1), body, tag: const SceneTag(SceneRole.plotArea)),
    );
    _drawAxes();
    _drawDataLabels();
  }

  // ---------------------------------------------------------------------------
  // Domain.

  void _prepareDomain() {
    final d = data.domain;
    count = d.length;
    domainLabels = d.labels;
    domainValues = d.values;
    final hasColumns = series.any((s) => s.mark == _Mark.column);
    switch (type) {
      case ChartType.histogram:
        final hd = data.histogram!;
        band = false;
        count = hd.bucketCount;
        domLo = hd.start;
        domHi = hd.edge(hd.bucketCount);
        return;
      case ChartType.waterfall:
        band = true;
        _prepareWaterfall();
        count = waterfall.length;
        domainLabels = [for (final w in waterfall) w.label];
        return;
      case ChartType.scatter:
        band = false;
        if (!d.isContinuous || spec.data.treatLabelsAsText) {
          domainValues = Regression.categoricalX(count);
        }
        timeDomain =
            d.kind == DomainKind.dateTime && !spec.data.treatLabelsAsText;
      case ChartType.bubble:
        band = false;
        domainValues = data.series.isEmpty
            ? Float64List(count)
            : data.series.first.values;
      case ChartType.line || ChartType.area || ChartType.combo:
        band =
            !(d.isContinuous &&
                !spec.data.treatLabelsAsText &&
                !hasColumns &&
                !d.isSynthetic);
        timeDomain = !band && d.kind == DomainKind.dateTime;
      default:
        band = true;
    }
    if (!band) {
      var lo = double.infinity, hi = -double.infinity;
      for (final v in domainValues) {
        if (!v.isFinite) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
      if (lo > hi) {
        lo = 0;
        hi = 1;
      }
      domLo = lo;
      domHi = hi;
    }
  }

  void _prepareWaterfall() {
    final o = spec.waterfallOptions;
    final s = data.series.isEmpty ? null : data.series.first;
    final items = <_WaterfallItem>[];
    if (s == null) {
      waterfall = items;
      return;
    }
    var total = 0.0;
    final subs = {for (final st in o.subtotals) st.afterIndex: st.label};
    for (var i = 0; i < s.length; i++) {
      final v = s.values[i].isNaN ? 0.0 : s.values[i];
      if (i == 0 && o.firstValueIsSubtotal) {
        items.add(_WaterfallItem(data.domain.labels[i], 0, v, 'total', i));
        total = v;
      } else {
        items.add(
          _WaterfallItem(
            data.domain.labels[i],
            total,
            total + v,
            v >= 0 ? 'pos' : 'neg',
            i,
          ),
        );
        total += v;
      }
      if (subs.containsKey(i)) {
        final label = subs[i]!;
        items.add(
          _WaterfallItem(
            label.isEmpty ? 'Subtotal' : label,
            0,
            total,
            'total',
            i,
          ),
        );
      }
    }
    waterfall = items;
  }

  // ---------------------------------------------------------------------------
  // Values.

  void _prepareValues() {
    final vSpec = horizontal ? spec.axes.h : spec.axes.v;
    final vGrid = horizontal ? spec.gridlines.h : spec.gridlines.v;
    left = _ValueAxis(horizontal ? 'h' : 'v', vSpec, vGrid);
    right = _ValueAxis('v2', spec.axes.v2, spec.gridlines.v);
    switch (type) {
      case ChartType.histogram:
        final hd = data.histogram!;
        left
          ..includeZero = true
          ..integer = true;
        for (final cs in hd.counts) {
          for (final v in cs) {
            left.add(v.toDouble());
          }
        }
        left.add(0);
        return;
      case ChartType.waterfall:
        left.includeZero = true;
        for (final w in waterfall) {
          left
            ..add(w.from)
            ..add(w.to);
        }
        left.sourceFormat = data.series.isEmpty
            ? null
            : data.series.first.numberFormat;
        return;
      case ChartType.candlestick:
        for (final s in data.series) {
          for (final v in s.values) {
            left.add(v);
          }
        }
        left.sourceFormat = data.series.isEmpty
            ? null
            : data.series.first.numberFormat;
        return;
      case ChartType.bubble:
        if (data.series.length > 1) {
          for (final v in data.series[1].values) {
            left.add(v);
          }
          left.sourceFormat = data.series[1].numberFormat;
        }
        return;
      default:
        break;
    }
    final stacking = type.supportsStacking ? spec.stacking : ChartStacking.none;
    final n = count;
    // Stack groups: (mark, axis).
    final groups = <String, List<_SeriesInfo>>{};
    for (final s in series) {
      final stacked =
          stacking != ChartStacking.none &&
          (s.mark == _Mark.column || s.mark == _Mark.area);
      final g = stacked ? '${s.mark.name}:${s.rightAxis}' : 'single:${s.key}';
      (groups[g] ??= []).add(s);
    }
    for (final entry in groups.entries) {
      final members = entry.value;
      final stacked = entry.key.startsWith('single:') == false;
      Float64List? totals;
      if (stacked && stacking == ChartStacking.percent) {
        totals = Float64List(n);
        for (final s in members) {
          for (var i = 0; i < n; i++) {
            final v = s.series.values[i];
            if (!v.isNaN) totals[i] += v.abs();
          }
        }
      }
      final pos = Float64List(n);
      final neg = Float64List(n);
      for (final s in members) {
        final b = Float64List(n);
        final t = Float64List(n);
        for (var i = 0; i < n; i++) {
          var v = s.series.values[i];
          if (v.isNaN &&
              (spec.data.emptyCells == EmptyCellMode.zero ||
                  spec.style.plotNullValues)) {
            v = 0;
          }
          if (totals != null && !v.isNaN) {
            v = totals[i] == 0 ? 0 : v / totals[i];
          }
          if (!stacked) {
            b[i] = 0;
            t[i] = v;
          } else if (v.isNaN) {
            b[i] = double.nan;
            t[i] = double.nan;
          } else if (v >= 0) {
            b[i] = pos[i];
            pos[i] += v;
            t[i] = pos[i];
          } else {
            b[i] = neg[i];
            neg[i] += v;
            t[i] = neg[i];
          }
        }
        base[s.key] = b;
        top[s.key] = t;
        final axis = s.rightAxis ? right : left;
        if (totals != null) axis.percent = true;
        axis.sourceFormat ??= s.series.numberFormat;
        if (s.mark == _Mark.column || s.mark == _Mark.area) {
          axis.includeZero = true;
        }
        for (var i = 0; i < n; i++) {
          axis.add(t[i]);
          if (stacked) axis.add(b[i]);
        }
        // Trendlines extend the range a little.
      }
    }
    if (left.includeZero) left.add(0);
    if (right.includeZero && right.used) right.add(0);
  }

  // ---------------------------------------------------------------------------
  // Axes layout.

  TextStyleSpec get labelStyle =>
      c.font(domainAxisSpec.labels.font, size: 12, color: c.theme.mutedText);

  TextStyleSpec valueLabelStyle(_ValueAxis a) =>
      c.font(a.spec.labels.font, size: 12, color: c.theme.mutedText);

  TextStyleSpec axisTitleStyle(ChartAxis a) =>
      c.font(a.title.font, size: 12, bold: true, color: c.theme.text);

  void _buildValueScale(_ValueAxis a, double r0, double r1, double lengthPx) {
    final tickTarget = math.max(
      2,
      (lengthPx / (horizontal ? 90 : 45)).floor() + 1,
    );
    var lo = a.used ? a.lo : 0.0;
    var hi = a.used ? a.hi : 1.0;
    if (a.spec.logScale) {
      if (lo <= 0) {
        var minPos = double.infinity;
        for (final s in series) {
          if ((s.rightAxis ? right : left) != a) continue;
          for (final v in top[s.key] ?? s.series.values) {
            if (v > 0 && v < minPos) minPos = v;
          }
        }
        if (lo <= 0 &&
            a.used &&
            !c.warnings.any(
              (w) => w.code == ChartWarningCode.logNonPositiveSkipped,
            )) {
          c.warnings.add(
            const ChartWarning(
              ChartWarningCode.logNonPositiveSkipped,
              'Values ≤ 0 are skipped on a log scale',
            ),
          );
        }
        lo = minPos.isFinite ? minPos : 1;
        if (hi < lo) hi = lo * 10;
      }
      final nr = NiceTicks.log(
        a.spec.min != null && a.spec.min! > 0 ? a.spec.min! : lo,
        a.spec.max ?? hi,
      );
      final (s0, s1) = a.spec.reverse ? (r1, r0) : (r0, r1);
      a.scale = LogScale(nr.min, nr.max, s0, s1, ticks: nr.ticks);
      a.pattern = a.spec.numberFormat ?? _valuePattern(a, 0);
    } else {
      final nr = NiceTicks.compute(
        lo,
        hi,
        target: tickTarget,
        fixedMin: a.spec.min,
        fixedMax: a.spec.max,
        count: a.grid.major.count,
        spacing:
            a.grid.major.spacing ??
            (a.integer && hi - lo < tickTarget ? 1 : null),
      );
      final (s0, s1) = a.spec.reverse ? (r1, r0) : (r0, r1);
      a.scale = LinearScale(nr.min, nr.max, s0, s1, ticks: nr.ticks);
      a.pattern = a.spec.numberFormat ?? _valuePattern(a, nr.decimals);
    }
    final style = valueLabelStyle(a);
    a.labels = [for (final t in a.scale.ticks) c.formatValue(t, a.pattern)];
    a.labelWidth = 0;
    for (final l in a.labels) {
      a.labelWidth = math.max(a.labelWidth, c.measure(l, style).width);
    }
    a.labelHeight = c.measure('0', style).height;
    if (!a.spec.labels.show) {
      a.labelWidth = 0;
      a.labelHeight = 0;
    }
  }

  String _valuePattern(_ValueAxis a, int decimals) {
    if (a.percent) {
      return ChartFormats.tickPattern(math.max(0, decimals - 2), percent: true);
    }
    final f = a.sourceFormat;
    if (f != null && f != 'preset:automatic' && !ChartFormats.isDateTime(f)) {
      if (ChartFormats.isPercent(f)) {
        return ChartFormats.tickPattern(
          math.max(0, decimals - 2),
          percent: true,
        );
      }
      return f;
    }
    if (f != null && ChartFormats.isDateTime(f)) return f;
    return ChartFormats.tickPattern(decimals);
  }

  void _buildDomainScale(double r0, double r1) {
    final reverse = domainAxisSpec.reverse;
    final (s0, s1) = reverse ? (r1, r0) : (r0, r1);
    if (band) {
      bandScale = BandScale(count, s0, s1);
      return;
    }
    final len = (r1 - r0).abs();
    final target = math.max(2, (len / (horizontal ? 45 : 90)).floor() + 1);
    final a = domainAxisSpec;
    if (type == ChartType.histogram) {
      final hd = data.histogram!;
      final ticks = <double>[];
      final every = math.max(
        1,
        (hd.bucketCount / math.max(1, target - 1)).ceil(),
      );
      for (var i = 0; i <= hd.bucketCount; i += every) {
        ticks.add(hd.edge(i));
      }
      domScale = LinearScale(
        domLo,
        domHi,
        s0,
        s1,
        ticks: Float64List.fromList(ticks),
      );
      domTicks = domScale!.ticks;
      domPattern =
          a.numberFormat ??
          ChartFormats.tickPattern(
            NiceTicks.decimalsFor(hd.bucketSize * every),
          );
      if (data.series.isNotEmpty && a.numberFormat == null) {
        final f = data.series.first.numberFormat;
        if (f != null &&
            f != 'preset:automatic' &&
            !ChartFormats.isPercent(f)) {
          domPattern = f;
        }
      }
      return;
    }
    if (timeDomain && !a.logScale) {
      var lo = a.min ?? domLo, hi = a.max ?? domHi;
      if (hi <= lo) hi = lo + 1;
      final (ticks, pattern) = TimeTicks.compute(lo, hi, target);
      domScale = LinearScale(lo, hi, s0, s1, ticks: ticks);
      domTicks = ticks;
      domPattern = a.numberFormat ?? pattern;
      return;
    }
    if (a.logScale) {
      final lo = domLo > 0 ? domLo : 1.0;
      final nr = NiceTicks.log(
        a.min != null && a.min! > 0 ? a.min! : lo,
        a.max ?? domHi,
      );
      domScale = LogScale(nr.min, nr.max, s0, s1, ticks: nr.ticks);
      domTicks = nr.ticks;
      domPattern = a.numberFormat ?? ChartFormats.tickPattern(0);
      return;
    }
    final nr = NiceTicks.compute(
      domLo,
      domHi,
      target: target,
      fixedMin: a.min,
      fixedMax: a.max,
      count: domainGrid.major.count,
      spacing: domainGrid.major.spacing,
    );
    domScale = LinearScale(nr.min, nr.max, s0, s1, ticks: nr.ticks);
    domTicks = nr.ticks;
    final f = type == ChartType.bubble
        ? (data.series.isEmpty ? null : data.series.first.numberFormat)
        : data.domain.numberFormat;
    domPattern =
        a.numberFormat ??
        (f != null && f != 'preset:automatic'
            ? f
            : ChartFormats.tickPattern(nr.decimals));
  }

  /// Domain label layout result: rotation and skip step, plus the reserved extent.
  (double angle, int step, double extent, List<String> labels) _domainLabelPlan(
    double length,
  ) {
    final a = domainAxisSpec;
    if (!a.labels.show) return (0, 1, 0, const []);
    final style = labelStyle;
    final lineH = c.measure('Ag', style).height;
    if (!band) {
      final labels = [for (final t in domTicks) c.formatValue(t, domPattern)];
      return (0, 1, horizontal ? _maxWidth(labels, style) : lineH, labels);
    }
    if (count == 0) return (0, 1, 0, const []);
    final bw = length / count;
    if (horizontal) {
      final maxW = math.min(_maxWidth(domainLabels, style), region.width * 0.3);
      final step = math.max(1, (lineH * 1.1 / math.max(bw, 0.01)).ceil());
      return (
        0,
        step,
        maxW,
        [
          for (final l in domainLabels)
            c.measurer.ellipsize(l, style, maxW + 0.5),
        ],
      );
    }
    final maxW = _maxWidth(domainLabels, style);
    double angle;
    switch (a.labels.slant) {
      case LabelSlant.custom:
        angle = a.labels.angle.clamp(-90.0, 90.0) * math.pi / 180;
      case LabelSlant.none:
        angle = 0;
      case LabelSlant.auto:
        angle = maxW <= bw * 0.95 ? 0 : -math.pi / 6;
        if (angle != 0 &&
            lineH / math.sin(angle.abs()) > bw * 1.5 &&
            maxW > bw * 3) {
          angle = -math.pi / 4;
        }
    }
    if (angle == 0) {
      final step = math.max(1, ((maxW + 6) / math.max(bw, 0.01)).ceil());
      return (0, step, lineH, domainLabels);
    }
    final s = math.sin(angle.abs()), co = math.cos(angle.abs());
    final maxLen = math.min(maxW, region.height * 0.3 / math.max(s, 0.2));
    final labels = [
      for (final l in domainLabels)
        c.measurer.ellipsize(l, style, maxLen + 0.5),
    ];
    final step = math.max(
      1,
      (lineH * 1.1 / math.max(s, 0.05) / math.max(bw, 0.01)).ceil(),
    );
    final extent = math.min(maxW, maxLen) * s + lineH * co;
    return (angle, step, extent, labels);
  }

  double _maxWidth(List<String> labels, TextStyleSpec style) {
    var w = 0.0;
    final step = labels.length > 2000 ? (labels.length / 2000).ceil() : 1;
    for (var i = 0; i < labels.length; i += step) {
      final m = c.measure(labels[i], style).width;
      if (m > w) w = m;
    }
    return w;
  }

  double _titleExtent(ChartAxis a) =>
      a.title.hasText ? c.measure('Ag', axisTitleStyle(a)).height + 6 : 0;

  late (double, int, double, List<String>) _domPlan;

  void _layoutAxes() {
    final r = region;
    final hasRight = !horizontal && right.used;
    if (!horizontal) {
      // Pass 1 estimate.
      _buildValueScale(left, r.bottom - 30, r.top, r.height - 30);
      if (hasRight) {
        _buildValueScale(right, r.bottom - 30, r.top, r.height - 30);
      }
      double leftW() =>
          left.labelWidth +
          (left.labelWidth > 0 ? 8 : 0) +
          _titleExtent(left.spec);
      double rightW() =>
          hasRight ? right.labelWidth + 8 + _titleExtent(right.spec) : 8;
      var plotW = math.max(10.0, r.width - leftW() - rightW());
      _buildDomainScale(0, plotW);
      _domPlan = _domainLabelPlan(plotW);
      final bottomH =
          _domPlan.$3 +
          (_domPlan.$3 > 0 ? 6 : 0) +
          _titleExtent(domainAxisSpec);
      final plotH = math.max(10.0, r.height - bottomH - left.labelHeight / 2);
      final topY = r.top + left.labelHeight / 2;
      _buildValueScale(left, topY + plotH, topY, plotH);
      if (hasRight) _buildValueScale(right, topY + plotH, topY, plotH);
      plotW = math.max(10.0, r.width - leftW() - rightW());
      final x0 = r.left + leftW();
      plot = ChartRect(x0, topY, plotW, plotH);
      _buildDomainScale(plot.left, plot.right);
      _domPlan = _domainLabelPlan(plot.width);
    } else {
      // Bar: domain on the left, values along the bottom.
      _buildDomainScale(r.top, r.bottom);
      _domPlan = _domainLabelPlan(r.height);
      final leftW =
          _domPlan.$3 + (_domPlan.$3 > 0 ? 8 : 0) + _titleExtent(spec.axes.v);
      _buildValueScale(left, r.left + leftW, r.right - 8, r.width - leftW - 8);
      final bottomH =
          left.labelHeight +
          (left.labelHeight > 0 ? 6 : 0) +
          _titleExtent(spec.axes.h);
      final lastLabelHalf = left.labels.isEmpty
          ? 0.0
          : c.measure(left.labels.last, valueLabelStyle(left)).width / 2;
      final plotW = math.max(
        10.0,
        r.width - leftW - math.max(8.0, lastLabelHalf),
      );
      final plotH = math.max(10.0, r.height - bottomH);
      plot = ChartRect(r.left + leftW, r.top, plotW, plotH);
      _buildValueScale(left, plot.left, plot.right, plot.width);
      _buildDomainScale(plot.top, plot.bottom);
      _domPlan = _domainLabelPlan(plot.height);
    }
  }

  // ---------------------------------------------------------------------------
  // Positions.

  /// Domain position (px) of point [i].
  double domAt(int i) {
    if (band) return bandScale!.center(i);
    return domScale!.map(domainValues[i]);
  }

  /// Screen point for (domain px, value px).
  (double, double) pt(double d, double v) => horizontal ? (v, d) : (d, v);

  ChartRect barRect(double dStart, double dWidth, double v0, double v1) =>
      horizontal
      ? ChartRect.fromLTRB(v0, dStart, v1, dStart + dWidth)
      : ChartRect.fromLTRB(dStart, v1, dStart + dWidth, v0);

  double valuePx(_ValueAxis a, double v) {
    final px = a.scale.map(v);
    if (px.isNaN) return px;
    return px;
  }

  /// Baseline px of the value axis (0 clamped into the visible range).
  double baselinePx(_ValueAxis a) {
    final s = a.scale;
    if (s is LogScale) return s.r0;
    final z = 0.0
        .clamp(math.min(s.min, s.max), math.max(s.min, s.max))
        .toDouble();
    return s.map(z);
  }

  // ---------------------------------------------------------------------------
  // Gridlines and axes.

  bool _showMajor(AxisGridlines g, {required bool valueAxis}) =>
      g.major.show ??
      (valueAxis || type == ChartType.scatter || type == ChartType.bubble);

  void _drawGridlines() {
    final valueGrid = left.grid;
    final grid = <ScenePrimitive>[];
    void lines(
      Iterable<double> pxs,
      bool alongDomain,
      int color,
      String detail,
      double width,
    ) {
      final b = PathBuilder();
      for (final p in pxs) {
        if (p.isNaN) continue;
        if (alongDomain == horizontal) {
          // Horizontal line at y = p.
          b
            ..moveTo(plot.left, p)
            ..lineTo(plot.right, p);
        } else {
          b
            ..moveTo(p, plot.top)
            ..lineTo(p, plot.bottom);
        }
      }
      if (!b.isEmpty) {
        grid.add(
          SPath(
            b.commands,
            stroke: SStroke(color, width: width),
            tag: SceneTag(SceneRole.gridline, detail: detail),
          ),
        );
      }
    }

    // Value axis gridlines (lines perpendicular to the value axis).
    if (valueGrid.minor.show ?? false) {
      lines(
        [
          for (final t in left.scale.minorTicks(valueGrid.minor.count ?? 1))
            left.scale.map(t),
        ],
        true,
        c.theme.color(valueGrid.minor.color, c.theme.minorGridline),
        '${left.id}:minor',
        1,
      );
    }
    if (_showMajor(valueGrid, valueAxis: true)) {
      lines(
        [for (final t in left.scale.ticks) left.scale.map(t)],
        true,
        c.theme.color(valueGrid.major.color, c.theme.gridline),
        left.id,
        1,
      );
    }
    // Domain gridlines.
    final dg = domainGrid;
    final domId = horizontal ? 'v' : 'h';
    if (!band) {
      if ((dg.minor.show ?? false) && domScale != null) {
        lines(
          [
            for (final t in domScale!.minorTicks(dg.minor.count ?? 1))
              domScale!.map(t),
          ],
          false,
          c.theme.color(dg.minor.color, c.theme.minorGridline),
          '$domId:minor',
          1,
        );
      }
      if (_showMajor(dg, valueAxis: false)) {
        lines(
          [for (final t in domTicks) domScale!.map(t)],
          false,
          c.theme.color(dg.major.color, c.theme.gridline),
          domId,
          1,
        );
      }
    } else if (dg.major.show ?? false) {
      lines(
        [for (var i = 0; i <= count; i++) bandScale!.r0 + i * bandScale!.step],
        false,
        c.theme.color(dg.major.color, c.theme.gridline),
        domId,
        1,
      );
    }
    c.out.addAll(grid);
  }

  void _drawAxes() {
    final theme = c.theme;
    final axisColor = theme.axisLine;
    // Domain axis line along the value baseline.
    final dSpec = domainAxisSpec;
    final base = baselinePx(left);
    if (dSpec.showLine) {
      final (x0, y0) = pt(horizontal ? plot.top : plot.left, base);
      final (x1, y1) = pt(horizontal ? plot.bottom : plot.right, base);
      c.out.add(
        SPolyline(
          Float64List.fromList([x0, y0, x1, y1]),
          SStroke(axisColor),
          tag: SceneTag(SceneRole.axisLine, detail: horizontal ? 'v' : 'h'),
        ),
      );
    }
    _drawDomainLabels();
    _drawValueAxis(left, leftSide: true);
    if (!horizontal && right.used) _drawValueAxis(right, leftSide: false);
    // Axis titles.
    final hTitle = spec.axes.h.title;
    if (hTitle.hasText) {
      final st = axisTitleStyle(spec.axes.h);
      c.out.add(
        c.text(
          c.measurer.ellipsize(hTitle.text, st, plot.width),
          plot.centerX,
          region.bottom,
          st,
          anchor: TextAnchor.bottomCenter,
          tag: const SceneTag(SceneRole.axisTitle, detail: 'h'),
        ),
      );
    }
    final vTitle = spec.axes.v.title;
    if (vTitle.hasText) {
      final st = axisTitleStyle(spec.axes.v);
      c.out.add(
        c.text(
          c.measurer.ellipsize(vTitle.text, st, plot.height),
          region.left,
          plot.centerY,
          st,
          anchor: TextAnchor.topCenter,
          angle: -math.pi / 2,
          tag: const SceneTag(SceneRole.axisTitle, detail: 'v'),
        ),
      );
    }
    final v2Title = spec.axes.v2.title;
    if (!horizontal && right.used && v2Title.hasText) {
      final st = axisTitleStyle(spec.axes.v2);
      c.out.add(
        c.text(
          c.measurer.ellipsize(v2Title.text, st, plot.height),
          region.right,
          plot.centerY,
          st,
          anchor: TextAnchor.topCenter,
          angle: math.pi / 2,
          tag: const SceneTag(SceneRole.axisTitle, detail: 'v2'),
        ),
      );
    }
  }

  void _ticks(
    TickSpec t,
    List<double> majorPx,
    List<double> minorPx,
    double edge,
    bool vertical,
    int sign,
    String detail,
  ) {
    final b = PathBuilder();
    void add(List<double> pxs, TickMark m, double len) {
      if (m == TickMark.none) return;
      final dir = (m == TickMark.outside ? 1 : -1) * sign;
      for (final p in pxs) {
        if (vertical) {
          b
            ..moveTo(p, edge)
            ..lineTo(p, edge + dir * len);
        } else {
          b
            ..moveTo(edge, p)
            ..lineTo(edge - dir * len, p);
        }
      }
    }

    add(majorPx, t.major, 5);
    add(minorPx, t.minor, 3);
    if (!b.isEmpty) {
      c.out.add(
        SPath(
          b.commands,
          stroke: SStroke(c.theme.axisLine),
          tag: SceneTag(SceneRole.tick, detail: detail),
        ),
      );
    }
  }

  void _drawValueAxis(_ValueAxis a, {required bool leftSide}) {
    final st = valueLabelStyle(a);
    final ticksPx = [for (final t in a.scale.ticks) a.scale.map(t)];
    if (a.spec.showLine && !horizontal) {
      final x = leftSide ? plot.left : plot.right;
      c.out.add(
        SPolyline(
          Float64List.fromList([x, plot.top, x, plot.bottom]),
          SStroke(c.theme.axisLine),
          tag: SceneTag(SceneRole.axisLine, detail: a.id),
        ),
      );
    }
    final minorPx = [
      for (final t in a.scale.minorTicks(a.grid.minor.count ?? 1))
        a.scale.map(t),
    ];
    if (horizontal) {
      _ticks(a.grid.ticks, ticksPx, minorPx, plot.bottom, true, 1, a.id);
    } else {
      _ticks(
        a.grid.ticks,
        ticksPx,
        minorPx,
        leftSide ? plot.left : plot.right,
        false,
        leftSide ? 1 : -1,
        a.id,
      );
    }
    if (!a.spec.labels.show) return;
    var lastEdge = double.negativeInfinity;
    for (var i = 0; i < a.labels.length; i++) {
      final p = ticksPx[i];
      if (p.isNaN) continue;
      final tag = SceneTag(SceneRole.axisLabel, detail: a.id, pointIndex: i);
      if (horizontal) {
        final w = c.measure(a.labels[i], st).width;
        if (p - w / 2 < lastEdge + 4) continue;
        lastEdge = p + w / 2;
        c.out.add(
          c.text(
            a.labels[i],
            p,
            plot.bottom + 6,
            st,
            anchor: TextAnchor.topCenter,
            tag: tag,
          ),
        );
      } else {
        c.out.add(
          c.text(
            a.labels[i],
            leftSide ? plot.left - 8 : plot.right + 8,
            p,
            st,
            anchor: leftSide ? TextAnchor.middleRight : TextAnchor.middleLeft,
            tag: tag,
          ),
        );
      }
    }
  }

  void _drawDomainLabels() {
    final (angle, step, _, labels) = _domPlan;
    final st = labelStyle;
    final detail = horizontal ? 'v' : 'h';
    final majorPx = band
        ? [for (var i = 0; i < count; i += step) bandScale!.center(i)]
        : [for (final t in domTicks) domScale!.map(t)];
    final minorPx = band || domScale == null
        ? const <double>[]
        : [
            for (final t in domScale!.minorTicks(domainGrid.minor.count ?? 1))
              domScale!.map(t),
          ];
    if (horizontal) {
      _ticks(domainGrid.ticks, majorPx, minorPx, plot.left, false, 1, detail);
    } else {
      _ticks(domainGrid.ticks, majorPx, minorPx, plot.bottom, true, 1, detail);
    }
    if (labels.isEmpty) return;
    if (!band) {
      var lastEdge = double.negativeInfinity;
      for (var i = 0; i < labels.length; i++) {
        final p = domScale!.map(domTicks[i]);
        if (p.isNaN) continue;
        final tag = SceneTag(
          SceneRole.axisLabel,
          detail: detail,
          pointIndex: i,
        );
        if (horizontal) {
          c.out.add(
            c.text(
              labels[i],
              plot.left - 8,
              p,
              st,
              anchor: TextAnchor.middleRight,
              tag: tag,
            ),
          );
          continue;
        }
        final w = c.measure(labels[i], st).width;
        if (p - w / 2 < lastEdge + 6) continue;
        lastEdge = p + w / 2;
        c.out.add(
          c.text(
            labels[i],
            p,
            plot.bottom + 6,
            st,
            anchor: TextAnchor.topCenter,
            tag: tag,
          ),
        );
      }
      return;
    }
    for (var i = 0; i < count; i += step) {
      final p = bandScale!.center(i);
      final tag = SceneTag(SceneRole.axisLabel, detail: detail, pointIndex: i);
      final l = labels[i];
      if (l.isEmpty) continue;
      if (horizontal) {
        c.out.add(
          c.text(
            l,
            plot.left - 8,
            p,
            st,
            anchor: TextAnchor.middleRight,
            tag: tag,
          ),
        );
      } else if (angle == 0) {
        c.out.add(
          c.text(
            l,
            p,
            plot.bottom + 6,
            st,
            anchor: TextAnchor.topCenter,
            tag: tag,
          ),
        );
      } else {
        c.out.add(
          c.text(
            l,
            p,
            plot.bottom + 6,
            st,
            anchor: angle < 0 ? TextAnchor.middleRight : TextAnchor.middleLeft,
            angle: angle,
            tag: tag,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Series.

  int pointColor(_SeriesInfo s, int i) {
    final p = s.style.points[i];
    return p == null ? s.color : c.theme.color(p.color, s.color);
  }

  void _drawSeries(List<ScenePrimitive> body) {
    final columns = series.where((s) => s.mark == _Mark.column).toList();
    // Slots for grouped columns.
    final stacking = type.supportsStacking ? spec.stacking : ChartStacking.none;
    final slotKeys = <String>[];
    final slotOf = <String, int>{};
    for (final s in columns) {
      final k = stacking == ChartStacking.none ? s.key : 'stack:${s.rightAxis}';
      slotOf[s.key] = slotKeys.contains(k)
          ? slotKeys.indexOf(k)
          : (slotKeys..add(k)).length - 1;
    }
    // Areas first (behind), then columns, then lines and scatter.
    for (final s in series.where((s) => s.mark == _Mark.area)) {
      _drawArea(s, body);
    }
    if (columns.isNotEmpty) {
      final bw = band
          ? bandScale!.bandWidth
          : math.max(2.0, plot.width / math.max(1, count) * 0.8);
      if (band && count > 2000) {
        _drawDensity(columns, body);
      } else {
        final groupW = bw * (slotKeys.length > 1 ? 0.8 : 0.7);
        final slotW = groupW / math.max(1, slotKeys.length);
        for (final s in columns) {
          _drawColumns(s, body, slotOf[s.key]!, slotW, groupW);
        }
      }
    }
    for (final s in series.where(
      (s) => s.mark == _Mark.line || s.mark == _Mark.scatter,
    )) {
      if (s.mark == _Mark.line) {
        _drawLine(s, body);
      } else {
        _drawScatter(s, body);
      }
    }
    for (final s in series) {
      _drawTrendline(s, body);
    }
  }

  void _drawColumns(
    _SeriesInfo s,
    List<ScenePrimitive> body,
    int slot,
    double slotW,
    double groupW,
  ) {
    final a = s.rightAxis ? right : left;
    final b = base[s.key]!, t = top[s.key]!;
    final items = <ScenePrimitive>[];
    final opacity = s.style.fillOpacity ?? 1;
    final hasStroke = s.style.lineColor != null;
    for (var i = 0; i < count; i++) {
      if (t[i].isNaN) continue;
      final center = domAt(i);
      final dStart = center - groupW / 2 + slot * slotW;
      var v0 = valuePx(a, b[i]);
      var v1 = valuePx(a, t[i]);
      if (v0.isNaN) v0 = baselinePx(a);
      if (v1.isNaN) continue;
      final r = barRect(horizontal ? dStart : dStart, slotW, v0, v1);
      items.add(
        SRect(
          r,
          fill: Argb.withOpacity(pointColor(s, i), opacity),
          stroke: hasStroke
              ? SStroke(
                  Argb.withOpacity(
                    c.theme.color(s.style.lineColor, s.color),
                    s.style.lineOpacity,
                  ),
                )
              : null,
          tag: SceneTag(SceneRole.point, seriesKey: s.key, pointIndex: i),
        ),
      );
    }
    c.addSeriesGroup(s.key, items, body);
  }

  void _drawDensity(List<_SeriesInfo> columns, List<ScenePrimitive> body) {
    if (!c.warnings.any((w) => w.code == ChartWarningCode.tooManyCategories)) {
      c.warnings.add(
        ChartWarning(
          ChartWarningCode.tooManyCategories,
          'Too many categories to show individually',
          count: count,
        ),
      );
    }
    final pixels = math.max(1, (horizontal ? plot.height : plot.width).ceil());
    for (final s in columns) {
      final a = s.rightAxis ? right : left;
      final t = top[s.key]!;
      final hi = Float64List(pixels)..fillRange(0, pixels, double.nan);
      final lo = Float64List(pixels)..fillRange(0, pixels, double.nan);
      final start = horizontal ? plot.top : plot.left;
      for (var i = 0; i < count; i++) {
        final v = t[i];
        if (v.isNaN) continue;
        final p = ((domAt(i) - start).floor()).clamp(0, pixels - 1);
        if (hi[p].isNaN || v > hi[p]) hi[p] = v;
        if (lo[p].isNaN || v < lo[p]) lo[p] = v;
      }
      final b = PathBuilder();
      final basePx = baselinePx(a);
      var open = false;
      final back = <double>[];
      void closeRun() {
        if (!open) return;
        for (var k = back.length - 2; k >= 0; k -= 2) {
          final (x, y) = pt(back[k], basePx);
          b.lineTo(x, y);
        }
        b.close();
        back.clear();
        open = false;
      }

      for (var p = 0; p < pixels; p++) {
        if (hi[p].isNaN) {
          closeRun();
          continue;
        }
        final d = start + p + 0.5;
        final vMax = math.max(hi[p], 0.0);
        final (x, y) = pt(d, valuePx(a, vMax));
        if (!open) {
          final (bx, by) = pt(d, basePx);
          b
            ..moveTo(bx, by)
            ..lineTo(x, y);
          open = true;
        } else {
          b.lineTo(x, y);
        }
        back
          ..add(d)
          ..add(0);
      }
      closeRun();
      if (!b.isEmpty) {
        c.addSeriesGroup(s.key, [
          SPath(
            b.commands,
            fill: s.color,
            tag: SceneTag(SceneRole.series, seriesKey: s.key),
          ),
        ], body);
      }
    }
  }

  /// Indices to draw for a line/area/scatter series (gaps, downsampling).
  Int32List _visibleIndices(Float64List values) {
    final n = values.length;
    final threshold = spec.data.maxPoints ?? 10000;
    if (n > threshold) {
      final xs = Float64List(n);
      for (var i = 0; i < n; i++) {
        xs[i] = band ? i.toDouble() : domainValues[i];
      }
      final target = Lttb.targetFor(horizontal ? plot.height : plot.width);
      if (target < n) {
        if (!c.warnings.any((w) => w.code == ChartWarningCode.downsampled)) {
          c.warnings.add(
            ChartWarning(
              ChartWarningCode.downsampled,
              'Data downsampled for display',
              count: n,
            ),
          );
        }
        return Lttb.downsample(xs, values, target);
      }
    }
    return Int32List.fromList([
      for (var i = 0; i < n; i++)
        if (!values[i].isNaN && (band || !domainValues[i].isNaN)) i,
    ]);
  }

  /// Splits drawable indices into runs at gaps (empty cells, `emptyCells = gap`).
  List<List<int>> _runs(Float64List values, Int32List idx) {
    final connect = spec.data.emptyCells == EmptyCellMode.connect;
    final runs = <List<int>>[];
    var cur = <int>[];
    var prev = -1;
    for (final i in idx) {
      if (!connect && prev >= 0 && i - prev > 1) {
        var gap = false;
        for (var k = prev + 1; k < i; k++) {
          if (values[k].isNaN) {
            gap = true;
            break;
          }
        }
        if (gap) {
          if (cur.isNotEmpty) runs.add(cur);
          cur = <int>[];
        }
      }
      cur.add(i);
      prev = i;
    }
    if (cur.isNotEmpty) runs.add(cur);
    return runs;
  }

  Float64List _valuesFor(_SeriesInfo s) {
    final t = top[s.key];
    if (t != null) return t;
    return s.series.values;
  }

  void _drawLine(_SeriesInfo s, List<ScenePrimitive> body) {
    final a = s.rightAxis ? right : left;
    final values = _valuesFor(s);
    final idx = _visibleIndices(values);
    final width = s.style.lineWidth ?? 2;
    final color = Argb.withOpacity(
      c.theme.color(s.style.lineColor, s.color),
      s.style.lineOpacity,
    );
    final stroke = SStroke(
      color,
      width: width,
      dash: c.seriesDash(s, width),
      cap: SStrokeCap.round,
      join: SStrokeJoin.round,
    );
    final items = <ScenePrimitive>[];
    final tag = SceneTag(SceneRole.series, seriesKey: s.key);
    if (width > 0) {
      for (final run in _runs(values, idx)) {
        final xy = Float64List(run.length * 2);
        for (var k = 0; k < run.length; k++) {
          final (x, y) = pt(domAt(run[k]), valuePx(a, values[run[k]]));
          xy[2 * k] = x;
          xy[2 * k + 1] = y;
        }
        if (spec.style.smooth && run.length > 2) {
          items.add(
            SPath(_monotone(xy), stroke: stroke, tag: tag.withPoint(run.first)),
          );
        }
        items.add(
          SPolyline(
            xy,
            spec.style.smooth && run.length > 2
                ? SStroke(0x00000000, width: width)
                : stroke,
            indices: Int32List.fromList(run),
            tag: tag,
          ),
        );
      }
    }
    final ps = s.style.pointSize ?? (count == 1 ? 7 : 0);
    if (ps > 0) items.add(_markers(s, a, values, idx, ps));
    c.addSeriesGroup(s.key, items, body);
  }

  SMarkers _markers(
    _SeriesInfo s,
    _ValueAxis a,
    Float64List values,
    Int32List idx,
    double size,
  ) {
    final xy = <double>[];
    final ids = <int>[];
    final fills = <int>[];
    var perPoint = false;
    for (final i in idx) {
      final (x, y) = pt(domAt(i), valuePx(a, values[i]));
      if (x.isNaN || y.isNaN) continue;
      xy
        ..add(x)
        ..add(y);
      ids.add(i);
      final pc = pointColor(s, i);
      if (pc != s.color) perPoint = true;
      fills.add(pc);
    }
    return SMarkers(
      Float64List.fromList(xy),
      c.seriesShape(s),
      size,
      fill: s.color,
      indices: Int32List.fromList(ids),
      fills: perPoint ? Int32List.fromList(fills) : null,
      tag: SceneTag(SceneRole.point, seriesKey: s.key),
    );
  }

  void _drawScatter(_SeriesInfo s, List<ScenePrimitive> body) {
    final a = s.rightAxis ? right : left;
    final values = s.series.values;
    final idx = _visibleIndices(values);
    final items = <ScenePrimitive>[];
    final lw = s.style.lineWidth ?? 0;
    if (lw > 0) {
      for (final run in _runs(values, idx)) {
        final xy = Float64List(run.length * 2);
        for (var k = 0; k < run.length; k++) {
          final (x, y) = pt(domAt(run[k]), valuePx(a, values[run[k]]));
          xy[2 * k] = x;
          xy[2 * k + 1] = y;
        }
        items.add(
          SPolyline(
            xy,
            SStroke(
              Argb.withOpacity(
                c.theme.color(s.style.lineColor, s.color),
                s.style.lineOpacity,
              ),
              width: lw,
              dash: c.seriesDash(s, lw),
            ),
            indices: Int32List.fromList(run),
            tag: SceneTag(SceneRole.series, seriesKey: s.key),
          ),
        );
      }
    }
    final ps = s.style.pointSize ?? 7;
    if (ps > 0) items.add(_markers(s, a, values, idx, ps));
    c.addSeriesGroup(s.key, items, body);
  }

  void _drawArea(_SeriesInfo s, List<ScenePrimitive> body) {
    final a = s.rightAxis ? right : left;
    final t = top[s.key]!, b = base[s.key]!;
    final idx = _visibleIndices(t);
    final items = <ScenePrimitive>[];
    final fill = Argb.withOpacity(
      pointColor(s, -1),
      s.style.fillOpacity ?? 0.3,
    );
    final width = s.style.lineWidth ?? 2;
    final basePx = baselinePx(a);
    for (final run in _runs(t, idx)) {
      final pb = PathBuilder();
      final topXy = Float64List(run.length * 2);
      for (var k = 0; k < run.length; k++) {
        final i = run[k];
        final (x, y) = pt(domAt(i), valuePx(a, t[i]));
        topXy[2 * k] = x;
        topXy[2 * k + 1] = y;
        if (k == 0) {
          pb.moveTo(x, y);
        } else {
          pb.lineTo(x, y);
        }
      }
      for (var k = run.length - 1; k >= 0; k--) {
        final i = run[k];
        final bv = b[i].isNaN ? double.nan : valuePx(a, b[i]);
        final (x, y) = pt(domAt(i), bv.isNaN ? basePx : bv);
        pb.lineTo(x, y);
      }
      pb.close();
      items.add(
        SPath(
          pb.commands,
          fill: fill,
          tag: SceneTag(SceneRole.series, seriesKey: s.key),
        ),
      );
      if (width > 0) {
        items.add(
          SPolyline(
            topXy,
            SStroke(
              Argb.withOpacity(
                c.theme.color(s.style.lineColor, s.color),
                s.style.lineOpacity,
              ),
              width: width,
              dash: c.seriesDash(s, width),
              join: SStrokeJoin.round,
            ),
            indices: Int32List.fromList(run),
            tag: SceneTag(SceneRole.series, seriesKey: s.key),
          ),
        );
      }
    }
    final ps = s.style.pointSize ?? 0;
    if (ps > 0) items.add(_markers(s, a, t, idx, ps));
    c.addSeriesGroup(s.key, items, body);
  }

  /// Monotone cubic (Fritsch–Carlson) through the points of [xy].
  static List<PathCmd> _monotone(Float64List xy) {
    final n = xy.length ~/ 2;
    final b = PathBuilder()..moveTo(xy[0], xy[1]);
    if (n == 2) {
      b.lineTo(xy[2], xy[3]);
      return b.commands;
    }
    final m = Float64List(n);
    final d = Float64List(n - 1);
    for (var i = 0; i < n - 1; i++) {
      final dx = xy[2 * i + 2] - xy[2 * i];
      d[i] = dx == 0 ? 0 : (xy[2 * i + 3] - xy[2 * i + 1]) / dx;
    }
    m[0] = d[0];
    m[n - 1] = d[n - 2];
    for (var i = 1; i < n - 1; i++) {
      m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
    }
    for (var i = 0; i < n - 1; i++) {
      if (d[i] == 0) {
        m[i] = 0;
        m[i + 1] = 0;
        continue;
      }
      final a = m[i] / d[i], bb = m[i + 1] / d[i];
      final h = a * a + bb * bb;
      if (h > 9) {
        final t = 3 / math.sqrt(h);
        m[i] = t * a * d[i];
        m[i + 1] = t * bb * d[i];
      }
    }
    for (var i = 0; i < n - 1; i++) {
      final x0 = xy[2 * i],
          y0 = xy[2 * i + 1],
          x1 = xy[2 * i + 2],
          y1 = xy[2 * i + 3];
      final h = (x1 - x0) / 3;
      b.cubicTo(x0 + h, y0 + m[i] * h, x1 - h, y1 - m[i + 1] * h, x1, y1);
    }
    return b.commands;
  }

  void _drawTrendline(_SeriesInfo s, List<ScenePrimitive> body) {
    final tl = s.style.trendline;
    if (tl == null || !type.supportsTrendlines) return;
    if (type.supportsStacking && spec.stacking != ChartStacking.none) return;
    final a = s.rightAxis ? right : left;
    final xs = c.regressionX();
    final color = Argb.withOpacity(
      c.theme.color(tl.color, s.color),
      tl.opacity,
    );
    final stroke = SStroke(
      color,
      width: tl.lineWidth,
      dash: dashPattern(tl.lineDash, tl.lineWidth),
    );
    final tag = SceneTag(SceneRole.trendline, seriesKey: s.key);
    double dpx(double x) {
      if (band) return bandScale!.r0 + (x - 0.5) * bandScale!.step;
      return domScale!.map(x);
    }

    final xy = <double>[];
    if (tl.type == TrendlineType.movingAverage) {
      final ma = Regression.movingAverage(
        s.series.values,
        math.max(2, tl.period),
      );
      for (var i = 0; i < ma.length; i++) {
        if (ma[i].isNaN) continue;
        final (x, y) = pt(dpx(xs[i]), valuePx(a, ma[i]));
        xy
          ..add(x)
          ..add(y);
      }
    } else {
      final fit = c.trendlineFit(s, tl);
      if (fit == null) return;
      var lo = double.infinity, hi = -double.infinity;
      for (var i = 0; i < xs.length; i++) {
        final x = xs[i];
        if (x.isNaN || s.series.values[i].isNaN) continue;
        if ((tl.type == TrendlineType.logarithmic ||
                tl.type == TrendlineType.power) &&
            x <= 0) {
          continue;
        }
        if (x < lo) lo = x;
        if (x > hi) hi = x;
      }
      if (lo > hi) return;
      final samples = tl.type == TrendlineType.linear ? 2 : 64;
      for (var k = 0; k < samples; k++) {
        final x = samples == 1 ? lo : lo + (hi - lo) * k / (samples - 1);
        final y = fit.predict(x);
        if (!y.isFinite) continue;
        final (px, py) = pt(dpx(x), valuePx(a, y));
        if (px.isNaN || py.isNaN) continue;
        xy
          ..add(px)
          ..add(py);
      }
      if (tl.label == TrendlineLabel.equation && xy.length >= 2) {
        final st = c.font(ChartFont.inherit, size: 11, color: color);
        c.out.add(
          c.text(
            fit.equation(),
            xy[xy.length - 2],
            xy[xy.length - 1] - 4,
            st,
            anchor: TextAnchor.bottomRight,
            tag: tag,
          ),
        );
      }
    }
    if (xy.length >= 4) {
      c.addSeriesGroup(s.key, [
        SPolyline(Float64List.fromList(xy), stroke, tag: tag),
      ], body);
    }
  }

  // ---------------------------------------------------------------------------
  // Special cartesian types.

  void _drawHistogram(List<ScenePrimitive> body) {
    final hd = data.histogram!;
    final nSeries = hd.counts.length;
    final s0 = domScale!;
    for (var si = 0; si < nSeries; si++) {
      final info = si < c.seriesInfos.length ? c.seriesInfos[si] : null;
      final key = hd.seriesKeys[si];
      final color = info?.color ?? c.theme.seriesColor(si);
      final items = <ScenePrimitive>[];
      for (var b = 0; b < hd.bucketCount; b++) {
        final cnt = hd.counts[si][b];
        if (cnt == 0) continue;
        final x0 = s0.map(hd.edge(b)), x1 = s0.map(hd.edge(b + 1));
        final w = (x1 - x0).abs();
        final gap = math.min(1.0, w * 0.1);
        final slotW = (w - gap) / nSeries;
        final start = math.min(x0, x1) + gap / 2 + si * slotW;
        final r = ChartRect.fromLTRB(
          start,
          valuePx(left, cnt.toDouble()),
          start + slotW,
          valuePx(left, 0),
        );
        items.add(
          SRect(
            r,
            fill: color,
            tag: SceneTag(SceneRole.point, seriesKey: key, pointIndex: b),
          ),
        );
        final perItem = r.height / cnt;
        if (spec.histogramOptions.showItemDividers && perItem >= 3 && cnt > 1) {
          final pb = PathBuilder();
          for (var k = 1; k < cnt; k++) {
            final y = r.bottom - k * perItem;
            pb
              ..moveTo(r.left, y)
              ..lineTo(r.right, y);
          }
          items.add(
            SPath(pb.commands, stroke: SStroke(c.background, width: 1)),
          );
        }
      }
      c.addSeriesGroup(key, items, body);
    }
  }

  void _drawCandlesticks(List<ScenePrimitive> body) {
    final o = spec.candlestickOptions;
    final groups = data.series.length ~/ 4;
    final bw = bandScale!.bandWidth;
    final bodyW = math.max(1.0, bw * 0.6 / math.max(1, groups));
    for (var g = 0; g < groups; g++) {
      final low = data.series[4 * g].values,
          open = data.series[4 * g + 1].values;
      final close = data.series[4 * g + 2].values,
          high = data.series[4 * g + 3].values;
      final key = data.series[4 * g].key;
      final rising = c.theme.color(
        o.risingColor,
        g == 0 ? c.theme.positive : c.theme.seriesColor(g),
      );
      final falling = c.theme.color(
        o.fallingColor,
        g == 0 ? c.theme.negative : c.theme.seriesColor(g),
      );
      final items = <ScenePrimitive>[];
      final wickUp = PathBuilder(), wickDown = PathBuilder();
      for (var i = 0; i < count; i++) {
        if ([low[i], open[i], close[i], high[i]].any((v) => v.isNaN)) continue;
        final center = domAt(i) - bw * 0.3 + (g + 0.5) * bodyW;
        final up = close[i] >= open[i];
        final wick = up ? wickUp : wickDown;
        final (x0, y0) = pt(center, valuePx(left, low[i]));
        final (x1, y1) = pt(center, valuePx(left, high[i]));
        wick
          ..moveTo(x0, y0)
          ..lineTo(x1, y1);
        final r = barRect(
          center - bodyW / 2,
          bodyW,
          valuePx(left, math.min(open[i], close[i])),
          valuePx(left, math.max(open[i], close[i])),
        );
        final color = up ? rising : falling;
        final filled = up ? o.risingFilled : o.fallingFilled;
        items.add(
          SRect(
            r.height < 1 && !horizontal
                ? ChartRect(r.left, r.top - 0.5, r.width, 1)
                : r,
            fill: filled ? color : c.background,
            stroke: SStroke(color),
            tag: SceneTag(SceneRole.point, seriesKey: key, pointIndex: i),
          ),
        );
      }
      if (!wickUp.isEmpty) {
        items.insert(
          0,
          SPath(
            wickUp.commands,
            stroke: SStroke(rising),
            tag: SceneTag(SceneRole.series, seriesKey: key),
          ),
        );
      }
      if (!wickDown.isEmpty) {
        items.insert(
          0,
          SPath(
            wickDown.commands,
            stroke: SStroke(falling),
            tag: SceneTag(SceneRole.series, seriesKey: key),
          ),
        );
      }
      c.addSeriesGroup(key, items, body);
    }
  }

  void _drawWaterfall(List<ScenePrimitive> body) {
    final o = spec.waterfallOptions;
    final key = data.series.isEmpty ? '' : data.series.first.key;
    final pos = c.theme.color(o.positiveColor, c.theme.seriesColor(0));
    final neg = c.theme.color(o.negativeColor, c.theme.seriesColor(1));
    final tot = c.theme.color(o.subtotalColor, c.theme.seriesColor(2));
    final bw = bandScale!.bandWidth * 0.7;
    final conn = PathBuilder();
    for (var i = 0; i < waterfall.length; i++) {
      final w = waterfall[i];
      final center = domAt(i);
      final r = barRect(
        center - bw / 2,
        bw,
        valuePx(left, w.from),
        valuePx(left, w.to),
      );
      final color = switch (w.kind) {
        'pos' => pos,
        'neg' => neg,
        _ => tot,
      };
      body.add(
        SRect(
          r,
          fill: color,
          tag: SceneTag(
            SceneRole.point,
            seriesKey: key,
            pointIndex: w.pointIndex,
            detail: w.kind == 'total' ? 'subtotal' : null,
          ),
        ),
      );
      if (o.connectorShow && i + 1 < waterfall.length) {
        final next = waterfall[i + 1];
        final level = next.kind == 'total' ? w.to : next.from;
        final (x0, y0) = pt(center + bw / 2, valuePx(left, level));
        final (x1, y1) = pt(domAt(i + 1) - bw / 2, valuePx(left, level));
        conn
          ..moveTo(x0, y0)
          ..lineTo(x1, y1);
      }
    }
    if (!conn.isEmpty) {
      body.add(
        SPath(
          conn.commands,
          stroke: SStroke(
            c.theme.color(o.connectorColor, c.theme.axisLine),
            dash: dashPattern(o.connectorDash, 1),
          ),
          tag: SceneTag(SceneRole.connector, seriesKey: key),
        ),
      );
    }
  }

  void _drawBubbles(List<ScenePrimitive> body) {
    if (data.series.length < 2) return;
    final xs = data.series[0].values, ys = data.series[1].values;
    final sizes = data.series.length >= 3 ? data.series.last.values : null;
    final o = spec.bubbleOptions;
    final groups = c.bubbleGroups();
    var smin = double.infinity, smax = -double.infinity;
    if (sizes != null) {
      for (final v in sizes) {
        if (v.isNaN) continue;
        smin = math.min(smin, v.abs());
        smax = math.max(smax, v.abs());
      }
    }
    final order = <int>[
      for (var i = 0; i < count; i++)
        if (!xs[i].isNaN && !ys[i].isNaN) i,
    ];
    double diameter(int i) {
      if (sizes == null || sizes[i].isNaN || !(smax > smin)) {
        return (o.minSize + o.maxSize) / 2;
      }
      return o.minSize +
          (o.maxSize - o.minSize) *
              math.sqrt((sizes[i].abs() - smin) / (smax - smin));
    }

    order.sort((a, b) => diameter(b).compareTo(diameter(a)));
    final xy = Float64List(order.length * 2);
    final ds = Float64List(order.length);
    final fills = Int32List(order.length);
    final key = data.series[1].key;
    final baseColor = c.seriesInfos.length > 1
        ? c.seriesInfos[1].color
        : c.theme.seriesColor(0);
    final style = c.font(ChartFont.inherit, size: 11);
    final labels = <ScenePrimitive>[];
    for (var k = 0; k < order.length; k++) {
      final i = order[k];
      xy[2 * k] = domScale!.map(xs[i]);
      xy[2 * k + 1] = valuePx(left, ys[i]);
      ds[k] = diameter(i);
      final color = groups != null && o.colorBy != BubbleColorBy.series
          ? c.theme.seriesColor(groups.$2[i])
          : (groups != null ? c.theme.seriesColor(groups.$2[i]) : baseColor);
      fills[k] = Argb.withOpacity(color, 0.75);
      final label = data.domain.isSynthetic ? '' : data.domain.labels[i];
      if (label.isNotEmpty && c.measure(label, style).width < ds[k] - 4) {
        labels.add(
          c.text(
            label,
            xy[2 * k],
            xy[2 * k + 1],
            style.copyWith(color: c.theme.onColor(color)),
            anchor: TextAnchor.center,
            tag: SceneTag(SceneRole.dataLabel, seriesKey: key, pointIndex: i),
          ),
        );
      }
    }
    body.add(
      SMarkers(
        xy,
        MarkerShape.circle,
        o.maxSize,
        fill: Argb.withOpacity(baseColor, 0.75),
        stroke: SStroke(Argb.withOpacity(c.background, 0.9)),
        indices: Int32List.fromList(order),
        sizes: ds,
        fills: fills,
        tag: SceneTag(SceneRole.point, seriesKey: key),
      ),
    );
    body.addAll(labels);
  }

  // ---------------------------------------------------------------------------
  // Data labels.

  void _drawDataLabels() {
    if (type == ChartType.histogram ||
        type == ChartType.candlestick ||
        type == ChartType.bubble) {
      return;
    }
    if (type == ChartType.waterfall) {
      final s = data.series.isEmpty ? null : data.series.first;
      if (s == null || !spec.seriesStyle(s.key).dataLabels.show) return;
      final st = c.font(spec.seriesStyle(s.key).dataLabels.font, size: 11);
      for (var i = 0; i < waterfall.length; i++) {
        final w = waterfall[i];
        final v = w.kind == 'total' ? w.to : w.to - w.from;
        final (x, y) = pt(domAt(i), valuePx(left, math.max(w.from, w.to)));
        c.out.add(
          c.text(
            c.formatValue(v, s.numberFormat),
            x,
            y - 3,
            st,
            anchor: TextAnchor.bottomCenter,
            tag: SceneTag(
              SceneRole.dataLabel,
              seriesKey: s.key,
              pointIndex: w.pointIndex,
            ),
          ),
        );
      }
      return;
    }
    final stacking = type.supportsStacking ? spec.stacking : ChartStacking.none;
    for (final s in series) {
      final dl = s.style.dataLabels;
      if (!dl.show) continue;
      final a = s.rightAxis ? right : left;
      final t = top[s.key] ?? s.series.values;
      final b = base[s.key];
      final st = c.font(dl.font, size: 11, color: c.theme.text);
      final items = <ScenePrimitive>[];
      final stacked =
          stacking != ChartStacking.none &&
          (s.mark == _Mark.column || s.mark == _Mark.area);
      final idx = s.mark == _Mark.column
          ? [for (var i = 0; i < count; i++) i]
          : _visibleIndices(t).toList();
      if (idx.length > 500) continue;
      for (final i in idx) {
        final raw = s.series.values[i];
        if (raw.isNaN || t[i].isNaN) continue;
        final label =
            dl.type == DataLabelType.percent &&
                stacking == ChartStacking.percent
            ? c.formatValue((t[i] - (b?[i] ?? 0)).abs(), '0%')
            : c.formatValue(raw, s.series.numberFormat);
        final tag = SceneTag(
          SceneRole.dataLabel,
          seriesKey: s.key,
          pointIndex: i,
        );
        final d = domAt(i);
        final vEnd = valuePx(a, t[i]);
        if (vEnd.isNaN) continue;
        final vStart = b == null || b[i].isNaN
            ? baselinePx(a)
            : valuePx(a, b[i]);
        var position = dl.position;
        if (position == DataLabelPosition.auto) {
          position = s.mark == _Mark.column
              ? (stacked
                    ? DataLabelPosition.center
                    : DataLabelPosition.outsideEnd)
              : DataLabelPosition.above;
        }
        final negative = raw < 0;
        double vx;
        TextAnchor anchor;
        int color = st.color;
        final fill = pointColor(s, i);
        switch (position) {
          case DataLabelPosition.center:
            vx = (vStart + vEnd) / 2;
            anchor = TextAnchor.center;
            color = c.theme.onColor(fill);
          case DataLabelPosition.insideEnd:
            vx =
                vEnd + (horizontal ? (negative ? 4 : -4) : (negative ? -4 : 4));
            anchor = horizontal
                ? (negative ? TextAnchor.middleLeft : TextAnchor.middleRight)
                : (negative ? TextAnchor.bottomCenter : TextAnchor.topCenter);
            color = c.theme.onColor(fill);
          case DataLabelPosition.insideBase:
            vx =
                vStart +
                (horizontal ? (negative ? -4 : 4) : (negative ? 4 : -4));
            anchor = horizontal
                ? (negative ? TextAnchor.middleRight : TextAnchor.middleLeft)
                : (negative ? TextAnchor.topCenter : TextAnchor.bottomCenter);
            color = c.theme.onColor(fill);
          case DataLabelPosition.below:
            vx = vEnd + (horizontal ? -6 : 6);
            anchor = horizontal ? TextAnchor.middleRight : TextAnchor.topCenter;
          case DataLabelPosition.left:
            final (x, y) = pt(d, vEnd);
            items.add(
              c.text(
                label,
                x - 6,
                y,
                st,
                anchor: TextAnchor.middleRight,
                tag: tag,
              ),
            );
            continue;
          case DataLabelPosition.right:
            final (x, y) = pt(d, vEnd);
            items.add(
              c.text(
                label,
                x + 6,
                y,
                st,
                anchor: TextAnchor.middleLeft,
                tag: tag,
              ),
            );
            continue;
          default: // outsideEnd, above
            vx =
                vEnd + (horizontal ? (negative ? -4 : 4) : (negative ? 4 : -4));
            anchor = horizontal
                ? (negative ? TextAnchor.middleRight : TextAnchor.middleLeft)
                : (negative ? TextAnchor.topCenter : TextAnchor.bottomCenter);
        }
        final (x, y) = pt(d, vx);
        items.add(
          c.text(
            label,
            x,
            y,
            st.copyWith(color: color),
            anchor: anchor,
            tag: tag,
          ),
        );
      }
      c.addSeriesGroup(s.key, items, c.out);
    }
  }
}
