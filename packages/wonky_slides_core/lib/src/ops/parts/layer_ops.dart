part of '../operations.dart';

// Layers and reading order (03 §8.1, §17.2; SL-34).

/// Moves elements in the z-order of their owner (the Layers panel's drag
/// and drop, `slides.arrange.setZ`, 03 §8.1): directly above [aboveId] or
/// directly below [belowId] (a sibling under the parent the elements get),
/// or — with neither — on top of the children of element group
/// [intoGroupId] (null = the owner's top level).
///
/// Dragging into or out of an element group re-parents: the frames are
/// mapped between the group child spaces so nothing moves on the slide
/// (02 §6.9), leaving a group multiplies its opacity in (as *Ungroup*
/// does), groups left empty are deleted and the touched (unrotated,
/// unflipped) groups are refitted to their children. The moved elements
/// keep their relative order. One undo step.
final class MoveElementsZ extends SlidesOperation {
  const MoveElementsZ(
    this.elementIds, {
    this.aboveId,
    this.belowId,
    this.intoGroupId,
  });

  /// The elements to move (one owner).
  final List<String> elementIds;

  /// Directly above (in front of) this element.
  final String? aboveId;

  /// Directly below (behind) this element.
  final String? belowId;

  /// On top of this element group's children (when [aboveId] and
  /// [belowId] are null).
  final String? intoGroupId;

  @override
  String get name => 'MoveElementsZ';
}

/// Sets the custom reading order of owner [ownerId]'s elements (03 §17.2,
/// `slides.a11y.setReadingOrder`): [elementIds] get ascending
/// `readingKey`s, every other element of the owner loses its key. An empty
/// list resets the owner to the automatic order (*Reset to automatic*).
final class SetReadingOrder extends SlidesOperation {
  const SetReadingOrder(this.ownerId, this.elementIds);

  /// The slide (or layout / master).
  final String ownerId;

  /// The elements in reading order.
  final List<String> elementIds;

  @override
  String get name => 'SetReadingOrder';
}
