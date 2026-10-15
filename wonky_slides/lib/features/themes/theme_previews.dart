import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart' show SlidesPlanner;
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart' show MemoryDeck;
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart' show SequentialIdGenerator;

import '../editor_screen/deck_editor_controller.dart';
import '../stage/slide_renderer.dart';
import '../thumbnails/slide_thumbnail.dart';

const _previewUser = '00000000-0000-4000-8000-000000000001';
const _previewDeck = '00000000-0000-4000-8000-0000000075e5';

/// A preview deck: a renderer over an in-memory deck that is never synced
/// and never written to the open deck (05 §9 "previews don't write").
class ThemePreviewDeck {
  ThemePreviewDeck._(this.renderer, this.cardSlideId, this.layoutSlides);

  final SlideRenderer renderer;

  /// The theme card: the `title` layout with the theme's name.
  final String? cardSlideId;

  /// Layout id → the preview slide drawing that layout with its prompts.
  final Map<String, String> layoutSlides;

  void dispose() => renderer.dispose();

  /// Builds a preview deck. [rows] hold a `deck` row and the theme rows;
  /// one slide per layout of [themeId] gets its placeholders filled with
  /// the layout's prompt texts, and a card slide shows [title] and
  /// [subtitle] on the theme's `title` layout.
  static ThemePreviewDeck _build(
    DeckModel model,
    String themeId, {
    required String title,
    required String subtitle,
    bool layouts = true,
  }) {
    final deck = MemoryDeck(
      model: model,
      userId: _previewUser,
      planner: const SlidesPlanner(),
      ids: SequentialIdGenerator(900000),
    );
    final themeLayouts = model.indexes.themes.layoutsOfTheme(themeId);
    String? addSlide(SlideLayoutRec l, String? Function(SlideElementRec) text) {
      final before = {for (final s in model.slides) s.id};
      deck.execute(AddSlides(layoutId: l.id));
      final id = model.slides
          .map((s) => s.id)
          .firstWhere((s) => !before.contains(s), orElse: () => '');
      if (id.isEmpty) return null;
      for (final e in model.elementsOf(id)) {
        final of = e.placeholderOf == null
            ? null
            : model.element(e.placeholderOf!);
        if (of == null) continue;
        final t = text(of);
        if (t == null || t.isEmpty) continue;
        try {
          deck.execute(SetText(ElementText(e.id), t));
        } on PlanException {
          // A placeholder without a text body (picture, code, chart).
        }
      }
      return id;
    }

    String? card;
    final titleLayout =
        model.indexes.themes.layoutByKey(themeId, 'title') ??
        (themeLayouts.isEmpty ? null : themeLayouts.first);
    if (titleLayout != null) {
      card = addSlide(titleLayout, (of) {
        return switch (of.placeholderType) {
          SlidePlaceholderType.title => _delta(title),
          SlidePlaceholderType.subtitle => _delta(subtitle),
          _ => null,
        };
      });
    }
    final slides = <String, String>{};
    if (layouts) {
      for (final l in themeLayouts) {
        final id = addSlide(l, (of) => of.text);
        if (id != null) slides[l.id] = id;
      }
    }
    return ThemePreviewDeck._(SlideRenderer(model: model), card, slides);
  }

  static String _delta(String text) => jsonEncode([
    {'insert': '$text\n'},
  ]);

  /// The preview of built-in theme [key] at [size].
  static ThemePreviewDeck builtIn(
    String key,
    SlideSize size, {
    required String subtitle,
  }) {
    final model = DeckModel(deckId: _previewDeck);
    final deck = MemoryDeck(
      model: model,
      userId: _previewUser,
      planner: const SlidesPlanner(),
      ids: SequentialIdGenerator(1),
    );
    final def = BuiltInThemes.byKey(key)!;
    deck.execute(
      CreateDeck(
        deckId: _previewDeck,
        title: def.name,
        themeKey: key,
        size: size,
        firstLayoutKey: null,
      ),
    );
    return _build(
      model,
      model.deck!.themeId!,
      title: def.name,
      subtitle: subtitle,
      layouts: false,
    );
  }

  /// The preview of theme [themeId] of [source] (its rows copied as they
  /// are, ids kept), with one slide per layout.
  static ThemePreviewDeck deckTheme(
    DeckModel source,
    String themeId, {
    required String subtitle,
  }) {
    final theme = source.theme(themeId)!;
    final d = source.deck;
    final rows = <(String, Map<String, Object?>)>[
      (
        SlidesTables.deck,
        {
          if (d != null) ...d.columns,
          SlidesCols.id: _previewDeck,
          DeckCols.themeId: themeId,
          DeckCols.showSlideNumbers: false,
          DeckCols.footerText: null,
        },
      ),
      (
        SlidesTables.deckTheme,
        {...theme.columns, DeckThemeCols.deckId: _previewDeck},
      ),
    ];
    for (final m in source.mastersOf(themeId)) {
      rows.add((SlidesTables.slideMaster, m.columns));
      for (final e in source.allElementsOf(m.id)) {
        rows.add((SlidesTables.slideElement, e.columns));
      }
      for (final l in source.layoutsOf(m.id)) {
        rows.add((SlidesTables.slideLayout, l.columns));
        for (final e in source.allElementsOf(l.id)) {
          rows.add((SlidesTables.slideElement, e.columns));
        }
      }
    }
    return _build(
      DeckModel.fromRows(_previewDeck, rows),
      themeId,
      title: theme.name,
      subtitle: subtitle,
    );
  }
}

/// The theme and layout previews of one open deck (Themes panel, layout
/// galleries; 05 §9): built-in themes at the deck's size (shared by every
/// deck of that size) and the deck's own themes, rebuilt lazily after the
/// deck's themes, masters, layouts or size change.
class ThemePreviews {
  ThemePreviews._(this.editor) {
    editor.model.addListener(_onBatch);
  }

  static final Expando<ThemePreviews> _of = Expando('ThemePreviews');

  /// The previews of [editor]'s deck (created on first use; disposed with
  /// [dispose] by whoever disposes the editor, else they live as long as
  /// the editor).
  static ThemePreviews of(DeckEditorController editor) =>
      _of[editor] ??= ThemePreviews._(editor);

  /// The previews of [editor] if any were built.
  static ThemePreviews? maybeOf(DeckEditorController editor) => _of[editor];

  final DeckEditorController editor;

  static final Map<String, ThemePreviewDeck> _builtIns = {};
  final Map<String, ThemePreviewDeck> _deckThemes = {};

  /// Preview subtitle (localized by the caller).
  String subtitle = 'Aa';

  SlideSize get size {
    final d = editor.model.deck;
    return d == null
        ? SlideSize.widescreen
        : SlideSize(d.sizePreset, d.width, d.height);
  }

  /// The preview deck of built-in theme [key] at the deck's size.
  ThemePreviewDeck builtIn(String key) {
    final s = size;
    return _builtIns['$key|${s.width}x${s.height}'] ??=
        ThemePreviewDeck.builtIn(key, s, subtitle: subtitle);
  }

  /// The preview deck of the deck's theme [themeId] (null when missing).
  ThemePreviewDeck? deckTheme(String themeId) {
    if (editor.model.theme(themeId) == null) return null;
    return _deckThemes[themeId] ??= ThemePreviewDeck.deckTheme(
      editor.model,
      themeId,
      subtitle: subtitle,
    );
  }

  /// The preview deck holding [layoutId] (its theme's), or null.
  ThemePreviewDeck? deckOfLayout(String layoutId) {
    final l = editor.model.layout(layoutId);
    if (l == null) return null;
    final t = editor.model.indexes.themes.themeOfLayout(l);
    return t == null ? null : deckTheme(t.id);
  }

  void _onBatch(DeckChangeBatch batch) {
    final m = editor.model;
    var stale = false;
    for (final e in batch.events) {
      switch (e) {
        case ThemeChanged():
          stale = true;
        case DeckChanged(:final columns):
          if (columns.contains(DeckCols.width) ||
              columns.contains(DeckCols.height)) {
            stale = true;
          }
        case ElementsChanged(:final ownerIds):
          if (ownerIds.any((o) => m.slide(o) == null)) stale = true;
        default:
      }
      if (stale) break;
    }
    if (!stale) return;
    for (final d in _deckThemes.values) {
      d.dispose();
    }
    _deckThemes.clear();
  }

  void dispose() {
    editor.model.removeListener(_onBatch);
    for (final d in _deckThemes.values) {
      d.dispose();
    }
    _deckThemes.clear();
    _of[editor] = null;
  }
}

/// A preview thumbnail: [slideId] of [deck] at [width] in [appearance].
class ThemePreviewThumbnail extends StatelessWidget {
  const ThemePreviewThumbnail({
    super.key,
    required this.deck,
    required this.slideId,
    required this.width,
    required this.appearance,
    this.semanticLabel,
  });

  final ThemePreviewDeck deck;
  final String slideId;
  final double width;
  final SlideAppearance appearance;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SlideThumbnail(
    renderer: deck.renderer,
    slideId: slideId,
    width: width,
    appearance: appearance,
    semanticLabel: semanticLabel,
  );
}
