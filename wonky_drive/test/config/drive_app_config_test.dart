import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_drive/config/drive_app_config.dart';
import 'package:wonky_core/wonky_core.dart' show UiDriveTools;
import 'package:wonky_drive/features/storage/storage_controller.dart';
import 'package:wonky_drive/l10n/drive_l10n.dart';
import 'package:wonky_ui/wonky_ui.dart';

void main() {
  const config = DriveAppConfig();

  group('Given the Wonky Drive app config', () {
    test('when read then it is the Drive app with no editor of its own', () {
      expect(config.app, WonkyAppKind.drive);
      expect(config.appName, 'Wonky Drive');
      expect(config.shortAppName, 'Drive');
      expect(config.primaryKind, isNull);
      expect(config.newItemRoute, isNull);
      expect(config.importRoute, isNull);
    });

    test('when read then its home lists every kind with the Drive menu', () {
      final scope = config.homeScope!;

      expect(scope.isAll, isTrue);
      expect(scope.lists(DriveItemKind.document), isTrue);
      expect(scope.lists(DriveItemKind.spreadsheet), isTrue);
      expect(scope.lists(DriveItemKind.presentation), isTrue);
      expect(scope.lists(DriveItemKind.file), isTrue);
      expect(config.homeNav, HomeNavSpec.drive);
    });

    test('when asked for an item path then files live under /file/', () {
      expect(config.itemPath('abc'), '/file/abc');
      expect(
        config.itemPath('abc'),
        WonkyAppKind.itemPathFor(DriveItemKind.file, 'abc'),
      );
    });

    test('when read then it registers the Drive commands and the ui.drive '
        'tools', () {
      final h = CommandTestHarness(config: config);
      addTearDown(h.dispose);
      final ids = {for (final c in config.commands(h.services)) c.id.value};

      expect(
        ids,
        containsAll([
          'drive.view.setLayout',
          'drive.view.sort',
          'drive.view.toggleFoldersOnTop',
          'drive.prefs.set',
          'drive.storage.show',
          'drive.file.preview',
          'drive.upload.files',
        ]),
      );
      expect(config.mcpUiTools(h.services).keys.toSet(), {
        for (final d in UiDriveTools.all) d.name,
      });
    });

    test('when creating an item then nothing is created', () async {
      final h = CommandTestHarness(config: config);
      addTearDown(h.dispose);

      expect(await config.createItem(h.services), isNull);
    });
  });

  group('Given the Storage page route', () {
    late CommandTestHarness h;

    setUp(() => h = CommandTestHarness(config: config));
    tearDown(() => h.dispose());

    Future<void> pumpAt(WidgetTester tester, String location) async {
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(path: '/', builder: (c, s) => const Text('home')),
          ...config.routes(h.services),
        ],
      );
      h.services.router = router;
      await tester.pumpWidget(
        ShadApp.router(
          theme: WonkyTheme.light(),
          routerConfig: router,
          localizationsDelegates: [
            WonkyAppLocalizations.delegate,
            WonkyUiLocalizations.delegate,
            ...config.localizationsDelegates,
          ],
          builder: (context, child) =>
              Material(type: MaterialType.transparency, child: child),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('when opened then it shows the Storage page in the home '
        'frame', (tester) async {
      await pumpAt(tester, '/storage');

      expect(
        find.byKey(const ValueKey<String>('storage.page')),
        findsOneWidget,
      );
      expect(find.text(driveL10nEnglish.storageTitle), findsWidgets);
      expect(StorageHost.of(h.services).page.value?.filter, StorageFilter.all);
    });

    testWidgets('when opened with a filter then the table is filtered', (
      tester,
    ) async {
      await pumpAt(tester, '/storage?filter=notOpened');

      expect(
        StorageHost.of(h.services).page.value?.filter,
        StorageFilter.notOpened,
      );
    });
  });
}
