import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

/// A place in a presentation: timeline [step] of slide [slideId]
/// (Slides 10 §2, 06 §9). Step 0 is the slide after its transition and
/// automatic step; each click advances one step up to the timeline's
/// `stepCount`, then the next slide starts at step 0.
final class PresentPosition {
  const PresentPosition(this.slideId, [this.step = 0]);

  final String slideId;
  final int step;

  @override
  bool operator ==(Object other) =>
      other is PresentPosition &&
      other.slideId == slideId &&
      other.step == step;

  @override
  int get hashCode => Object.hash(slideId, step);

  @override
  String toString() => 'PresentPosition($slideId, $step)';
}

/// The compiled timeline of a slide (the M9 stub has no steps; SL-24's
/// compiler plugs in here, so navigation already walks timeline steps).
typedef SlideTimelineOf = SlideTimeline Function(String slideId);

/// The presentation order over the deck's flattened slide order (02 §3.4)
/// and the slides' timelines: next/previous step-wise, slide-wise, first,
/// last and go-to (Slides 10 §2.1–§2.2).
///
/// Skipped slides (the slide's or its group's `skipped`) are left out of
/// next/previous unless [showSkipped] (the presenter view's *Show skipped
/// slides*); they stay reachable with [goTo]. After a skipped slide *Next*
/// continues with the following presented slide.
class PresentSequence {
  PresentSequence(
    this.order, {
    required this.timelineOf,
    this.showSkipped = false,
  });

  /// The deck order (rebuilt when the deck changes).
  SlideOrder order;
  final SlideTimelineOf timelineOf;
  bool showSkipped;

  bool _included(SlideOrderEntry e) => showSkipped || !e.skipped;

  /// The number of clicks of [slideId].
  int stepCount(String slideId) => timelineOf(slideId).stepCount;

  PresentPosition _start(SlideOrderEntry e) => PresentPosition(e.id);

  PresentPosition _end(SlideOrderEntry e) =>
      PresentPosition(e.id, stepCount(e.id));

  SlideOrderEntry? _after(int index) {
    for (var i = index + 1; i < order.entries.length; i++) {
      if (_included(order.entries[i])) return order.entries[i];
    }
    return null;
  }

  SlideOrderEntry? _before(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (_included(order.entries[i])) return order.entries[i];
    }
    return null;
  }

  /// The first presented slide, or null (no slides, or all skipped).
  PresentPosition? first() {
    final e = _after(-1);
    return e == null ? null : _start(e);
  }

  /// The last presented slide (at its start).
  PresentPosition? last() {
    final e = _before(order.entries.length);
    return e == null ? null : _start(e);
  }

  /// Where presenting from [slideId] starts: the first presented slide at
  /// or after it, else the last one before it (10 §1.2).
  PresentPosition? startAt(String? slideId) {
    final i = slideId == null ? -1 : order.indexOf(slideId);
    if (i < 0) return first();
    final e = order.entries[i];
    if (_included(e)) return _start(e);
    final a = _after(i) ?? _before(i);
    return a == null ? null : _start(a);
  }

  /// The next step or slide; null after the last step of the last slide.
  PresentPosition? next(PresentPosition p) {
    final i = order.indexOf(p.slideId);
    if (i < 0) return first();
    if (p.step < stepCount(p.slideId)) {
      return PresentPosition(p.slideId, p.step + 1);
    }
    final e = _after(i);
    return e == null ? null : _start(e);
  }

  /// The previous step's end state, or the previous slide's final frame;
  /// null at the very beginning.
  PresentPosition? previous(PresentPosition p) {
    final i = order.indexOf(p.slideId);
    if (i < 0) return first();
    if (p.step > 0) return PresentPosition(p.slideId, p.step - 1);
    final e = _before(i);
    return e == null ? null : _end(e);
  }

  /// The next slide at its start (remaining builds skipped).
  PresentPosition? nextSlide(PresentPosition p) {
    final i = order.indexOf(p.slideId);
    if (i < 0) return first();
    final e = _after(i);
    return e == null ? null : _start(e);
  }

  /// The previous slide at its start.
  PresentPosition? previousSlide(PresentPosition p) {
    final i = order.indexOf(p.slideId);
    if (i < 0) return first();
    final e = _before(i);
    return e == null ? null : _start(e);
  }

  /// [slideId] at [step] (clamped), skipped or not; null when unknown.
  PresentPosition? goTo(String slideId, [int step = 0]) {
    if (order.entry(slideId) == null) return null;
    return PresentPosition(slideId, step.clamp(0, stepCount(slideId)));
  }

  /// The slide at 1-based deck position [number] (the navigator's numbers,
  /// incl. skipped slides; *Go to slide*), or null.
  PresentPosition? goToNumber(int number) {
    if (number < 1 || number > order.entries.length) return null;
    return _start(order.entries[number - 1]);
  }

  /// The presented slide nearest to deck index [index] (after the current
  /// slide was deleted while presenting).
  PresentPosition? nearest(int index) {
    if (order.entries.isEmpty) return null;
    final i = index.clamp(0, order.entries.length - 1);
    final e = order.entries[i];
    if (_included(e)) return _start(e);
    final a = _after(i) ?? _before(i);
    return a == null ? null : _start(a);
  }

  /// The slides in the presented sequence (what the strip and the counter
  /// count), in deck order.
  List<SlideOrderEntry> get presented => [
    for (final e in order.entries)
      if (_included(e)) e,
  ];
}
