import 'dart:convert';

import 'package:wonky_slides_core/markdown.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart' show SuRect;
import 'package:wonky_slides_core/schema.dart' show ElementCols;
import 'package:wonky_slides_core/themes.dart' show ColorRef;
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../../platform/mcp/tool_support.dart';
import 'slides_mcp_support.dart';
import 'slides_writes.dart';

/// Converts MCP arguments (snake_case, Markdown, slide units) into the
/// columns and values the Slides planner takes (Slides 11 §3.1–§3.2).
abstract final class SlidesInput {
  /// A text body from a `TextInput` (Markdown string, `{markdown}` or
  /// `{delta}`): the normalized Delta JSON. Flattening and slide-link
  /// warnings go to [warnings].
  static String text(
    DeckModel model,
    Object? input, {
    bool notes = false,
    required String pointer,
    List<SlidesWarning>? warnings,
    String? elementId,
  }) {
    if (input is Map && input['delta'] is List) {
      try {
        return SlidesText.normalizeJson(
          jsonEncode(input['delta']),
          notes: notes,
        )!;
      } on Object catch (e) {
        throw SlidesMcp.invalid('Invalid text delta: $e', pointer: pointer);
      }
    }
    final md = input is Map ? input['markdown'] : input;
    if (md is! String) {
      throw SlidesMcp.invalid(
        'Text must be Markdown or {"delta": [...]}.',
        pointer: pointer,
      );
    }
    final r = SlidesMarkdownCodec.toDelta(
      md,
      notes: notes,
      slideLink: (target) => slideLink(model, target),
    );
    for (final w in r.warnings) {
      warnings?.add(
        SlidesWarning(
          w,
          w == SlidesMarkdownWarnings.slideLink
              ? 'A slide link names no slide of this presentation; it was '
                    'removed.'
              : 'Markdown without a slide text form (images, tables, code '
                    'fences, HTML) was removed; use the element tools.',
          elementId: elementId,
          pointer: pointer,
        ),
      );
    }
    return r.deltaJson;
  }

  /// The stored `slide:<b62>` link of a Markdown `slide:` target (position,
  /// uuid or base-62 id), or null.
  static String? slideLink(DeckModel model, String target) {
    String? id;
    final n = int.tryParse(target.trim());
    if (n != null) {
      final slides = model.slides;
      if (n >= 1 && n <= slides.length) id = slides[n - 1].id;
    } else {
      final c = SlidesMcp.canonicalId(target);
      if (c != null && model.slide(c) != null) id = c;
    }
    return id == null ? null : 'slide:${Base62Uuid.encode(id)}';
  }

  /// Slide links of reads: `slide:<b62>` → the 1-based position.
  static String Function(String b62) linkOut(DeckModel model) {
    final positions = {
      for (final (i, s) in model.slides.indexed) Base62Uuid.encode(s.id): i + 1,
    };
    return (b62) => '${positions[b62] ?? b62}';
  }

  /// The Markdown of a body for reads.
  static String markdown(DeckModel model, String? json) =>
      SlidesMarkdownCodec.toMarkdown(json, slideLink: linkOut(model));

  /// A body in [format] (`markdown`, `rich`, `plain`).
  static Object textOut(DeckModel model, String? json, String format) =>
      switch (format) {
        'rich' => SlidesMarkdownCodec.toRich(json, slideLink: linkOut(model)),
        'plain' => SlidesMarkdownCodec.toPlain(json),
        _ => markdown(model, json),
      };

  // ------------------------------------------------------------- styles

  /// A `fillJson` from a Color string or a fill object.
  static String fill(Object? v, {required String pointer}) {
    if (v is String) {
      final c = v.trim();
      if (c == 'transparent' || c == 'none') {
        return jsonEncode({'v': 1, 'type': 'none'});
      }
      _color(c, pointer);
      return jsonEncode({'v': 1, 'type': 'solid', 'color': c});
    }
    if (v is Map) return jsonEncode({'v': 1, ...camel(v)});
    throw SlidesMcp.invalid('Invalid fill.', pointer: pointer);
  }

  /// A slide `backgroundJson` from a Color or a fill/background object.
  static String background(Object? v, {required String pointer}) {
    if (v is Map && v['fill'] != null) return jsonEncode({'v': 1, ...camel(v)});
    return jsonEncode({
      'v': 1,
      'fill': jsonDecode(fill(v, pointer: pointer)),
    });
  }

  static void _color(String c, String pointer) {
    if (ColorRef.tryParse(c) == null) {
      throw SlidesMcp.invalid(
        'Invalid color "$c": use "#RRGGBB", "#RRGGBBAA" or "theme:accent1".',
        pointer: pointer,
      );
    }
  }

  /// The element columns of a `Style` (merged over [current] JSON
  /// columns of the element, 02 §5).
  static Map<String, Object?> styleColumns(
    Map<String, Object?> style, {
    SlideElementRec? current,
    required String pointer,
  }) {
    final out = <String, Object?>{};
    Map<String, Object?> decode(String? json) {
      if (json == null) return {};
      try {
        final d = jsonDecode(json);
        return d is Map ? d.cast<String, Object?>() : {};
      } on FormatException {
        return {};
      }
    }

    if (style.containsKey('fill')) {
      out[ElementCols.fillJson] = fill(style['fill'], pointer: '$pointer/fill');
    }
    final stroke = style['stroke'];
    if (stroke is Map) {
      final s = {...decode(current?.strokeJson), 'v': 1};
      if (stroke['color'] is String) {
        _color(stroke['color'] as String, '$pointer/stroke/color');
        s['color'] = stroke['color'];
      }
      if (stroke['width'] is num) s['width'] = stroke['width'];
      if (stroke['dash'] == 'none') {
        s
          ..clear()
          ..addAll({'v': 1, 'type': 'none'});
      } else if (stroke['dash'] is String) {
        s['dash'] = stroke['dash'];
        s.remove('type');
      }
      out[ElementCols.strokeJson] = jsonEncode(s);
    }
    if (style['opacity'] is num) {
      out[ElementCols.opacity] = (style['opacity'] as num).toDouble();
    }
    if (style['corner_radius'] is num) {
      final d = {...decode(current?.dataJson), 'v': 1};
      d['adjust'] = {
        ...?(d['adjust'] as Map?)?.cast<String, Object?>(),
        'radius': style['corner_radius'],
      };
      out[ElementCols.dataJson] = jsonEncode(d);
    }
    final shadow = style['shadow'];
    if (shadow is String) {
      final e = {...decode(current?.effectsJson), 'v': 1};
      switch (shadow) {
        case 'none':
          e.remove('shadow');
        case 'soft':
          e['shadow'] = {'color': '#00000033', 'blur': 24, 'dx': 0, 'dy': 8};
        case 'strong':
          e['shadow'] = {'color': '#00000066', 'blur': 36, 'dx': 0, 'dy': 16};
      }
      out[ElementCols.effectsJson] = jsonEncode(e);
    }
    return out;
  }

  /// The `textStyleJson` merge patch of `Style.text` (02 §5.1).
  static Map<String, Object?>? textStylePatch(Map<String, Object?>? text) {
    if (text == null || text.isEmpty) return null;
    final defaults = <String, Object?>{
      if (text['font'] is String) 'font': text['font'],
      if (text['size'] is num) 'size': text['size'],
      if (text['color'] is String) 'color': text['color'],
      if (text['align'] is String) 'align': text['align'],
      if (text['line_height'] is num) 'lineHeight': text['line_height'],
      if (text['style'] is String) 'style': text['style'],
    };
    return {
      if (text['anchor'] is String) 'anchor': text['anchor'],
      if (text['autofit'] is String) 'autofit': text['autofit'],
      if (defaults.isNotEmpty) 'defaults': defaults,
    };
  }

  // ------------------------------------------------------------ geometry

  /// The slide size of [model].
  static (double, double) slideSize(DeckModel model) =>
      (model.deck?.width ?? 1920, model.deck?.height ?? 1080);

  /// A frame from `Frame` / `Placement` arguments ([fallback] when
  /// neither is given).
  static SuRect frame(
    DeckModel model, {
    Map<String, Object?>? frame,
    Map<String, Object?>? placement,
    required SuRect fallback,
    required String pointer,
  }) {
    final (sw, sh) = slideSize(model);
    if (frame != null) {
      double n(String k, double d) => (frame[k] as num?)?.toDouble() ?? d;
      return SuRect(
        n('x', fallback.x),
        n('y', fallback.y),
        n('w', fallback.width),
        n('h', fallback.height),
      );
    }
    if (placement == null) return fallback;
    final m = (placement['margin'] as num?)?.toDouble() ?? 80;
    final iw = sw - 2 * m, ih = sh - 2 * m;
    switch (placement['preset']) {
      case 'full':
        return SuRect(m, m, iw, ih);
      case 'fullBleed':
        return SuRect(0, 0, sw, sh);
      case 'leftHalf':
        return SuRect(m, m, (iw - m) / 2, ih);
      case 'rightHalf':
        return SuRect(m + (iw + m) / 2, m, (iw - m) / 2, ih);
      case 'topHalf':
        return SuRect(m, m, iw, (ih - m) / 2);
      case 'bottomHalf':
        return SuRect(m, m + (ih + m) / 2, iw, (ih - m) / 2);
      case 'leftThird' || 'centerThird' || 'rightThird':
        final w = (iw - 2 * m) / 3;
        final i = switch (placement['preset']) {
          'leftThird' => 0,
          'centerThird' => 1,
          _ => 2,
        };
        return SuRect(m + i * (w + m), m, w, ih);
      case 'grid':
        final g = (placement['grid'] as Map?)?.cast<String, Object?>() ?? {};
        final cols = (g['columns'] as num?)?.toInt() ?? 2;
        final rows = (g['rows'] as num?)?.toInt() ?? 2;
        final cell = ((g['cell'] as num?)?.toInt() ?? 1).clamp(1, cols * rows);
        final gap = (g['gap'] as num?)?.toDouble() ?? m / 2;
        final w = (iw - (cols - 1) * gap) / cols;
        final h = (ih - (rows - 1) * gap) / rows;
        final r = (cell - 1) ~/ cols, c = (cell - 1) % cols;
        return SuRect(m + c * (w + gap), m + r * (h + gap), w, h);
      case 'center':
      default:
        final w = fallback.width.clamp(1, iw).toDouble();
        final h = fallback.height.clamp(1, ih).toDouble();
        return SuRect((sw - w) / 2, (sh - h) / 2, w, h);
    }
  }

  // ------------------------------------------------------------- casing

  /// `snake_case` keys → `camelCase`, recursively.
  static Map<String, Object?> camel(Map<dynamic, dynamic> m) => {
    for (final e in m.entries) camelKey('${e.key}'): _camelValue(e.value),
  };

  static Object? _camelValue(Object? v) => switch (v) {
    Map() => camel(v),
    List() => [for (final x in v) _camelValue(x)],
    _ => v,
  };

  /// `duration_ms` → `durationMs`.
  static String camelKey(String k) => k.replaceAllMapped(
    RegExp(r'_([a-z0-9])'),
    (m) => m.group(1)!.toUpperCase(),
  );

  /// An enum value: `build_in` → `buildIn`.
  static String camelEnum(String v) => camelKey(v);

  /// `buildIn` → `build_in` (reads).
  static String snakeEnum(String v) => v.replaceAllMapped(
    RegExp('[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );

  /// `camelCase` keys → `snake_case`, recursively (reads).
  static Object? snake(Object? v) => switch (v) {
    Map() => {
      for (final e in v.entries) snakeEnum('${e.key}'): snake(e.value),
    },
    List() => [for (final x in v) snake(x)],
    _ => v,
  };

  /// A `TransitionSpec` JSON (06 §7) from the MCP `TransitionSpec`.
  static String transitionJson(Map<String, Object?> t) {
    final m = camel(t);
    final advance = m['advance'];
    if (advance is Map && advance['mode'] is String) {
      m['advance'] = {
        ...advance.cast<String, Object?>(),
        'mode': camelEnum(advance['mode'] as String),
      };
    }
    return jsonEncode({'v': 1, ...m});
  }

  /// An error for a missing argument.
  static McpToolException missing(String key) =>
      SlidesMcp.invalid('"$key" is required.', pointer: '/$key');
}
