import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import 'support/storage_pump.dart';

/// The *Out of storage* dialog (D-11, Drive 03 §6.3): every variant's
/// texts and buttons, light/dark at 360 px, MCP operability, and the
/// `QuotaErrorPresenter` mapping `quotaExceeded` errors of any command or
/// call to the right variant.
void main() {
  final l = lookupWonkyAppLocalizations(const Locale('en'));
  final xa = lookupWonkyAppLocalizations(const Locale('en', 'XA'));

  String body(QuotaProblem p) => QuotaExceededDialog.spec(l, p).description!;
  String title(QuotaProblem p) => QuotaExceededDialog.spec(l, p).title;
  List<String> buttons(QuotaProblem p) => [
    for (final b in QuotaExceededDialog.spec(l, p).buttons) b.label,
  ];

  const own = OwnQuotaProblem(
    neededBytes: 13002342, // 12.4 MB
    availableBytes: 3250585, // 3.1 MB
    quotaBytes: quota,
  );
  const owner = OwnerQuotaProblem(ownerName: 'Anna Berg');
  const batch = BatchQuotaProblem(
    fileCount: 5,
    neededBytes: 65011712, // 62.0 MB
    availableBytes: 19398656, // 18.5 MB
  );
  const transfer = TransferQuotaProblem(
    newOwnerName: 'Bo Chen',
    neededBytes: 8598323, // 8.2 MB
    itemName: 'Q3 deck',
  );
  const accept = TransferAcceptQuotaProblem(
    neededBytes: 8598323,
    availableBytes: 2097152, // 2.0 MB
    itemName: 'Q3 deck',
  );
  const tooLarge = FileTooLargeProblem(maxBytes: quota);
  const tooLargeNow = FileTooLargeProblem(maxBytes: 19398656, byQuota: true);
  const variants = <String, QuotaProblem>{
    'own': own,
    'owner': owner,
    'batch': batch,
    'transfer': transfer,
    'accept': accept,
    'tooLarge': tooLarge,
    'tooLargeNow': tooLargeNow,
  };

  group('Given the dialog variants of Drive 03 §6.3', () {
    test(
      'when the own quota is short then it says what is needed and left',
      () {
        expect(title(own), "You're out of storage");
        expect(
          body(own),
          'This needs 12.4 MB, but you have 3.1 MB left of your 50 MB. Free up '
          'space in Wonky Drive by deleting files you no longer need and '
          'emptying the trash.',
        );
        expect(buttons(own), ['Close', 'Manage storage']);
      },
    );

    test('when the size is unknown then it only says what is left', () {
      expect(
        body(
          const OwnQuotaProblem(
            neededBytes: null,
            availableBytes: 3250585,
            quotaBytes: quota,
          ),
        ),
        startsWith('You have 3.1 MB left of your 50 MB.'),
      );
    });

    test('when the owner of the item is full then it names the owner', () {
      expect(title(owner), 'Anna Berg is out of storage');
      expect(
        body(owner),
        "Images added to this document count against the owner's storage. "
        'Ask Anna Berg to free up space, or add the image to a document you '
        'own.',
      );
      expect(
        body(
          const OwnerQuotaProblem(
            ownerName: 'Anna Berg',
            itemKind: DriveItemKind.spreadsheet,
          ),
        ),
        contains('Images added to this spreadsheet'),
      );
      expect(
        body(
          const OwnerQuotaProblem(
            ownerName: 'Anna Berg',
            reason: QuotaReasons.import,
          ),
        ),
        contains('Ask Anna Berg to free up space first.'),
      );
      expect(buttons(owner), ['Close']);
    });

    test('when a batch upload doesn\'t fit then it offers the files that '
        'fit', () {
      expect(title(batch), 'Not enough storage for all files');
      expect(
        body(batch),
        'These 5 files need 62.0 MB, but you have 18.5 MB left. Upload the '
        'files that fit, or free up space first.',
      );
      expect(buttons(batch), [
        'Cancel',
        'Manage storage',
        'Upload the files that fit',
      ]);
    });

    test('when an ownership transfer is refused then the requester and the '
        'new owner get their texts', () {
      expect(title(transfer), "Bo Chen doesn't have enough storage");
      expect(
        body(transfer),
        'Bo Chen needs 8.2 MB free to take ownership of “Q3 deck”. Ask them '
        'to free up space first.',
      );
      expect(buttons(transfer), ['Close']);
      expect(title(accept), "You don't have enough storage");
      expect(
        body(accept),
        'Taking ownership of “Q3 deck” needs 8.2 MB, but you have 2.0 MB '
        'left.',
      );
      expect(buttons(accept), ['Close', 'Manage storage']);
    });

    test('when a file is too large then the cap or the room left is named', () {
      expect(title(tooLarge), 'This file is too large');
      expect(body(tooLarge), 'Files can be at most 50 MB.');
      expect(
        body(tooLargeNow),
        "Files can be at most 18.5 MB right now, because that's how much "
        'storage you have left.',
      );
    });

    test('when shown in en_XA then every text is localized', () {
      for (final p in variants.values) {
        final spec = QuotaExceededDialog.spec(xa, p);
        expect(spec.title, startsWith('['));
        expect(spec.description, startsWith('['));
        for (final b in spec.buttons) {
          expect(b.label, startsWith('['));
        }
      }
    });
  });

  group('Given the dialog on screen', () {
    late CommandTestHarness h;
    tearDown(() => h.dispose());

    for (final b in Brightness.values) {
      for (final MapEntry(key: name, value: p) in variants.entries) {
        testWidgets('when the $name variant shows at 360 px in ${b.name} '
            'mode then it fits', (tester) async {
          h = storageHarness(storage: FakeStorage.used(49 * mb));
          await pumpWithShell(
            tester,
            h,
            const SizedBox(),
            brightness: b,
            size: const Size(360, 720),
          );

          h.services.quotaErrors.show(p).ignore();
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('dialog.quota')), findsOneWidget);
          expect(find.text(title(p)), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('when an agent reads and presses it through the UI bridge '
        'then Manage storage opens Drive\'s Storage page', (tester) async {
      h = storageHarness(storage: FakeStorage.used(49 * mb));
      await pumpWithShell(tester, h, const SizedBox());

      final choice = h.services.quotaErrors.show(own);
      await tester.pumpAndSettle();
      final dialog = h.services.openDialogs.last;
      final d = dialog.describe();
      expect(d['title'], "You're out of storage");
      expect(
        [for (final b in d['buttons']! as List) (b as Map)['id']],
        ['close', 'manage'],
      );
      expect(dialog.press('manage'), isTrue);
      await tester.pumpAndSettle();

      expect(await choice, QuotaDialogChoice.manage);
      expect(h.crossApp.opened, [(WonkyAppKind.drive, '/storage')]);
      expect(h.services.openDialogs, isEmpty);
    });

    testWidgets('when Esc is pressed then the dialog closes', (tester) async {
      h = storageHarness(storage: FakeStorage.used(49 * mb));
      // Narrow: the test font is twice as wide as the app's, so the three
      // batch buttons only fit stacked.
      await pumpWithShell(
        tester,
        h,
        const SizedBox(),
        size: const Size(360, 720),
      );

      final choice = h.services.quotaErrors.show(batch);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(await choice, QuotaDialogChoice.close);
      expect(h.crossApp.opened, isEmpty);
    });
  });

  group('Given QuotaErrorPresenter', () {
    late CommandTestHarness h;
    tearDown(() => h.dispose());

    test('when an error is not quotaExceeded then it is not handled', () {
      h = storageHarness();
      final e = WonkyException(code: WonkyErrorCode.forbidden, message: 'x');

      expect(QuotaErrorPresenter.isQuotaExceeded(e), isFalse);
      expect(h.services.quotaErrors.present(e), isFalse);
      expect(h.services.quotaErrors.present(StateError('x')), isFalse);
    });

    test('when the caller is short then the own variant has the server\'s '
        'numbers', () {
      h = storageHarness();
      final p = h.services.quotaErrors.problemOf(
        FakeStorage.quotaError(neededBytes: 2 * mb, availableBytes: mb),
      );

      expect(p, isA<OwnQuotaProblem>());
      expect(body(p!), startsWith('This needs 2.0 MB, but you have 1.0 MB'));
    });

    test('when the owner of the open spreadsheet is short then the owner '
        'variant names them', () {
      h = storageHarness();
      h.services.currentItem.value = h.drive.seed(
        name: 'Budget',
        kind: DriveItemKind.spreadsheet,
        role: AccessRole.editor,
      );
      final p = h.services.quotaErrors.problemOf(
        FakeStorage.quotaError(
          neededBytes: 3 * mb,
          isCaller: false,
          chargedUserName: 'Anna Berg',
          reason: QuotaReasons.image,
        ),
      );

      expect(title(p!), 'Anna Berg is out of storage');
      expect(body(p), contains('this spreadsheet'));
    });

    test('when a transfer is refused then requester and new owner get their '
        'variants', () {
      h = storageHarness();
      final requester = h.services.quotaErrors.problemOf(
        FakeStorage.quotaError(
          neededBytes: 8 * mb,
          isCaller: false,
          chargedUserName: 'Bo Chen',
          reason: QuotaReasons.transfer,
        ),
        itemName: 'Q3 deck',
      );
      final accepter = h.services.quotaErrors.problemOf(
        FakeStorage.quotaError(
          neededBytes: 8 * mb,
          availableBytes: 2 * mb,
          reason: QuotaReasons.transfer,
        ),
        itemName: 'Q3 deck',
      );

      expect(title(requester!), "Bo Chen doesn't have enough storage");
      expect(title(accepter!), "You don't have enough storage");
    });

    test('when the details are missing then the own variant uses the known '
        'usage', () {
      h = storageHarness(storage: FakeStorage.used(49 * mb));
      final p = h.services.quotaErrors.problemOf(
        WonkyException(code: WonkyErrorCode.quotaExceeded, message: 'full'),
      );

      expect(body(p!), startsWith('You have 1.0 MB left of your 50 MB.'));
    });
  });

  group('Given a command refused with quotaExceeded', () {
    late CommandTestHarness h;
    tearDown(() => h.dispose());

    CommandTestHarness harness() {
      late CommandTestHarness harness;
      harness = CommandTestHarness(
        config: TestAppConfig(
          extraCommands: [
            CallbackCommand(
              id: 'test.failsOnQuota',
              title: (_) => 'Fails on quota',
              run: (ctx, a) async => throw FakeStorage.quotaError(
                neededBytes: 2 * mb,
                availableBytes: mb,
              ),
            ),
            // A command that runs another one (like *Make a copy*): the
            // same error is reported twice, the dialog shows once.
            CallbackCommand(
              id: 'test.nested',
              title: (_) => 'Nested',
              run: (ctx, a) => harness.services.dispatcher.invoke(
                'test.failsOnQuota',
                source: ctx.source,
              ),
            ),
          ],
        ),
        storage: FakeStorage.used(49 * mb),
      );
      return harness;
    }

    testWidgets('when a person invoked it then the dialog shows once', (
      tester,
    ) async {
      h = harness();
      await pumpWithShell(tester, h, const SizedBox());

      await expectLater(
        h.invoke('test.nested', const {}, InvocationSource.menu),
        throwsA(isA<WonkyException>()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialog.quota')), findsOneWidget);
      expect(find.text("You're out of storage"), findsOneWidget);
    });

    testWidgets('when an agent invoked it then no dialog shows (the agent '
        'gets the error)', (tester) async {
      h = harness();
      await pumpWithShell(tester, h, const SizedBox());

      await expectLater(
        h.invoke('test.failsOnQuota', const {}, InvocationSource.mcp),
        throwsA(isA<WonkyException>()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialog.quota')), findsNothing);
    });
  });
}
