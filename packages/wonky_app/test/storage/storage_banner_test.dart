import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

import 'support/storage_pump.dart';

/// The storage banner (D-11, Drive 03 §6.2): the 90 % warning, the
/// over-quota state, dismissal rules per place, editors only for owned
/// items, *Empty trash* first, live updates, light/dark, 360 px, en_XA.
void main() {
  late CommandTestHarness h;
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey<String>(k));

  Widget banner({
    StorageBannerPlace place = StorageBannerPlace.home,
    DriveItemView? item,
  }) => Align(
    alignment: Alignment.topCenter,
    child: StorageBanner(services: h.services, place: place, item: item),
  );

  const overText =
      "You're out of storage. You can keep editing, but you can't upload "
      'files, add images, import, or make copies until you free up space.';

  for (final b in Brightness.values) {
    group('Given ${b.name} mode', () {
      testWidgets('when 46.1 MB of 50 MB are used then the warning banner '
          'shows with Manage storage', (tester) async {
        h = storageHarness(storage: FakeStorage.used((46.1 * mb).round()));
        await pumpWithShell(tester, h, banner(), brightness: b);

        expect(
          find.text("You've used 46.1 MB of your 50 MB storage."),
          findsOneWidget,
        );
        expect(key('storage.banner.warning.manage'), findsOneWidget);
        expect(key('storage.banner.warning.dismiss'), findsOneWidget);
      });

      testWidgets('when over quota on a home then the banner is not '
          'dismissible', (tester) async {
        h = storageHarness(storage: FakeStorage.used((50.4 * mb).round()));
        await pumpWithShell(tester, h, banner(), brightness: b);

        expect(find.text(overText), findsOneWidget);
        expect(key('storage.banner.over.dismiss'), findsNothing);
      });
    });
  }

  group('Given the 90 % banner', () {
    testWidgets('when below 90 % then no banner shows', (tester) async {
      h = storageHarness(storage: FakeStorage.used(40 * mb));
      await pumpWithShell(tester, h, banner());

      expect(key('storage.banner.warning'), findsNothing);
      expect(key('storage.banner.over'), findsNothing);
    });

    testWidgets('when calculating then no banner shows', (tester) async {
      h = storageHarness(storage: FakeStorage.used(60 * mb, calculating: true));
      await pumpWithShell(tester, h, banner());

      expect(key('storage.banner.over'), findsNothing);
    });

    testWidgets('when dismissed then it stays hidden for 7 days on this '
        'device', (tester) async {
      final store = MemoryStore();
      final start = DateTime.utc(2026, 10, 15, 9);
      h = CommandTestHarness(store: store, storage: FakeStorage.used(46 * mb));
      await withClock(Clock.fixed(start), () async {
        await pumpWithShell(tester, h, banner());
        await tester.tap(key('storage.banner.warning.dismiss'));
        await tester.pump();
      });
      expect(key('storage.banner.warning'), findsNothing);
      await settleTooltips(tester);

      // A later visit (new widget) within the 7 days: still hidden.
      await withClock(
        Clock.fixed(start.add(const Duration(days: 6))),
        () async {
          await pumpWithShell(tester, h, const SizedBox());
          await pumpWithShell(tester, h, banner());
          await tester.pump();
        },
      );
      expect(key('storage.banner.warning'), findsNothing);

      // After 7 days it is back.
      await withClock(
        Clock.fixed(start.add(const Duration(days: 8))),
        () async {
          await pumpWithShell(tester, h, const SizedBox());
          await pumpWithShell(tester, h, banner());
          await tester.pump();
        },
      );
      expect(key('storage.banner.warning'), findsOneWidget);
    });

    testWidgets('when Manage storage is pressed then Drive\'s Storage page '
        'opens', (tester) async {
      h = storageHarness(storage: FakeStorage.used(46 * mb));
      await pumpWithShell(tester, h, banner());

      await tester.tap(key('storage.banner.warning.manage'));
      await tester.pumpAndSettle();

      expect(h.crossApp.opened, [(WonkyAppKind.drive, '/storage')]);
    });
  });

  group('Given an over-quota user', () {
    testWidgets('when space is freed (storageChanged) then the banner '
        'disappears live', (tester) async {
      final storage = FakeStorage.used((50.4 * mb).round());
      h = storageHarness(storage: storage);
      await pumpWithShell(tester, h, banner());
      expect(key('storage.banner.over'), findsOneWidget);

      storage.emit(FakeStorage.usageOf(20 * mb));
      await tester.pump();

      expect(key('storage.banner.over'), findsNothing);
      expect(key('storage.banner.warning'), findsNothing);
    });

    testWidgets('when the trash holds ≥ 10 % of the usage then Empty trash '
        'comes first', (tester) async {
      h = storageHarness(
        storage: FakeStorage.used(52 * mb, trashBytes: 8 * mb),
      );
      await pumpWithShell(tester, h, banner());

      final trash = tester.getTopLeft(key('storage.banner.over.emptyTrash'));
      final manage = tester.getTopLeft(key('storage.banner.over.manage'));
      expect(trash.dx, lessThan(manage.dx));
    });

    testWidgets('when the trash is small then only Manage storage shows', (
      tester,
    ) async {
      h = storageHarness(storage: FakeStorage.used(52 * mb, trashBytes: mb));
      await pumpWithShell(tester, h, banner());

      expect(key('storage.banner.over.emptyTrash'), findsNothing);
      expect(key('storage.banner.over.manage'), findsOneWidget);
    });

    testWidgets('when Empty trash is pressed then the trash is emptied after '
        'the confirmation', (tester) async {
      h = storageHarness(
        storage: FakeStorage.used(52 * mb, trashBytes: 8 * mb),
      );
      final doc = h.drive.seed(name: 'Old');
      await h.drive.trash([doc.uuid]);
      await pumpWithShell(tester, h, banner());

      await tester.tap(key('storage.banner.over.emptyTrash'));
      await tester.pumpAndSettle();
      await tester.tap(key('dialog.confirm.confirm'));
      await tester.pumpAndSettle();

      expect(h.drive.calls, contains('emptyTrash'));
    });
  });

  group('Given an editor', () {
    testWidgets('when the user owns the item then the over-quota banner '
        'shows and can be dismissed until the next day', (tester) async {
      final store = MemoryStore();
      h = CommandTestHarness(
        store: store,
        storage: FakeStorage.used((50.4 * mb).round()),
      );
      final doc = h.drive.seed(name: 'Plan');
      final day = DateTime(2026, 10, 15, 9);
      await withClock(Clock.fixed(day), () async {
        await pumpWithShell(
          tester,
          h,
          banner(place: StorageBannerPlace.editor, item: doc),
        );
        expect(key('storage.banner.over'), findsOneWidget);
        await tester.tap(key('storage.banner.over.dismiss'));
        await tester.pump();
      });
      expect(key('storage.banner.over'), findsNothing);
      await settleTooltips(tester);

      await withClock(Clock.fixed(day.add(const Duration(days: 1))), () async {
        await pumpWithShell(tester, h, const SizedBox());
        await pumpWithShell(
          tester,
          h,
          banner(place: StorageBannerPlace.editor, item: doc),
        );
        await tester.pump();
      });
      expect(key('storage.banner.over'), findsOneWidget);
    });

    testWidgets('when someone else owns the item then no banner shows', (
      tester,
    ) async {
      h = storageHarness(storage: FakeStorage.used((50.4 * mb).round()));
      final doc = h.drive.seed(name: 'Shared', role: AccessRole.editor);
      await pumpWithShell(
        tester,
        h,
        banner(place: StorageBannerPlace.editor, item: doc),
      );

      expect(key('storage.banner.over'), findsNothing);
    });
  });

  group('Given a narrow window', () {
    testWidgets('when 360 px wide in en_XA then the banner wraps without '
        'overflow', (tester) async {
      h = storageHarness(
        storage: FakeStorage.used(52 * mb, trashBytes: 8 * mb),
      );
      await pumpWithShell(
        tester,
        h,
        banner(),
        size: const Size(360, 640),
        locale: pseudoLocale,
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Ýöû'), findsOneWidget);
      expect(key('storage.banner.over.emptyTrash'), findsOneWidget);
    });
  });
}
