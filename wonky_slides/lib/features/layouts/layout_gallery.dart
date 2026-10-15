import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart' show SlideAppearance;

import '../editor_screen/deck_editor_controller.dart';
import '../themes/preview_card.dart';
import '../themes/theme_previews.dart';

/// The menu slot of the toolbar's *Layout ▾* gallery (`MenuCustomItems`).
const layoutGallerySlot = 'toolbar.layout.gallery';

/// Stable widget keys of the layout gallery.
abstract final class LayoutGalleryKeys {
  static const gallery = ValueKey<String>('slides.layoutGallery');

  /// The cell of [layoutId].
  static ValueKey<String> cell(String layoutId) =>
      ValueKey<String>('slides.layoutGallery.$layoutId');
}

/// The layouts a layout gallery offers for the current slide: the visible
/// layouts of the current slide's theme (else the deck's default theme),
/// in theme order (05 §4).
List<SlideLayoutRec> galleryLayouts(DeckEditorController ed) {
  final m = ed.model;
  final themes = m.indexes.themes;
  final cur = ed.currentSlideId == null ? null : m.slide(ed.currentSlideId!);
  final layout = cur == null ? null : themes.effectiveLayout(cur);
  final theme =
      (layout == null ? null : themes.themeOfLayout(layout)) ??
      themes.defaultTheme;
  if (theme == null) return const [];
  return [
    for (final l in themes.layoutsOfTheme(theme.id))
      if (!l.hidden) l,
  ];
}

/// The layout gallery (Slides 04 §6.2 toolbar *Layout ▾*, §7.4 Inspector ›
/// Slide › Layout; 05 §4): thumbnails of the layouts of the current slide's
/// theme drawn with their prompts in the deck's appearance, the name under
/// each, the current slide's layout highlighted. Choosing one calls
/// [onSelected] (the caller runs `slides.slide.applyLayout`). Keyboard: Tab
/// moves over the cells, Enter / Space choose. Previews never write.
class LayoutGallery extends StatelessWidget {
  const LayoutGallery({
    super.key,
    required this.editor,
    required this.onSelected,
    this.thumbWidth = 96,
    this.columns,
    this.enabled = true,
  });

  final DeckEditorController editor;
  final ValueChanged<SlideLayoutRec> onSelected;
  final double thumbWidth;

  /// Fixed column count (null = as many as fit).
  final int? columns;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final layouts = galleryLayouts(editor);
    final previews = ThemePreviews.of(editor);
    final m = editor.model;
    final cur = editor.currentSlideId == null
        ? null
        : m.slide(editor.currentSlideId!);
    final current = cur == null ? null : m.indexes.themes.effectiveLayout(cur);
    final appearance = m.deck?.appearance ?? SlideAppearance.light;
    Widget cell(SlideLayoutRec l) {
      final deck = previews.deckOfLayout(l.id);
      final slide = deck?.layoutSlides[l.id];
      final on = l.id == current?.id;
      return PreviewCard(
        key: LayoutGalleryKeys.cell(l.id),
        label: l.name,
        selected: on,
        onPressed: enabled ? () => onSelected(l) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.border),
                borderRadius: BorderRadius.circular(3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: deck == null || slide == null
                    ? SizedBox(
                        width: thumbWidth,
                        height: thumbWidth * _inverseAspect(editor),
                      )
                    : ThemePreviewThumbnail(
                        deck: deck,
                        slideId: slide,
                        width: thumbWidth,
                        appearance: appearance,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: thumbWidth,
              child: Text(
                l.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.small.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

    final grid = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [for (final l in layouts) cell(l)],
    );
    return FocusTraversalGroup(
      child: KeyedSubtree(
        key: LayoutGalleryKeys.gallery,
        child: columns == null
            ? grid
            : SizedBox(width: columns! * (thumbWidth + 16), child: grid),
      ),
    );
  }
}

double _inverseAspect(DeckEditorController ed) {
  final d = ed.model.deck;
  return d == null ? 9 / 16 : d.height / d.width;
}
