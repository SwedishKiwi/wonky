import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show CommandDisabled, CommandStatus;
import 'package:wonky_drive/config/drive_app_config.dart';

/// Drive's view, settings and Storage commands (Drive 04 §8–9): they act on
/// the shown list, persist per device or in `driveDefaults`, and none of
/// them is undoable (suite 08 §2).
void main() {
  late CommandTestHarness h;
  DriveController? list;

  DriveController openList() => list = DriveController(
    services: h.services,
    location: const DriveLocation.myDrive(),
  );

  setUp(() {
    h = CommandTestHarness(config: const DriveAppConfig());
    h.services.router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (c, s) => const SizedBox()),
        GoRoute(path: '/storage', builder: (c, s) => const SizedBox()),
      ],
    );
  });
  tearDown(() async {
    list?.dispose();
    list = null;
    await h.dispose();
  });

  Object? device(String key) => h.services.prefs.device<Object>(key);
  String location() =>
      h.services.router.routeInformationProvider.value.uri.toString();

  group('Given the Drive home list', () {
    setUp(openList);

    test(
      'when the layout is set then the list switches, the choice is '
      'remembered on this device and nothing lands on the undo stack',
      () async {
        final r = await h.invoke('drive.view.setLayout', {'layout': 'grid'});

        expect(r.data, {'layout': 'grid'});
        expect(list!.layout, DriveLayout.grid);
        expect(device(DriveController.viewLayoutKey), 'grid');
        expect(h.undoLabels, isEmpty);

        await h.invoke('drive.view.setLayout');
        expect(list!.layout, DriveLayout.list);
      },
    );

    test('when sorting by size then the list sorts descending and the sort '
        'is remembered', () async {
      final r = await h.invoke('drive.view.sort', {'field': 'size'});

      expect(r.data, {'field': 'size', 'descending': true});
      expect(list!.sortField, DriveSortField.size);
      expect(device(DriveController.viewSortFieldKey), 'size');
      expect(device(DriveController.viewSortDescendingKey), true);

      await h.invoke('drive.view.sort', {'field': 'name'});
      expect(list!.descending, isFalse);
    });

    test(
      'when sorting by an unknown field then the command is refused',
      () async {
        await expectLater(
          h.invoke('drive.view.sort', {'field': 'createdAt'}),
          throwsA(isA<Exception>()),
        );
        expect(list!.sortField, DriveSortField.modifiedAt);
      },
    );

    test('when Folders on top is toggled then it flips and is checked '
        'accordingly', () async {
      expect(list!.foldersFirst, isTrue);

      final r = await h.invoke('drive.view.toggleFoldersOnTop');

      expect(r.data, {'foldersOnTop': false});
      expect(list!.foldersFirst, isFalse);
      expect(device(DriveController.viewFoldersOnTopKey), false);
    });

    test('when a list default changes in Drive settings then the device '
        'choice is replaced and the list follows', () async {
      await h.invoke('drive.view.setLayout', {'layout': 'grid'});
      await h.invoke('drive.view.sort', {'field': 'name'});

      await h.invoke('drive.prefs.set', {'key': 'layout', 'value': 'list'});
      await h.invoke('drive.prefs.set', {'key': 'sortField', 'value': 'size'});

      expect(h.services.prefs.driveDefaults['layout'], 'list');
      expect(device(DriveController.viewLayoutKey), isNull);
      expect(list!.layout, DriveLayout.list);
      expect(list!.sortField, DriveSortField.size);
      expect(list!.descending, isTrue);
      expect(h.undoLabels, isEmpty);
    });
  });

  group('Given Drive settings', () {
    test(
      'when a new list opens then it starts with the Drive defaults',
      () async {
        await h.invoke('drive.prefs.set', {'key': 'layout', 'value': 'grid'});
        await h.invoke('drive.prefs.set', {
          'key': 'sortField',
          'value': 'name',
        });
        await h.invoke('drive.prefs.set', {
          'key': 'foldersOnTop',
          'value': false,
        });

        final c = openList();

        expect(c.layout, DriveLayout.grid);
        expect(c.sortField, DriveSortField.name);
        expect(c.descending, isFalse);
        expect(c.foldersFirst, isFalse);
      },
    );

    test('when an unknown key or a wrong value is set then the command '
        'fails and nothing changes', () async {
      await expectLater(
        h.invoke('drive.prefs.set', {'key': 'theme', 'value': 'dark'}),
        throwsA(isA<Exception>()),
      );
      final wrong = await h.invoke('drive.prefs.set', {
        'key': 'layout',
        'value': 'tiles',
      });

      expect(wrong.status, CommandStatus.failed);
      expect(h.services.prefs.driveDefaults, isEmpty);
    });

    test('when file extensions are hidden then lists show file names '
        'without them, other kinds unchanged', () async {
      const config = DriveAppConfig();
      final pdf = h.drive.seed(name: 'notes.pdf', kind: DriveItemKind.file);
      final tar = h.drive.seed(name: 'site.tar.gz', kind: DriveItemKind.file);
      final dot = h.drive.seed(name: '.env', kind: DriveItemKind.file);
      final doc = h.drive.seed(name: 'v1.2 plan');

      expect(config.listItemName(h.services, pdf), 'notes.pdf');

      await h.invoke('drive.prefs.set', {
        'key': 'showExtensions',
        'value': false,
      });

      expect(config.listItemName(h.services, pdf), 'notes');
      expect(config.listItemName(h.services, tar), 'site');
      expect(config.listItemName(h.services, dot), '.env');
      expect(config.listItemName(h.services, doc), 'v1.2 plan');
    });

    test('when name conflicts and converting are switched then the upload '
        'settings are stored', () async {
      await h.invoke('drive.prefs.set', {
        'key': 'askOnNameConflict',
        'value': false,
      });
      await h.invoke('drive.prefs.set', {
        'key': 'convertUploads',
        'value': true,
      });

      expect(h.services.prefs.driveDefaults, {
        'askOnNameConflict': false,
        'convertUploads': true,
      });
      expect(
        (await h.users.getPreferences()).driveDefaults,
        contains('"convertUploads":true'),
      );
    });
  });

  group('Given no list is shown', () {
    test('when a view command runs then it is disabled', () async {
      await expectLater(
        h.invoke('drive.view.setLayout', {'layout': 'grid'}),
        throwsA(isA<CommandDisabled>()),
      );
    });
  });

  test('Given the Storage page command when it runs with a filter then the '
      'page opens filtered; unknown filters fail', () async {
    final r = await h.invoke('drive.storage.show', {'filter': 'large'});
    expect(r.data, {'filter': 'large'});
    expect(location(), '/storage?filter=large');

    await h.invoke('drive.storage.show');
    expect(location(), '/storage');

    await expectLater(
      h.invoke('drive.storage.show', {'filter': 'huge'}),
      throwsA(isA<Exception>()),
    );
  });
}
