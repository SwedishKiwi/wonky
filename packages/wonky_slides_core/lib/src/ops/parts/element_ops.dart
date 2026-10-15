part of '../operations.dart';

// Elements (02 §12.1 "Elements", 03 §6–§9).

/// A new element of [InsertElements]: the kind, the frame and any other
/// `SlideElement` columns ([columns], by column name: `fillJson`, `text`,
/// `dataJson`, …). The planner fills `id`, the owner, `zKey`, `matchKey`
/// and `createdAt`. [id] may be preset (paste, MCP results).
///
/// SL-7 additions: tables get [tableRows] × [tableColumns] axes (default
/// 2 × 2), code elements get [codeStates] (`CodeState` columns; default one
/// empty state, 07 A-07-2).
final class ElementSpec {
  const ElementSpec({
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation,
    this.columns = const {},
    this.id,
    this.children = const [],
    this.tableRows,
    this.tableColumns,
    this.codeStates = const [],
  });

  /// Rows of a new table (null = 2).
  final int? tableRows;

  /// Columns of a new table (null = 2).
  final int? tableColumns;

  /// States of a new code element (empty = one empty state).
  final List<Map<String, Object?>> codeStates;

  final ElementKind kind;
  final double x;
  final double y;
  final double width;
  final double height;
  final double? rotation;
  final Map<String, Object?> columns;
  final String? id;

  /// Children of a group element (frames in the group's child space).
  final List<ElementSpec> children;
}

/// Inserts elements on a slide, layout or master ([ownerId]) on top of
/// [parentId]'s children (null = top level), or above [aboveId].
final class InsertElements extends SlidesOperation {
  const InsertElements(
    this.ownerId,
    this.elements, {
    this.ownerKind = ElementOwnerKind.slide,
    this.parentId,
    this.aboveId,
  });

  final String ownerId;
  final ElementOwnerKind ownerKind;
  final List<ElementSpec> elements;
  final String? parentId;
  final String? aboveId;

  @override
  String get name => 'InsertElements';
}

/// A frame change of one element: only the non-null values are written
/// (moving names `x,y`; resizing `x,y,width,height`), always together with
/// the coupled columns that change (02 P4).
final class FrameUpdate {
  const FrameUpdate(
    this.elementId, {
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation,
    this.flipH,
    this.flipV,
  });

  final String elementId;
  final double? x;
  final double? y;
  final double? width;
  final double? height;
  final double? rotation;
  final bool? flipH;
  final bool? flipV;
}

/// Move/resize/rotate/flip (03 §3).
final class UpdateFrames extends SlidesOperation {
  const UpdateFrames(this.updates, {this.label});

  final List<FrameUpdate> updates;

  /// Undo label override ("Move", "Resize", "Rotate", "Nudge").
  final String? label;

  @override
  String get name => 'UpdateFrames';
}

/// Element properties (null = unchanged).
final class SetElementProps extends SlidesOperation {
  const SetElementProps(
    this.elementIds, {
    this.fillJson,
    this.strokeJson,
    this.effectsJson,
    this.opacity,
    this.locked,
    this.hidden,
    this.elementName,
    this.altText,
    this.decorative,
    this.linkJson,
    this.matchKey,
    this.readingKey,
  });

  final List<String> elementIds;
  final Patch<String?>? fillJson;
  final Patch<String?>? strokeJson;
  final Patch<String?>? effectsJson;
  final Patch<double?>? opacity;
  final bool? locked;
  final bool? hidden;

  /// Layers-panel name (`SlideElement.name`).
  final Patch<String?>? elementName;
  final Patch<String?>? altText;
  final bool? decorative;
  final Patch<String?>? linkJson;
  final String? matchKey;
  final Patch<String?>? readingKey;

  @override
  String get name => 'SetElementProps';
}

/// Deletes elements (and group children, table rows, builds, code states,
/// chart links, listed explicitly for undo).
final class DeleteElements extends SlidesOperation {
  const DeleteElements(this.elementIds);

  final List<String> elementIds;

  @override
  String get name => 'DeleteElements';
}

/// Z-order changes (03 §9).
enum ZOrderOp {
  /// Bring to front.
  toFront,

  /// Bring forward one step.
  forward,

  /// Send backward one step.
  backward,

  /// Send to back.
  toBack,
}

/// Reorders elements among their siblings (`zKey`).
final class ReorderZ extends SlidesOperation {
  const ReorderZ(this.elementIds, this.op);

  final List<String> elementIds;
  final ZOrderOp op;

  @override
  String get name => 'ReorderZ';
}

/// Align/distribute modes (03 §5).
enum AlignMode {
  left,
  centerH,
  right,
  top,
  middleV,
  bottom,
  distributeH,
  distributeV,
}

/// What [AlignDistribute] aligns to.
enum AlignReference {
  /// The selection bounds.
  selection,

  /// The slide.
  slide,

  /// The first selected element (key object).
  keyObject,
}

/// Aligns or distributes elements (writes frames).
final class AlignDistribute extends SlidesOperation {
  const AlignDistribute(
    this.elementIds,
    this.mode, {
    this.reference = AlignReference.selection,
  });

  final List<String> elementIds;
  final AlignMode mode;
  final AlignReference reference;

  @override
  String get name => 'AlignDistribute';
}

/// Groups elements into a new group element (re-parents and maps frames
/// into the group's child space, 02 §6.9).
final class GroupElements extends SlidesOperation {
  const GroupElements(this.elementIds, {this.groupId});

  final List<String> elementIds;

  /// Id of the new group (null = fresh).
  final String? groupId;

  @override
  String get name => 'GroupElements';
}

/// Ungroups group elements (bakes the group transform into the children).
final class UngroupElements extends SlidesOperation {
  const UngroupElements(this.groupIds);

  final List<String> groupIds;

  @override
  String get name => 'UngroupElements';
}

/// Replaces an image's source (keeps frame, mask and adjustments; the
/// crop is reset unless [crop] is given — 03 §6.5.2 re-fits the new image
/// to cover the same frame, SL-15).
final class ReplaceImage extends SlidesOperation {
  const ReplaceImage(
    this.elementId, {
    required this.src,
    required this.naturalWidth,
    required this.naturalHeight,
    this.fileName,
    this.mimeType,
    this.crop,
  });

  /// The new crop (`{l, t, r, b}` fractions of the natural size removed
  /// from each side), or null for none.
  final Map<String, double>? crop;

  final String elementId;

  /// `wonky-file://<uuid>`.
  final String src;
  final int naturalWidth;
  final int naturalHeight;
  final String? fileName;
  final String? mimeType;

  @override
  String get name => 'ReplaceImage';
}

/// Replaces an element's kind payload (`dataJson`, whole value, 02 §6).
final class SetElementData extends SlidesOperation {
  const SetElementData(this.elementId, this.dataJson);

  final String elementId;
  final String dataJson;

  @override
  String get name => 'SetElementData';
}
