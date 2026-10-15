import 'package:wonky_slides_core/charts.dart' show SlideChartMotion;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/ops.dart' show BuildSpec;

/// Ready-made build sequences (06 §10): *Build all steps* of code blocks
/// (07 §6) and charts (08 §9).
abstract final class BuildRecipes {
  /// The builds of *Build all steps* for [elementId], or null when it is
  /// neither a code block with steps nor a chart:
  ///
  /// - code: one `codeHighlight` per highlight step of the first state,
  ///   then for every further state a `codeState` followed by its
  ///   highlight steps — each on click;
  /// - chart: one `chartGrow` by series (by category with one series),
  ///   each part on click.
  static List<BuildSpec>? allSteps(DeckReader deck, String elementId) {
    final e = deck.element(elementId);
    if (e == null || e.slideId == null) return null;
    switch (e.kind) {
      case ElementKind.code:
        final states = deck.codeStatesOf(elementId);
        final specs = <BuildSpec>[];
        for (final (i, s) in states.indexed) {
          if (i > 0) {
            specs.add(
              BuildEdits.spec(
                elementId: elementId,
                kind: SlideBuildKind.emphasis,
                effect: 'codeState',
                params: {'state': i + 1},
              ),
            );
          }
          final steps = MotionCodeState.stepsOf(s.highlight);
          for (var k = 1; k <= steps; k++) {
            specs.add(
              BuildEdits.spec(
                elementId: elementId,
                kind: SlideBuildKind.emphasis,
                effect: 'codeHighlight',
                params: {'step': k},
              ),
            );
          }
        }
        return specs.isEmpty ? null : specs;
      case ElementKind.chart:
        final shape = SlideChartMotion.shapeOf(e, deck);
        final bySeries = shape == null || shape.seriesKeys.length > 1;
        return [
          BuildEdits.spec(
            elementId: elementId,
            kind: SlideBuildKind.buildIn,
            effect: 'chartGrow',
            delivery: BuildDelivery(
              by: bySeries ? DeliveryBy.series : DeliveryBy.category,
              partTrigger: SlideBuildTrigger.onClick,
            ),
          ),
        ];
      default:
        return null;
    }
  }
}

/// Motion path presets (06 §3.4): editable SVG path data in su relative
/// to the element's center at the start of the build, scaled to the
/// element (a quarter of the slide width at most).
abstract final class MotionPaths {
  /// The presets offered by the Build tab.
  static const presets = ['line', 'arc', 'curve', 'circle', 'zigzag'];

  /// The path of [preset] for [element] (null element = 400 su long).
  static String preset(String preset, SlideElementRec? element) {
    final w = element?.width ?? 400;
    final d = _round((w * 1.5).clamp(200, 480).toDouble());
    final h = _round(d * 0.5);
    String n(double v) => _fmt(v);
    return switch (preset) {
      'arc' => 'M0 0 Q${n(d / 2)} ${n(-h * 1.2)} ${n(d)} 0',
      'curve' => 'M0 0 C${n(d / 3)} ${n(-h)} ${n(d * 2 / 3)} ${n(h)} ${n(d)} 0',
      'circle' => () {
        final r = _round(d / 3);
        final k = _round(r * 0.5523);
        return 'M0 0 C${n(k)} 0 ${n(r)} ${n(-r + k)} ${n(r)} ${n(-r)} '
            'C${n(r)} ${n(-r - k)} ${n(k)} ${n(-2 * r)} 0 ${n(-2 * r)} '
            'C${n(-k)} ${n(-2 * r)} ${n(-r)} ${n(-r - k)} ${n(-r)} ${n(-r)} '
            'C${n(-r)} ${n(-r + k)} ${n(-k)} 0 0 0';
      }(),
      'zigzag' => () {
        final s = d / 4;
        return 'M0 0 L${n(s)} ${n(-h / 2)} L${n(2 * s)} 0 '
            'L${n(3 * s)} ${n(-h / 2)} L${n(d)} 0';
      }(),
      _ => 'M0 0 L${n(d)} 0',
    };
  }

  static double _round(double v) => v.roundToDouble();

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}
