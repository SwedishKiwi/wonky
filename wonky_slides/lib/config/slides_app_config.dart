import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart';

import '../commands/commands.dart';
import '../features/editor_screen/deck_editor_screen.dart';
import '../features/editor_screen/route_placeholders.dart';
import '../features/settings/slides_settings.dart';
import '../features/sync/slides_data.dart'
    show NoReservedSpaceException, SlidesData;
import '../l10n/slides_l10n.dart';
import 'menus/slides_menu_spec.dart';

/// Brand color of Wonky Slides (the amber of its product icon and of the
/// presentation kind, `kindColor`).
const slidesBrandColor = Color(0xffd97706);

/// Wonky Slides' description for the shared shell (suite 03, Slides 01 §7,
/// Slides 12 SL-1).
///
/// The home is the shell's app home scoped to presentations
/// (`HomeScope.kind(presentation)`: Recent, My files, Shared, Starred,
/// Offline, Trash; only folders that contain a presentation; Slides 04
/// §15). The deck editor at `/p/:uuid` is the `DeckEditorScreen` (04 §2,
/// SL-11) with the child routes `present`, `print` and `history`; the
/// commands, menus and Slides settings are registered here.
/// Presentations are created offline-first in reserved deck spaces by the
/// data layer installed at sign-in ([SlidesData], SL-9).
class SlidesAppConfig extends WonkyAppConfig {
  const SlidesAppConfig();

  @override
  WonkyAppKind get app => WonkyAppKind.slides;

  @override
  String get appName => 'Wonky Slides';

  @override
  DriveItemKind get primaryKind => DriveItemKind.presentation;

  @override
  Color get brandColor => slidesBrandColor;

  @override
  Widget logo({double size = 28}) =>
      WonkyProductIcon(WonkyProduct.slides, size: size);

  @override
  String itemPath(String uuid) => '/p/$uuid';

  @override
  HomeScope? get homeScope => const HomeScope.kind(DriveItemKind.presentation);

  /// The deck editor (Slides 04 §2); `?slide=<slideId>` opens that slide.
  @override
  Widget buildEditor(BuildContext context, GoRouterState state, String uuid) =>
      DeckEditorScreen(
        key: ValueKey<String>('slides.deck.$uuid'),
        services: ShellScope.of(context),
        itemUuid: uuid,
        initialSlideId: state.uri.queryParameters['slide'],
      );

  /// `/p/:uuid/present`, `/p/:uuid/print` and `/p/:uuid/history` (04 §1)
  /// under the editor route, so the deck session stays open underneath.
  /// SL-19 (present), SL-20 (print) and SL-39 (history) replace the
  /// placeholders.
  @override
  List<RouteBase> editorRoutes(ShellServices services) => [
    for (final route in DeckChildRoute.values)
      GoRoute(
        path: route.name,
        pageBuilder: (c, st) => NoTransitionPage<void>(
          key: st.pageKey,
          child: DeckRoutePlaceholder(
            key: ValueKey<String>(
              'slides.${route.name}.${st.pathParameters['uuid']}',
            ),
            services: services,
            itemUuid: st.pathParameters['uuid']!,
            route: route,
          ),
        ),
      ),
  ];

  /// Every `slides.*` command (`commands/commands.dart`).
  @override
  List<Command<CommandArgs>> commands(ShellServices services) =>
      slidesCommands(services);

  /// The Slides menubar (04 §4).
  @override
  MenuRoot menus(BuildContext context, ShellMenus shell) =>
      slidesMenus(shell, l: slidesL10n(context));

  /// Slides settings (04 §13.16): `/settings/app/<section>`.
  @override
  List<SettingsSectionSpec> appSettingsSections(ShellServices services) =>
      slidesSettingsSections(services);

  /// `ui.slides.*` MCP UI-bridge tools come with SL-42 (Slides 11); the
  /// shared `ui.*` tools (menu tree, commands, dialogs, state with the
  /// editor's `describeState`) already cover the chrome.
  @override
  Map<String, UiToolHandler> mcpUiTools(ShellServices services) => const {};

  /// The Slides data layer follows the signed-in user (Slides 02 §9): the
  /// replica `slides_<userId>.db` and its sync controller (SL-9).
  @override
  Future<void> onSignedIn(ShellServices services) async {
    await super.onSignedIn(services);
    SlidesData.install(services);
  }

  @override
  Future<void> onSigningOut(ShellServices services) async {
    await SlidesData.uninstall(services);
    await super.onSigningOut(services);
  }

  /// *New presentation*, the home's *+ New* and `/new` (Drive's *New*
  /// menu): offline-first creation in a reserved deck space plus the queued
  /// `drive.registerPresentation` (Slides 02 §9.3; templates and devices
  /// without a reservation create on the server). Offline before this
  /// device reserved its first spaces, a toast says so and nothing is
  /// created (null makes `/new` go back).
  @override
  Future<UuidValue?> createItem(
    ShellServices services, {
    UuidValue? parentUuid,
    UuidValue? templateUuid,
    String? name,
  }) async {
    try {
      return await SlidesData.createPresentation(
        services,
        parentUuid: parentUuid,
        templateUuid: templateUuid,
        name: name,
      );
    } on NoReservedSpaceException {
      final l = slidesL10nOf(services);
      services.toasts.show(
        l.createNeedsConnectionTitle,
        description: l.createNeedsConnectionBody,
      );
      return null;
    }
  }

  @override
  String untitledName(BuildContext context) =>
      slidesL10n(context).untitledPresentation;

  @override
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
    SlidesLocalizations.delegate,
  ];
}
