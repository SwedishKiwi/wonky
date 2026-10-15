/// The timeline model of a slide (06 §9): compiles builds into steps
/// (§4.2, normative), schedules effects and evaluates frames — `initial`,
/// `endOfStep`, `frameAt`, `finalFrame`, `printFrame` — deterministically
/// (integer milliseconds, closed-form easing, seeded generators).
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../geometry/path_ops.dart';
import '../../geometry/svg_path.dart';
import '../../model/api/kinds.dart';
import '../../model/api/records.dart';
import '../../theme/model/common.dart' show SuRect;
import '../builds/build_options.dart';
import '../builds/parts.dart';
import '../easing/motion_easing.dart';
import '../effects/effect_catalog.dart';
import '../util/seeded_random.dart';
import 'motion_input.dart';
import 'slide_frame.dart';

part 'effect_programs.dart';
part 'timeline_compiler.dart';
part 'timeline_evaluator.dart';

/// A position in a slide's timeline: [ms] into step [step]; `ms ≥` the
/// step's duration = settled.
final class TimelinePosition {
  /// Creates a position.
  const TimelinePosition(this.step, this.ms);

  /// Step index (0 = the automatic step).
  final int step;

  /// Milliseconds since the step started.
  final int ms;

  @override
  bool operator ==(Object other) =>
      other is TimelinePosition && other.step == step && other.ms == ms;

  @override
  int get hashCode => Object.hash(step, ms);

  @override
  String toString() => 'TimelinePosition($step, $ms)';
}

/// What a scheduled effect does.
enum EffectRole {
  /// The build's effect on the element or one of its parts.
  build,

  /// After-build dimming/hiding of earlier parts (06 §2.3).
  dim,
}

/// One scheduled effect of a step (06 §9.2).
final class ScheduledEffect {
  /// Creates an effect (hand-made timelines in tests).
  const ScheduledEffect({
    required this.buildId,
    required this.elementId,
    this.part = 0,
    required this.startMs,
    required this.durationMs,
    this.persistent = false,
    this.effectId = '',
    this.kind = SlideBuildKind.buildIn,
    this.role = EffectRole.build,
    this.loops = false,
  }) : _eff = null;

  ScheduledEffect._(_Eff eff, this.startMs)
    : _eff = eff,
      buildId = eff.build.id,
      elementId = eff.elementId,
      part = eff.partNumber,
      durationMs = eff.totalMs,
      persistent = eff.persistent,
      effectId = eff.spec?.id ?? eff.effectId,
      kind = eff.kind,
      role = eff.role,
      loops = eff.loops;

  final _Eff? _eff;

  final String buildId;
  final String elementId;

  /// 0 = the whole element; k ≥ 1 = part k (1-based, natural order).
  final int part;

  /// Relative to the step start.
  final int startMs;

  /// Length including repeats (one cycle for [loops]).
  final int durationMs;

  /// The end state stays (motion, persistent emphasis, visibility).
  final bool persistent;

  /// The effect played (after fallbacks and reduced motion).
  final String effectId;
  final SlideBuildKind kind;
  final EffectRole role;

  /// Repeats until the next step starts (`repeat.untilNextClick`).
  final bool loops;

  /// `startMs + durationMs`.
  int get endMs => startMs + durationMs;

  /// The bound easing, or null for hand-made effects.
  BoundEasing? get easing => _eff?.easing;

  /// Summary for UIs and MCP.
  Map<String, Object?> toJson() => {
    'buildId': buildId,
    'elementId': elementId,
    if (part != 0) 'part': part,
    'effect': effectId,
    'kind': kind.name,
    if (role != EffectRole.build) 'role': role.name,
    'startMs': startMs,
    'durationMs': durationMs,
    if (loops) 'loops': true,
  };
}

/// One step of a timeline.
final class TimelineStep {
  /// Creates a step.
  const TimelineStep({
    required this.index,
    this.durationMs = 0,
    this.effects = const [],
  });

  final int index;

  /// End of the last effect (0 for an empty step 0).
  final int durationMs;

  /// Sorted by `startMs` (then sequence order).
  final List<ScheduledEffect> effects;

  /// Whether an effect keeps looping after [durationMs] (players keep
  /// ticking until the next step).
  bool get hasLoops => effects.any((e) => e.loops);

  /// Summary.
  Map<String, Object?> toJson() => {
    'index': index,
    'durationMs': durationMs,
    'effects': [for (final e in effects) e.toJson()],
  };
}

/// A warning of the compiler (skipped builds, fallbacks).
final class TimelineWarning {
  /// Creates a warning.
  const TimelineWarning(this.code, this.message, {this.buildId});

  /// `elementMissing`, `alreadyVisible`, `alreadyHidden`, `hiddenTarget`,
  /// `unsupportedEffect`, `wrongElementKind`, `unsupportedTrigger`,
  /// `invalidOptions`, `invalidEasing`, `deliveryFallback`,
  /// `codeStepMissing`, `codeStateMissing`, `flashLimit`.
  final String code;
  final String message;
  final String? buildId;

  /// JSON.
  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    'buildId': ?buildId,
  };

  @override
  String toString() => '$code: $message';
}

/// A slide's compiled builds (06 §9.2). A timeline made with the public
/// constructor (tests, fakes) has no effect programs: every frame is the
/// edit frame.
class SlideTimeline {
  /// Creates a timeline without programs.
  const SlideTimeline({
    required this.slideId,
    this.steps = const [TimelineStep(index: 0)],
    this.warnings = const [],
  });

  final String slideId;

  /// `steps[0]` = the automatic step (may be empty).
  final List<TimelineStep> steps;
  final List<TimelineWarning> warnings;

  /// Clicks after step 0.
  int get stepCount => steps.length - 1;

  /// After the transition, before step 0 runs.
  SlideFrame get initial => SlideFrame.edit;

  /// The settled frame after [step] (clamped to the steps; −1 = initial).
  SlideFrame endOfStep(int step) => SlideFrame.edit;

  /// The exact frame at [p].
  SlideFrame frameAt(TimelinePosition p) => SlideFrame.edit;

  /// `endOfStep(steps.length - 1)`.
  SlideFrame get finalFrame => endOfStep(steps.length - 1);

  /// The print frame (06 §9.6, v2 review Q24): the authored layout with
  /// content-progressive elements complete (code at its last state, no
  /// highlight; charts fully built; text complete).
  SlideFrame get printFrame => SlideFrame.edit;

  /// Total duration of all steps (ms).
  int get durationMs => steps.fold(0, (a, s) => a + s.durationMs);

  /// Effects per element (06 §9.2 `tracks`): element id → (step, effect).
  Map<String, List<(int, ScheduledEffect)>> get tracks {
    final out = <String, List<(int, ScheduledEffect)>>{};
    for (final s in steps) {
      for (final e in s.effects) {
        (out[e.elementId] ??= []).add((s.index, e));
      }
    }
    return out;
  }

  /// The steps [buildId] plays in (build order badges "2–5", 06 §5.5).
  List<int> stepsOfBuild(String buildId) => [
    for (final s in steps)
      if (s.effects.any((e) => e.buildId == buildId)) s.index,
  ];

  /// "5 clicks, 12.4 s" data for UIs and MCP.
  Map<String, Object?> describe() => {
    'clicks': stepCount,
    'durationMs': durationMs,
  };
}

/// Compiles builds into a [SlideTimeline] (06 §9.1).
abstract final class SlideTimelineCompiler {
  /// Compiles [input] (06 §4.2): steps, scheduled effects, warnings and
  /// the frame evaluator.
  static SlideTimeline compile(SlideMotionInput input) =>
      _Compiler(input).compile();
}
