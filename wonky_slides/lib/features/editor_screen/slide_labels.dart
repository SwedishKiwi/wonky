import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

/// Labels of slides and layouts for the chrome (go-to dialog, menus,
/// status bar, outline shell).
abstract final class SlideLabels {
  /// The plain text of the slide's title placeholder ('' when it has
  /// none or it is empty).
  static String title(DeckReader deck, String slideId) {
    for (final e in deck.elementsOf(slideId)) {
      if (e.placeholderType == SlidePlaceholderType.title) {
        return SlidesText.plainText(e.text).trim();
      }
    }
    return '';
  }

  /// "4 · Our mission — Intro" (04 §13.10); [untitled] when the slide has
  /// no title.
  static String goToLabel(
    DeckModel model,
    SlideOrderEntry entry, {
    required String untitled,
  }) {
    final t = title(model, entry.id);
    final g = entry.groupId == null ? null : model.group(entry.groupId!);
    final name = t.isEmpty ? untitled : t;
    final group = g == null || g.title.isEmpty ? '' : ' — ${g.title}';
    return '${entry.index + 1} · $name$group';
  }

  /// The visible layouts of the deck's default theme, in theme order
  /// (New slide with layout ▸, Apply layout ▸).
  static List<SlideLayoutRec> layouts(DeckModel model) {
    final theme = model.defaultTheme;
    if (theme == null) return const [];
    return [
      for (final l in model.indexes.themes.layoutsOfTheme(theme.id))
        if (!l.hidden) l,
    ];
  }
}
