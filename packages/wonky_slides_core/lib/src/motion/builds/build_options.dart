/// `SlideBuild.optionsJson` (06 §2.2, A-06-3): effect parameters, delivery
/// (building in parts), after-build behavior, repeat and persistence, with
/// a validating codec. Unknown keys are kept (forward compatibility).
library;

import 'dart:convert';

import '../../model/api/kinds.dart';
import '../effects/effect_catalog.dart';

/// `delivery.by` (06 §2.3).
enum DeliveryBy {
  /// The whole element at once.
  all,

  /// Each paragraph (bullet).
  paragraph,

  /// Each top-level paragraph with its nested sub-bullets.
  paragraphGroup,

  /// Each laid-out line (P1; compiles as paragraph without layout).
  line,

  /// Each word.
  word,

  /// Each grapheme cluster.
  character,

  /// Chart: each visible series.
  series,

  /// Chart: all series at category 1, 2, ….
  category,

  /// Chart: each point.
  point,

  /// Chart: series (lines draw on), then data labels.
  chartElement;

  /// Whether this delivery splits text.
  bool get isText =>
      this == paragraph ||
      this == paragraphGroup ||
      this == line ||
      this == word ||
      this == character;

  /// Whether this delivery splits a chart.
  bool get isChart =>
      this == series ||
      this == category ||
      this == point ||
      this == chartElement;

  /// The value named [name], or null.
  static DeliveryBy? fromName(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// `delivery.order` (06 §2.3).
enum PartOrder {
  /// First part first.
  forward,

  /// Last part first.
  backward,

  /// Middle out.
  center,

  /// Outside in.
  edges,

  /// Fisher–Yates with a PRNG seeded by the build id.
  random;

  /// The value named [name], or null.
  static PartOrder? fromName(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// `afterBuild.mode` (06 §2.3).
enum AfterBuildMode {
  /// Earlier parts stay.
  none,

  /// Earlier parts dim to `dimOpacity` (or recolor to `dimColor`).
  dim,

  /// Earlier parts disappear.
  hide;

  /// The value named [name], or null.
  static AfterBuildMode? fromName(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// `optionsJson.delivery`.
final class BuildDelivery {
  /// Creates a delivery.
  const BuildDelivery({
    this.by = DeliveryBy.all,
    this.order = PartOrder.forward,
    this.from = 1,
    this.to,
    this.partTrigger,
    this.staggerMs,
    this.includeBackground = true,
  });

  /// The whole element at once.
  static const all = BuildDelivery();

  final DeliveryBy by;
  final PartOrder order;

  /// 1-based first part to build.
  final int from;

  /// 1-based last part to build (inclusive); null = to the end.
  final int? to;

  /// How parts after the first start; null = the default of [by] and the
  /// build kind ([effectivePartTrigger]).
  final SlideBuildTrigger? partTrigger;

  /// Gap between part starts; null = auto.
  final int? staggerMs;

  /// Charts: axes, gridlines, legend and titles come with part 1.
  final bool includeBackground;

  /// The part trigger in effect (06 §2.3, 08 §9.2): paragraphs of an in
  /// build one click each; words and characters staggered with the
  /// previous; chart parts after the previous; everything else after the
  /// previous.
  SlideBuildTrigger effectivePartTrigger(SlideBuildKind kind) {
    if (partTrigger != null) return partTrigger!;
    if ((by == DeliveryBy.paragraph ||
            by == DeliveryBy.paragraphGroup ||
            by == DeliveryBy.line) &&
        kind == SlideBuildKind.buildIn) {
      return SlideBuildTrigger.onClick;
    }
    if (by == DeliveryBy.word || by == DeliveryBy.character) {
      return SlideBuildTrigger.withPrevious;
    }
    return SlideBuildTrigger.afterPrevious;
  }

  /// The stagger in effect for parts of a build of [durationMs]: explicit
  /// [staggerMs], else 15 % of the duration (paragraphs), 60 ms (words),
  /// 30 ms (characters), 150 ms (charts), 0 for after-previous text parts.
  int effectiveStaggerMs(SlideBuildKind kind, int durationMs) {
    if (staggerMs != null) return staggerMs!;
    if (by.isChart) return 150;
    final trigger = effectivePartTrigger(kind);
    if (trigger == SlideBuildTrigger.afterPrevious) return 0;
    return switch (by) {
      DeliveryBy.word => 60,
      DeliveryBy.character => 30,
      _ => (durationMs * 0.15).round(),
    };
  }

  /// A copy with [by] replaced.
  BuildDelivery withBy(DeliveryBy by) => BuildDelivery(
    by: by,
    order: order,
    from: from,
    to: to,
    partTrigger: partTrigger,
    staggerMs: staggerMs,
    includeBackground: includeBackground,
  );

  /// JSON (defaults omitted).
  Map<String, Object?> toJson() => {
    'by': by.name,
    if (order != PartOrder.forward) 'order': order.name,
    if (from != 1 || to != null) 'parts': {'from': from, 'to': to},
    if (partTrigger != null) 'partTrigger': partTrigger!.name,
    if (staggerMs != null) 'staggerMs': staggerMs,
    if (!includeBackground) 'includeBackground': false,
  };
}

/// `optionsJson.afterBuild`.
final class AfterBuild {
  /// Creates the behavior.
  const AfterBuild({
    this.mode = AfterBuildMode.none,
    this.dimOpacity = 0.35,
    this.dimColor,
  });

  /// Nothing happens to earlier parts.
  static const none = AfterBuild();

  final AfterBuildMode mode;
  final double dimOpacity;

  /// Theme ref or hex for dimmed text, or null.
  final String? dimColor;

  /// JSON (defaults omitted).
  Map<String, Object?> toJson() => {
    'mode': mode.name,
    if (dimOpacity != 0.35) 'dimOpacity': dimOpacity,
    if (dimColor != null) 'dimColor': dimColor,
  };
}

/// `optionsJson.repeat` (transient emphasis only).
final class BuildRepeat {
  /// Creates the repeat.
  const BuildRepeat({
    this.count = 1,
    this.untilNextClick = false,
    this.autoReverse = false,
  });

  /// Plays once.
  static const once = BuildRepeat();

  /// 1–20.
  final int count;

  /// Loops until the next step starts.
  final bool untilNextClick;
  final bool autoReverse;

  /// JSON (defaults omitted).
  Map<String, Object?> toJson() => {
    if (count != 1) 'count': count,
    if (untilNextClick) 'untilNextClick': true,
    if (autoReverse) 'autoReverse': true,
  };
}

/// The decoded `SlideBuild.optionsJson`.
final class BuildOptions {
  /// Creates options.
  const BuildOptions({
    this.params = const {},
    this.delivery = BuildDelivery.all,
    this.afterBuild = AfterBuild.none,
    this.repeat = BuildRepeat.once,
    this.persist,
    this.extra = const {},
  });

  /// All defaults (`optionsJson` null).
  static const defaults = BuildOptions();

  /// Effect parameters (omitted keys = catalog defaults; unknown kept).
  final Map<String, Object?> params;
  final BuildDelivery delivery;
  final AfterBuild afterBuild;
  final BuildRepeat repeat;

  /// Emphasis: overrides the effect's default persistence (06 §3.3).
  final bool? persist;

  /// Unknown top-level keys (written back unchanged).
  final Map<String, Object?> extra;

  /// Parameter [key] with the catalog default of [spec].
  Object? param(EffectSpec? spec, String key) =>
      params[key] ?? spec?.param(key)?.defaultValue;

  /// Numeric parameter [key] (catalog default, then [orElse]).
  double number(EffectSpec? spec, String key, double orElse) {
    final v = param(spec, key);
    return v is num ? v.toDouble() : orElse;
  }

  /// The JSON object (`"v": 1`, defaults omitted).
  Map<String, Object?> toJson() => {
    ...extra,
    'v': 1,
    if (params.isNotEmpty) 'params': params,
    if (delivery.by != DeliveryBy.all || delivery.toJson().length > 1)
      'delivery': delivery.toJson(),
    if (afterBuild.mode != AfterBuildMode.none)
      'afterBuild': afterBuild.toJson(),
    if (repeat.toJson().isNotEmpty) 'repeat': repeat.toJson(),
    if (persist != null) 'persist': persist,
  };

  /// The column value: null when everything is a default.
  String? encode() {
    final j = toJson();
    if (j.length == 1) return null;
    return jsonEncode(j);
  }

  /// Decodes and validates [json] (null = defaults). Wrong types are
  /// errors; out-of-range values are clamped with a warning. When
  /// [kind]/[effect] are given the params are validated against the
  /// catalog too (06 §3.5).
  static MotionValidation<BuildOptions> decode(
    String? json, {
    SlideBuildKind? kind,
    String? effect,
  }) {
    final warnings = <MotionIssue>[];
    final errors = <MotionIssue>[];
    if (json == null || json.trim().isEmpty) {
      return MotionValidation(defaults, warnings, errors);
    }
    Object? raw;
    try {
      raw = jsonDecode(json);
    } on FormatException catch (e) {
      errors.add(MotionIssue('invalid_json', e.message));
      return MotionValidation(defaults, warnings, errors);
    }
    if (raw is! Map<String, Object?>) {
      errors.add(const MotionIssue('invalid_type', 'Must be a JSON object'));
      return MotionValidation(defaults, warnings, errors);
    }
    return fromJson(raw, kind: kind, effect: effect);
  }

  /// [decode] of an already parsed object.
  static MotionValidation<BuildOptions> fromJson(
    Map<String, Object?> raw, {
    SlideBuildKind? kind,
    String? effect,
  }) {
    final warnings = <MotionIssue>[];
    final errors = <MotionIssue>[];
    void err(String path, String message) =>
        errors.add(MotionIssue('invalid_type', message, path: path));
    num? clampNum(Object? v, String path, num min, num max) {
      if (v == null) return null;
      if (v is! num || !v.isFinite) {
        err(path, 'Must be a number');
        return null;
      }
      final n = v.clamp(min, max);
      if (n != v) {
        warnings.add(MotionIssue('clamped', 'Clamped to $n', path: path));
      }
      return n;
    }

    final extra = <String, Object?>{
      for (final e in raw.entries)
        if (!const {
          'v',
          'params',
          'delivery',
          'afterBuild',
          'repeat',
          'persist',
        }.contains(e.key))
          e.key: e.value,
    };

    var params = <String, Object?>{};
    final p = raw['params'];
    if (p is Map<String, Object?>) {
      params = {...p};
    } else if (p != null) {
      err('params', 'Must be an object');
    }
    if (kind != null && effect != null) {
      final v = EffectCatalog.validate(kind, effect, params);
      if (EffectCatalog.byId(kind, effect) != null) {
        params = v.value;
        warnings.addAll(v.warnings);
        errors.addAll(v.errors);
      }
    }

    var delivery = BuildDelivery.all;
    final d = raw['delivery'];
    if (d is Map<String, Object?>) {
      final by = d['by'] == null
          ? DeliveryBy.all
          : DeliveryBy.fromName(d['by']);
      if (by == null) err('delivery.by', 'Unknown delivery "${d['by']}"');
      final order = d['order'] == null
          ? PartOrder.forward
          : PartOrder.fromName(d['order']);
      if (order == null) err('delivery.order', 'Unknown order "${d['order']}"');
      var from = 1;
      int? to;
      final parts = d['parts'];
      if (parts is Map<String, Object?>) {
        from = (clampNum(parts['from'], 'delivery.parts.from', 1, 100000) ?? 1)
            .round();
        to = clampNum(parts['to'], 'delivery.parts.to', 1, 100000)?.round();
        if (to != null && to < from) {
          warnings.add(
            const MotionIssue(
              'clamped',
              'The last part comes before the first',
              path: 'delivery.parts.to',
            ),
          );
          to = from;
        }
      } else if (parts != null) {
        err('delivery.parts', 'Must be an object');
      }
      SlideBuildTrigger? partTrigger;
      if (d['partTrigger'] != null) {
        partTrigger = SlideBuildTrigger.fromName(d['partTrigger']);
        if (partTrigger == null ||
            partTrigger == SlideBuildTrigger.onElementClick) {
          err('delivery.partTrigger', 'Unknown trigger "${d['partTrigger']}"');
          partTrigger = null;
        }
      }
      final stagger = clampNum(d['staggerMs'], 'delivery.staggerMs', 0, 60000);
      final bg = d['includeBackground'];
      if (bg != null && bg is! bool) {
        err('delivery.includeBackground', 'Must be true or false');
      }
      delivery = BuildDelivery(
        by: by ?? DeliveryBy.all,
        order: order ?? PartOrder.forward,
        from: from,
        to: to,
        partTrigger: partTrigger,
        staggerMs: stagger?.round(),
        includeBackground: bg is bool ? bg : true,
      );
    } else if (d != null) {
      err('delivery', 'Must be an object');
    }

    var afterBuild = AfterBuild.none;
    final a = raw['afterBuild'];
    if (a is Map<String, Object?>) {
      final mode = a['mode'] == null
          ? AfterBuildMode.none
          : AfterBuildMode.fromName(a['mode']);
      if (mode == null) err('afterBuild.mode', 'Unknown mode "${a['mode']}"');
      final dim = clampNum(a['dimOpacity'], 'afterBuild.dimOpacity', 0, 1);
      final color = a['dimColor'];
      if (color != null && color is! String) {
        err('afterBuild.dimColor', 'Must be a color');
      }
      afterBuild = AfterBuild(
        mode: mode ?? AfterBuildMode.none,
        dimOpacity: dim?.toDouble() ?? 0.35,
        dimColor: color is String ? color : null,
      );
    } else if (a != null) {
      err('afterBuild', 'Must be an object');
    }

    var repeat = BuildRepeat.once;
    final r = raw['repeat'];
    if (r is Map<String, Object?>) {
      final count = clampNum(r['count'], 'repeat.count', 1, 20);
      final until = r['untilNextClick'];
      final reverse = r['autoReverse'];
      if (until != null && until is! bool) {
        err('repeat.untilNextClick', 'Must be true or false');
      }
      if (reverse != null && reverse is! bool) {
        err('repeat.autoReverse', 'Must be true or false');
      }
      repeat = BuildRepeat(
        count: count?.round() ?? 1,
        untilNextClick: until == true,
        autoReverse: reverse == true,
      );
    } else if (r != null) {
      err('repeat', 'Must be an object');
    }

    final persist = raw['persist'];
    if (persist != null && persist is! bool) {
      err('persist', 'Must be true or false');
    }

    return MotionValidation(
      BuildOptions(
        params: params,
        delivery: delivery,
        afterBuild: afterBuild,
        repeat: repeat,
        persist: persist is bool ? persist : null,
        extra: extra,
      ),
      warnings,
      errors,
    );
  }
}

/// RFC 7386 JSON merge patch of [patch] onto [target] (pane edits of
/// `optionsJson` and `transitionJson`: read-modify-write on the latest
/// local value, 06 §11).
Map<String, Object?> jsonMergePatch(
  Map<String, Object?>? target,
  Map<String, Object?> patch,
) {
  final out = <String, Object?>{...?target};
  for (final e in patch.entries) {
    final v = e.value;
    if (v == null) {
      out.remove(e.key);
    } else if (v is Map<String, Object?>) {
      final cur = out[e.key];
      out[e.key] = jsonMergePatch(cur is Map<String, Object?> ? cur : null, v);
    } else {
      out[e.key] = v;
    }
  }
  return out;
}
