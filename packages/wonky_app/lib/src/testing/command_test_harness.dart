import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../auth/auth_controller.dart';
import '../bootstrap/app_urls.dart';
import '../commands/command.dart';
import '../commands/shell_commands/general_commands.dart';
import '../config/wonky_app_config.dart';
import '../core/connectivity_service.dart';
import '../core/local_store.dart';
import '../data/collab_repositories.dart';
import '../data/file_repository.dart';
import '../data/sharing_repository.dart';
import '../shell/shell_services.dart';
import '../undo/undo_service.dart';
import 'fake_repositories.dart';

/// A minimal [WonkyAppConfig] for tests (a Write-like app whose editor is an
/// empty box).
class TestAppConfig extends WonkyAppConfig {
  const TestAppConfig({
    this.app = WonkyAppKind.write,
    this.extraCommands = const [],
  });

  @override
  final WonkyAppKind app;

  /// Returned by [commands] (registered next to the shell's).
  final List<Command<CommandArgs>> extraCommands;

  @override
  String get appName => 'Wonky Test';

  @override
  DriveItemKind get primaryKind => app == WonkyAppKind.write
      ? DriveItemKind.document
      : DriveItemKind.spreadsheet;

  @override
  Color get brandColor => const Color(0xff2563eb);

  @override
  Widget logo({double size = 28}) => SizedBox.square(dimension: size);

  @override
  String itemPath(String uuid) =>
      app == WonkyAppKind.write ? '/d/$uuid' : '/s/$uuid';

  @override
  Widget buildEditor(BuildContext context, GoRouterState state, String uuid) =>
      const SizedBox.shrink();

  @override
  List<Command<CommandArgs>> commands(ShellServices services) => extraCommands;

  @override
  String untitledName(BuildContext context) => 'Untitled';
}

/// Runs commands through the real [ShellServices], registry, dispatcher and
/// [UndoService] against in-memory fakes, without widgets (suite 15 §5,
/// 08 §4):
///
/// ```dart
/// final h = CommandTestHarness();
/// final doc = h.drive.seed(name: 'Plan');
/// await h.invoke('shell.drive.rename', {'uuid': doc.uuid.uuid, 'name': 'Q3'});
/// await h.undo();
/// expect(h.drive.item(doc.uuid).name, 'Plan');
/// ```
///
/// Commands that need a dialog get `CommandResult.cancelled` (there is no
/// navigator); pass every argument instead, as MCP does.
class CommandTestHarness {
  CommandTestHarness({
    WonkyAppConfig config = const TestAppConfig(),
    FakeDriveRepository? drive,
    FakeUserRepository? users,
    FakeAuthRepository? auth,
    SharingRepository? sharing,
    CommentRepository? comments,
    NotificationRepository? notifications,
    PresenceRepository? presence,
    VersionRepository? versions,
    FileRepository? files,
    MetaRepository? meta,
    ActivityRepository? activity,
    LocalStore? store,
    UuidV7Generator? ids,
    bool registerShellCommands = true,
  }) : drive = drive ?? FakeDriveRepository(ids: ids),
       users = users ?? FakeUserRepository(),
       authRepository = auth ?? FakeAuthRepository() {
    TestWidgetsFlutterBinding.ensureInitialized();
    services = ShellServices(
      config: config,
      auth: AuthController(authRepository),
      repositories: ShellRepositories(
        drive: this.drive,
        users: this.users,
        sharing: sharing ?? UnfakedSharingRepository(),
        comments: comments ?? UnfakedCommentRepository(),
        notifications: notifications ?? UnfakedNotificationRepository(),
        presence: presence ?? UnfakedPresenceRepository(),
        versions: versions ?? UnfakedVersionRepository(),
        files: files ?? UnfakedFileRepository(),
        meta: meta ?? UnfakedMetaRepository(),
        activity: activity,
      ),
      urls: const AppUrls(
        apiUrl: 'http://localhost:8080/',
        apps: {
          WonkyAppKind.write: 'http://localhost:8101/',
          WonkyAppKind.sheets: 'http://localhost:8102/',
        },
      ),
      connectivity: ConnectivityService(ping: () async {}),
      deviceStore: store ?? MemoryStore(),
      ids: ids,
    );
    services.currentUser.value = this.users.profile;
    if (registerShellCommands) {
      services.registry.registerAll(allShellCommands(services));
    }
    services.registry.registerAll(config.commands(services));
  }

  late final ShellServices services;
  final FakeDriveRepository drive;
  final FakeUserRepository users;
  final FakeAuthRepository authRepository;

  UndoService get undoService => services.undo;

  /// Invokes [id] with JSON [args] through the dispatcher (schema
  /// validation, role and enabled checks, undo transaction).
  Future<CommandResult> invoke(
    String id, [
    Map<String, Object?> args = const {},
    InvocationSource source = InvocationSource.mcp,
  ]) => services.dispatcher.invoke(id, args: args, source: source);

  Future<UndoOutcome?> undo() => services.undo.undo();

  Future<UndoOutcome?> redo() => services.undo.redo();

  /// Labels of the undoable steps of the active context, newest first.
  List<String> get undoLabels => [
    for (final h in services.undo.history()) h.step.label,
  ];

  Future<void> dispose() async {
    services.dispose();
    await drive.dispose();
  }
}
