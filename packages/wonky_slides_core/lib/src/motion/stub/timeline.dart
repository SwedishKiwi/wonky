/// The M9 stub of the timeline API (06 §9, 12 §5.5): every slide compiles
/// to zero steps and every frame is the edit frame, so the stage, present
/// mode and the PDF renderer can be written against the final API before
/// builds exist. SL-24 replaces the compiler (and fills the effect
/// programs) in `core/motion/`; the type names stay.
library;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../model/api/records.dart';

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
}

/// One scheduled effect of a step (06 §9.2). Stub: no effect programs yet.
final class ScheduledEffect {
  /// Creates an effect.
  const ScheduledEffect({
    required this.buildId,
    required this.elementId,
    this.part = 0,
    required this.startMs,
    required this.durationMs,
    this.persistent = false,
  });

  final String buildId;
  final String elementId;

  /// 0 = whole element.
  final int part;

  /// Relative to the step start.
  final int startMs;
  final int durationMs;
  final bool persistent;
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
  final int durationMs;

  /// Sorted by `startMs`.
  final List<ScheduledEffect> effects;
}

/// The visual state of one element in a frame (06 §9.2). Absent from a
/// [SlideFrame] = the edit state (unanimated).
final class ElementVisualState {
  /// Creates a state.
  ElementVisualState({
    this.visible = true,
    this.opacity = 1,
    Matrix4? transform,
    this.blurSigma = 0,
    this.drawProgress = 1,
    this.codeStateIndex,
    this.codeHighlightStep,
  }) : transform = transform ?? Matrix4.identity();

  /// The edit state.
  static final edit = ElementVisualState();

  final bool visible;

  /// 0..1.
  final double opacity;

  /// 4×4 transform in su (incl. perspective), applied about the element.
  final Matrix4 transform;

  /// su.
  final double blurSigma;

  /// Line drawing 0..1 (1 = complete).
  final double drawProgress;

  /// Code element: state index shown (07), or null = the edit choice.
  final int? codeStateIndex;

  /// Code element: highlight step, or null.
  final int? codeHighlightStep;
}

/// One frame of a slide: element states (absent = edit state).
final class SlideFrame {
  /// Creates a frame.
  const SlideFrame([this.elements = const {}]);

  /// The edit frame: everything visible, authored state.
  static const edit = SlideFrame();

  /// Element id → state.
  final Map<String, ElementVisualState> elements;

  /// The state of [elementId] (the edit state when absent).
  ElementVisualState stateOf(String elementId) =>
      elements[elementId] ?? ElementVisualState.edit;
}

/// A warning of the compiler (skipped builds, fallbacks).
final class TimelineWarning {
  /// Creates a warning.
  const TimelineWarning(this.code, this.message, {this.buildId});

  final String code;
  final String message;
  final String? buildId;
}

/// A slide's compiled builds (06 §9.2).
final class SlideTimeline {
  /// Creates a timeline.
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

  /// After the transition, before step 0 runs. Stub: the edit frame.
  SlideFrame get initial => SlideFrame.edit;

  /// The settled frame after [step]. Stub: the edit frame.
  SlideFrame endOfStep(int step) => SlideFrame.edit;

  /// The exact frame at [p]. Stub: the edit frame.
  SlideFrame frameAt(TimelinePosition p) => SlideFrame.edit;

  /// `endOfStep(steps.length - 1)`.
  SlideFrame get finalFrame => endOfStep(steps.length - 1);

  /// The print frame (06 §9.6). Stub: the edit frame.
  SlideFrame get printFrame => SlideFrame.edit;

  /// Total duration of all steps (ms).
  int get durationMs => steps.fold(0, (a, s) => a + s.durationMs);

  /// "5 clicks, 12.4 s" data for UIs and MCP.
  Map<String, Object?> describe() => {
    'clicks': stepCount,
    'durationMs': durationMs,
  };
}

/// What the compiler needs for one slide (06 §9.4). Stub: the slide and its
/// builds; SL-24 adds resolved elements and part geometry providers.
final class SlideMotionInput {
  /// Creates the input.
  const SlideMotionInput({required this.slide, this.builds = const []});

  final SlideRec slide;

  /// The slide's builds in order.
  final List<SlideBuildRec> builds;
}

/// Compiles builds into a [SlideTimeline] (06 §9.1).
abstract final class SlideTimelineCompiler {
  /// M9 stub: zero steps, every frame the edit frame.
  static SlideTimeline compile(SlideMotionInput input) =>
      SlideTimeline(slideId: input.slide.id);
}

/// The plan of a transition between two slides (06 §9.5). Stub: a cut.
final class TransitionPlan {
  /// Creates a plan.
  const TransitionPlan({
    this.durationMs = 0,
    this.outgoing = const [],
    this.incoming = const [],
  });

  /// A cut (no animation).
  static const cut = TransitionPlan();

  final int durationMs;

  /// Element ids leaving with the outgoing slide.
  final List<String> outgoing;

  /// Element ids arriving with the incoming slide.
  final List<String> incoming;
}

/// Compiles the transition into a slide (06 §9.5).
abstract final class TransitionCompiler {
  /// M9 stub: every transition is a cut.
  static TransitionPlan compile({
    required SlideFrame from,
    required SlideFrame to,
    String? transitionJson,
  }) => TransitionPlan.cut;
}
