import '../../schema/slides_schema.dart';
import '../api/deck_reader.dart';
import '../api/records.dart';

/// Themes, masters and layouts of a deck (02 §11 `ThemeIndex`): the
/// layout → master → theme chain, the effective layout of a slide with the
/// fallback of 02 §10, and usage counts (05 §8.2, §9).
final class ThemeIndex {
  ThemeIndex._(this._deck, this.defaultTheme, this._layoutsOfTheme);

  /// Builds the index of [deck].
  factory ThemeIndex.of(DeckReader deck) {
    final byTheme = <String, List<SlideLayoutRec>>{};
    for (final t in deck.themes) {
      byTheme[t.id] = [
        for (final m in deck.mastersOf(t.id)) ...deck.layoutsOf(m.id),
      ];
    }
    return ThemeIndex._(deck, deck.defaultTheme, byTheme);
  }

  final DeckReader _deck;

  /// The deck's default theme (`Deck.themeId`, else the smallest id).
  final DeckThemeRec? defaultTheme;

  final Map<String, List<SlideLayoutRec>> _layoutsOfTheme;

  Map<String, int>? _layoutUse;

  /// The master of [layout] (null when missing).
  SlideMasterRec? masterOf(SlideLayoutRec layout) {
    final m = layout.masterId;
    return m == null ? null : _deck.master(m);
  }

  /// The theme of [master] (null when missing).
  DeckThemeRec? themeOf(SlideMasterRec master) {
    final t = master.themeId;
    return t == null ? null : _deck.theme(t);
  }

  /// The theme of [layout] (null when its master or theme is missing).
  DeckThemeRec? themeOfLayout(SlideLayoutRec layout) {
    final m = masterOf(layout);
    return m == null ? null : themeOf(m);
  }

  /// Layouts of [themeId] (every master, in order).
  List<SlideLayoutRec> layoutsOfTheme(String themeId) =>
      _layoutsOfTheme[themeId] ?? const [];

  /// The first layout with [key] in [themeId], or null.
  SlideLayoutRec? layoutByKey(String themeId, String key) {
    for (final l in layoutsOfTheme(themeId)) {
      if (l.key == key) return l;
    }
    return null;
  }

  /// The layout [slide] is drawn with (02 §10): its `layoutId` when that
  /// layout exists (and its master and theme do), else the `blank`-key
  /// layout of the default theme, else null (the key of a missing layout
  /// is unknown).
  SlideLayoutRec? effectiveLayout(SlideRec slide) {
    final id = slide.layoutId;
    final l = id == null ? null : _deck.layout(id);
    if (l != null && themeOfLayout(l) != null) return l;
    final t = defaultTheme;
    if (t == null) return null;
    return layoutByKey(t.id, 'blank');
  }

  /// Whether [slide]'s stored `layoutId` resolves (02 §10).
  bool hasValidLayout(SlideRec slide) {
    final id = slide.layoutId;
    final l = id == null ? null : _deck.layout(id);
    return l != null && themeOfLayout(l) != null;
  }

  /// Number of slides drawn with each layout (effective layout).
  Map<String, int> get layoutUse {
    final cached = _layoutUse;
    if (cached != null) return cached;
    final out = <String, int>{};
    for (final s in _deck.records(SlidesTables.slide)) {
      final l = effectiveLayout(s as SlideRec);
      if (l != null) out[l.id] = (out[l.id] ?? 0) + 1;
    }
    return _layoutUse = out;
  }

  /// Number of slides using [layoutId].
  int slidesUsingLayout(String layoutId) => layoutUse[layoutId] ?? 0;

  /// Number of slides using a layout of [masterId].
  int slidesUsingMaster(String masterId) {
    var n = 0;
    for (final l in _deck.layoutsOf(masterId)) {
      n += slidesUsingLayout(l.id);
    }
    return n;
  }

  /// Number of slides using a layout of [themeId].
  int slidesUsingTheme(String themeId) {
    var n = 0;
    for (final l in layoutsOfTheme(themeId)) {
      n += slidesUsingLayout(l.id);
    }
    return n;
  }
}
