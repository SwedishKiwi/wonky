import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../schema/slides_schema.dart';
import '../theme/builtins/theme_package.dart';

/// A row `(table, columns)`.
typedef SlidesRow = (String table, Map<String, Object?> columns);

/// The ids of a theme copied into a deck.
final class ThemeCopyIds {
  /// Creates the ids.
  const ThemeCopyIds(this.themeId, this.masterId, this.layoutIds);

  /// The `deck_theme` row.
  final String themeId;

  /// The first master.
  final String masterId;

  /// Layout ids by layout key (`title`, `titleBody`, …).
  final Map<String, String> layoutIds;
}

/// Every `slide_element` column with its default (02 §3.5), owners unset.
Map<String, Object?> elementDefaults() => {
  for (final c in SlidesTables.columns[SlidesTables.slideElement]!) c: null,
  ElementCols.flipH: false,
  ElementCols.flipV: false,
  ElementCols.locked: false,
  SlidesCols.hidden: false,
  ElementCols.decorative: false,
};

/// Copies of a theme package into a deck (02 §2.1, §9.3; 05 §9): the
/// theme row, masters, layouts and their elements with the deterministic
/// ids `SlidesIds.themeCopyId(deck, sourceKey)` /
/// `SlidesIds.themePartId(theme, partKey)`, so two devices copying the same
/// theme offline write the same rows. Match keys of copied theme elements
/// are derived from their ids (deterministic too).
abstract final class ThemeCopy {
  /// The match key of a copied theme element (the base-62 form of its id).
  static String partMatchKey(String elementId) => Base62Uuid.encode(elementId);

  /// The rows of [pkg] copied into deck [deckId].
  ///
  /// The theme id is `SlidesIds.themeCopyId(deckId, sourceKey)`, or
  /// [themeId] when given (a theme created in this deck without
  /// provenance). [matchKeyOf] overrides the match keys (fixtures).
  static (List<SlidesRow>, ThemeCopyIds) packageRows(
    ThemePackage pkg, {
    required String deckId,
    required String? sourceKey,
    required DateTime now,
    String? themeId,
    String? sortKey,
    String Function(String elementId)? matchKeyOf,
  }) {
    final tid =
        themeId ??
        SlidesIds.themeCopyId(
          deckId,
          sourceKey ??
              (throw ArgumentError('sourceKey or themeId is required')),
        );
    String part(String key) => SlidesIds.themePartId(tid, key);
    final matchKey = matchKeyOf ?? partMatchKey;
    final rows = <SlidesRow>[
      (
        SlidesTables.deckTheme,
        {
          SlidesCols.id: tid,
          DeckThemeCols.deckId: deckId,
          ...pkg.theme.toColumns(),
          DeckThemeCols.sourceKey: sourceKey,
          SlidesCols.sortKey: sortKey ?? FractionalIndex.first(),
          SlidesCols.createdAt: now,
        },
      ),
    ];
    final layoutIds = <String, String>{};
    String? masterKey;
    String? firstMaster;
    for (final m in pkg.masters) {
      final masterId = part(m.partKey);
      firstMaster ??= masterId;
      masterKey = FractionalIndex.after(masterKey);
      rows.add((
        SlidesTables.slideMaster,
        {
          SlidesCols.id: masterId,
          SlideMasterCols.themeId: tid,
          SlidesCols.name: m.name,
          SlidesCols.sortKey: masterKey,
          SlidesCols.backgroundJson: m.background == null
              ? null
              : jsonEncode(m.background!.toJson()),
          SlidesCols.createdAt: now,
        },
      ));
      rows.addAll(
        _elements(
          m.elements,
          ElementCols.masterId,
          masterId,
          part,
          matchKey,
          now,
        ),
      );
      String? layoutKey;
      for (final l in m.layouts) {
        final layoutId = part(l.partKey);
        if (l.key != null) layoutIds.putIfAbsent(l.key!, () => layoutId);
        layoutKey = FractionalIndex.after(layoutKey);
        rows.add((
          SlidesTables.slideLayout,
          {
            SlidesCols.id: layoutId,
            SlideLayoutCols.masterId: masterId,
            SlidesCols.name: l.name,
            SlideLayoutCols.key: l.key,
            SlidesCols.sortKey: layoutKey,
            SlidesCols.backgroundJson: l.background == null
                ? null
                : jsonEncode(l.background!.toJson()),
            SlidesCols.hideMasterElements: l.hideMasterElements,
            SlidesCols.hidden: l.hidden,
            SlidesCols.createdAt: now,
          },
        ));
        rows.addAll(
          _elements(
            l.elements,
            ElementCols.layoutId,
            layoutId,
            part,
            matchKey,
            now,
          ),
        );
      }
    }
    return (rows, ThemeCopyIds(tid, firstMaster ?? '', layoutIds));
  }

  static List<SlidesRow> _elements(
    List<ThemeElementSpec> elements,
    String ownerColumn,
    String ownerId,
    String Function(String) part,
    String Function(String) matchKey,
    DateTime now,
  ) {
    final out = <SlidesRow>[];
    String? z;
    for (final e in elements) {
      z = FractionalIndex.after(z);
      final c = e.toColumns();
      final placeholderOfPart = c.remove('placeholderOfPart') as String?;
      final id = part(e.partKey);
      out.add((
        SlidesTables.slideElement,
        {
          ...elementDefaults(),
          ...c,
          SlidesCols.id: id,
          ownerColumn: ownerId,
          ElementCols.placeholderOf: placeholderOfPart == null
              ? null
              : part(placeholderOfPart),
          ElementCols.zKey: z,
          ElementCols.matchKey: matchKey(id),
          SlidesCols.createdAt: now,
        },
      ));
    }
    return out;
  }
}
