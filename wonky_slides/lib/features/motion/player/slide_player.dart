import 'dart:math' as math;

import 'package:wonky_slides_core/motion.dart';

/// What a stage shows at one moment of a [SlidePlayer] (06 §6).
sealed class PlayerView {
  const PlayerView();

  /// The slide shown (the incoming slide of a transition).
  String get slideId;
}

/// One slide in a frame of its timeline.
final class SlidePlayerView extends PlayerView {
  const SlidePlayerView(this.slideId, this.step, this.frame);

  @override
  final String slideId;

  /// The timeline step the frame belongs to.
  final int step;
  final SlideFrame frame;
}

/// A transition from [fromSlideId] (drawn in [fromFrame]) to [slideId]
/// (drawn in [toFrame]) at [ms] into [plan].
final class TransitionPlayerView extends PlayerView {
  const TransitionPlayerView({
    required this.plan,
    required this.ms,
    required this.frame,
    required this.fromSlideId,
    required this.fromFrame,
    required this.slideId,
    required this.toFrame,
  });

  final TransitionPlan plan;
  final int ms;
  final TransitionFrame frame;
  final String fromSlideId;
  final SlideFrame fromFrame;
  @override
  final String slideId;
  final SlideFrame toFrame;
}

/// The degraded rest of an animation (06 §14): a crossfade between two
/// snapshots ([mix] 0 = from, 1 = to).
final class CrossfadePlayerView extends PlayerView {
  const CrossfadePlayerView({
    required this.fromSlideId,
    required this.fromFrame,
    required this.slideId,
    required this.toFrame,
    required this.mix,
  });

  final String fromSlideId;
  final SlideFrame fromFrame;
  @override
  final String slideId;
  final SlideFrame toFrame;
  final double mix;
}

/// What a transition is compiled from (06 §9.9): the slide left in the
/// frame it showed and the slide entered in the frame it starts with.
final class TransitionRequest {
  const TransitionRequest({
    required this.fromSlideId,
    required this.fromStep,
    required this.fromFrame,
    required this.toSlideId,
    required this.toStep,
    required this.toFrame,
    required this.reverse,
  });

  final String fromSlideId;

  /// The left slide's settled step (its frame is `endOfStep(fromStep)`).
  final int fromStep;
  final SlideFrame fromFrame;
  final String toSlideId;

  /// −1 = the entered slide's initial frame (its step 0 plays after the
  /// transition), else the settled step it is shown at.
  final int toStep;
  final SlideFrame toFrame;

  /// Backward navigation: the left slide's transition reversed.
  final bool reverse;

  /// A cache key without the frames (they follow from the steps).
  String get key =>
      '$fromSlideId:$fromStep>$toSlideId:$toStep${reverse ? '<' : ''}';
}

/// Plays a slide's compiled timeline and the transitions between slides
/// (Slides 06 §6, §9; the shared player of present mode, the presenter
/// view and previews). Pure state over a caller-provided clock: every
/// view is a function of the time passed to [viewAt], so the same inputs
/// give the same frames (tests seek exact times; the stage ticks with a
/// `Ticker` while [needsTicks]).
///
/// - [enter] shows a slide: the transition from the slide shown before
///   (when given), then step 0 — or the settled `toStep` (backward
///   navigation, jumps to a step).
/// - [playStep] plays step *i* from its start (*Next* on the slide).
/// - [show] jumps to the settled end of a step (*Previous*, seeking).
/// - [finish] ends whatever runs (a click during a build).
/// - [degrade] turns the rest of the running animation into a crossfade
///   (frame budget missed, 06 §14).
class SlidePlayer {
  SlidePlayer({required this.timelineOf, required this.planOf});

  /// The compiled timeline of a slide.
  final SlideTimeline Function(String slideId) timelineOf;

  /// The transition plan of a request (callers cache plans).
  final TransitionPlan Function(TransitionRequest request) planOf;

  String? _slideId;
  int _step = 0;
  int _start = 0;
  TransitionPlan? _plan;
  TransitionRequest? _request;
  bool _plays = false;
  bool _finished = true;
  _Crossfade? _degraded;

  /// The slide shown (null before the first [enter]/[show]).
  String? get slideId => _slideId;

  /// The step shown (or playing).
  int get step => _step;

  /// The running transition's plan, or null.
  TransitionPlan? get plan => _plan;

  /// Whether the rest of the running animation is a crossfade.
  bool get degraded => _degraded != null;

  /// When the current segment started (the caller's clock).
  int get startMs => _start;

  int get _transitionMs => _plan?.durationMs ?? 0;

  /// Shows [slideId] settled at the end of [step] (no animation).
  void show(String slideId, int step, {required int now}) {
    _slideId = slideId;
    _step = step;
    _start = now;
    _plan = null;
    _request = null;
    _plays = false;
    _finished = true;
    _degraded = null;
  }

  /// Plays [step] of the shown slide from its start ([elapsed] ms ago).
  void playStep(int step, {required int now, int elapsed = 0}) {
    _step = step;
    _start = now - elapsed;
    _plan = null;
    _request = null;
    _plays = true;
    _finished = false;
    _degraded = null;
  }

  /// Enters [toSlideId] from [fromSlideId] (shown in its settled step
  /// [fromStep]): the transition, then step 0 when [toStep] is 0 and
  /// [playStep0] — else the settled [toStep]. [reverse] plays the left
  /// slide's transition backwards (06 §6). Started [elapsed] ms ago.
  void enter(
    String toSlideId, {
    required int now,
    String? fromSlideId,
    int fromStep = 0,
    SlideFrame? fromFrame,
    int toStep = 0,
    bool reverse = false,
    bool playStep0 = true,
    int elapsed = 0,
  }) {
    final plays = toStep == 0 && playStep0 && !reverse;
    final to = timelineOf(toSlideId);
    TransitionPlan? plan;
    TransitionRequest? request;
    if (fromSlideId != null) {
      request = TransitionRequest(
        fromSlideId: fromSlideId,
        fromStep: fromStep,
        fromFrame: fromFrame ?? timelineOf(fromSlideId).endOfStep(fromStep),
        toSlideId: toSlideId,
        toStep: plays ? -1 : toStep,
        toFrame: plays ? to.initial : to.endOfStep(toStep),
        reverse: reverse,
      );
      plan = planOf(request);
      if (plan.durationMs <= 0) plan = null;
    }
    _slideId = toSlideId;
    _step = toStep;
    _start = now - elapsed;
    _plan = plan;
    _request = plan == null ? null : request;
    _plays = plays;
    _finished = false;
    _degraded = null;
  }

  /// The settled frame of the shown step.
  SlideFrame get settledFrame {
    final id = _slideId;
    if (id == null) return SlideFrame.edit;
    return timelineOf(id).endOfStep(_step);
  }

  int _stepDuration() {
    final id = _slideId;
    if (id == null || !_plays) return 0;
    final t = timelineOf(id);
    return _step < t.steps.length ? t.steps[_step].durationMs : 0;
  }

  bool _loops() {
    final id = _slideId;
    if (id == null || !_plays) return false;
    final t = timelineOf(id);
    return _step < t.steps.length && t.steps[_step].hasLoops;
  }

  /// When the running animation ends (the caller's clock).
  int get endMs => _start + _transitionMs + _stepDuration();

  /// Whether a transition or build is running at [now] (a *Next* finishes
  /// it first, 10 §2.1). A looping emphasis after its first cycle doesn't
  /// count.
  bool isRunning(int now) => !_finished && now < endMs;

  /// Whether a transition is running at [now].
  bool inTransition(int now) =>
      !_finished && _plan != null && now - _start < _transitionMs;

  /// Whether the stage must keep ticking at [now] (running, or a loop
  /// that cycles until the next click).
  bool needsTicks(int now) => isRunning(now) || (!_finished && _loops());

  /// Ends the running transition/build: the settled frame shows at once.
  void finish() {
    _finished = true;
    _degraded = null;
  }

  /// Plays the rest of the running animation as a crossfade of snapshots
  /// from the frame at [now] to the settled frame (06 §14).
  void degrade(int now) {
    if (!isRunning(now) || _degraded != null) return;
    final v = viewAt(now);
    if (v == null) return;
    final (fromId, fromFrame) = switch (v) {
      TransitionPlayerView() => (v.fromSlideId, v.fromFrame),
      SlidePlayerView() => (v.slideId, v.frame),
      CrossfadePlayerView() => (v.fromSlideId, v.fromFrame),
    };
    final end = endMs;
    _degraded = _Crossfade(
      fromId,
      fromFrame,
      now,
      math.max(now + 1, math.min(end, now + 1500)),
    );
  }

  /// The view at [now] (deterministic).
  PlayerView? viewAt(int now) {
    final id = _slideId;
    if (id == null) return null;
    final t = now - _start;
    final d = _degraded;
    if (d != null && !_finished && now < d.end) {
      return CrossfadePlayerView(
        fromSlideId: d.fromSlideId,
        fromFrame: d.fromFrame,
        slideId: id,
        toFrame: settledFrame,
        mix: ((now - d.start) / (d.end - d.start)).clamp(0.0, 1.0),
      );
    }
    if (d != null) {
      return SlidePlayerView(id, _step, settledFrame);
    }
    final plan = _plan;
    final r = _request;
    if (!_finished && plan != null && r != null && t < plan.durationMs) {
      final ms = math.max(0, t);
      return TransitionPlayerView(
        plan: plan,
        ms: ms,
        frame: plan.frameAt(ms),
        fromSlideId: r.fromSlideId,
        fromFrame: r.fromFrame,
        slideId: id,
        toFrame: r.toFrame,
      );
    }
    final timeline = timelineOf(id);
    if (!_finished && _plays && _step < timeline.steps.length) {
      final ms = t - _transitionMs;
      final s = timeline.steps[_step];
      if (ms < s.durationMs || s.hasLoops) {
        return SlidePlayerView(
          id,
          _step,
          timeline.frameAt(TimelinePosition(_step, math.max(0, ms))),
        );
      }
    }
    return SlidePlayerView(id, _step, timeline.endOfStep(_step));
  }
}

final class _Crossfade {
  _Crossfade(this.fromSlideId, this.fromFrame, this.start, this.end);

  final String fromSlideId;
  final SlideFrame fromFrame;
  final int start, end;
}
