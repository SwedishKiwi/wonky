part of '../operations.dart';

// Themes, masters and layouts (02 §12.1 "Themes", 05; planner SL-7,
// SL-17, SL-28).

/// Imports a theme tree into the deck: a built-in ([builtInKey]), a
/// theme package JSON ([packageJson], `ThemePackage.toJson`) or the rows of
/// a deck theme ([themeEntry]), with deterministic ids
/// (`SlidesIds.themeCopyId/themePartId`).
final class ImportTheme extends SlidesOperation {
  const ImportTheme({
    this.builtInKey,
    this.packageJson,
    this.themeEntry,
    this.sourceKey,
    this.themeName,
  }) : assert(
         (builtInKey != null ? 1 : 0) +
                 (packageJson != null ? 1 : 0) +
                 (themeEntry != null ? 1 : 0) ==
             1,
       );

  final String? builtInKey;
  final Map<String, Object?>? packageJson;

  /// The rows of a theme of a deck (SL-17: *Import theme from a
  /// presentation*, *Duplicate theme*): an entry of a clipboard payload's
  /// `themes` (`SlidesClipboardCodec.themeEntry` — the `deck_theme` columns
  /// plus `masters`, `layouts` and `elements` row lists). Copied with every
  /// row (element groups, images, all columns); with a [sourceKey] the ids
  /// are deterministic (`themeCopyId(deck, sourceKey)`,
  /// `themePartId(theme, sourceRowId)`), so repeated imports merge; without
  /// one the copy gets fresh ids (a duplicate).
  final Map<String, Object?>? themeEntry;

  /// Provenance for package and theme-entry imports
  /// (`deck:<item>:<theme>`, `SlidesIds.deckThemeSourceKey`).
  final String? sourceKey;

  /// The copy's name (null = the source's).
  final String? themeName;

  @override
  String get name => 'ImportTheme';
}

/// Updates theme JSON columns (`colorsJson`, `fontsJson`, …) and/or the
/// name (null = unchanged).
final class UpdateTheme extends SlidesOperation {
  const UpdateTheme(this.themeId, {this.themeName, this.columns = const {}});

  final String themeId;
  final String? themeName;

  /// Theme column → JSON string (validated by `DeckThemeValidator`).
  final Map<String, String?> columns;

  @override
  String get name => 'UpdateTheme';
}

/// Applies a theme to slides; [layoutMapping] maps old layout ids to new
/// ones (`LayoutRemapper`, 05 §5.4; missing = matched by key, else by
/// placeholder signature, `LayoutMatcher`). Empty [slideIds] = every
/// slide. [setDefault] (SL-7 addition) writes `Deck.themeId`; null = when
/// the theme is applied to every slide (05 §9 scope *All*).
final class ApplyThemeToSlides extends SlidesOperation {
  const ApplyThemeToSlides(
    this.themeId,
    this.slideIds, {
    this.layoutMapping = const {},
    this.setDefault,
  });

  final String themeId;
  final List<String> slideIds;
  final Map<String, String> layoutMapping;
  final bool? setDefault;

  @override
  String get name => 'ApplyThemeToSlides';
}

/// Deletes a theme (refused while slides use it, 05).
final class DeleteTheme extends SlidesOperation {
  const DeleteTheme(this.themeId);

  final String themeId;

  @override
  String get name => 'DeleteTheme';
}

/// Adds a master to a theme (columns of `SlideMaster`).
final class AddMaster extends SlidesOperation {
  const AddMaster(this.themeId, {this.masterName, this.duplicateOf});

  final String themeId;
  final String? masterName;
  final String? duplicateOf;

  @override
  String get name => 'AddMaster';
}

/// Adds a layout to a master (optionally duplicating [duplicateOf]).
final class AddLayout extends SlidesOperation {
  const AddLayout(this.masterId, {this.layoutName, this.key, this.duplicateOf});

  final String masterId;
  final String? layoutName;
  final String? key;
  final String? duplicateOf;

  @override
  String get name => 'AddLayout';
}

/// Updates master/layout columns (`name`, `backgroundJson`, `hidden`, …;
/// SL-28: `sortKey` moves a layout among its master's layouts or a master
/// among its theme's masters).
final class UpdateMasterOrLayout extends SlidesOperation {
  const UpdateMasterOrLayout(this.id, this.columns);

  /// A master or layout id.
  final String id;
  final Map<String, Object?> columns;

  @override
  String get name => 'UpdateMasterOrLayout';
}

/// Deletes masters/layouts (slides fall back, 02 §10).
final class DeleteMastersOrLayouts extends SlidesOperation {
  const DeleteMastersOrLayouts(this.ids);

  final List<String> ids;

  @override
  String get name => 'DeleteMastersOrLayouts';
}
