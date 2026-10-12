import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../bootstrap/app_urls.dart';
import '../commands/command.dart';
import '../menus/shell_menus.dart';
import '../shell/shell_services.dart';
import '../versions/version_renderer.dart';

/// A file an app can import (drag-and-drop or "Upload file…").
class ImportFile {
  const ImportFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final List<int> bytes;
  final String? mimeType;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// App hook for uploads/imports from the drive (suite 05 §3.1).
abstract class ImportHandler {
  /// Lower-case extensions this app imports (`md`, `docx`, `xlsx`, …).
  Set<String> get extensions;

  /// Shows the platform file picker; returns the picked files (empty when
  /// cancelled).
  Future<List<ImportFile>> pickFiles(BuildContext context);

  /// Imports [files] into [parentUuid]; shows options dialogs as needed and
  /// returns the created items.
  Future<List<DriveItemView>> importFiles(
    BuildContext context,
    ShellServices services,
    List<ImportFile> files, {
    UuidValue? parentUuid,
  });
}

/// A side panel the app contributes to the editor's panel host.
typedef PanelBuilder = SidePanelSpec Function(BuildContext context, ShellServices services);

/// Describes one app to the shared shell (suite 03): `WonkyShell(config:
/// WriteAppConfig())`.
abstract class WonkyAppConfig {
  const WonkyAppConfig();

  /// Which app this is.
  WonkyAppKind get app;

  /// "Wonky Write" / "Wonky Sheets" (product name, not localized).
  String get appName;

  /// The kind of file this app edits.
  DriveItemKind get primaryKind;

  /// Brand color (logo tile, accents).
  Color get brandColor;

  /// The app logo (title row, top bar, auth screens).
  Widget logo({double size = 28});

  /// Path of the editor route for [uuid] (`/d/<uuid>` or `/s/<uuid>`).
  String itemPath(String uuid);

  /// Builds the editor screen for `itemPath` routes. The screen should use
  /// `EditorScaffold` and wrap its controller in a `DocumentScope`.
  Widget buildEditor(BuildContext context, GoRouterState state, String uuid);

  /// Extra app routes (`/d/:uuid/history`, `/themes`, `/s/:uuid/script` …),
  /// relative to the app's base href.
  List<RouteBase> routes(ShellServices services) => const [];

  /// App commands (registered at start-up; shell ids are reserved).
  List<Command<CommandArgs>> commands(ShellServices services) => const [];

  /// The app's menubar: extend [shell]'s shared menus (File, Edit, View,
  /// Tools, Help) with app menus and items.
  MenuRoot menus(BuildContext context, ShellMenus shell) => shell.root;

  /// Builders for `MenuSpec.custom` items, by id.
  Map<String, Widget Function(BuildContext context, VoidCallback close)> customMenuItems(
    ShellServices services,
  ) => const {};

  /// App side panels (Outline, Named ranges, …). Shell panels (comments,
  /// history, details) are added by the shell.
  List<PanelBuilder> panels() => const [];

  /// Localization delegates of the app.
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [];

  /// Renders versions in the full-screen history route.
  VersionRenderer? get versionRenderer => null;

  /// Upload/import support on the home screen.
  ImportHandler? get importHandler => null;

  /// Creates a new item of the primary kind (Sheets creates the spreadsheet
  /// locally in a reserved space, offline-first). Returns its uuid. The
  /// default calls `drive.createDocument` / `drive.createSpreadsheet`.
  Future<UuidValue?> createItem(
    ShellServices services, {
    UuidValue? parentUuid,
    UuidValue? templateUuid,
    String? name,
  }) => services.createItemOnServer(
    primaryKind,
    parentUuid: parentUuid,
    templateUuid: templateUuid,
    name: name,
  );

  /// Default name of new items ("Untitled document").
  String untitledName(BuildContext context);

  /// Wraps the app (extra providers). Called inside the shell providers.
  Widget wrap(BuildContext context, ShellServices services, Widget child) => child;

  /// Called after sign-in (start sync, …) and before sign-out (stop sync).
  Future<void> onSignedIn(ShellServices services) async {}
  Future<void> onSigningOut(ShellServices services) async {}

  /// Settings sections the app adds after the shared ones.
  List<SettingsSectionSpec> settingsSections(ShellServices services) => const [];
}

/// An extra settings section.
class SettingsSectionSpec {
  const SettingsSectionSpec({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String Function(BuildContext context) title;
  final IconData icon;
  final WidgetBuilder builder;
}
