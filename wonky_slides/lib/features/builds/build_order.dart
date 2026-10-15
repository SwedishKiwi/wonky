import 'dart:math' as math;

import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

/// One row of the Order list (06 §5.4): a build with its place in the
/// compiled timeline.
final class BuildOrderRow {
  const BuildOrderRow({
    required this.build,
    required this.index,
    required this.step,
    required this.steps,
    required this.startMs,
    required this.durationMs,
    required this.parts,
    this.warning,
  });

  final SlideBuildRec build;

  /// Position in the slide's sequence (0-based).
  final int index;

  /// The step the build starts in (its header).
  final int step;

  /// Every step it plays in (`2–5` for a build by bullet).
  final List<int> steps;

  /// Start relative to its step (ms).
  final int startMs;

  /// Length including its parts and repeats (ms; 0 when skipped).
  final int durationMs;

  /// Parts scheduled (0 = the whole element).
  final int parts;

  /// Why the compiler skipped or changed it, or null (06 §2.4).
  final TimelineWarning? warning;

  String get id => build.id;

  /// Whether the compiler skipped the build.
  bool get skipped => steps.isEmpty;

  /// "2–5", "1" or "0" (automatic) — the badge label (06 §5.5).
  String get stepLabel => stepRangeLabel(steps.isEmpty ? [step] : steps);

  /// The label of a set of steps.
  static String stepRangeLabel(List<int> steps) {
    if (steps.isEmpty) return '';
    final lo = steps.reduce(math.min), hi = steps.reduce(math.max);
    return lo == hi ? '$lo' : '$lo–$hi';
  }
}

/// A step header with its rows.
final class BuildOrderStep {
  const BuildOrderStep(this.index, this.durationMs, this.rows);

  /// 0 = automatic, k = click k.
  final int index;
  final int durationMs;
  final List<BuildOrderRow> rows;
}

/// The Order list of a slide (06 §5.4): the builds grouped by the step
/// they start in, with timing from the compiled timeline.
final class BuildOrder {
  const BuildOrder(this.slideId, this.rows, this.steps, this.timeline);

  final String slideId;

  /// Every build in sequence order.
  final List<BuildOrderRow> rows;

  /// Steps that have rows (step 0 only when it has builds).
  final List<BuildOrderStep> steps;
  final SlideTimeline timeline;

  /// The row of [buildId], or null.
  BuildOrderRow? rowOf(String buildId) {
    for (final r in rows) {
      if (r.id == buildId) return r;
    }
    return null;
  }

  /// The rows of [elementId] in order.
  List<BuildOrderRow> rowsOf(String elementId) => [
    for (final r in rows)
      if (r.build.elementId == elementId) r,
  ];

  /// Element id → the steps its builds play in (build order badges).
  Map<String, List<BuildOrderRow>> get byElement {
    final out = <String, List<BuildOrderRow>>{};
    for (final r in rows) {
      final e = r.build.elementId;
      if (e != null) (out[e] ??= []).add(r);
    }
    return out;
  }

  /// Builds the list of [slideId] from [deck] and its [timeline].
  static BuildOrder of(
    DeckReader deck,
    String slideId,
    SlideTimeline timeline,
  ) {
    final builds = deck.buildsOf(slideId);
    final warnings = <String, TimelineWarning>{};
    for (final w in timeline.warnings) {
      final id = w.buildId;
      if (id != null) warnings.putIfAbsent(id, () => w);
    }
    final rows = <BuildOrderRow>[];
    var prevStep = 0;
    for (final (i, b) in builds.indexed) {
      final steps = <int>[];
      var start = -1, end = 0;
      final parts = <int>{};
      for (final s in timeline.steps) {
        var inStep = false;
        for (final e in s.effects) {
          if (e.buildId != b.id || e.role != EffectRole.build) continue;
          inStep = true;
          if (steps.isEmpty || s.index == steps.first) {
            if (start < 0 || e.startMs < start) start = e.startMs;
            end = math.max(end, e.endMs);
          }
          if (e.part > 0) parts.add(e.part);
        }
        if (inStep) steps.add(s.index);
      }
      // A skipped build is listed with the build before it.
      final step = steps.isEmpty ? prevStep : steps.first;
      rows.add(
        BuildOrderRow(
          build: b,
          index: i,
          step: step,
          steps: steps,
          startMs: math.max(0, start),
          durationMs: start < 0 ? 0 : end - start,
          parts: parts.length,
          warning: warnings[b.id],
        ),
      );
      prevStep = step;
    }
    final byStep = <int, List<BuildOrderRow>>{};
    for (final r in rows) {
      (byStep[r.step] ??= []).add(r);
    }
    final keys = byStep.keys.toList()..sort();
    return BuildOrder(slideId, rows, [
      for (final k in keys)
        BuildOrderStep(
          k,
          k < timeline.steps.length ? timeline.steps[k].durationMs : 0,
          byStep[k]!,
        ),
    ], timeline);
  }
}
