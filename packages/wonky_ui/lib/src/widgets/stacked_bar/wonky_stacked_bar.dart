import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// One part of a [WonkyStackedBar].
@immutable
class WonkyStackedBarSegment {
  const WonkyStackedBarSegment({
    required this.label,
    required this.value,
    required this.color,
    this.valueLabel,
    this.id,
    this.hollow = false,
    this.inBar = true,
    this.inLegend = true,
  });

  /// Legend text ("Documents").
  final String label;

  /// Share of the bar (same unit as [WonkyStackedBar.total]).
  final double value;

  final Color color;

  /// Formatted value next to the label ("4.2 MB").
  final String? valueLabel;

  /// Stable id of the legend entry (key `<keyPrefix>.<id>`).
  final String? id;

  /// Legend swatch as an outline (the "free" remainder).
  final bool hollow;

  /// Whether the segment is drawn in the bar (false: legend only).
  final bool inBar;

  /// Whether the segment is listed in the legend (false: bar only).
  final bool inLegend;

  String get legendText => valueLabel == null ? label : '$label $valueLabel';
}

/// A horizontal bar of stacked parts with a legend (suite 02 §4, Drive 04
/// §14): the Storage page's usage by kind. Parts are drawn in order; the
/// rest of [total] shows the track color. Screen readers get one node whose
/// label lists every legend entry ("Documents 4.2 MB, Spreadsheets …").
class WonkyStackedBar extends StatelessWidget {
  const WonkyStackedBar({
    super.key,
    required this.segments,
    this.total,
    this.height = 12,
    this.showLegend = true,
    this.semanticLabel,
    this.keyPrefix = 'stackedBar',
  });

  final List<WonkyStackedBarSegment> segments;

  /// The full bar; null = the sum of the drawn segments. Parts beyond it
  /// are scaled down to fit.
  final double? total;

  final double height;
  final bool showLegend;

  /// Overrides the generated semantics label.
  final String? semanticLabel;

  /// Prefix of the legend entries' keys.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final c = theme.colorScheme;
    final drawn = [
      for (final s in segments)
        if (s.inBar && s.value > 0) s,
    ];
    final sum = drawn.fold<double>(0, (a, s) => a + s.value);
    final full = total == null || total! < sum ? sum : total!;
    final legend = [
      for (final s in segments)
        if (s.inLegend) s,
    ];
    final label = semanticLabel ?? legend.map((s) => s.legendText).join(', ');

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final parts = <Widget>[];
            var left = 0.0;
            for (final s in drawn) {
              if (full <= 0 || left >= w) break;
              // Tiny parts stay visible (2 px).
              final width = (s.value / full * w).clamp(2.0, w - left);
              parts.add(
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: s.color,
                      border: Border(
                        right: BorderSide(color: c.card, width: 1),
                      ),
                    ),
                  ),
                ),
              );
              left += width;
            }
            return DecoratedBox(
              decoration: BoxDecoration(color: c.secondary),
              child: Stack(children: parts),
            );
          },
        ),
      ),
    );

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bar,
            if (showLegend && legend.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  for (final s in legend)
                    Row(
                      key: s.id == null
                          ? null
                          : ValueKey<String>('$keyPrefix.${s.id}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.hollow ? null : s.color,
                            border: s.hollow
                                ? Border.all(color: c.mutedForeground)
                                : null,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: s.label),
                                if (s.valueLabel != null)
                                  TextSpan(
                                    text: ' ${s.valueLabel}',
                                    style: TextStyle(
                                      color: c.mutedForeground,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            style: theme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
