part of '../operations.dart';

// Themes, masters and layouts (02 §12.1 "Themes", 05; planner SL-7,
// SL-17, SL-28).

/// Imports a theme tree into the deck: a built-in ([builtInKey]) or a
/// theme package JSON ([packageJson], `ThemePackage.toJson`), with
/// deterministic ids (`SlidesIds.themeCopyId/themePartId`).
final class ImportTheme extends SlidesOperation {
  const ImportTheme({this.builtInKey, this.packageJson, this.sourceKey})
    : assert((builtInKey == null) != (packageJson == null));

  final String? builtInKey;
  final Map<String, Object?>? packageJson;

  /// Provenance for package imports (`deck:<item>:<theme>`).
  final String? sourceKey;

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

/// Updates master/layout columns (`name`, `backgroundJson`, `hidden`, …).
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
