import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_drive/l10n/drive_l10n.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/storage_fakes.dart';

final l = driveL10nEnglish;

/// The Storage page (Drive 03 §6.4, Drive 04 §7): usage by kind, *Free up
/// space*, the items table with multi-selection and its actions through
/// commands, light/dark, 360 px and the pseudo-locale.
void main() {
  late StorageTestbed t;

  setUp(() {
    t = StorageTestbed();
    t.setUsage(
      documents: 4 * mb,
      spreadsheets: 6 * mb,
      files: 22 * mb,
      trash: 4 * mb,
    );
  });
  tearDown(() => t.dispose());

  Finder key(String k) => find.byKey(ValueKey<String>(k));
  Finder row(DriveItemView i) => key('storage.row.${i.uuid.uuid}');
  Finder headline(String text) => find.descendant(
    of: key('storage.usage.headline'),
    matching: find.text(text),
    matchRoot: true,
  );

  Future<void> tapRow(WidgetTester tester, DriveItemView i) async {
    await tester.tap(
      find.descendant(of: row(i), matching: find.text(i.name)).first,
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('Given a drive with large, trashed and old items', () {
    late DriveItemView audio;
    late DriveItemView sales;
    late DriveItemView scan;
    late DriveItemView notes;
    final old = storageNow.subtract(const Duration(days: 400));

    setUp(() {
      final team = t.seed('Finance', kind: DriveItemKind.folder);
      audio = t.seed(
        'interview.m4a',
        bytes: 18 * mb,
        category: FileCategory.audio,
        createdAt: old,
      );
      sales = t.seed(
        'Sales 2025',
        kind: DriveItemKind.spreadsheet,
        bytes: 6 * mb,
        parent: team.uuid,
        lastOpenedAt: storageNow.subtract(const Duration(days: 1)),
      );
      scan = t.seed(
        'old-scan.pdf',
        bytes: 4 * mb,
        category: FileCategory.pdf,
        trashed: true,
      );
      notes = t.seed('Notes', kind: DriveItemKind.document, bytes: 40 * kb);
    });

    testWidgets('when the page opens then it shows the usage by kind, the '
        'suggestions and the items by size', (tester) async {
      await t.pump(tester);

      expect(find.text(l.storageTitle), findsWidgets);
      expect(headline('36.0 MB of 50 MB used'), findsOneWidget);
      expect(find.text(l.storagePercent(72)), findsOneWidget);
      expect(key('storage.legend.documents'), findsOneWidget);
      expect(key('storage.legend.free'), findsOneWidget);
      expect(key('storage.suggestion.emptyTrash'), findsOneWidget);
      expect(key('storage.suggestion.large'), findsOneWidget);
      expect(find.text(l.storageCardLargeBody(3)), findsOneWidget);
      expect(key('storage.suggestion.notOpened'), findsOneWidget);
      expect(
        find.text(l.storageCardNotOpenedBody(1, '18.0 MB')),
        findsOneWidget,
      );

      final rows = tester
          .widgetList<Semantics>(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('storage.row.'),
            ),
          )
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      expect(rows, [
        for (final i in [audio, sales, scan, notes])
          'storage.row.${i.uuid.uuid}',
      ]);
      expect(find.text('Finance'), findsOneWidget);
      expect(
        find.descendant(of: row(scan), matching: find.text(l.storageInTrash)),
        findsOneWidget,
      );
      expect(key('drive.nav.storage'), findsOneWidget);
      expect(
        tester.getSemantics(key('drive.nav.storage')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('when Review on Large files is pressed then the table shows '
        'only large items and the chip clears the filter', (tester) async {
      await t.pump(tester);

      await tester.tap(key('storage.suggestion.large.action'));
      await tester.pumpAndSettle();

      expect(t.location, '/storage?filter=large');
      expect(row(notes), findsNothing);
      expect(row(audio), findsOneWidget);

      await tester.tap(key('storage.filter.clear'));
      await tester.pumpAndSettle();
      expect(t.location, '/storage');
      expect(row(notes), findsOneWidget);
    });

    testWidgets('when the type menu picks Trash then only trashed items are '
        'listed', (tester) async {
      await t.pump(tester);

      await tester.tap(key('storage.filter'));
      await tester.pumpAndSettle();
      await tester.tap(key('storage.filter.trash'));
      await tester.pumpAndSettle();

      expect(t.location, '/storage?filter=trash');
      expect(row(scan), findsOneWidget);
      expect(row(audio), findsNothing);
    });

    testWidgets('when two rows are selected and moved to the trash then they '
        'are trashed, and undo and redo round-trip', (tester) async {
      await t.pump(tester);

      await tapRow(tester, audio);
      await tester.tap(key('storage.row.${sales.uuid.uuid}.check'));
      await tester.pumpAndSettle();
      expect(find.text(l.storageSelectionSize(2, '24.0 MB')), findsOneWidget);
      expect(t.services.driveSelection.value, hasLength(2));

      await tester.tap(key('storage.selection.trash'));
      await tester.pumpAndSettle();

      bool trashed(DriveItemView i) => t.h.drive.item(i.uuid).isTrashed;
      expect(trashed(audio) && trashed(sales), isTrue);

      await t.h.undo();
      expect(trashed(audio) || trashed(sales), isFalse);
      await t.h.redo();
      expect(trashed(audio) && trashed(sales), isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('when a trashed row is deleted forever then the confirm '
        'names the freed size and the item is gone', (tester) async {
      await t.pump(tester);

      await tapRow(tester, scan);
      expect(key('storage.selection.trash'), findsNothing);
      await tester.tap(key('storage.selection.deleteForever'));
      await tester.pumpAndSettle();

      expect(find.text(l.storageDeleteTitle(1)), findsOneWidget);
      expect(find.text(l.storageDeleteBody('4.0 MB')), findsOneWidget);
      await tester.tap(key('dialog.confirm.confirm'));
      await tester.pumpAndSettle();

      expect(t.h.drive.items.where((i) => i.uuid == scan.uuid), isEmpty);
      expect(row(scan), findsNothing);
      expect(t.h.drive.calls, contains('deletePermanently'));
    });

    testWidgets('when Empty trash is confirmed then the dialog names the '
        'count and size and the trash is emptied', (tester) async {
      await t.pump(tester);

      await tester.tap(key('storage.emptyTrash'));
      await tester.pumpAndSettle();
      expect(find.text(l.storageEmptyTrashBody(1, '4.0 MB')), findsOneWidget);

      await tester.tap(key('dialog.confirm.confirm'));
      await tester.pumpAndSettle();

      expect(t.h.drive.calls, contains('emptyTrash'));
      expect(row(scan), findsNothing);
    });

    testWidgets('when keys are used in the table then arrows select, Space '
        'previews a file and Delete trashes', (tester) async {
      await t.pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(t.services.driveSelection.value.single.uuid, audio.uuid);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(t.h.drive.item(audio.uuid).isTrashed, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(t.services.driveSelection.value.single.uuid, scan.uuid);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(t.location, '/file/${scan.uuid.uuid}');
    });

    testWidgets('when a row is double-clicked then the item opens', (
      tester,
    ) async {
      await t.pump(tester);

      await tester.tap(find.text(audio.name));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(audio.name));
      await tester.pumpAndSettle();

      expect(t.location, '/file/${audio.uuid.uuid}');
    });

    testWidgets('when a row menu opens then it is the drive item menu for '
        'that row', (tester) async {
      await t.pump(tester);

      await tester.tap(key('storage.row.${sales.uuid.uuid}.menu'));
      await tester.pumpAndSettle();

      expect(t.services.driveSelection.value.single.uuid, sales.uuid);
      expect(
        find.text(
          lookupWonkyAppLocalizations(const Locale('en')).cmdMoveToTrash,
        ),
        findsWidgets,
      );
    });
  });

  testWidgets('Given an empty drive when the page opens then the table says '
      'nothing uses storage and no suggestion is shown', (tester) async {
    t.setUsage();
    await t.pump(tester);

    expect(key('storage.empty'), findsOneWidget);
    expect(key('storage.suggestions.none'), findsOneWidget);
    expect(key('storage.emptyTrash'), findsNothing);
  });

  testWidgets('Given usage over the quota when the page opens then the '
      'headline and bar show it', (tester) async {
    t.setUsage(files: 50 * mb, documents: mb ~/ 2);
    await t.pump(tester);

    expect(headline('50.5 MB of 50 MB used — over quota'), findsOneWidget);
    expect(find.text(l.storageOverBy('512 KB')), findsOneWidget);
    expect(key('storage.legend.free'), findsNothing);
  });

  testWidgets('Given the backfill is calculating when the page opens then '
      'the meter says so', (tester) async {
    t.setUsage(files: mb, calculating: true);
    await t.pump(tester, settle: false);

    expect(key('storage.usage.calculating'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Given no connection when the page opens then the table shows '
      'the offline state and Retry loads it', (tester) async {
    t.api.failWith = const OfflineException('offline');
    t.seed('a.bin', bytes: mb);
    await t.pump(tester);

    expect(find.text(l.storageOfflineTitle), findsOneWidget);
    t.api.failWith = null;
    await tester.tap(key('storage.retry'));
    await tester.pumpAndSettle();
    expect(find.text('a.bin'), findsOneWidget);
  });

  testWidgets('Given the page when a storageChanged event frees space then '
      'the headline and list update live', (tester) async {
    final big = t.seed('big.bin', bytes: 30 * mb);
    t.setUsage(files: 30 * mb);
    await t.pump(tester);
    expect(headline('30.0 MB of 50 MB used'), findsOneWidget);

    await t.h.drive.deletePermanently([big.uuid]);
    t.setUsage();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(headline('0 bytes of 50 MB used'), findsOneWidget);
    expect(find.text('big.bin'), findsNothing);
  });

  for (final b in Brightness.values) {
    for (final (variant, size) in [
      ('wide', const Size(1280, 900)),
      ('narrow', const Size(360, 780)),
    ]) {
      testWidgets('Given the Storage page in ${b.name} at $variant when it '
          'shows then nothing overflows and it is accessible', (tester) async {
        final semantics = tester.ensureSemantics();
        t.seed('interview.m4a', bytes: 18 * mb, category: FileCategory.audio);
        t.seed(
          'Q3 planning with a very long name that keeps going on',
          kind: DriveItemKind.document,
          bytes: 2 * mb,
        );
        t.seed('old-scan.pdf', bytes: 4 * mb, trashed: true);
        await t.pump(tester, brightness: b, size: size);

        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        await settleTooltips(tester);
      });
    }
  }

  testWidgets('Given the pseudo-locale when the page shows at 360 px then '
      'long strings fit', (tester) async {
    t.seed('interview.m4a', bytes: 18 * mb, category: FileCategory.audio);
    t.seed('old-scan.pdf', bytes: 4 * mb, trashed: true);
    await t.pump(
      tester,
      size: const Size(360, 780),
      locale: const Locale('en', 'XA'),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Šţöŕåĝé'), findsWidgets);
  });
}
