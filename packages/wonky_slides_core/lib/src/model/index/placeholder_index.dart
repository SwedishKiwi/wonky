import 'dart:convert';

import '../../theme/json/json_util.dart';
import '../../theme/layout/placeholder_resolver.dart';
import '../../theme/layout/placeholder_type.dart';
import '../../theme/model/box_text_style.dart';
import '../../theme/model/common.dart';
import '../api/deck_reader.dart';
import '../api/records.dart';
import 'theme_index.dart';

/// Placeholder chains of a deck (02 §11 `PlaceholderIndex`, 05 §5): the
/// decoded placeholder columns of elements ([nodeOf], cached per record),
/// placeholders of layouts and masters, and a `PlaceholderResolver` per
/// slide whose dangling fallback is the master placeholder of the same type
/// (02 §10).
final class PlaceholderIndex {
  /// Creates the index over [deck] with its [themes] index.
  PlaceholderIndex(this._deck, this._themes);

  final DeckReader _deck;
  final ThemeIndex _themes;

  static final Expando<PlaceholderNode> _nodes = Expando('placeholderNode');

  /// Decodes a JSON column to a map (null when absent or invalid).
  static JsonMap? decodeMap(String? json) {
    if (json == null) return null;
    try {
      final v = jsonDecode(json);
      return v is Map<String, Object?> ? v : null;
    } on FormatException {
      return null;
    }
  }

  /// Decodes `textStyleJson` (null when absent or invalid).
  static BoxTextStyle? decodeTextStyle(String? json) {
    final m = decodeMap(json);
    if (m == null) return null;
    return BoxTextStyle.fromJson(m, 'textStyleJson', IssueSink());
  }

  /// The placeholder columns of [e] (cached per record).
  static PlaceholderNode nodeOf(SlideElementRec e) =>
      _nodes[e] ??= PlaceholderNode(
        id: e.id,
        placeholderType: e.placeholderType,
        placeholderOf: e.placeholderOf,
        x: e.x,
        y: e.y,
        width: e.width,
        height: e.height,
        rotation: e.rotation,
        textStyle: decodeTextStyle(e.textStyleJson),
        fill: decodeMap(e.fillJson),
        stroke: decodeMap(e.strokeJson),
        effects: decodeMap(e.effectsJson),
        data: decodeMap(e.dataJson),
        opacity: e.opacity,
      );

  /// Placeholder definitions of a layout or master [ownerId] in `(zKey,
  /// id)` order (top level only).
  List<SlideElementRec> placeholdersOf(String ownerId) => [
    for (final e in _deck.elementsOf(ownerId))
      if (e.placeholderType != null) e,
  ];

  /// The first placeholder of [type] on master [masterId], or null.
  SlideElementRec? masterPlaceholder(
    String masterId,
    SlidePlaceholderType type,
  ) {
    for (final e in placeholdersOf(masterId)) {
      if (e.placeholderType == type) return e;
    }
    return null;
  }

  /// The first placeholder of [type] on [layoutId], else on its master.
  SlideElementRec? layoutPlaceholder(
    String layoutId,
    SlidePlaceholderType type,
  ) {
    for (final e in placeholdersOf(layoutId)) {
      if (e.placeholderType == type) return e;
    }
    final l = _deck.layout(layoutId);
    final m = l?.masterId;
    return m == null ? null : masterPlaceholder(m, type);
  }

  /// Placeholder instances on [slideId] (elements with a type; top level).
  List<SlideElementRec> instancesOf(String slideId) => [
    for (final e in _deck.elementsOf(slideId))
      if (e.placeholderType != null) e,
  ];

  /// A resolver for elements of [slideId] (or of a layout/master when
  /// [slideId] is null) on a [bounds] slide.
  PlaceholderResolver resolver({String? slideId, required SuRect bounds}) {
    final slide = slideId == null ? null : _deck.slide(slideId);
    final layout = slide == null ? null : _themes.effectiveLayout(slide);
    final masterId = layout?.masterId;
    return PlaceholderResolver(
      slideBounds: bounds,
      lookup: (id) {
        final e = _deck.element(id);
        // Only layout/master elements are chain links.
        if (e == null || e.slideId != null) return null;
        return nodeOf(e);
      },
      masterFallback: masterId == null
          ? null
          : (type) {
              final m = masterPlaceholder(masterId, type);
              return m == null ? null : nodeOf(m);
            },
    );
  }

  /// The effective values of [e] (instances walk their chain; other
  /// elements resolve to themselves).
  EffectivePlaceholder effective(SlideElementRec e, {required SuRect bounds}) =>
      resolver(slideId: e.slideId, bounds: bounds).resolve(nodeOf(e));

  /// Whether [instance]'s `placeholderOf` points at a missing element
  /// (02 §10 *dangling*).
  bool isDangling(SlideElementRec instance) {
    final p = instance.placeholderOf;
    if (p == null) return false;
    final e = _deck.element(p);
    return e == null || e.slideId != null;
  }
}
