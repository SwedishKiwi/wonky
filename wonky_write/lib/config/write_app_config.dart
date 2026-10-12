import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../commands/screen_commands.dart';
import '../features/document/write_collab_commands.dart';
import '../features/history/write_version_renderer.dart';
import '../features/import/import_service.dart';
import '../features/print/print_preview_screen.dart';
import '../features/screen/write_document_screen.dart';
import '../features/themes/document_theme.dart';
import 'write_menus.dart';

/// Brand color of Wonky Write.
const writeBrandColor = Color(0xff2563eb);

/// Wonky Write's description for the shared shell (suite 03, Write 05).
class WriteAppConfig extends WonkyAppConfig {
  const WriteAppConfig();

  @override
  WonkyAppKind get app => WonkyAppKind.write;

  @override
  String get appName => 'Wonky Write';

  @override
  DriveItemKind get primaryKind => DriveItemKind.document;

  @override
  Color get brandColor => writeBrandColor;

  @override
  Widget logo({double size = 28}) => WonkyAppLogo(
    color: writeBrandColor,
    icon: LucideIcons.fileText,
    size: size,
  );

  @override
  String itemPath(String uuid) => '/d/$uuid';

  @override
  String untitledName(BuildContext context) => 'Untitled document';

  @override
  Widget buildEditor(BuildContext context, GoRouterState state, String uuid) {
    final services = ShellScope.of(context);
    return WriteDocumentScreen(
      key: ValueKey<String>('write.editor.$uuid'),
      services: services,
      itemUuid: uuid,
      themes: themeCatalogFor(services),
      heading: state.uri.queryParameters['heading'],
    );
  }

  @override
  List<RouteBase> routes(ShellServices services) => [
    GoRoute(
      path: '/d/:uuid/print',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: PrintPreviewScreen(
          key: ValueKey<String>('write.print.${state.pathParameters['uuid']}'),
          services: services,
          itemUuid: state.pathParameters['uuid']!,
          themes: themeCatalogFor(services),
        ),
      ),
    ),
  ];

  @override
  List<Command<CommandArgs>> commands(ShellServices services) => [
    ...writeCommands(services, themeCatalogFor(services)),
    ...writeCollabCommands(services),
  ];

  @override
  MenuRoot menus(BuildContext context, ShellMenus shell) => writeMenus(shell);

  @override
  Map<String, Widget Function(BuildContext context, VoidCallback close)>
  customMenuItems(ShellServices services) => {
    WriteMenuIds.tablePicker: (context, close) => Padding(
      padding: const EdgeInsets.all(8),
      child: WonkyTableSizePicker(
        key: const ValueKey<String>('menu.insert.tablePicker'),
        onSelected: (rows, cols) {
          close();
          services.dispatcher.invoke(
            'write.insert.table',
            args: {'rows': rows, 'cols': cols},
            source: InvocationSource.menu,
            context: context,
          );
        },
      ),
    ),
  };

  @override
  VersionRenderer? get versionRenderer => _versions;

  static final _versions = WriteVersionRenderer();

  @override
  ImportHandler? get importHandler => const WriteImportHandler();
}

/// The app logo: a rounded tile in the brand color with a white glyph.
class WonkyAppLogo extends StatelessWidget {
  const WonkyAppLogo({
    super.key,
    required this.color,
    required this.icon,
    this.size = 28,
  });

  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Wonky Write',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, const Color(0xffffffff), 0.12)!, color],
        ),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Icon(icon, size: size * 0.56, color: const Color(0xffffffff)),
    ),
  );
}
