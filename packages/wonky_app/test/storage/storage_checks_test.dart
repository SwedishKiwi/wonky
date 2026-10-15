import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart'
    show CommandStatus, InvocationSource;

import 'support/storage_pump.dart';

/// The client-side quota pre-checks (D-11, Drive 03 §7.2): single actions
/// (`ensureRoom`, incl. the owner of someone else's item and offline), Drive
/// uploads (`fittingUploads`: too large, one file, batch with *Upload the
/// files that fit*) and the *Make a copy* pre-check of `shell.drive.copy`.
void main() {
  late CommandTestHarness h;
  late FakeStorage storage;
  tearDown(() async {
    h.services.connectivity.forceOffline(false);
    await h.dispose();
  });

  Finder dialog() => find.byKey(const ValueKey('dialog.quota'));
  Finder button(String id) => find.byKey(ValueKey('dialog.quota.$id'));

  Future<void> setUpShell(WidgetTester tester, int usedBytes) async {
    storage = FakeStorage.used(usedBytes);
    h = storageHarness(storage: storage);
    // 360 px: the dialog buttons stack (the test font is twice as wide as
    // the app's, three buttons don't fit side by side).
    await pumpWithShell(
      tester,
      h,
      const SizedBox(),
      size: const Size(360, 700),
    );
  }

  group('Given 49 MB of 50 MB used', () {
    testWidgets('when a 2 MB upload is pre-checked then the dialog says '
        '"needs 2.0 MB … 1.0 MB left" before any byte is sent (AC-D3.1)', (
      tester,
    ) async {
      await setUpShell(tester, 49 * mb);

      final ok = h.services.storageChecks.ensureRoom(2 * mb);
      await tester.pumpAndSettle();

      expect(find.text("You're out of storage"), findsOneWidget);
      expect(
        find.textContaining('This needs 2.0 MB, but you have 1.0 MB left'),
        findsOneWidget,
      );
      expect(storage.checkRoomCalls, isEmpty);
      await tester.tap(button('close'));
      await tester.pumpAndSettle();
      expect(await ok, isFalse);
    });

    testWidgets('when 500 KB are pre-checked then the server is asked and '
        'the action goes on', (tester) async {
      await setUpShell(tester, 49 * mb);

      expect(await h.services.storageChecks.ensureRoom(500 * 1024), isTrue);
      expect(storage.checkRoomCalls, [(500 * 1024, null)]);
      expect(dialog(), findsNothing);
    });

    testWidgets('when offline then the known usage still refuses, but '
        'nothing else is asked', (tester) async {
      await setUpShell(tester, 10 * mb);
      h.services.connectivity.forceOffline(true);

      expect(await h.services.storageChecks.ensureRoom(5 * mb), isTrue);
      expect(storage.checkRoomCalls, isEmpty);
    });
  });

  group('Given an image added to someone else\'s document', () {
    testWidgets('when its owner is full then the owner dialog names them '
        '(AC-D3.3)', (tester) async {
      await setUpShell(tester, 1 * mb);
      final doc = h.drive.seed(name: 'Anna\'s plan', role: AccessRole.editor);
      storage.onCheckRoom = (bytes, item) => item == doc.uuid
          ? FakeStorage.quotaError(
              neededBytes: bytes,
              isCaller: false,
              chargedUserName: 'Anna Berg',
            )
          : null;

      final ok = h.services.storageChecks.ensureRoom(
        3 * mb,
        reason: QuotaReasons.image,
        item: doc,
      );
      await tester.pumpAndSettle();

      expect(find.text('Anna Berg is out of storage'), findsOneWidget);
      expect(
        find.textContaining('Images added to this document count against'),
        findsOneWidget,
      );
      expect(storage.checkRoomCalls, [(3 * mb, doc.uuid)]);
      await tester.tap(button('close'));
      await tester.pumpAndSettle();
      expect(await ok, isFalse);
    });

    testWidgets('when the user\'s own storage is full then the image still '
        'goes to the owner\'s check', (tester) async {
      await setUpShell(tester, 52 * mb);
      final doc = h.drive.seed(name: 'Shared', role: AccessRole.editor);

      expect(
        await h.services.storageChecks.ensureRoom(
          3 * mb,
          reason: QuotaReasons.image,
          item: doc,
        ),
        isTrue,
      );
      expect(storage.checkRoomCalls, [(3 * mb, doc.uuid)]);
    });
  });

  group('Given a Drive upload of several files', () {
    testWidgets('when all fit then all start', (tester) async {
      await setUpShell(tester, 10 * mb);

      expect(
        await h.services.storageChecks.fittingUploads([mb, 2 * mb, 3 * mb]),
        [0, 1, 2],
      );
    });

    testWidgets('when one file is above the cap then it is left out with '
        '"This file is too large"', (tester) async {
      await setUpShell(tester, 0);

      final ok = h.services.storageChecks.fittingUploads([mb, 60 * mb]);
      await tester.pumpAndSettle();
      expect(find.text('This file is too large'), findsOneWidget);
      expect(find.text('Files can be at most 50 MB.'), findsOneWidget);
      await tester.tap(button('close'));
      await tester.pumpAndSettle();

      expect(await ok, [0]);
    });

    testWidgets('when the only file doesn\'t fit then the own dialog shows '
        'and nothing starts', (tester) async {
      await setUpShell(tester, 49 * mb);

      final ok = h.services.storageChecks.fittingUploads([2 * mb]);
      await tester.pumpAndSettle();
      expect(find.text("You're out of storage"), findsOneWidget);
      await tester.tap(button('close'));
      await tester.pumpAndSettle();

      expect(await ok, isEmpty);
    });

    testWidgets('when only some fit then "Upload the files that fit" starts '
        'those', (tester) async {
      await setUpShell(tester, (31.5 * mb).round()); // 18.5 MB left

      final ok = h.services.storageChecks.fittingUploads([
        10 * mb,
        12 * mb,
        8 * mb,
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Not enough storage for all files'), findsOneWidget);
      expect(
        find.text(
          'These 3 files need 30.0 MB, but you have 18.5 MB left. Upload the '
          'files that fit, or free up space first.',
        ),
        findsOneWidget,
      );
      await tester.tap(button('fit'));
      await tester.pumpAndSettle();

      expect(await ok, [0, 2]);
    });

    testWidgets('when the batch dialog is cancelled then nothing starts', (
      tester,
    ) async {
      await setUpShell(tester, (31.5 * mb).round());

      final ok = h.services.storageChecks.fittingUploads([10 * mb, 12 * mb]);
      await tester.pumpAndSettle();
      await tester.tap(button('cancel'));
      await tester.pumpAndSettle();

      expect(await ok, isEmpty);
    });

    testWidgets('when the usage is unknown and the server refuses then its '
        'numbers decide', (tester) async {
      storage = FakeStorage();
      h = storageHarness(storage: storage);
      await pumpWithShell(
        tester,
        h,
        const SizedBox(),
        size: const Size(360, 700),
      );
      storage.onCheckRoom = (bytes, _) =>
          FakeStorage.quotaError(neededBytes: bytes, availableBytes: 5 * mb);

      final ok = h.services.storageChecks.fittingUploads([4 * mb, 4 * mb]);
      await tester.pumpAndSettle();
      expect(find.textContaining('you have 5.0 MB left'), findsOneWidget);
      await tester.tap(button('fit'));
      await tester.pumpAndSettle();

      expect(await ok, [0]);
    });
  });

  group('Given Make a copy', () {
    testWidgets('when the copy doesn\'t fit then the dialog shows and no copy '
        'is made', (tester) async {
      await setUpShell(tester, 49 * mb);
      final doc = h.drive.seed(name: 'Big', countedBytes: 3 * mb);

      final r = h.services.dispatcher.invoke(
        'shell.drive.copy',
        args: {'uuid': doc.uuid.uuid, 'name': 'Copy of Big'},
        source: InvocationSource.menu,
      );
      await tester.pumpAndSettle();
      expect(find.text("You're out of storage"), findsOneWidget);
      await tester.tap(button('close'));
      await tester.pumpAndSettle();

      expect((await r).status, CommandStatus.cancelled);
      expect(h.drive.items.where((i) => i.name == 'Copy of Big'), isEmpty);
    });

    testWidgets('when an agent copies then the server decides (no dialog)', (
      tester,
    ) async {
      await setUpShell(tester, 49 * mb);
      final doc = h.drive.seed(name: 'Big', countedBytes: 3 * mb);

      await h.invoke('shell.drive.copy', {
        'uuid': doc.uuid.uuid,
        'name': 'Copy of Big',
      });
      await tester.pumpAndSettle();

      expect(dialog(), findsNothing);
    });
  });
}
