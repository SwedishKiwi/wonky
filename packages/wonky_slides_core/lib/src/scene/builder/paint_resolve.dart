/// Element style JSON (02 §5.2–§5.4) → concrete scene paint values, with
/// the theme's default object styles (05 §2.7) for unset columns.
library;

import 'dart:math' as math;

import 'package:wonky_charts/wonky_charts.dart' show SStrokeCap, SStrokeJoin;

import '../../connectors/connector_router.dart';
import '../../theme/color/color_ref.dart';
import '../../theme/json/json_util.dart';
import '../../theme/model/object_styles.dart';
import '../../theme/model/paint.dart';
import '../../theme/resolve/resolved_theme.dart';
import '../nodes/scene_nodes.dart';

/// Resolves style JSON against a theme.
abstract final class ScenePaint {
  /// The fill of [json] (`fillJson`), else [fallback] (a theme default),
  /// else none.
  static ResolvedFill fill(
    ResolvedTheme theme,
    JsonMap? json, {
    SlideFill? fallback,
  }) {
    SlideFill? f;
    if (json != null) f = SlideFill.fromJson(json, 'fillJson', IssueSink());
    f ??= fallback;
    return f == null ? const ResolvedNoFill() : theme.fill(f);
  }

  /// The stroke of [json] (`strokeJson`) over [fallback]: missing
  /// properties come from the fallback, then renderer defaults (width 2,
  /// `text1`). `{"type":"none"}` or a zero width → null.
  static NodeStroke? stroke(
    ResolvedTheme theme,
    JsonMap? json, {
    SlideStroke? fallback,
    bool arrows = false,
  }) {
    SlideStroke? s;
    if (json != null) s = SlideStroke.fromJson(json, 'strokeJson', IssueSink());
    if (s == null && fallback == null) return null;
    if (s?.isNone ?? false) return null;
    if (s == null && fallback!.isNone) return null;
    final f = fallback != null && !fallback.isNone ? fallback : null;
    final width = s?.width ?? f?.width ?? 2;
    if (width <= 0) return null;
    final colorRef = s?.color ?? f?.color;
    final color = colorRef == null
        ? theme.colorOf('text1')!
        : theme.color(colorRef);
    final dash = s?.dash ?? f?.dash ?? 'solid';
    final cap = s?.cap ?? f?.cap;
    return NodeStroke(
      width: width,
      color: color,
      dash: dashPattern(dash, width),
      cap: switch (cap) {
        'round' => SStrokeCap.round,
        'square' => SStrokeCap.square,
        _ => dash == 'dot' ? SStrokeCap.round : SStrokeCap.butt,
      },
      join: switch (s?.join ?? f?.join) {
        'round' => SStrokeJoin.round,
        'bevel' => SStrokeJoin.bevel,
        _ => SStrokeJoin.miter,
      },
      startArrow: arrows
          ? ArrowHeads.parse(s?.startArrow ?? f?.startArrow)
          : ArrowHead.none,
      endArrow: arrows
          ? ArrowHeads.parse(s?.endArrow ?? f?.endArrow)
          : ArrowHead.none,
      arrowScale: switch (s?.arrowSize ?? f?.arrowSize) {
        's' => 0.75,
        'l' => 1.5,
        _ => 1,
      },
    );
  }

  /// The on/off pattern of a dash style for a stroke of [width] (su).
  static List<double> dashPattern(String dash, double width) {
    final w = math.max(width, 1.0);
    return switch (dash) {
      'dash' => [4 * w, 3 * w],
      'dot' => [0.01, 2 * w],
      'dashDot' => [4 * w, 3 * w, 0.01, 3 * w],
      'longDash' => [8 * w, 3 * w],
      _ => const [],
    };
  }

  /// The effects of [json] (`effectsJson`): outer shadow, glow (as a
  /// zero-offset shadow with spread) and layer blur.
  static NodeEffects effects(ResolvedTheme theme, JsonMap? json) {
    if (json == null) return NodeEffects.none;
    final shadows = <NodeShadow>[];
    final sh = json['shadow'];
    if (sh is Map) {
      final s = SlideShadow.fromJson(sh, 'effectsJson.shadow', IssueSink());
      if (s != null) {
        shadows.add(
          NodeShadow(
            color: theme.color(s.color),
            dx: s.dx,
            dy: s.dy,
            blur: s.blur,
            spread: s.spread,
          ),
        );
      }
    }
    final glow = json['glow'];
    if (glow is Map) {
      final c = ColorRef.tryParse(glow['color']);
      final r = glow['radius'];
      if (c != null && r is num && r > 0) {
        shadows.add(
          NodeShadow(
            color: theme.color(c),
            blur: r.toDouble(),
            spread: r.toDouble() / 2,
          ),
        );
      }
    }
    final blur = json['blur'];
    final sigma = blur is num && blur > 0 ? blur.toDouble() : 0.0;
    if (shadows.isEmpty && sigma == 0) return NodeEffects.none;
    return NodeEffects(shadows: shadows, blurSigma: sigma);
  }

  /// [fill] shaded by [shade] (−1 darkens … +1 lightens, OKLCH lightness).
  static ResolvedFill shaded(ResolvedFill fill, double shade) {
    if (shade == 0) return fill;
    int adjust(int c) => LumModifier(shade).apply(c);
    return switch (fill) {
      ResolvedSolidFill(:final color) => ResolvedSolidFill(adjust(color)),
      ResolvedGradientFill() => ResolvedGradientFill(
        kind: fill.kind,
        angle: fill.angle,
        stops: [for (final (p, c) in fill.stops) (p, adjust(c))],
        centerX: fill.centerX,
        centerY: fill.centerY,
        radius: fill.radius,
      ),
      _ => fill,
    };
  }

  /// Whether [fill] draws anything.
  static bool visible(ResolvedFill? fill) => switch (fill) {
    null || ResolvedNoFill() => false,
    ResolvedSolidFill(:final color) => (color >>> 24) != 0,
    _ => true,
  };

  /// The table border of a cell column value or a theme border, resolved.
  static NodeStroke? border(ResolvedTheme theme, TableBorder? b) {
    if (b == null || !b.isVisible) return null;
    return NodeStroke(
      width: b.width,
      color: theme.color(b.color),
      dash: dashPattern(b.dash, b.width),
    );
  }

  /// Parses a cell border column (`"width|style|color"`; `dashed`/`dotted`
  /// accepted for `dash`/`dot`).
  static TableBorder? parseBorder(String? raw) {
    if (raw == null) return null;
    final normalized = raw
        .replaceFirst('|dashed|', '|dash|')
        .replaceFirst('|dotted|', '|dot|');
    return TableBorder.parse(normalized, 'border', IssueSink());
  }
}
