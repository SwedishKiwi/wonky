/// `Slide.transitionJson` (06 §7.1, A-06-4), the transition catalog
/// (06 §7.2) and the motion keys of `Deck.defaultsJson` (A-06-7), with
/// validating codecs. A slide's null `transitionJson` means the deck
/// default, which itself defaults to `{"type": "none"}`. Unknown keys are
/// kept. The transition *plans* (rendering, Magic Move) are SL-25's.
library;

import 'dart:convert';

import '../../model/api/kinds.dart';
import '../easing/motion_easing.dart';
import '../effects/effect_catalog.dart';
import 'build_options.dart';

/// One transition type of the catalog (06 §7.2).
final class TransitionTypeSpec {
  /// Creates a type.
  const TransitionTypeSpec(
    this.id,
    this.name,
    this.defaultDurationMs, {
    this.params = const [],
    this.is3d = false,
    this.available = true,
  });

  final String id;
  final String name;
  final int defaultDurationMs;
  final List<ParamSpec> params;
  final bool is3d;

  /// false for P2 types (they play as `fade`).
  final bool available;

  /// Catalog entry as JSON (MCP, AI).
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'defaultDurationMs': defaultDurationMs,
    'params': [for (final p in params) p.toJson()],
    '3d': is3d,
    if (!available) 'available': false,
  };
}

const _dir4 = ParamSpec(
  'direction',
  ParamType.choice,
  defaultValue: 'left',
  choices: ['left', 'right', 'up', 'down'],
);

/// The transition catalog (06 §7.2).
abstract final class TransitionCatalog {
  /// Every type in catalog order.
  static const List<TransitionTypeSpec> types = [
    TransitionTypeSpec('none', 'None', 0),
    TransitionTypeSpec(
      'fade',
      'Fade',
      500,
      params: [ParamSpec('through', ParamType.color)],
    ),
    TransitionTypeSpec(
      'dissolve',
      'Dissolve',
      700,
      params: [
        ParamSpec('cell', ParamType.number, defaultValue: 8, min: 1, max: 200),
      ],
    ),
    TransitionTypeSpec('push', 'Push', 700, params: [_dir4]),
    TransitionTypeSpec('slide', 'Slide in', 600, params: [_dir4]),
    TransitionTypeSpec('cover', 'Cover', 600, params: [_dir4]),
    TransitionTypeSpec('uncover', 'Uncover', 600, params: [_dir4]),
    TransitionTypeSpec(
      'wipe',
      'Wipe',
      700,
      params: [
        ParamSpec(
          'direction',
          ParamType.choice,
          defaultValue: 'left',
          choices: direction8,
        ),
        ParamSpec(
          'softness',
          ParamType.number,
          defaultValue: 0.15,
          min: 0,
          max: 1,
        ),
      ],
    ),
    TransitionTypeSpec(
      'iris',
      'Iris',
      700,
      params: [
        ParamSpec(
          'shape',
          ParamType.choice,
          defaultValue: 'circle',
          choices: ['circle', 'rect', 'diamond'],
        ),
        ParamSpec(
          'origin',
          ParamType.choice,
          defaultValue: 'center',
          choices: anchorChoices,
        ),
      ],
    ),
    TransitionTypeSpec(
      'zoom',
      'Zoom',
      700,
      params: [
        ParamSpec(
          'mode',
          ParamType.choice,
          defaultValue: 'in',
          choices: ['in', 'out'],
        ),
        ParamSpec(
          'origin',
          ParamType.choice,
          defaultValue: 'center',
          choices: anchorChoices,
        ),
      ],
    ),
    TransitionTypeSpec(
      'flip',
      'Flip',
      900,
      is3d: true,
      params: [
        ParamSpec(
          'axis',
          ParamType.choice,
          defaultValue: 'y',
          choices: ['x', 'y'],
        ),
        _dir4,
      ],
    ),
    TransitionTypeSpec('cube', 'Cube', 1000, is3d: true, params: [_dir4]),
    TransitionTypeSpec('doorway', 'Doorway', 1100, is3d: true),
    TransitionTypeSpec('swap', 'Swap', 1000, is3d: true, params: [_dir4]),
    TransitionTypeSpec('revolve', 'Revolve', 1000, is3d: true, params: [_dir4]),
    TransitionTypeSpec('magicMove', 'Magic Move', 1000),
    TransitionTypeSpec(
      'pageCurl',
      'Page curl',
      1200,
      is3d: true,
      params: [_dir4],
      available: false,
    ),
    TransitionTypeSpec('objectZoom', 'Object zoom', 1200, available: false),
  ];

  static final Map<String, TransitionTypeSpec> _byId = {
    for (final t in types) t.id: t,
  };

  /// The type [id], or null.
  static TransitionTypeSpec? byId(String id) => _byId[id];
}

/// `transitionJson.advance` (06 §4.4).
final class TransitionAdvance {
  /// Creates the advance settings.
  const TransitionAdvance({
    this.auto = false,
    this.afterMs = 0,
    this.autoBuilds = false,
    this.buildDelayMs = 1000,
  });

  /// On click.
  static const onClick = TransitionAdvance();

  /// `mode: auto`.
  final bool auto;

  /// Auto: delay after the last step settles.
  final int afterMs;

  /// Auto: play onClick steps automatically too.
  final bool autoBuilds;

  /// Auto builds: delay before each formerly-onClick step.
  final int buildDelayMs;

  /// JSON.
  Map<String, Object?> toJson() => {
    'mode': auto ? 'auto' : 'onClick',
    if (auto || afterMs != 0) 'afterMs': afterMs,
    if (autoBuilds) 'autoBuilds': true,
    if (buildDelayMs != 1000) 'buildDelayMs': buildDelayMs,
  };
}

/// `transitionJson.magicMove` (06 §8.6).
final class MagicMoveOptions {
  /// Creates the options.
  const MagicMoveOptions({
    this.textMatching = 'object',
    this.matchByContent = true,
    this.fadeUnmatched = 'together',
    this.rotation = 'shortest',
    this.stagger = 0,
  });

  /// object | word | character.
  final String textMatching;
  final bool matchByContent;

  /// together | before | after.
  final String fadeUnmatched;

  /// shortest | literal.
  final String rotation;

  /// ms between successive matched pairs.
  final int stagger;

  /// JSON.
  Map<String, Object?> toJson() => {
    'textMatching': textMatching,
    'matchByContent': matchByContent,
    'fadeUnmatched': fadeUnmatched,
    'rotation': rotation,
    'stagger': stagger,
  };
}

/// The decoded `Slide.transitionJson` (or the deck default).
final class TransitionSpec {
  /// Creates a transition.
  const TransitionSpec({
    this.type = 'none',
    this.durationMs = 0,
    this.easing = 'easeInOutCubic',
    this.params = const {},
    this.reverseOnBack = true,
    this.advance = TransitionAdvance.onClick,
    this.magicMove,
    this.extra = const {},
  });

  /// A cut (`{"type": "none"}`).
  static const none = TransitionSpec();

  /// Type id (06 §7.2); unknown ids from newer clients play as `fade`.
  final String type;
  final int durationMs;
  final String easing;
  final Map<String, Object?> params;
  final bool reverseOnBack;
  final TransitionAdvance advance;
  final MagicMoveOptions? magicMove;

  /// Unknown top-level keys (kept).
  final Map<String, Object?> extra;

  /// The catalog entry, or null for unknown types.
  TransitionTypeSpec? get typeSpec => TransitionCatalog.byId(type);

  /// Whether this is a cut.
  bool get isNone => type == 'none';

  /// The parsed easing (`easeInOutCubic` when invalid).
  MotionEasing get curve =>
      MotionEasing.tryParse(easing) ?? MotionEasing.parse('easeInOutCubic');

  /// A transition of [type] with the catalog defaults.
  factory TransitionSpec.of(String type) {
    final t = TransitionCatalog.byId(type);
    return TransitionSpec(
      type: type,
      durationMs: t?.defaultDurationMs ?? 500,
      params: {
        for (final p in t?.params ?? const <ParamSpec>[])
          if (p.defaultValue != null) p.key: p.defaultValue,
      },
      magicMove: type == 'magicMove' ? const MagicMoveOptions() : null,
    );
  }

  /// The JSON object (`"v": 1`).
  Map<String, Object?> toJson() => {
    ...extra,
    'v': 1,
    'type': type,
    if (!isNone) 'durationMs': durationMs,
    if (!isNone) 'easing': easing,
    if (params.isNotEmpty) 'params': params,
    if (!reverseOnBack) 'reverseOnBack': false,
    if (advance.auto || advance.autoBuilds || advance.afterMs != 0)
      'advance': advance.toJson(),
    if (magicMove != null) 'magicMove': magicMove!.toJson(),
  };

  /// The column value.
  String encode() => jsonEncode(toJson());

  /// The transition into a slide whose own column is [slideJson], with the
  /// deck's `defaultsJson` [deckDefaultsJson] (06 §7.1): the slide's own
  /// value, else the deck default, else none. Invalid JSON counts as
  /// absent.
  static TransitionSpec effective(String? slideJson, String? deckDefaultsJson) {
    if (slideJson != null) {
      final v = decode(slideJson);
      if (v.isValid) return v.value;
    }
    final t = DeckMotionDefaults.decode(deckDefaultsJson).transition;
    return t ?? none;
  }

  /// Decodes and validates [json] (null = none).
  static MotionValidation<TransitionSpec> decode(String? json) {
    if (json == null || json.trim().isEmpty) {
      return const MotionValidation(none, [], []);
    }
    Object? raw;
    try {
      raw = jsonDecode(json);
    } on FormatException catch (e) {
      return MotionValidation(none, const [], [
        MotionIssue('invalid_json', e.message),
      ]);
    }
    if (raw is! Map<String, Object?>) {
      return const MotionValidation(none, [], [
        MotionIssue('invalid_type', 'Must be a JSON object'),
      ]);
    }
    return fromJson(raw);
  }

  /// [decode] of an already parsed object.
  static MotionValidation<TransitionSpec> fromJson(Map<String, Object?> raw) {
    final warnings = <MotionIssue>[];
    final errors = <MotionIssue>[];
    void err(String path, String message) =>
        errors.add(MotionIssue('invalid_type', message, path: path));
    int? intIn(Object? v, String path, int min, int max) {
      if (v == null) return null;
      if (v is! num || !v.isFinite) {
        err(path, 'Must be a number');
        return null;
      }
      final n = v.round().clamp(min, max);
      if (n != v) {
        warnings.add(MotionIssue('clamped', 'Clamped to $n', path: path));
      }
      return n;
    }

    final type = raw['type'] ?? 'none';
    if (type is! String || type.isEmpty) {
      err('type', 'Must be a transition type');
      return MotionValidation(none, warnings, errors);
    }
    final spec = TransitionCatalog.byId(type);
    if (spec == null) {
      warnings.add(
        MotionIssue(
          'unknown_transition',
          'Unknown transition "$type" (plays as fade)',
          path: 'type',
        ),
      );
    }
    final duration =
        intIn(raw['durationMs'], 'durationMs', 0, 20000) ??
        spec?.defaultDurationMs ??
        500;
    var easing = 'easeInOutCubic';
    final e = raw['easing'];
    if (e is String) {
      if (MotionEasing.tryParse(e) == null) {
        err('easing', 'Unknown easing "$e"');
      } else {
        easing = e;
      }
    } else if (e != null) {
      err('easing', 'Must be an easing expression');
    }
    var params = <String, Object?>{};
    final p = raw['params'];
    if (p is Map<String, Object?>) {
      params = {...p};
      for (final ps in spec?.params ?? const <ParamSpec>[]) {
        final v = params[ps.key];
        if (v == null) continue;
        if (ps.type == ParamType.choice &&
            (v is! String || !ps.choices.contains(v))) {
          err('params.${ps.key}', 'Must be one of ${ps.choices.join(', ')}');
        } else if (ps.type == ParamType.number) {
          if (v is! num) {
            err('params.${ps.key}', 'Must be a number');
          } else {
            final n = v.clamp(ps.min ?? v, ps.max ?? v);
            if (n != v) {
              warnings.add(
                MotionIssue(
                  'clamped',
                  'Clamped to $n',
                  path: 'params.${ps.key}',
                ),
              );
              params[ps.key] = n;
            }
          }
        }
      }
    } else if (p != null) {
      err('params', 'Must be an object');
    }
    final back = raw['reverseOnBack'];
    if (back != null && back is! bool) {
      err('reverseOnBack', 'Must be true or false');
    }

    var advance = TransitionAdvance.onClick;
    final a = raw['advance'];
    if (a is Map<String, Object?>) {
      final mode = a['mode'] ?? 'onClick';
      if (mode != 'onClick' && mode != 'auto') {
        err('advance.mode', 'Must be onClick or auto');
      }
      final ab = a['autoBuilds'];
      if (ab != null && ab is! bool) {
        err('advance.autoBuilds', 'Must be true or false');
      }
      advance = TransitionAdvance(
        auto: mode == 'auto',
        afterMs: intIn(a['afterMs'], 'advance.afterMs', 0, 3600000) ?? 0,
        autoBuilds: ab == true,
        buildDelayMs:
            intIn(a['buildDelayMs'], 'advance.buildDelayMs', 0, 600000) ?? 1000,
      );
    } else if (a != null) {
      err('advance', 'Must be an object');
    }

    MagicMoveOptions? magic;
    final m = raw['magicMove'];
    if (m is Map<String, Object?>) {
      String choice(String key, List<String> values, String def) {
        final v = m[key];
        if (v == null) return def;
        if (v is String && values.contains(v)) return v;
        err('magicMove.$key', 'Must be one of ${values.join(', ')}');
        return def;
      }

      final byContent = m['matchByContent'];
      if (byContent != null && byContent is! bool) {
        err('magicMove.matchByContent', 'Must be true or false');
      }
      magic = MagicMoveOptions(
        textMatching: choice('textMatching', const [
          'object',
          'word',
          'character',
        ], 'object'),
        matchByContent: byContent is bool ? byContent : true,
        fadeUnmatched: choice('fadeUnmatched', const [
          'together',
          'before',
          'after',
        ], 'together'),
        rotation: choice('rotation', const ['shortest', 'literal'], 'shortest'),
        stagger: intIn(m['stagger'], 'magicMove.stagger', 0, 2000) ?? 0,
      );
    } else if (m != null) {
      err('magicMove', 'Must be an object');
    } else if (type == 'magicMove') {
      magic = const MagicMoveOptions();
    }

    final extra = <String, Object?>{
      for (final en in raw.entries)
        if (!const {
          'v',
          'type',
          'durationMs',
          'easing',
          'params',
          'reverseOnBack',
          'advance',
          'magicMove',
        }.contains(en.key))
          en.key: en.value,
    };
    return MotionValidation(
      TransitionSpec(
        type: type,
        durationMs: type == 'none' ? 0 : duration,
        easing: easing,
        params: params,
        reverseOnBack: back is bool ? back : true,
        advance: advance,
        magicMove: magic,
        extra: extra,
      ),
      warnings,
      errors,
    );
  }

  /// [current] (a slide's or the default transition JSON) with the merge
  /// [patch] applied (`slides.transition.set`); a patch changing `type`
  /// starts from the new type's defaults (keeps `advance` and
  /// `reverseOnBack`).
  static MotionValidation<TransitionSpec> patch(
    TransitionSpec current,
    Map<String, Object?> patch,
  ) {
    var base = current.toJson();
    final type = patch['type'];
    if (type is String && type != current.type) {
      base = {
        ...TransitionSpec.of(type).toJson(),
        if (base['advance'] != null) 'advance': base['advance'],
        if (base['reverseOnBack'] != null)
          'reverseOnBack': base['reverseOnBack'],
      };
    }
    return fromJson(jsonMergePatch(base, patch));
  }
}

/// The motion keys of `Deck.defaultsJson` (06 A-06-7): `transition` (the
/// default transition of slides whose own `transitionJson` is null) and
/// `build` (the last used quick-add build). Other keys (07's
/// `codeFontSize`, …) are kept untouched.
final class DeckMotionDefaults {
  /// Creates the defaults.
  const DeckMotionDefaults({
    this.transition,
    this.build,
    this.other = const {},
  });

  /// The deck's default transition, or null (= none).
  final TransitionSpec? transition;

  /// `{kind, effect, trigger, durationMs, easing}` of the last quick add.
  final BuildDefaults? build;

  /// Every other key of `defaultsJson`.
  final Map<String, Object?> other;

  /// Decodes [defaultsJson] (invalid JSON = empty).
  static DeckMotionDefaults decode(String? defaultsJson) {
    if (defaultsJson == null) return const DeckMotionDefaults();
    Object? raw;
    try {
      raw = jsonDecode(defaultsJson);
    } on FormatException {
      return const DeckMotionDefaults();
    }
    if (raw is! Map<String, Object?>) return const DeckMotionDefaults();
    final t = raw['transition'];
    final b = raw['build'];
    TransitionSpec? transition;
    if (t is Map<String, Object?>) {
      final v = TransitionSpec.fromJson(t);
      if (v.isValid) transition = v.value;
    }
    return DeckMotionDefaults(
      transition: transition,
      build: b is Map<String, Object?> ? BuildDefaults.fromJson(b) : null,
      other: {
        for (final e in raw.entries)
          if (e.key != 'transition' && e.key != 'build') e.key: e.value,
      },
    );
  }

  /// The `defaultsJson` with [transition] set (null removes the key).
  static String withTransition(
    String? defaultsJson,
    TransitionSpec? transition,
  ) {
    final d = decode(defaultsJson);
    return jsonEncode({
      'v': 1,
      ...d.other,
      'transition': ?transition?.toJson(),
      'build': ?d.build?.toJson(),
    });
  }

  /// The `defaultsJson` with the quick-add [build] defaults set.
  static String withBuild(String? defaultsJson, BuildDefaults build) {
    final d = decode(defaultsJson);
    return jsonEncode({
      'v': 1,
      ...d.other,
      'transition': ?d.transition?.toJson(),
      'build': build.toJson(),
    });
  }
}

/// `Deck.defaultsJson.build`.
final class BuildDefaults {
  /// Creates the defaults.
  const BuildDefaults({
    required this.kind,
    required this.effect,
    this.trigger = SlideBuildTrigger.onClick,
    this.durationMs,
    this.easing,
  });

  final SlideBuildKind kind;
  final String effect;
  final SlideBuildTrigger trigger;
  final int? durationMs;
  final String? easing;

  /// Parses the JSON object (invalid values fall back).
  factory BuildDefaults.fromJson(Map<String, Object?> j) => BuildDefaults(
    kind: SlideBuildKind.fromName(j['kind']) ?? SlideBuildKind.buildIn,
    effect: j['effect'] is String ? j['effect'] as String : 'fade',
    trigger:
        SlideBuildTrigger.fromName(j['trigger']) ?? SlideBuildTrigger.onClick,
    durationMs: (j['durationMs'] as num?)?.round(),
    easing: j['easing'] is String ? j['easing'] as String : null,
  );

  /// JSON.
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'effect': effect,
    'trigger': trigger.name,
    'durationMs': ?durationMs,
    'easing': ?easing,
  };
}
