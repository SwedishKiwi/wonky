/// The user operations of Wonky Slides (02 §12.1): commands (UI), MCP
/// tools, AI and server writers construct a [SlidesOperation]; the
/// `SlidesMutationPlanner` turns it into a `SlidesPlan` against the deck
/// model. One part file per area.
///
/// Contract (SL-3): names and fields are binding for the packages of
/// Slides 12 §4; the planner (SL-7, and SL-24…SL-28 for builds, code,
/// charts and themes) implements them and may extend fields through a
/// contract change. Ids in operations are canonical lower-case UUID
/// strings; geometry is in slide units (su, 02 §2.2).
library;

import '../theme/layout/slide_size.dart';
import '../theme/model/common.dart';
import '../model/api/kinds.dart';

part 'parts/deck_ops.dart';
part 'parts/slide_ops.dart';
part 'parts/group_ops.dart';
part 'parts/clipboard_ops.dart';
part 'parts/element_ops.dart';
part 'parts/text_ops.dart';
part 'parts/table_ops.dart';
part 'parts/build_ops.dart';
part 'parts/code_ops.dart';
part 'parts/chart_ops.dart';
part 'parts/theme_ops.dart';
part 'parts/maintenance_ops.dart';
part 'parts/layer_ops.dart';

/// A user operation the `SlidesMutationPlanner` turns into a plan.
sealed class SlidesOperation {
  const SlidesOperation();

  /// The operation's name for logs, MCP errors and tests ("AddSlides").
  String get name;
}

/// A property change that may set a nullable column to null: `null` field
/// = unchanged, `Patch(null)` = clear, `Patch(v)` = set.
final class Patch<T> {
  /// Creates a patch setting [value].
  const Patch(this.value);

  /// The new value (null clears).
  final T value;

  @override
  bool operator ==(Object other) => other is Patch<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Patch($value)';
}

/// Where slides or groups go in the deck's order (02 §3.4).
sealed class SlideTarget {
  const SlideTarget();
}

/// The top-level key space: before/after a top-level item (a group or an
/// ungrouped slide). Both null = at the end.
final class TopLevel extends SlideTarget {
  /// Creates the target.
  const TopLevel({this.beforeId, this.afterId});

  /// Insert before this group/slide id.
  final String? beforeId;

  /// Insert after this group/slide id.
  final String? afterId;
}

/// Inside group [groupId]: before/after one of its slides. Both null = at
/// the end of the group.
final class InGroup extends SlideTarget {
  /// Creates the target.
  const InGroup(this.groupId, {this.beforeId, this.afterId});

  /// The group.
  final String groupId;

  /// Insert before this slide id.
  final String? beforeId;

  /// Insert after this slide id.
  final String? afterId;
}

/// Which text body an operation addresses (02 §4).
sealed class TextTarget {
  const TextTarget();
}

/// `SlideElement.text` of a text box, shape or placeholder.
final class ElementText extends TextTarget {
  /// Creates the target.
  const ElementText(this.elementId);

  /// The element.
  final String elementId;
}

/// `SlideTableCell.text` of a table cell (created on write, deterministic
/// id `SlidesIds.tableCellId`).
final class CellText extends TextTarget {
  /// Creates the target.
  const CellText(this.elementId, this.rowId, this.columnId);

  /// The table element.
  final String elementId;

  /// Row axis.
  final String rowId;

  /// Column axis.
  final String columnId;
}

/// `Slide.notes` (speaker notes).
final class NotesText extends TextTarget {
  /// Creates the target.
  const NotesText(this.slideId);

  /// The slide.
  final String slideId;
}
