import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_drive/features/storage/storage_controller.dart';

import '../../support/storage_fakes.dart';

/// The Storage page's state (Drive 03 §6.4): filters, keyset paging, the
/// *Free up space* counts, selection published to the shell and live
/// reloads.
void main() {
  late StorageTestbed t;
  late StoragePageController c;

  StoragePageController open({
    StorageFilter filter = StorageFilter.all,
    int pageSize = 50,
  }) => c = StoragePageController(
    services: t.services,
    filter: filter,
    pageSize: pageSize,
    debounce: Duration.zero,
  );

  List<String> names() => [for (final i in c.items) i.name];

  setUp(() => t = StorageTestbed());
  tearDown(() async {
    c.dispose();
    await t.dispose();
  });

  group('Given owned items of several kinds and sizes', () {
    setUp(() {
      final team = t.seed('Team', kind: DriveItemKind.folder);
      t.seed('interview.m4a', bytes: 18 * mb, category: FileCategory.audio);
      t.seed('Sales', kind: DriveItemKind.spreadsheet, bytes: 6 * mb);
      t.seed('old-scan.pdf', bytes: 4 * mb, trashed: true);
      t.seed(
        'Notes',
        kind: DriveItemKind.document,
        bytes: 300 * kb,
        parent: team.uuid,
      );
      t.seed('tiny.txt', bytes: 2 * kb);
    });

    test('when the page loads then items are listed by counted size and '
        'folders are left out', () async {
      open();
      await c.reload();

      expect(names(), [
        'interview.m4a',
        'Sales',
        'old-scan.pdf',
        'Notes',
        'tiny.txt',
      ]);
      expect(c.loading, isFalse);
    });

    test(
      'when filtered by type or trash then only those rows are listed',
      () async {
        open(filter: StorageFilter.spreadsheets);
        await c.reload();
        expect(names(), ['Sales']);

        c.setFilter(StorageFilter.trash);
        await pumpEventQueue();
        expect(names(), ['old-scan.pdf']);

        c.setFilter(StorageFilter.files);
        await pumpEventQueue();
        expect(names(), ['interview.m4a', 'old-scan.pdf', 'tiny.txt']);
      },
    );

    test('when the page loads then the Large files card counts items of '
        '1 MB or more', () async {
      open();
      await c.reload();
      await pumpEventQueue();

      expect(c.large?.count, 3);
      expect(c.large?.bytes, 28 * mb);
      expect(c.large?.more, isFalse);
    });

    test('when there are more rows than a page then loadMore continues at '
        'the cursor', () async {
      open(pageSize: 2);
      await c.reload();
      expect(names(), ['interview.m4a', 'Sales']);
      expect(c.hasMore, isTrue);

      await c.loadMore();
      await c.loadMore();

      expect(names(), [
        'interview.m4a',
        'Sales',
        'old-scan.pdf',
        'Notes',
        'tiny.txt',
      ]);
      expect(c.hasMore, isFalse);
      expect(t.api.requests.last.$2, '4');
    });

    test(
      'when a row is in a folder then its location name is loaded',
      () async {
        open();
        await c.reload();
        await pumpEventQueue();

        final notes = c.items.firstWhere((i) => i.name == 'Notes');
        expect(c.folderName(notes.parentUuid!), 'Team');
      },
    );
  });

  group('Given items nobody opened for a long time', () {
    final old = storageNow.subtract(const Duration(days: 400));
    setUp(() {
      t.seed('archive.zip', bytes: 2 * mb, createdAt: old);
      t.seed(
        'opened-recently.pdf',
        bytes: 2 * mb,
        createdAt: old,
        lastOpenedAt: storageNow.subtract(const Duration(days: 3)),
      );
      t.seed(
        'opened-long-ago.pdf',
        bytes: mb,
        createdAt: old,
        lastOpenedAt: storageNow.subtract(const Duration(days: 200)),
      );
      t.seed(
        'new-upload.mov',
        bytes: 3 * mb,
        createdAt: storageNow.subtract(const Duration(days: 1)),
      );
      t.seed('small-old.txt', bytes: 10 * kb, createdAt: old);
    });

    test(
      'when filtering Not opened in 6 months then items of 256 KB or '
      'more not opened since the cutoff are listed, new uploads are not',
      () async {
        open(filter: StorageFilter.notOpened);
        await c.reload();
        await pumpEventQueue();

        expect(names(), ['archive.zip', 'opened-long-ago.pdf']);
        expect(c.notOpened?.count, 2);
        expect(c.notOpened?.bytes, 3 * mb);
        final f = t.api.requests
            .map((r) => r.$1)
            .firstWhere((f) => f.notOpenedSince != null);
        expect(f.minCountedBytes, StorageFilter.notOpenedMinBytes);
        expect(
          f.notOpenedSince,
          storageNow.subtract(const Duration(days: 180)),
        );
      },
    );
  });

  group('Given a loaded list', () {
    late List<DriveItemView> seeded;
    setUp(() async {
      seeded = [
        for (var i = 1; i <= 4; i++) t.seed('file$i.bin', bytes: i * mb),
      ];
      open();
      await c.reload();
    });

    test('when rows are clicked with modifiers then the selection follows '
        'and is published to the shell', () async {
      c.select(c.items[0]);
      c.select(c.items[2], range: true);
      expect(c.selection.map((i) => i.name), [
        'file4.bin',
        'file3.bin',
        'file2.bin',
      ]);
      expect(c.selectedBytes, 9 * mb);

      c.select(c.items[1], toggle: true);
      expect(t.services.driveSelection.value.map((i) => i.name), [
        'file4.bin',
        'file2.bin',
      ]);

      t.services.driveSelectAll!();
      expect(c.selection, hasLength(4));

      c.clearSelection();
      expect(t.services.driveSelection.value, isEmpty);
    });

    test('when ids are selected programmatically then unknown ids are '
        'reported and the first one is focused', () {
      final notFound = c.selectIds([
        seeded[1].uuid.uuid,
        '00000000-0000-7000-8000-000000000999',
      ]);

      expect(notFound, ['00000000-0000-7000-8000-000000000999']);
      expect(c.selection.single.name, 'file2.bin');
      expect(c.focusedId, seeded[1].uuid.uuid);
    });

    test('when arrow keys move the focus then the focused row is selected', () {
      c.moveFocus(1);
      c.moveFocus(1);
      c.moveFocus(1, extend: true);

      expect(c.selection.map((i) => i.name), ['file3.bin', 'file2.bin']);
    });

    test('when an item is trashed elsewhere then the list reloads and keeps '
        'the selection of the remaining rows', () async {
      c.select(c.items[0]);
      await t.h.drive.trash([seeded[3].uuid]);
      t.services.emitDriveChange(
        DriveChange(kind: DriveChangeKind.trashed, itemUuid: seeded[3].uuid),
      );
      await pumpEventQueue();

      expect(c.items.first.isTrashed, isTrue);
      expect(c.selection.single.uuid, seeded[3].uuid);
    });

    test('when the storage usage changes then the list reloads', () async {
      final before = t.api.requests.length;
      t.setUsage(files: 30 * mb);
      await pumpEventQueue();

      expect(t.api.requests.length, greaterThan(before));
    });

    test('when the page closes then the shell selection is cleared', () {
      c.select(c.items[0]);
      c.dispose();
      expect(t.services.driveSelection.value, isEmpty);
      expect(StorageHost.of(t.services).page.value, isNull);
      open();
    });
  });

  group('Given no connection', () {
    test(
      'when the page loads then the error is kept for the offline state',
      () async {
        t.api.failWith = const OfflineException('offline');
        open();
        await c.reload();

        expect(isOfflineError(c.error!), isTrue);
        expect(c.items, isEmpty);
      },
    );
  });

  test('Given a filter name when it is parsed then unknown names mean all', () {
    expect(StorageFilter.parse('large'), StorageFilter.large);
    expect(StorageFilter.parse('nope'), StorageFilter.all);
    expect(StorageFilter.parse(null), StorageFilter.all);
    expect(storagePath(StorageFilter.trash), '/storage?filter=trash');
    expect(storagePath(), '/storage');
    open();
  });
}
