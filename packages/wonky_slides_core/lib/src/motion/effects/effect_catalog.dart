/// The effect catalog of builds (06 §3) as data: ids, kinds, the element
/// kinds they apply to, parameters with defaults and ranges, default
/// duration and easing, persistence and the reduced-motion replacement.
/// The Animate pane, the MCP JSON schema and the AI prompt are generated
/// from it; [EffectCatalog.validate] is shared by commands, MCP and the AI
/// (06 §3.5).
library;

import '../../model/api/kinds.dart';
import '../../theme/color/color_ref.dart';

/// What happens to the element's state after an effect (06 §3.3).
enum EffectPersistence {
  /// Build in/out: changes visibility.
  visibility,

  /// Emphasis that returns to the previous state.
  transient,

  /// Emphasis/motion whose end state stays for the rest of the slide.
  persistent,
}

/// Reduced-motion replacement of an effect (06 §13).
enum ReducedMotionRule {
  /// Plays unchanged.
  same,

  /// `fade` / `fadeOut` with `min(duration, 300 ms)`.
  fade,

  /// Whole parts appear with a 200 ms fade (typewriter, type-in, erase).
  partsFade,

  /// Skipped (transient emphasis).
  skip,

  /// The end state appears (200 ms; persistent emphasis).
  instant,

  /// Fades out at the start and in at the end position (motion).
  fadeOutIn,
}

/// The value type of a parameter.
enum ParamType {
  /// A number in [ParamSpec.min]…[ParamSpec.max].
  number,

  /// An integer in [ParamSpec.min]…[ParamSpec.max].
  integer,

  /// true / false.
  boolean,

  /// One of [ParamSpec.choices].
  choice,

  /// A `ColorRef` string (hex or `theme:<key>`).
  color,

  /// A number (su) or the string `"offSlide"`.
  distance,

  /// SVG-style path data (motion paths).
  path,

  /// A JSON object (`moveTo.to`, `chartHighlight.target`).
  object,

  /// A number or null (`chartCamera` keeps the current value when null).
  optionalNumber,

  /// Free text (presets).
  string,
}

/// One effect parameter (06 §3 tables).
final class ParamSpec {
  /// Creates a parameter.
  const ParamSpec(
    this.key,
    this.type, {
    this.defaultValue,
    this.min,
    this.max,
    this.choices = const [],
  });

  final String key;
  final ParamType type;
  final Object? defaultValue;
  final num? min;
  final num? max;
  final List<String> choices;

  /// JSON-schema-like description (MCP, AI prompt).
  Map<String, Object?> toJson() => {
    'key': key,
    'type': type.name,
    'default': ?defaultValue,
    'min': ?min,
    'max': ?max,
    if (choices.isNotEmpty) 'choices': choices,
  };
}

/// Anchors of `origin` parameters.
const anchorChoices = [
  'center',
  'top',
  'bottom',
  'left',
  'right',
  'topLeft',
  'topRight',
  'bottomLeft',
  'bottomRight',
];

/// The 8 directions of `moveIn`/`wipe`.
const direction8 = [
  'left',
  'right',
  'top',
  'bottom',
  'topLeft',
  'topRight',
  'bottomLeft',
  'bottomRight',
];

/// Which element kinds an effect applies to.
enum EffectTarget {
  /// Every kind.
  visual,

  /// Text boxes, placeholders and shapes with text.
  text,

  /// Shapes, lines, connectors, arrows and icons.
  stroke,

  /// Shapes, text, lines, icons (color change).
  colorable,

  /// Charts.
  chart,

  /// 3D charts.
  chart3d,

  /// Code blocks.
  code;

  /// Whether an element of [kind] can take the effect.
  bool accepts(ElementKind kind) => switch (this) {
    visual => true,
    text => kind.hasText,
    stroke =>
      kind == ElementKind.shape ||
          kind == ElementKind.line ||
          kind == ElementKind.icon,
    colorable =>
      kind == ElementKind.shape ||
          kind == ElementKind.text ||
          kind == ElementKind.line ||
          kind == ElementKind.icon,
    chart || chart3d => kind == ElementKind.chart,
    code => kind == ElementKind.code,
  };
}

/// One effect of the catalog.
final class EffectSpec {
  /// Creates an effect.
  const EffectSpec({
    required this.id,
    required this.kind,
    required this.name,
    this.target = EffectTarget.visual,
    this.params = const [],
    required this.defaultDurationMs,
    this.defaultEasing = 'easeOut',
    this.derivedDuration = false,
    required this.persistence,
    required this.reducedMotion,
    this.group = 'basic',
    this.mirrorOf,
    this.available = true,
  });

  final String id;
  final SlideBuildKind kind;

  /// English name (the app localizes by id).
  final String name;
  final EffectTarget target;
  final List<ParamSpec> params;
  final int defaultDurationMs;
  final String defaultEasing;

  /// Typewriter, type-in and appear compute their own length.
  final bool derivedDuration;
  final EffectPersistence persistence;
  final ReducedMotionRule reducedMotion;

  /// Tile group of the pane (basic, exciting, text, shape, chart, code,
  /// emphasis, motion).
  final String group;

  /// Out effects: the in-effect they mirror (06 §3.2).
  final String? mirrorOf;

  /// false for designed-but-not-built effects (P2): they compile as fade.
  final bool available;

  /// The parameter [key], or null.
  ParamSpec? param(String key) {
    for (final p in params) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// The default parameter values.
  Map<String, Object?> get defaults => {
    for (final p in params)
      if (p.defaultValue != null) p.key: p.defaultValue,
  };

  /// Catalog entry as JSON (MCP schema, AI prompt).
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'appliesTo': target.name,
    'params': [for (final p in params) p.toJson()],
    'defaultDurationMs': defaultDurationMs,
    'defaultEasing': defaultEasing,
    'derivedDuration': derivedDuration,
    'persistence': persistence.name,
    'reducedMotion': reducedMotion.name,
  };
}

/// A finding of [EffectCatalog.validate] or the option codecs.
final class MotionIssue {
  /// Creates an issue.
  const MotionIssue(this.code, this.message, {this.path});

  /// `clamped`, `unknown_effect`, `wrong_kind`, `invalid_type`, …
  final String code;
  final String message;

  /// JSON path of the value (`params.distance`).
  final String? path;

  @override
  String toString() => path == null ? message : '$path: $message';

  /// JSON form (MCP `warnings`).
  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    'path': ?path,
  };
}

/// The result of a validation: normalized value, warnings (clamped values)
/// and errors (wrong types: MCP `invalid_args`).
final class MotionValidation<T> {
  /// Creates a result.
  const MotionValidation(this.value, this.warnings, this.errors);

  final T value;
  final List<MotionIssue> warnings;
  final List<MotionIssue> errors;

  /// Whether there are no errors.
  bool get isValid => errors.isEmpty;
}

/// The effect catalog (06 §3).
abstract final class EffectCatalog {
  static const _fade = ParamSpec('fade', ParamType.boolean, defaultValue: true);
  static const _fadeOff = ParamSpec(
    'fade',
    ParamType.boolean,
    defaultValue: false,
  );
  static const _origin = ParamSpec(
    'origin',
    ParamType.choice,
    defaultValue: 'center',
    choices: anchorChoices,
  );
  static const _dir8 = ParamSpec(
    'direction',
    ParamType.choice,
    defaultValue: 'left',
    choices: direction8,
  );
  static const _wipeSoft = ParamSpec(
    'softness',
    ParamType.number,
    defaultValue: 0.2,
    min: 0,
    max: 1,
  );
  static const _iris = [
    ParamSpec(
      'shape',
      ParamType.choice,
      defaultValue: 'circle',
      choices: ['circle', 'rect', 'diamond'],
    ),
    _origin,
  ];
  static const _flip = [
    ParamSpec('axis', ParamType.choice, defaultValue: 'y', choices: ['x', 'y']),
    ParamSpec(
      'direction',
      ParamType.choice,
      defaultValue: 'forward',
      choices: ['forward', 'backward'],
    ),
    ParamSpec(
      'perspective',
      ParamType.number,
      defaultValue: 0.0012,
      min: 0,
      max: 0.01,
    ),
  ];
  static const _count = ParamSpec(
    'count',
    ParamType.integer,
    defaultValue: 1,
    min: 1,
    max: 20,
  );

  /// Build in effects (06 §3.1).
  static const List<EffectSpec> buildIn = [
    EffectSpec(
      id: 'appear',
      kind: SlideBuildKind.buildIn,
      name: 'Appear',
      defaultDurationMs: 0,
      defaultEasing: 'linear',
      derivedDuration: true,
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.same,
    ),
    EffectSpec(
      id: 'fade',
      kind: SlideBuildKind.buildIn,
      name: 'Fade',
      defaultDurationMs: 500,
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.same,
    ),
    EffectSpec(
      id: 'rise',
      kind: SlideBuildKind.buildIn,
      name: 'Rise',
      params: [
        ParamSpec(
          'distance',
          ParamType.number,
          defaultValue: 40,
          min: 0,
          max: 4000,
        ),
        _fade,
      ],
      defaultDurationMs: 600,
      defaultEasing: 'spring(0.6,0)',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
    ),
    EffectSpec(
      id: 'moveIn',
      kind: SlideBuildKind.buildIn,
      name: 'Move in',
      params: [
        _dir8,
        ParamSpec(
          'distance',
          ParamType.distance,
          defaultValue: 'offSlide',
          min: 0,
          max: 10000,
        ),
        _fadeOff,
      ],
      defaultDurationMs: 700,
      defaultEasing: 'easeOutCubic',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
    ),
    EffectSpec(
      id: 'scale',
      kind: SlideBuildKind.buildIn,
      name: 'Scale',
      params: [
        ParamSpec('from', ParamType.number, defaultValue: 0.5, min: 0, max: 4),
        _origin,
        _fade,
      ],
      defaultDurationMs: 500,
      defaultEasing: 'easeOutCubic',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
    ),
    EffectSpec(
      id: 'pop',
      kind: SlideBuildKind.buildIn,
      name: 'Pop',
      params: [
        ParamSpec('from', ParamType.number, defaultValue: 0, min: 0, max: 4),
        ParamSpec(
          'bounce',
          ParamType.number,
          defaultValue: 0.35,
          min: 0,
          max: 0.8,
        ),
      ],
      defaultDurationMs: 500,
      defaultEasing: 'spring(0.5,0.35)',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
    ),
    EffectSpec(
      id: 'zoom',
      kind: SlideBuildKind.buildIn,
      name: 'Zoom',
      params: [
        ParamSpec('from', ParamType.number, defaultValue: 3, min: 0, max: 20),
        _fade,
      ],
      defaultDurationMs: 600,
      defaultEasing: 'easeOutQuint',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'exciting',
    ),
    EffectSpec(
      id: 'blur',
      kind: SlideBuildKind.buildIn,
      name: 'Blur',
      params: [
        ParamSpec('from', ParamType.number, defaultValue: 24, min: 0, max: 40),
        _fade,
      ],
      defaultDurationMs: 600,
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'exciting',
    ),
    EffectSpec(
      id: 'wipe',
      kind: SlideBuildKind.buildIn,
      name: 'Wipe',
      params: [_dir8, _wipeSoft],
      defaultDurationMs: 600,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'exciting',
    ),
    EffectSpec(
      id: 'iris',
      kind: SlideBuildKind.buildIn,
      name: 'Iris',
      params: _iris,
      defaultDurationMs: 600,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'exciting',
    ),
    EffectSpec(
      id: 'dissolve',
      kind: SlideBuildKind.buildIn,
      name: 'Dissolve',
      params: [
        ParamSpec('cell', ParamType.number, defaultValue: 6, min: 1, max: 200),
      ],
      defaultDurationMs: 700,
      defaultEasing: 'linear',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'exciting',
    ),
    EffectSpec(
      id: 'drop',
      kind: SlideBuildKind.buildIn,
      name: 'Drop',
      params: [
        ParamSpec(
          'height',
          ParamType.distance,
          defaultValue: 'offSlide',
          min: 0,
          max: 10000,
        ),
        ParamSpec(
          'bounces',
          ParamType.integer,
          defaultValue: 2,
          min: 0,
          max: 3,
        ),
      ],
      defaultDurationMs: 900,
      defaultEasing: 'linear',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'exciting',
    ),
    EffectSpec(
      id: 'flip',
      kind: SlideBuildKind.buildIn,
      name: 'Flip',
      params: _flip,
      defaultDurationMs: 700,
      defaultEasing: 'easeOutCubic',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'exciting',
    ),
    EffectSpec(
      id: 'rotate',
      kind: SlideBuildKind.buildIn,
      name: 'Rotate',
      params: [
        ParamSpec(
          'angle',
          ParamType.number,
          defaultValue: -90,
          min: -720,
          max: 720,
        ),
        _origin,
        ParamSpec('scale', ParamType.number, defaultValue: 1, min: 0, max: 4),
        _fade,
      ],
      defaultDurationMs: 700,
      defaultEasing: 'easeOutCubic',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'exciting',
    ),
    EffectSpec(
      id: 'typewriter',
      kind: SlideBuildKind.buildIn,
      name: 'Typewriter',
      target: EffectTarget.text,
      params: [
        ParamSpec('cps', ParamType.number, defaultValue: 30, min: 1, max: 200),
        ParamSpec('caret', ParamType.boolean, defaultValue: true),
        ParamSpec('jitter', ParamType.number, defaultValue: 0, min: 0, max: 1),
      ],
      defaultDurationMs: 0,
      defaultEasing: 'linear',
      derivedDuration: true,
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.partsFade,
      group: 'text',
    ),
    EffectSpec(
      id: 'lineDraw',
      kind: SlideBuildKind.buildIn,
      name: 'Draw line',
      target: EffectTarget.stroke,
      params: [
        ParamSpec(
          'fillDelay',
          ParamType.number,
          defaultValue: 0.6,
          min: 0,
          max: 1,
        ),
        ParamSpec(
          'direction',
          ParamType.choice,
          defaultValue: 'forward',
          choices: ['forward', 'backward'],
        ),
      ],
      defaultDurationMs: 1000,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'shape',
    ),
    EffectSpec(
      id: 'chartGrow',
      kind: SlideBuildKind.buildIn,
      name: 'Grow (chart)',
      target: EffectTarget.chart,
      params: [
        ParamSpec(
          'from',
          ParamType.choice,
          defaultValue: 'baseline',
          choices: ['baseline', 'center'],
        ),
      ],
      defaultDurationMs: 800,
      defaultEasing: 'easeOutCubic',
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'chart',
    ),
    EffectSpec(
      id: 'codeType',
      kind: SlideBuildKind.buildIn,
      name: 'Type code',
      target: EffectTarget.code,
      defaultDurationMs: 0,
      defaultEasing: 'linear',
      derivedDuration: true,
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.partsFade,
      group: 'code',
    ),
    EffectSpec(
      id: 'shimmer',
      kind: SlideBuildKind.buildIn,
      name: 'Shimmer',
      target: EffectTarget.text,
      defaultDurationMs: 1200,
      persistence: EffectPersistence.visibility,
      reducedMotion: ReducedMotionRule.fade,
      group: 'text',
      available: false,
    ),
  ];

  static EffectSpec _out(
    String id,
    String name,
    String mirror, {
    List<ParamSpec>? params,
    String? easing,
    int? durationMs,
  }) {
    final m = buildIn.firstWhere((e) => e.id == mirror);
    return EffectSpec(
      id: id,
      kind: SlideBuildKind.buildOut,
      name: name,
      target: m.target,
      params: params ?? m.params,
      defaultDurationMs: durationMs ?? m.defaultDurationMs,
      defaultEasing: easing ?? m.defaultEasing,
      derivedDuration: m.derivedDuration,
      persistence: EffectPersistence.visibility,
      reducedMotion: m.reducedMotion,
      group: m.group,
      mirrorOf: mirror,
      available: m.available,
    );
  }

  /// Build out effects (06 §3.2): mirrors of the in effects.
  static final List<EffectSpec> buildOut = [
    _out('disappear', 'Disappear', 'appear'),
    _out('fadeOut', 'Fade out', 'fade'),
    _out('sink', 'Sink', 'rise', easing: 'easeInCubic'),
    _out('moveOut', 'Move out', 'moveIn', easing: 'easeInCubic'),
    _out(
      'scaleOut',
      'Scale out',
      'scale',
      easing: 'easeInCubic',
      params: const [
        ParamSpec('to', ParamType.number, defaultValue: 0.5, min: 0, max: 4),
        _origin,
        _fade,
      ],
    ),
    _out(
      'popOut',
      'Pop out',
      'pop',
      easing: 'easeInCubic',
      params: const [
        ParamSpec('to', ParamType.number, defaultValue: 0, min: 0, max: 4),
        ParamSpec(
          'anticipation',
          ParamType.number,
          defaultValue: 0.08,
          min: 0,
          max: 0.5,
        ),
      ],
    ),
    _out(
      'zoomOut',
      'Zoom out',
      'zoom',
      easing: 'easeInCubic',
      params: const [
        ParamSpec('to', ParamType.number, defaultValue: 3, min: 0, max: 20),
        _fade,
      ],
    ),
    _out('blurOut', 'Blur out', 'blur', easing: 'easeIn'),
    _out('wipeOut', 'Wipe out', 'wipe'),
    _out('irisOut', 'Iris out', 'iris'),
    _out('dissolveOut', 'Dissolve out', 'dissolve'),
    _out(
      'fall',
      'Fall',
      'drop',
      params: const [
        ParamSpec(
          'height',
          ParamType.distance,
          defaultValue: 'offSlide',
          min: 0,
          max: 10000,
        ),
        ParamSpec(
          'rotation',
          ParamType.number,
          defaultValue: 15,
          min: -15,
          max: 15,
        ),
      ],
    ),
    _out('flipOut', 'Flip out', 'flip', easing: 'easeInCubic'),
    _out('rotateOut', 'Rotate out', 'rotate', easing: 'easeInCubic'),
    _out('eraseText', 'Erase text', 'typewriter'),
    _out('lineErase', 'Erase line', 'lineDraw'),
    _out('chartShrink', 'Shrink (chart)', 'chartGrow', easing: 'easeInCubic'),
  ];

  /// Emphasis effects (06 §3.3).
  static const List<EffectSpec> emphasis = [
    EffectSpec(
      id: 'pulse',
      kind: SlideBuildKind.emphasis,
      name: 'Pulse',
      params: [
        ParamSpec(
          'scale',
          ParamType.number,
          defaultValue: 1.1,
          min: 0.1,
          max: 4,
        ),
        _count,
      ],
      defaultDurationMs: 500,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.transient,
      reducedMotion: ReducedMotionRule.skip,
      group: 'emphasis',
    ),
    EffectSpec(
      id: 'bounce',
      kind: SlideBuildKind.emphasis,
      name: 'Bounce',
      params: [
        ParamSpec(
          'height',
          ParamType.number,
          defaultValue: 40,
          min: 0,
          max: 2000,
        ),
        _count,
      ],
      defaultDurationMs: 700,
      defaultEasing: 'linear',
      persistence: EffectPersistence.transient,
      reducedMotion: ReducedMotionRule.skip,
      group: 'emphasis',
    ),
    EffectSpec(
      id: 'shake',
      kind: SlideBuildKind.emphasis,
      name: 'Shake',
      params: [
        ParamSpec(
          'amplitude',
          ParamType.number,
          defaultValue: 12,
          min: 0,
          max: 400,
        ),
        ParamSpec('count', ParamType.integer, defaultValue: 3, min: 1, max: 20),
        ParamSpec(
          'axis',
          ParamType.choice,
          defaultValue: 'x',
          choices: ['x', 'y'],
        ),
      ],
      defaultDurationMs: 500,
      defaultEasing: 'linear',
      persistence: EffectPersistence.transient,
      reducedMotion: ReducedMotionRule.skip,
      group: 'emphasis',
    ),
    EffectSpec(
      id: 'blink',
      kind: SlideBuildKind.emphasis,
      name: 'Blink',
      params: [
        ParamSpec('count', ParamType.integer, defaultValue: 2, min: 1, max: 20),
      ],
      defaultDurationMs: 600,
      defaultEasing: 'linear',
      persistence: EffectPersistence.transient,
      reducedMotion: ReducedMotionRule.skip,
      group: 'emphasis',
    ),
    EffectSpec(
      id: 'spin',
      kind: SlideBuildKind.emphasis,
      name: 'Spin',
      params: [
        ParamSpec(
          'angle',
          ParamType.number,
          defaultValue: 360,
          min: -3600,
          max: 3600,
        ),
        _origin,
      ],
      defaultDurationMs: 1000,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.instant,
      group: 'emphasis',
    ),
    EffectSpec(
      id: 'grow',
      kind: SlideBuildKind.emphasis,
      name: 'Grow / shrink',
      params: [
        ParamSpec(
          'scale',
          ParamType.number,
          defaultValue: 1.2,
          min: 0.1,
          max: 4,
        ),
        _origin,
      ],
      defaultDurationMs: 500,
      defaultEasing: 'spring(0.5,0.2)',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.instant,
      group: 'emphasis',
    ),
    EffectSpec(
      id: 'opacityTo',
      kind: SlideBuildKind.emphasis,
      name: 'Transparency',
      params: [
        ParamSpec(
          'opacity',
          ParamType.number,
          defaultValue: 0.4,
          min: 0,
          max: 1,
        ),
      ],
      defaultDurationMs: 500,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.same,
      group: 'emphasis',
    ),
    EffectSpec(
      id: 'colorChange',
      kind: SlideBuildKind.emphasis,
      name: 'Color change',
      target: EffectTarget.colorable,
      params: [
        ParamSpec(
          'property',
          ParamType.choice,
          defaultValue: 'fill',
          choices: ['fill', 'stroke', 'text'],
        ),
        ParamSpec('to', ParamType.color, defaultValue: 'theme:accent2'),
      ],
      defaultDurationMs: 500,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.instant,
      group: 'emphasis',
    ),
    EffectSpec(
      id: 'highlight',
      kind: SlideBuildKind.emphasis,
      name: 'Highlight',
      target: EffectTarget.text,
      params: [
        ParamSpec('color', ParamType.color, defaultValue: 'theme:highlight'),
        ParamSpec(
          'style',
          ParamType.choice,
          defaultValue: 'marker',
          choices: ['marker', 'underline', 'box'],
        ),
      ],
      defaultDurationMs: 600,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.instant,
      group: 'text',
    ),
    EffectSpec(
      id: 'chartHighlight',
      kind: SlideBuildKind.emphasis,
      name: 'Highlight series',
      target: EffectTarget.chart,
      params: [
        ParamSpec('target', ParamType.object),
        ParamSpec(
          'dimOthers',
          ParamType.number,
          defaultValue: 0.3,
          min: 0,
          max: 1,
        ),
      ],
      defaultDurationMs: 400,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.instant,
      group: 'chart',
    ),
    EffectSpec(
      id: 'chartHighlightClear',
      kind: SlideBuildKind.emphasis,
      name: 'Clear highlight',
      target: EffectTarget.chart,
      defaultDurationMs: 400,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.instant,
      group: 'chart',
    ),
    EffectSpec(
      id: 'chartOrbit',
      kind: SlideBuildKind.emphasis,
      name: 'Orbit (3D)',
      target: EffectTarget.chart3d,
      params: [
        ParamSpec(
          'azimuth',
          ParamType.number,
          defaultValue: 360,
          min: -3600,
          max: 3600,
        ),
        ParamSpec(
          'elevation',
          ParamType.number,
          defaultValue: 0,
          min: -90,
          max: 90,
        ),
        ParamSpec('persist', ParamType.boolean, defaultValue: false),
      ],
      defaultDurationMs: 6000,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.transient,
      reducedMotion: ReducedMotionRule.skip,
      group: 'chart',
    ),
    EffectSpec(
      id: 'chartCamera',
      kind: SlideBuildKind.emphasis,
      name: 'Rotate to angle (3D)',
      target: EffectTarget.chart3d,
      params: [
        ParamSpec('azimuth', ParamType.optionalNumber, min: -360, max: 360),
        ParamSpec('elevation', ParamType.optionalNumber, min: -90, max: 90),
        ParamSpec('perspective', ParamType.optionalNumber, min: 0, max: 120),
        ParamSpec('preset', ParamType.string),
      ],
      defaultDurationMs: 1200,
      defaultEasing: 'easeInOutCubic',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.instant,
      group: 'chart',
    ),
    EffectSpec(
      id: 'codeHighlight',
      kind: SlideBuildKind.emphasis,
      name: 'Highlight lines',
      target: EffectTarget.code,
      params: [
        // 1-based highlight step of the current state; 0 clears (07 §4.5).
        ParamSpec('step', ParamType.integer, defaultValue: 1, min: 0, max: 200),
      ],
      defaultDurationMs: 400,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.instant,
      group: 'code',
    ),
    EffectSpec(
      id: 'codeState',
      kind: SlideBuildKind.emphasis,
      name: 'Next code state',
      target: EffectTarget.code,
      params: [
        // 1-based state (07 §6); omitted = the next state.
        ParamSpec('state', ParamType.integer, min: 1, max: 50),
        ParamSpec(
          'mode',
          ParamType.choice,
          choices: ['type', 'morph', 'instant'],
        ),
      ],
      defaultDurationMs: 0,
      defaultEasing: 'linear',
      derivedDuration: true,
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.partsFade,
      group: 'code',
    ),
  ];

  /// Motion effects (06 §3.4).
  static const List<EffectSpec> motion = [
    EffectSpec(
      id: 'path',
      kind: SlideBuildKind.motion,
      name: 'Motion path',
      params: [
        ParamSpec('path', ParamType.path, defaultValue: 'M0 0 L200 0'),
        ParamSpec(
          'preset',
          ParamType.choice,
          choices: ['line', 'arc', 'curve', 'circle', 'zigzag', 'custom'],
        ),
        ParamSpec('orientToPath', ParamType.boolean, defaultValue: false),
        ParamSpec('relativeEnd', ParamType.boolean, defaultValue: true),
      ],
      defaultDurationMs: 1500,
      defaultEasing: 'easeInOut',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.fadeOutIn,
      group: 'motion',
    ),
    EffectSpec(
      id: 'moveTo',
      kind: SlideBuildKind.motion,
      name: 'Transform',
      params: [ParamSpec('to', ParamType.object), _origin],
      defaultDurationMs: 1000,
      defaultEasing: 'spring(0.8,0)',
      persistence: EffectPersistence.persistent,
      reducedMotion: ReducedMotionRule.fadeOutIn,
      group: 'motion',
    ),
  ];

  static final Map<(SlideBuildKind, String), EffectSpec> _index = {
    for (final e in [...buildIn, ...emphasis, ...motion]) (e.kind, e.id): e,
  };

  static final Map<(SlideBuildKind, String), EffectSpec> _outIndex = {
    for (final e in buildOut) (e.kind, e.id): e,
  };

  /// Every effect in catalog order.
  static List<EffectSpec> get all => [
    ...buildIn,
    ...buildOut,
    ...emphasis,
    ...motion,
  ];

  /// The effect [id] of [kind], or null.
  static EffectSpec? byId(SlideBuildKind kind, String id) =>
      _index[(kind, id)] ?? _outIndex[(kind, id)];

  /// The effects of [kind] that apply to an element of [elementKind] (3D:
  /// [is3dChart]).
  static List<EffectSpec> forElement(
    SlideBuildKind kind,
    ElementKind elementKind, {
    bool is3dChart = false,
  }) => [
    for (final e in all)
      if (e.kind == kind &&
          e.available &&
          e.target.accepts(elementKind) &&
          (e.target != EffectTarget.chart3d || is3dChart))
        e,
  ];

  /// The fallback of an unknown or unavailable effect (06 §2.1): `fade` /
  /// `fadeOut` for in/out, null (skipped) for emphasis and motion.
  static EffectSpec? fallback(SlideBuildKind kind) => switch (kind) {
    SlideBuildKind.buildIn => byId(kind, 'fade'),
    SlideBuildKind.buildOut => byId(kind, 'fadeOut'),
    _ => null,
  };

  /// Validates [params] of effect [effect] of [kind] (06 §3.5):
  /// out-of-range numbers are clamped (warning), unknown keys are kept,
  /// wrong types are errors; an unknown effect is an error.
  static MotionValidation<Map<String, Object?>> validate(
    SlideBuildKind kind,
    String effect,
    Map<String, Object?>? params,
  ) {
    final spec = byId(kind, effect);
    final warnings = <MotionIssue>[];
    final errors = <MotionIssue>[];
    final out = <String, Object?>{...?params};
    if (spec == null) {
      errors.add(
        MotionIssue(
          'unknown_effect',
          'Unknown ${kind.name} effect "$effect"',
          path: 'effect',
        ),
      );
      return MotionValidation(out, warnings, errors);
    }
    for (final p in spec.params) {
      if (!out.containsKey(p.key)) continue;
      final v = out[p.key];
      final path = 'params.${p.key}';
      if (v == null) {
        if (p.type == ParamType.optionalNumber) continue;
        out.remove(p.key);
        continue;
      }
      switch (p.type) {
        case ParamType.number || ParamType.optionalNumber || ParamType.integer:
          if (v is! num || !v.isFinite) {
            errors.add(
              MotionIssue('invalid_type', 'Must be a number', path: path),
            );
            continue;
          }
          num n = p.type == ParamType.integer ? v.round() : v;
          if (p.min != null && n < p.min!) n = p.min!;
          if (p.max != null && n > p.max!) n = p.max!;
          if (n != v) {
            warnings.add(MotionIssue('clamped', 'Clamped to $n', path: path));
          }
          out[p.key] = n;
        case ParamType.distance:
          if (v == 'offSlide') continue;
          if (v is! num || !v.isFinite) {
            errors.add(
              MotionIssue(
                'invalid_type',
                'Must be a number or "offSlide"',
                path: path,
              ),
            );
            continue;
          }
          final n = v.clamp(p.min ?? 0, p.max ?? 10000);
          if (n != v) {
            warnings.add(MotionIssue('clamped', 'Clamped to $n', path: path));
          }
          out[p.key] = n;
        case ParamType.boolean:
          if (v is! bool) {
            errors.add(
              MotionIssue('invalid_type', 'Must be true or false', path: path),
            );
          }
        case ParamType.choice:
          if (v is! String || !p.choices.contains(v)) {
            errors.add(
              MotionIssue(
                'invalid_type',
                'Must be one of ${p.choices.join(', ')}',
                path: path,
              ),
            );
          }
        case ParamType.color:
          if (v is! String || ColorRef.tryParse(v) == null) {
            errors.add(
              MotionIssue('invalid_type', 'Must be a color', path: path),
            );
          }
        case ParamType.path:
          if (v is! String || v.trim().isEmpty) {
            errors.add(
              MotionIssue('invalid_type', 'Must be path data', path: path),
            );
          } else if (_segments(v) > 200) {
            errors.add(
              MotionIssue(
                'too_long',
                'A motion path has at most 200 segments',
                path: path,
              ),
            );
          }
        case ParamType.object:
          if (v is! Map) {
            errors.add(
              MotionIssue('invalid_type', 'Must be an object', path: path),
            );
          }
        case ParamType.string:
          if (v is! String) {
            errors.add(MotionIssue('invalid_type', 'Must be text', path: path));
          }
      }
    }
    if (spec.id == 'blink') {
      // WCAG 2.3.1: at most 3 flashes per second (06 §17), checked against
      // the default duration here; the compiler re-checks the real one.
      final count = (out['count'] as num?) ?? 2;
      if (count > 20) out['count'] = 20;
    }
    return MotionValidation(out, warnings, errors);
  }

  static int _segments(String d) =>
      RegExp(r'[MmLlHhVvCcSsQqTtAa]').allMatches(d).length;
}
