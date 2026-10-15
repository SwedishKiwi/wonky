part of '../operations.dart';

// Slides (02 §12.1 "Slides", 04 §5).

/// Adds [count] slides with [layoutId] (null = the layout of the slide
/// before [target], else the default theme's `titleBody`) at [target]
/// (null = after the current slide [afterSlideId], else at the end), with
/// their placeholder instances.
final class AddSlides extends SlidesOperation {
  const AddSlides({
    this.layoutId,
    this.target,
    this.afterSlideId,
    this.count = 1,
  });

  final String? layoutId;
  final SlideTarget? target;

  /// Shortcut target: after this slide, in its group (*New slide*).
  final String? afterSlideId;
  final int count;

  @override
  String get name => 'AddSlides';
}

/// Duplicates slides (with elements, table rows, builds, code states and
/// chart links; fresh ids; placeholder instance ids recomputed), each
/// after its source.
final class DuplicateSlides extends SlidesOperation {
  const DuplicateSlides(this.slideIds);

  final List<String> slideIds;

  @override
  String get name => 'DuplicateSlides';
}

/// Deletes slides, listing their dependent rows explicitly so undo revives
/// them (02 §12.1 planner rules).
final class DeleteSlides extends SlidesOperation {
  const DeleteSlides(this.slideIds);

  final List<String> slideIds;

  @override
  String get name => 'DeleteSlides';
}

/// Moves slides (in their flattened order) to [target]; writes `groupId`
/// and `sortKey` together (02 P4).
final class MoveSlides extends SlidesOperation {
  const MoveSlides(this.slideIds, this.target);

  final List<String> slideIds;
  final SlideTarget target;

  @override
  String get name => 'MoveSlides';
}

/// Slide properties (null = unchanged). A layout change remaps the
/// placeholder instances (05 §5.4).
final class SetSlideProps extends SlidesOperation {
  const SetSlideProps(
    this.slideIds, {
    this.skipped,
    this.backgroundJson,
    this.layoutId,
    this.transitionJson,
    this.notes,
    this.hideMasterElements,
    this.timingsJson,
  });

  final List<String> slideIds;
  final bool? skipped;
  final Patch<String?>? backgroundJson;
  final String? layoutId;
  final Patch<String?>? transitionJson;

  /// Notes Delta JSON (whole body; null = unchanged).
  final Patch<String?>? notes;
  final Patch<bool?>? hideMasterElements;
  final Patch<String?>? timingsJson;

  @override
  String get name => 'SetSlideProps';
}

/// Resets placeholder instances of slides to their layout (frames, styles
/// inherited again; content kept).
final class ResetSlideToLayout extends SlidesOperation {
  const ResetSlideToLayout(this.slideIds);

  final List<String> slideIds;

  @override
  String get name => 'ResetSlideToLayout';
}
