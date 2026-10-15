import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/clipboard.dart' show SlidesClipboardCodec;
import 'package:wonky_slides_core/model.dart' show DeckModelIndexes;

import '../../platform/users/user_service.dart';
import '../headless/headless_deck.dart';

/// *Import theme from a presentation…* (Slides 05 §9, SL-17,
/// `slidesThemes`): the themes of another deck the caller can view, so the
/// client can copy one into the open deck (`ImportTheme.themeEntry`).
class SlidesThemesEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// The themes of presentation [itemUuid] (viewer+) as JSON:
  /// `{"v": 1, "sourceItemUuid", "defaultThemeId", "themes": [entry…]}`,
  /// each entry the theme's rows (`SlidesClipboardCodec.themeEntry`: the
  /// `deck_theme` columns plus `masters`, `layouts`, `elements`) with
  /// `usedBy` (slides using it). Errors: notFound, forbidden.
  Future<String> list(Session session, UuidValue itemUuid) async {
    final deck = await const SlidesHeadlessProvider().open(
      HeadlessDeckContext(session, await UserService.actorOf(session)),
      itemUuid.uuid,
    );
    final model = deck.model;
    final themes = model.indexes.themes;
    return jsonEncode({
      'v': 1,
      'sourceItemUuid': itemUuid.uuid,
      'defaultThemeId': themes.defaultTheme?.id,
      'themes': [
        for (final t in model.themes)
          {
            ...SlidesClipboardCodec.themeEntry(model, t),
            'usedBy': themes.slidesUsingTheme(t.id),
          },
      ],
    });
  }
}
