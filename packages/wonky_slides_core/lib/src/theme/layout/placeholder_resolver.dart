/// Placeholder inheritance (Slides 05 §5.3, 02 §3.5 P6, §10): effective
/// values of a placeholder instance from the chain instance ▸ layout
/// placeholder ▸ master placeholder ▸ theme defaults for the type.
library;

import '../json/json_util.dart';
import '../model/box_text_style.dart';
import '../model/common.dart';
import 'placeholder_type.dart';

/// The placeholder-relevant columns of one `SlideElement` (02 §3.5). Null
/// columns inherit. JSON columns are decoded objects.
final class PlaceholderNode {
  /// Creates a node.
  const PlaceholderNode({
    required this.id,
    this.placeholderType,
    this.placeholderOf,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation,
    this.textStyle,
    this.fill,
    this.stroke,
    this.effects,
    this.data,
    this.opacity,
  });

  /// Element id.
  final String id;

  /// `placeholderType`.
  final SlidePlaceholderType? placeholderType;

  /// `placeholderOf` (the layout or master placeholder this inherits from).
  final String? placeholderOf;

  /// Frame columns.
  final double? x, y, width, height;

  /// Rotation (degrees).
  final double? rotation;

  /// `textStyleJson` (box text properties).
  final BoxTextStyle? textStyle;

  /// `fillJson`.
  final JsonMap? fill;

  /// `strokeJson`.
  final JsonMap? stroke;

  /// `effectsJson`.
  final JsonMap? effects;

  /// `dataJson`.
  final JsonMap? data;

  /// `opacity`.
  final double? opacity;

  /// Whether any frame column is set (a materialized frame, 05 §5.2).
  bool get hasFrame =>
      x != null || y != null || width != null || height != null;
}

/// The effective values of a placeholder.
final class EffectivePlaceholder {
  /// Creates effective values.
  const EffectivePlaceholder({
    required this.id,
    required this.type,
    required this.frame,
    required this.rotation,
    required this.textStyle,
    required this.styleKey,
    required this.fill,
    required this.stroke,
    required this.effects,
    required this.data,
    required this.opacity,
    required this.chain,
    required this.dangling,
  });

  /// The instance id.
  final String id;

  /// The placeholder type (from the first node that has one).
  final SlidePlaceholderType? type;

  /// Effective frame.
  final SuRect frame;

  /// Effective rotation.
  final double rotation;

  /// Box text properties merged along the chain (master first, instance
  /// last).
  final BoxTextStyle textStyle;

  /// The effective default paragraph style key (chain, else the type's
  /// default, else `body`).
  final String styleKey;

  /// Effective `fillJson`.
  final JsonMap? fill;

  /// Effective `strokeJson`.
  final JsonMap? stroke;

  /// Effective `effectsJson`.
  final JsonMap? effects;

  /// Effective `dataJson`.
  final JsonMap? data;

  /// Effective opacity.
  final double opacity;

  /// Ids walked: instance first.
  final List<String> chain;

  /// Whether the instance's `placeholderOf` pointed at a missing element
  /// (02 §10: rendered as a regular element from the master placeholder of
  /// the same type, else a 10 % inset frame).
  final bool dangling;
}

/// Resolves placeholder chains (05 §5.3). Pure; the caller supplies element
/// lookups (from `DeckModel` indexes, a layout library, tests).
final class PlaceholderResolver {
  /// Creates a resolver.
  ///
  /// [lookup] returns a placeholder element by id. [masterFallback] returns
  /// the master placeholder of a type for dangling instances (02 §10).
  /// [slideBounds] is the deck size (for the 10 % inset default frame).
  const PlaceholderResolver({
    required this.lookup,
    required this.slideBounds,
    this.masterFallback,
  });

  /// Element by id.
  final PlaceholderNode? Function(String id) lookup;

  /// The master placeholder of a type (dangling instances).
  final PlaceholderNode? Function(SlidePlaceholderType type)? masterFallback;

  /// The slide rectangle.
  final SuRect slideBounds;

  /// Maximum chain length (instance ▸ layout ▸ master, with slack).
  static const maxDepth = 4;

  /// Resolves [instance].
  EffectivePlaceholder resolve(PlaceholderNode instance) {
    final chain = <PlaceholderNode>[instance];
    var dangling = false;
    var next = instance.placeholderOf;
    final seen = {instance.id};
    while (next != null && chain.length < maxDepth && seen.add(next)) {
      final node = lookup(next);
      if (node == null) {
        if (chain.length == 1) dangling = true;
        break;
      }
      chain.add(node);
      next = node.placeholderOf;
    }
    if (dangling) {
      final type = instance.placeholderType;
      final master = type == null ? null : masterFallback?.call(type);
      if (master != null && master.id != instance.id) chain.add(master);
    }

    T? first<T>(T? Function(PlaceholderNode n) f) {
      for (final n in chain) {
        final v = f(n);
        if (v != null) return v;
      }
      return null;
    }

    final inset = slideBounds.width * 0.1;
    final insetY = slideBounds.height * 0.1;
    final frame = SuRect(
      first((n) => n.x) ?? slideBounds.x + inset,
      first((n) => n.y) ?? slideBounds.y + insetY,
      first((n) => n.width) ?? slideBounds.width - 2 * inset,
      first((n) => n.height) ?? slideBounds.height - 2 * insetY,
    );
    var text = BoxTextStyle.empty;
    for (final n in chain.reversed) {
      text = text.merge(n.textStyle);
    }
    final type = first((n) => n.placeholderType);
    return EffectivePlaceholder(
      id: instance.id,
      type: type,
      frame: frame,
      rotation: first((n) => n.rotation) ?? 0,
      textStyle: text,
      styleKey: text.styleKey ?? type?.defaultStyleKey ?? 'body',
      fill: first((n) => n.fill),
      stroke: first((n) => n.stroke),
      effects: first((n) => n.effects),
      data: first((n) => n.data),
      opacity: first((n) => n.opacity) ?? 1,
      chain: [for (final n in chain) n.id],
      dangling: dangling,
    );
  }
}
