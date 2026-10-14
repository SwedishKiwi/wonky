import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

class _CountingVersions implements VersionRepository {
  int lists = 0;

  @override
  Future<List<ItemVersionView>> list(
    UuidValue itemUuid, {
    bool namedOnly = false,
  }) async {
    lists++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _CountingVersions versions;
  late CommandTestHarness h;

  setUp(() {
    versions = _CountingVersions();
    h = CommandTestHarness(versions: versions);
  });

  group('Given an open versions list', () {
    test('when this client names or restores a version then the list '
        'reloads', () async {
      final c = VersionsController(
        h.services,
        UuidValue.fromString('01a13917-7cd7-7a32-9df1-314510d8c41d'),
      );
      await c.load();
      expect(versions.lists, 1);

      h.services.refreshVersions();
      await pumpEventQueue();

      expect(versions.lists, 2);
    });

    test('when the list is disposed then a refresh no longer loads', () async {
      final c = VersionsController(
        h.services,
        UuidValue.fromString('01a13917-7cd7-7a32-9df1-314510d8c41d'),
      );
      await c.load();
      c.dispose();

      h.services.refreshVersions();
      await pumpEventQueue();

      expect(versions.lists, 1);
    });
  });
}
