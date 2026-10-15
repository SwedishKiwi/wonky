import '../../scene/nodes/text_layout.dart';
import '../../theme/json/json_util.dart';
import '../../theme/layout/placeholder_type.dart';
import '../../theme/model/box_text_style.dart';
import '../../theme/model/common.dart';
import 'records.dart';

/// An element with its effective geometry after inheritance (placeholder
/// chain, group child space), as produced by the `SlideResolver` (02 §11,
/// SL-7) and consumed by the element kind handlers (03 §1.3), the scene
/// builder, hit testing and snapping.
///
/// SL-3 defined the geometry; SL-7 added the effective style (fill, stroke,
/// effects, kind payload, box text properties, text styles), placeholder
/// details and field text. Auto-fit and connector routes are derived by the
/// scene/geometry layer (SL-10).
final class ResolvedElement {
  /// Creates a resolved element.
  const ResolvedElement({
    required this.record,
    required this.frame,
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.opacity = 1,
    this.inherited = false,
    this.children = const [],
    this.placeholderType,
    this.dangling = false,
    this.fill,
    this.stroke,
    this.effects,
    this.data,
    this.textStyle,
    this.styleKey,
    this.textStyles,
    this.prompt,
    this.fieldText,
    this.parentId,
  });

  /// The element row (slide, layout or master element).
  final SlideElementRec record;

  /// Effective frame in the owner's slide space (su), with group child
  /// space mapped.
  final SuRect frame;

  /// Effective rotation in degrees (clockwise, `[0, 360)`).
  final double rotation;

  /// Effective horizontal flip.
  final bool flipH;

  /// Effective vertical flip.
  final bool flipV;

  /// Effective opacity 0..1 (group opacity multiplied in).
  final double opacity;

  /// Whether the element is drawn from a layout/master (not a slide row).
  final bool inherited;

  /// Resolved children of a group element, back to front.
  final List<ResolvedElement> children;

  /// The placeholder type (instances and definitions), or null.
  final SlidePlaceholderType? placeholderType;

  /// Whether the instance's `placeholderOf` dangles (02 §10).
  final bool dangling;

  /// Effective `fillJson` (decoded), or null = the kind's default.
  final JsonMap? fill;

  /// Effective `strokeJson`.
  final JsonMap? stroke;

  /// Effective `effectsJson`.
  final JsonMap? effects;

  /// Effective `dataJson` (kind payload).
  final JsonMap? data;

  /// Box text properties merged along the placeholder chain.
  final BoxTextStyle? textStyle;

  /// The box's default paragraph style key.
  final String? styleKey;

  /// Theme text styles + box properties for laying out [text] (elements
  /// that hold text).
  final ResolvedTextStyles? textStyles;

  /// The prompt of an empty placeholder (the layout placeholder's text,
  /// plain), or null.
  final String? prompt;

  /// The generated text of a field placeholder (slide number, footer).
  final String? fieldText;

  /// The effective parent group (null = top level).
  final String? parentId;

  /// The element id.
  String get id => record.id;

  /// The element's text body (Delta JSON) or null.
  String? get text => record.text;

  /// Whether the element is hidden (not drawn, 03 §8.2).
  bool get hidden => record.hidden;

  /// Whether the element is locked (03 §8.2).
  bool get locked => record.locked;
}
