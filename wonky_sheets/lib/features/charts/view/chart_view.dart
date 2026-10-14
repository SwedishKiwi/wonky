import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../../l10n/sheets_l10n.dart';
import '../controller/chart_controller.dart';
import '../render/chart_painter.dart';

/// A chart over the grid or on a chart sheet (08 §6.5, §9.1): the cached
/// scene laid out at the logical size and painted scaled by [zoom]; hover
/// shows the nearest point's value, a click on a legend entry highlights
/// that series.
class ChartObjectView extends StatefulWidget {
  const ChartObjectView({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
    this.zoom = 1,
    this.interactive = true,
  });

  final ChartController controller;

  /// Logical size (100 % zoom).
  final double width;
  final double height;
  final double zoom;
  final bool interactive;

  @override
  State<ChartObjectView> createState() => _ChartObjectViewState();
}

class _ChartObjectViewState extends State<ChartObjectView> {
  SceneHit? _hover;
  Offset? _hoverAt;
  Offset? _down;

  ChartController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  @override
  void didUpdateWidget(ChartObjectView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  ChartScene _scene(BuildContext context) => c.sceneFor(
    widget.width,
    widget.height,
    dark: chartDarkOf(context),
    tokens: chartUiTokensOf(context),
  );

  void _onHover(PointerHoverEvent e, ChartScene scene) {
    final p = e.localPosition / widget.zoom;
    final hit = scene.hitTest(p.dx, p.dy);
    final show =
        hit != null &&
        (hit.tag.role == SceneRole.point || hit.tag.role == SceneRole.series) &&
        hit.tag.pointIndex != null;
    final next = show ? hit : null;
    if (next?.tag != _hover?.tag ||
        (next != null && _hoverAt != e.localPosition)) {
      setState(() {
        _hover = next;
        _hoverAt = e.localPosition;
      });
    }
  }

  void _onUp(PointerUpEvent e, ChartScene scene) {
    final d = _down;
    _down = null;
    if (d == null || (e.localPosition - d).distance > 3) return;
    final p = e.localPosition / widget.zoom;
    final hit = scene.hitTest(p.dx, p.dy, tolerance: 2);
    if (hit?.tag.role == SceneRole.legendEntry) {
      final key = hit!.tag.seriesKey;
      c.highlight = c.highlight == key ? null : key;
    } else if (c.highlight != null &&
        (hit == null || hit.tag.role == SceneRole.background)) {
      c.highlight = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene(context);
    final w = widget.width * widget.zoom;
    final h = widget.height * widget.zoom;
    Widget paint = CustomPaint(
      size: Size(w, h),
      painter: ChartScenePainter(scene, scale: widget.zoom),
      isComplex: true,
      willChange: false,
    );
    if (!widget.interactive) return paint;
    final hover = _hover;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _down = e.localPosition,
      onPointerUp: (e) => _onUp(e, scene),
      child: MouseRegion(
        opaque: false,
        onHover: (e) => _onHover(e, scene),
        onExit: (_) {
          if (_hover != null) setState(() => _hover = null);
        },
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              paint,
              if (hover != null && _hoverAt != null)
                _Tooltip(
                  at: _hoverAt!,
                  bounds: Size(w, h),
                  lines: _tooltipLines(hover),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _tooltipLines(SceneHit hit) {
    final data = c.data;
    final i = hit.tag.pointIndex!;
    final lines = <String>[];
    if (i >= 0 && i < data.domain.length && !data.domain.isSynthetic) {
      lines.add(data.domain.labels[i]);
    }
    final fmt = DefaultChartValueFormatter(locale: c.editor.locale);
    final compare = c.spec.style.compareMode == CompareMode.category;
    for (final s in data.series) {
      if (!compare && s.key != hit.tag.seriesKey) continue;
      if (i < 0 || i >= s.values.length) continue;
      final v = s.values[i];
      final text = v.isNaN ? '–' : fmt.format(v, s.numberFormat);
      lines.add('${s.name}: $text');
    }
    return lines;
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.at, required this.bounds, required this.lines});

  final Offset at;
  final Size bounds;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    const maxW = 220.0;
    final left = math.max(0.0, math.min(at.dx + 12, bounds.width - maxW));
    final top = math.max(0.0, at.dy + 16);
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          key: const ValueKey<String>('sheets.chart.tooltip'),
          constraints: const BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.popover,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.border),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 6),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++)
                Text(
                  lines[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: i == 0
                      ? theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.popoverForeground,
                        )
                      : theme.textTheme.small.copyWith(
                          color: theme.colorScheme.popoverForeground,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder of a chart written by a newer app version (08 §1.3).
class NewerVersionChartCard extends StatelessWidget {
  const NewerVersionChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    return Container(
      color: theme.colorScheme.card,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        l.chartNewerVersion,
        textAlign: TextAlign.center,
        style: theme.textTheme.muted,
      ),
    );
  }
}
