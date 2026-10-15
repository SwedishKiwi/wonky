part of '../operations.dart';

// Deck (02 §12.1 "Deck", 05 §7, 09 §9.3).

/// Creates a new deck in an empty space (*New presentation*, 02 §9.3): the
/// `deck` row (id = [deckId] = the reserved space), a copy of the built-in
/// theme [themeKey] (deterministic `SlidesIds.themeCopyId/themePartId`
/// ids), and one slide with layout [firstLayoutKey] and its placeholder
/// instances. As built (SL-3): added to 02 §12.1 like Sheets'
/// `CreateSpreadsheet`.
final class CreateDeck extends SlidesOperation {
  const CreateDeck({
    required this.deckId,
    required this.title,
    this.themeKey = 'wonky',
    this.size,
    this.appearance,
    this.firstLayoutKey = 'title',
  });

  final String deckId;
  final String title;

  /// Built-in theme key (`BuiltInThemes`).
  final String themeKey;

  /// Slide size (null = the theme package's size, 16:9).
  final SlideSize? size;

  /// Appearance (null = the theme's default appearance).
  final SlideAppearance? appearance;

  /// Layout key of the first slide (null = no slide).
  final String? firstLayoutKey;

  @override
  String get name => 'CreateDeck';
}

/// How a page-size change treats existing content (05 §7).
enum SizeScaleMode {
  /// Scale content uniformly and center it (*Scale content*).
  scale,

  /// Keep frames as they are (*Don't scale*).
  keep,
}

/// A page-size change: writes `width`, `height`, `sizePreset` together
/// (coupled, 02 P4) and, with [SizeScaleMode.scale], every frame.
final class DeckSizeChange {
  const DeckSizeChange(this.size, {this.mode = SizeScaleMode.scale});

  final SlideSize size;
  final SizeScaleMode mode;
}

/// Deck properties (null = unchanged).
final class SetDeckProps extends SlidesOperation {
  const SetDeckProps({
    this.title,
    this.size,
    this.appearance,
    this.showSlideNumbers,
    this.hideNumberOnTitle,
    this.firstSlideNumber,
    this.footerText,
    this.language,
    this.defaultsJson,
    this.guidesJson,
    this.presentJson,
  });

  final String? title;
  final DeckSizeChange? size;
  final SlideAppearance? appearance;
  final bool? showSlideNumbers;
  final bool? hideNumberOnTitle;
  final int? firstSlideNumber;
  final Patch<String?>? footerText;
  final Patch<String?>? language;
  final Patch<String?>? defaultsJson;
  final Patch<String?>? guidesJson;
  final Patch<String?>? presentJson;

  @override
  String get name => 'SetDeckProps';
}

/// Sets the deck's default theme (`Deck.themeId`) for new slides.
final class SetDeckTheme extends SlidesOperation {
  const SetDeckTheme(this.themeId);

  final String themeId;

  @override
  String get name => 'SetDeckTheme';
}
