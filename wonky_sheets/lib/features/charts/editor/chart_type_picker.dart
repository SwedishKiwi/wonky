import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../../l10n/sheets_l10n.dart';
import '../../charts3d/icons/chart3d_glyph.dart';

/// A chart type with its preset variant (stacking, doughnut hole, smooth
/// lines) as offered by the type picker (08 §8.3).
@immutable
class ChartVariant {
  const ChartVariant(
    this.id,
    this.type, {
    this.stacking = ChartStacking.none,
    this.pieHole = 0,
    this.smooth = false,
    this.threeD = false,
  });

  final String id;
  final ChartType type;
  final ChartStacking stacking;
  final double pieHole;
  final bool smooth;

  /// Drawn in 3D (08 §23).
  final bool threeD;

  /// Whether [spec] shows this variant.
  bool matches(ChartSpec spec) =>
      spec.type == type &&
      spec.is3D == threeD &&
      (!type.supportsStacking || spec.stacking == stacking) &&
      (type != ChartType.pie ||
          (spec.pieOptions.pieHole > 0) == (pieHole > 0)) &&
      (type != ChartType.line || spec.style.smooth == smooth);

  /// `sheets.chart.setType` arguments.
  Map<String, Object?> args(String objectId) => {
    'objectId': objectId,
    'type': type.id,
    if (type.supportsStacking) 'stacking': stacking.name,
    if (type == ChartType.pie) 'pieHole': pieHole,
    if (type == ChartType.line) 'smooth': smooth,
    if (type.supports3D && !type.only3D) 'threeD': threeD,
  };

  String label(SheetsLocalizations l) => switch (id) {
    'line' => l.chartTypeLine,
    'smoothLine' => l.chartTypeSmoothLine,
    'combo' => l.chartTypeCombo,
    'area' => l.chartTypeArea,
    'stackedArea' => l.chartTypeStackedArea,
    'percentArea' => l.chartTypePercentArea,
    'column' => l.chartTypeColumn,
    'stackedColumn' => l.chartTypeStackedColumn,
    'percentColumn' => l.chartTypePercentColumn,
    'bar' => l.chartTypeBar,
    'stackedBar' => l.chartTypeStackedBar,
    'percentBar' => l.chartTypePercentBar,
    'pie' => l.chartTypePie,
    'doughnut' => l.chartTypeDoughnut,
    'scatter' => l.chartTypeScatter,
    'bubble' => l.chartTypeBubble,
    'histogram' => l.chartTypeHistogram,
    'candlestick' => l.chartTypeCandlestick,
    'waterfall' => l.chartTypeWaterfall,
    'scorecard' => l.chartTypeScorecard,
    'table' => l.chartTypeTable,
    'radar' => l.chartTypeRadar,
    'column3d' => l.chartType3DColumn,
    'stackedColumn3d' => l.chartType3DStackedColumn,
    'percentColumn3d' => l.chartType3DPercentColumn,
    'bar3d' => l.chartType3DBar,
    'stackedBar3d' => l.chartType3DStackedBar,
    'line3d' => l.chartType3DLine,
    'area3d' => l.chartType3DArea,
    'stackedArea3d' => l.chartType3DStackedArea,
    'pie3d' => l.chartType3DPie,
    'doughnut3d' => l.chartType3DDoughnut,
    'surface3d' => l.chartType3DSurface,
    _ => type.displayName,
  };
}

/// Every variant of the P0 and P1 types, by picker group.
const chartVariantGroups = <String, List<ChartVariant>>{
  'line': [
    ChartVariant('line', ChartType.line),
    ChartVariant('smoothLine', ChartType.line, smooth: true),
    ChartVariant('combo', ChartType.combo),
  ],
  'area': [
    ChartVariant('area', ChartType.area),
    ChartVariant('stackedArea', ChartType.area, stacking: ChartStacking.normal),
    ChartVariant(
      'percentArea',
      ChartType.area,
      stacking: ChartStacking.percent,
    ),
  ],
  'column': [
    ChartVariant('column', ChartType.column),
    ChartVariant(
      'stackedColumn',
      ChartType.column,
      stacking: ChartStacking.normal,
    ),
    ChartVariant(
      'percentColumn',
      ChartType.column,
      stacking: ChartStacking.percent,
    ),
  ],
  'bar': [
    ChartVariant('bar', ChartType.bar),
    ChartVariant('stackedBar', ChartType.bar, stacking: ChartStacking.normal),
    ChartVariant('percentBar', ChartType.bar, stacking: ChartStacking.percent),
  ],
  'pie': [
    ChartVariant('pie', ChartType.pie),
    ChartVariant('doughnut', ChartType.pie, pieHole: 0.5),
  ],
  'scatter': [
    ChartVariant('scatter', ChartType.scatter),
    ChartVariant('bubble', ChartType.bubble),
  ],
  '3d': [
    ChartVariant('column3d', ChartType.column, threeD: true),
    ChartVariant(
      'stackedColumn3d',
      ChartType.column,
      stacking: ChartStacking.normal,
      threeD: true,
    ),
    ChartVariant(
      'percentColumn3d',
      ChartType.column,
      stacking: ChartStacking.percent,
      threeD: true,
    ),
    ChartVariant('bar3d', ChartType.bar, threeD: true),
    ChartVariant(
      'stackedBar3d',
      ChartType.bar,
      stacking: ChartStacking.normal,
      threeD: true,
    ),
    ChartVariant('line3d', ChartType.line, threeD: true),
    ChartVariant('area3d', ChartType.area, threeD: true),
    ChartVariant(
      'stackedArea3d',
      ChartType.area,
      stacking: ChartStacking.normal,
      threeD: true,
    ),
    ChartVariant('pie3d', ChartType.pie, threeD: true),
    ChartVariant('doughnut3d', ChartType.pie, pieHole: 0.5, threeD: true),
    ChartVariant('surface3d', ChartType.surface, threeD: true),
  ],
  'other': [
    ChartVariant('histogram', ChartType.histogram),
    ChartVariant('candlestick', ChartType.candlestick),
    ChartVariant('waterfall', ChartType.waterfall),
    ChartVariant('scorecard', ChartType.scorecard),
    ChartVariant('table', ChartType.table),
    ChartVariant('radar', ChartType.radar),
  ],
};

/// All variants.
List<ChartVariant> get allChartVariants => [
  for (final g in chartVariantGroups.values) ...g,
];

/// The variant shown by [spec] (falls back to its plain type).
ChartVariant variantOf(ChartSpec spec) {
  for (final v in allChartVariants) {
    if (v.matches(spec)) return v;
  }
  return allChartVariants.firstWhere(
    (v) => v.type == spec.type,
    orElse: () => allChartVariants.first,
  );
}

/// The variant of a recommended spec.
ChartVariant variantOfSuggestion(ChartSuggestion s) => variantOf(s.spec);

String _groupLabel(SheetsLocalizations l, String g) => switch (g) {
  'line' => l.chartGroupLine,
  'area' => l.chartGroupArea,
  'column' => l.chartGroupColumn,
  'bar' => l.chartGroupBar,
  'pie' => l.chartGroupPie,
  'scatter' => l.chartGroupScatter,
  '3d' => l.chartGroup3D,
  _ => l.chartGroupOther,
};

/// The chart type select of the editor (08 §8.3): a button with the
/// current type that opens a popover with search, the suggested types and
/// all types by group, each drawn as a [ChartTypeIcon].
class ChartTypePicker extends StatefulWidget {
  const ChartTypePicker({
    super.key,
    required this.value,
    required this.suggestions,
    required this.onSelected,
    this.enabled = true,
  });

  final ChartVariant value;
  final List<ChartVariant> suggestions;
  final ValueChanged<ChartVariant> onSelected;
  final bool enabled;

  @override
  State<ChartTypePicker> createState() => _ChartTypePickerState();
}

class _ChartTypePickerState extends State<ChartTypePicker> {
  final _popover = ShadPopoverController();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _popover.dispose();
    _search.dispose();
    super.dispose();
  }

  void _pick(ChartVariant v) {
    _popover.hide();
    widget.onSelected(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return ShadPopover(
      controller: _popover,
      popover: (context) => SizedBox(
        width: 296,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInput(
                  key: const ValueKey<String>('chartEditor.type.search'),
                  controller: _search,
                  autofocus: true,
                  placeholder: Text(l.chartTypeSearch),
                  leading: const Icon(LucideIcons.search, size: 14),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
                ..._groups(context, l, theme),
              ],
            ),
          ),
        ),
      ),
      child: ShadButton.outline(
        key: const ValueKey<String>('chartEditor.type'),
        enabled: widget.enabled,
        width: double.infinity,
        mainAxisAlignment: MainAxisAlignment.start,
        onPressed: () {
          _search.clear();
          setState(() => _query = '');
          _popover.toggle();
        },
        leading: SizedBox(
          width: 24,
          height: 18,
          child: ChartTypeIcon(variant: widget.value),
        ),
        trailing: const Icon(LucideIcons.chevronDown, size: 14),
        child: Expanded(
          child: Text(
            widget.value.label(l),
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  List<Widget> _groups(
    BuildContext context,
    SheetsLocalizations l,
    ShadThemeData theme,
  ) {
    bool match(ChartVariant v) =>
        _query.isEmpty || v.label(l).toLowerCase().contains(_query);
    final out = <Widget>[];
    void group(String title, List<ChartVariant> list, String key) {
      final shown = list.where(match).toList();
      if (shown.isEmpty) return;
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
          child: Text(
            title,
            style: theme.textTheme.muted.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      out.add(
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in shown)
              _Tile(
                key: ValueKey<String>('chartEditor.type.$key.${v.id}'),
                variant: v,
                label: v.label(l),
                selected: v.id == widget.value.id,
                onTap: () => _pick(v),
              ),
          ],
        ),
      );
    }

    if (widget.suggestions.isNotEmpty) {
      group(l.chartGroupSuggested, widget.suggestions, 'suggested');
    }
    for (final e in chartVariantGroups.entries) {
      group(_groupLabel(l, e.key), e.value, e.key);
    }
    if (out.isEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.chartTypeNoMatch, style: theme.textTheme.muted),
        ),
      );
    }
    return out;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.variant,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ChartVariant variant;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) => Text(label),
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: ShadButton.ghost(
          width: 60,
          height: 50,
          padding: const EdgeInsets.all(6),
          backgroundColor: selected ? theme.colorScheme.accent : null,
          decoration: ShadDecoration(
            border: ShadBorder.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.border,
              radius: BorderRadius.circular(6),
            ),
          ),
          onPressed: onTap,
          child: SizedBox(
            width: 48,
            height: 36,
            child: ChartTypeIcon(variant: variant),
          ),
        ),
      ),
    );
  }
}

/// A painted glyph per chart type (08 §19 `ChartTypeIcon`), drawn with the
/// theme's chart colors.
class ChartTypeIcon extends StatelessWidget {
  const ChartTypeIcon({super.key, required this.variant});

  final ChartVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = ShadTheme.of(context).colorScheme;
    if (variant.threeD) {
      return CustomPaint(
        painter: Chart3DGlyphPainter(
          type: variant.type,
          stacking: variant.stacking,
          pieHole: variant.pieHole,
          colors: [c.chart1, c.chart2, c.chart3],
          floor: Color.lerp(c.background, c.mutedForeground, 0.25)!,
          background: c.background,
        ),
      );
    }
    return CustomPaint(
      painter: _GlyphPainter(variant, [
        c.chart1,
        c.chart2,
        c.chart3,
      ], c.mutedForeground),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.v, this.colors, this.muted);

  final ChartVariant v;
  final List<Color> colors;
  final Color muted;

  Paint _fill(int i) => Paint()..color = colors[i % colors.length];
  Paint _stroke(int i, [double w = 1.6]) => Paint()
    ..color = colors[i % colors.length]
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final axis = Paint()
      ..color = muted.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    void axes() {
      canvas.drawLine(Offset(1, h - 1), Offset(w - 1, h - 1), axis);
      canvas.drawLine(Offset(1, 1), Offset(1, h - 1), axis);
    }

    const vals = [0.45, 0.8, 0.6, 0.95];
    const vals2 = [0.3, 0.2, 0.35, 0.25];
    switch (v.id) {
      case 'column' || 'stackedColumn' || 'percentColumn' || 'histogram':
        axes();
        final n = v.id == 'histogram' ? 6 : 4;
        final hist = [0.2, 0.5, 0.9, 0.75, 0.4, 0.15];
        final gap = v.id == 'histogram' ? 0.0 : w * 0.06;
        final bw = (w - 4 - gap * (n + 1)) / n;
        for (var i = 0; i < n; i++) {
          final x = 3 + gap + i * (bw + gap);
          final a = v.id == 'histogram' ? hist[i] : vals[i];
          if (v.id == 'column' || v.id == 'histogram') {
            canvas.drawRect(
              Rect.fromLTWH(x, (h - 2) * (1 - a), bw, (h - 2) * a),
              _fill(0),
            );
          } else {
            final total = v.id == 'percentColumn' ? 1.0 : a;
            final b = v.id == 'percentColumn' ? 0.55 : vals2[i];
            final top = (h - 2) * (1 - total);
            final split =
                top + (h - 2) * total * (1 - b / math.max(total, 0.01));
            canvas.drawRect(Rect.fromLTRB(x, top, x + bw, split), _fill(1));
            canvas.drawRect(Rect.fromLTRB(x, split, x + bw, h - 2), _fill(0));
          }
        }
      case 'bar' || 'stackedBar' || 'percentBar':
        axes();
        const n = 3;
        final gap = h * 0.1;
        final bh = (h - 2 - gap * (n + 1)) / n;
        for (var i = 0; i < n; i++) {
          final y = 1 + gap + i * (bh + gap);
          final a = vals[i];
          if (v.id == 'bar') {
            canvas.drawRect(Rect.fromLTWH(2, y, (w - 4) * a, bh), _fill(0));
          } else {
            final total = v.id == 'percentBar' ? 1.0 : a;
            final split = (w - 4) * total * 0.6;
            canvas.drawRect(Rect.fromLTWH(2, y, split, bh), _fill(0));
            canvas.drawRect(
              Rect.fromLTWH(2 + split, y, (w - 4) * total - split, bh),
              _fill(1),
            );
          }
        }
      case 'line' || 'smoothLine':
        axes();
        final pts = [
          Offset(3, h * 0.7),
          Offset(w * 0.3, h * 0.35),
          Offset(w * 0.55, h * 0.55),
          Offset(w * 0.8, h * 0.2),
          Offset(w - 2, h * 0.3),
        ];
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (var i = 1; i < pts.length; i++) {
          if (v.smooth) {
            final p0 = pts[i - 1], p1 = pts[i];
            final mx = (p0.dx + p1.dx) / 2;
            path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
          } else {
            path.lineTo(pts[i].dx, pts[i].dy);
          }
        }
        canvas.drawPath(path, _stroke(0, 2));
        final p2 = Path()
          ..moveTo(3, h * 0.85)
          ..lineTo(w * 0.35, h * 0.7)
          ..lineTo(w * 0.6, h * 0.78)
          ..lineTo(w - 2, h * 0.6);
        canvas.drawPath(p2, _stroke(1, 2));
      case 'area' || 'stackedArea' || 'percentArea':
        axes();
        final top = v.id == 'percentArea' ? 2.0 : null;
        final p1 = Path()
          ..moveTo(2, h - 2)
          ..lineTo(2, top ?? h * 0.5)
          ..lineTo(w * 0.35, top ?? h * 0.25)
          ..lineTo(w * 0.65, top ?? h * 0.4)
          ..lineTo(w - 2, top ?? h * 0.15)
          ..lineTo(w - 2, h - 2)
          ..close();
        canvas.drawPath(p1, _fill(1)..color = colors[1].withValues(alpha: 0.7));
        final p0 = Path()
          ..moveTo(2, h - 2)
          ..lineTo(2, h * 0.75)
          ..lineTo(w * 0.35, h * 0.55)
          ..lineTo(w * 0.65, h * 0.7)
          ..lineTo(w - 2, h * 0.5)
          ..lineTo(w - 2, h - 2)
          ..close();
        canvas.drawPath(p0, _fill(0));
      case 'combo':
        axes();
        for (var i = 0; i < 4; i++) {
          final bw = (w - 8) / 4 * 0.6;
          final x = 4 + i * (w - 8) / 4;
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              (h - 2) * (1 - vals[i] * 0.7),
              bw,
              (h - 2) * vals[i] * 0.7,
            ),
            _fill(0),
          );
        }
        final p = Path()
          ..moveTo(4, h * 0.45)
          ..lineTo(w * 0.4, h * 0.2)
          ..lineTo(w * 0.7, h * 0.35)
          ..lineTo(w - 3, h * 0.1);
        canvas.drawPath(p, _stroke(1, 2));
      case 'pie' || 'doughnut':
        final c = Offset(w / 2, h / 2);
        final r = math.min(w, h) / 2 - 1;
        final rect = Rect.fromCircle(center: c, radius: r);
        const sweeps = [2.4, 1.9, 1.98];
        var a = -math.pi / 2;
        final ring = v.pieHole > 0;
        final rr = ring ? r * 0.72 : r;
        final arcRect = Rect.fromCircle(center: c, radius: rr);
        for (var i = 0; i < 3; i++) {
          if (ring) {
            canvas.drawArc(
              arcRect,
              a,
              sweeps[i] - 0.06,
              false,
              _stroke(i, r * 0.5)..strokeCap = StrokeCap.butt,
            );
          } else {
            canvas.drawArc(rect, a, sweeps[i], true, _fill(i));
          }
          a += sweeps[i];
        }
      case 'scatter' || 'bubble':
        axes();
        const pts = [
          (0.2, 0.7, 2.0),
          (0.4, 0.4, 3.5),
          (0.55, 0.6, 2.5),
          (0.75, 0.25, 4.5),
          (0.88, 0.45, 2.0),
        ];
        for (var i = 0; i < pts.length; i++) {
          final (x, y, s) = pts[i];
          canvas.drawCircle(
            Offset(w * x, h * y),
            v.id == 'bubble' ? s * 1.4 : 2.2,
            _fill(v.id == 'bubble' ? i : 0)
              ..color = colors[v.id == 'bubble' ? i % 3 : 0].withValues(
                alpha: v.id == 'bubble' ? 0.8 : 1,
              ),
          );
        }
      case 'candlestick':
        axes();
        for (var i = 0; i < 4; i++) {
          final x = 6 + i * (w - 10) / 4;
          final up = i.isEven;
          final top = h * (up ? 0.25 : 0.35) + i;
          final bottom = h * (up ? 0.6 : 0.75) - i;
          canvas.drawLine(
            Offset(x + 3, top - 4),
            Offset(x + 3, bottom + 4),
            _stroke(up ? 0 : 1, 1),
          );
          canvas.drawRect(
            Rect.fromLTRB(x, top, x + 6, bottom),
            _fill(up ? 0 : 1),
          );
        }
      case 'waterfall':
        axes();
        const steps = [(0.0, 0.5), (0.5, 0.7), (0.7, 0.45), (0.45, 0.85)];
        for (var i = 0; i < steps.length; i++) {
          final (a, b) = steps[i];
          final x = 4 + i * (w - 8) / 4;
          final bw = (w - 8) / 4 * 0.7;
          canvas.drawRect(
            Rect.fromLTRB(
              x,
              (h - 2) * (1 - math.max(a, b)),
              x + bw,
              (h - 2) * (1 - math.min(a, b)),
            ),
            _fill(b >= a ? 0 : 1),
          );
        }
      case 'scorecard':
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, w - 2, h - 2),
          const Radius.circular(3),
        );
        canvas.drawRRect(r, _stroke(2, 1));
        canvas.drawRect(
          Rect.fromLTWH(w * 0.25, h * 0.3, w * 0.5, h * 0.22),
          _fill(0),
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.35, h * 0.62, w * 0.3, h * 0.1),
          _fill(1),
        );
      case 'table':
        final p = Paint()
          ..color = muted
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), p);
        canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h / 4), _fill(0));
        for (var i = 2; i < 4; i++) {
          canvas.drawLine(Offset(1, h * i / 4), Offset(w - 1, h * i / 4), p);
        }
        canvas.drawLine(Offset(w / 2, 1), Offset(w / 2, h - 1), p);
      case 'radar':
        final c = Offset(w / 2, h / 2);
        final r = math.min(w, h) / 2 - 1;
        final web = Path();
        final data = Path();
        const ds = [0.9, 0.6, 0.8, 0.5, 0.7];
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          final q = c + Offset(math.cos(a), math.sin(a)) * r * ds[i];
          if (i == 0) {
            web.moveTo(p.dx, p.dy);
            data.moveTo(q.dx, q.dy);
          } else {
            web.lineTo(p.dx, p.dy);
            data.lineTo(q.dx, q.dy);
          }
        }
        web.close();
        data.close();
        canvas.drawPath(web, axis..style = PaintingStyle.stroke);
        canvas.drawPath(
          data,
          _fill(0)..color = colors[0].withValues(alpha: 0.5),
        );
        canvas.drawPath(data, _stroke(0, 1.4));
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.v.id != v.id || old.colors != colors || old.muted != muted;
}
