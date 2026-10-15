import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_charts/wonky_charts.dart';

/// The tooltip lines of the data point tagged [tag] (Sheets 08 §9.1): the
/// category label, then `Series: value` of that series — or of every series
/// at that category when the spec compares by category.
List<String> chartTooltipLines(
  ChartData data,
  ChartSpec spec,
  SceneTag tag, {
  String locale = 'en_US',
}) {
  final i = tag.pointIndex;
  if (i == null) return const [];
  final lines = <String>[];
  if (i >= 0 && i < data.domain.length && !data.domain.isSynthetic) {
    lines.add(data.domain.labels[i]);
  }
  final fmt = DefaultChartValueFormatter(locale: locale);
  final compare = spec.style.compareMode == CompareMode.category;
  for (final s in data.series) {
    if (!compare && s.key != tag.seriesKey) continue;
    if (i < 0 || i >= s.values.length) continue;
    final v = s.values[i];
    final text = v.isNaN ? '–' : fmt.format(v, s.numberFormat);
    lines.add('${s.name}: $text');
  }
  return lines;
}

/// Whether a hit on [tag] shows a tooltip (a data point or series part with
/// a point index).
bool chartTooltipApplies(SceneTag? tag) =>
    tag != null &&
    (tag.role == SceneRole.point || tag.role == SceneRole.series) &&
    tag.pointIndex != null;

/// The hover tooltip of a chart (a popover card near the pointer, kept
/// inside [bounds]); place it in a `Stack` over the chart.
class ChartTooltip extends StatelessWidget {
  const ChartTooltip({
    super.key,
    required this.at,
    required this.bounds,
    required this.lines,
    this.cardKey = const ValueKey<String>('charts.tooltip'),
  });

  /// The pointer position in the chart's coordinates.
  final Offset at;

  /// The chart's size.
  final Size bounds;

  /// The first line is the heading.
  final List<String> lines;

  /// Key of the card (tests, MCP).
  final Key cardKey;

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
          key: cardKey,
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
