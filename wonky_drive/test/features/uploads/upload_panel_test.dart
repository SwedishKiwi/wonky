import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_drive/config/drive_app_config.dart';
import 'package:wonky_drive/features/uploads/upload_host.dart';
import 'package:wonky_drive/features/uploads/upload_panel.dart';
import 'package:wonky_drive/features/uploads/upload_queue.dart';
import 'package:wonky_drive/features/uploads/upload_store.dart';
import 'package:wonky_drive/features/uploads/upload_task.dart';
import 'package:wonky_drive/l10n/drive_l10n.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/upload_fakes.dart';

/// The upload panel (Drive 04 §4): every row state in light and dark, at
/// 1280 px and 360 px, collapse/expand, the close confirm and the row
/// actions.
void main() {
  late CommandTestHarness h;
  late FakeUploadApi api;
  late UploadHost host;
  late UploadQueue q;

  setUp(() async {
    h = CommandTestHarness(
      config: const DriveAppConfig(),
      storage: FakeStorage.used(0),
    );
    api = FakeUploadApi();
    host = UploadHost.of(h.services)..api = api;
    q = UploadQueue(
      api: api,
      store: MemoryUploadStore(),
      connectivity: h.services.connectivity,
      newId: sequentialIds(),
    );
    host.attach(q);
  });

  tearDown(() async {
    h.services.connectivity.forceOffline(false);
    Api.simulatedOffline = false;
    await host.stop();
    await h.dispose();
  });

  /// One row per state; the uploads are held offline so nothing moves.
  Future<void> seedStates() async {
    await q.start();
    h.services.connectivity.forceOffline(true);
    final tasks = await q.enqueue([
      textFile('interview-recording-final-version.m4a', 100),
      textFile('notes.pdf'),
      textFile('waiting.txt'),
      textFile('queued.txt'),
      textFile('full.zip'),
      textFile('lost.txt'),
    ], parentName: 'Team');
    tasks[0]
      ..status = UploadStatus.uploading
      ..bytesSent = 42;
    tasks[1]
      ..status = UploadStatus.done
      ..result = fileView(tasks[1].itemUuid, 'notes.pdf');
    tasks[3].status = UploadStatus.queued;
    tasks[4]
      ..status = UploadStatus.failed
      ..failure = UploadFailure.outOfStorage;
    tasks[5]
      ..status = UploadStatus.failed
      ..failure = UploadFailure.folderGone;
    q.addRejected([textFile('photo.raw', 99)], UploadFailure.tooLarge);
    host.showPanel();
  }

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Size size = const Size(1280, 800),
  }) async {
    await pumpWonky(
      tester,
      UploadPanelLayer(services: h.services, child: const SizedBox.expand()),
      brightness: brightness,
      size: size,
      extraDelegates: const [
        WonkyAppLocalizations.delegate,
        DriveLocalizations.delegate,
      ],
    );
    await tester.pumpAndSettle();
  }

  for (final b in Brightness.values) {
    for (final (variant, size) in [
      ('wide', const Size(1280, 1000)),
      ('360 px', const Size(360, 1000)),
    ]) {
      testWidgets('Given every row state when the panel shows in ${b.name} '
          'at $variant then each row has its status and action', (
        tester,
      ) async {
        await seedStates();
        await pump(tester, brightness: b, size: size);

        expect(find.byKey(UploadPanelKeys.panel), findsOneWidget);
        expect(find.text('Uploading 3 items'), findsOneWidget);
        expect(find.text('42 %'), findsOneWidget);
        expect(find.text('Uploaded'), findsOneWidget);
        expect(find.text('Waiting for connection'), findsOneWidget);
        expect(find.text('Queued'), findsOneWidget);
        expect(
          find.text("Not uploaded — you're out of storage"),
          findsOneWidget,
        );
        expect(
          find.text('The folder is gone or you lost access to it'),
          findsOneWidget,
        );
        expect(
          find.text('Too large — files can be at most 50.0 MB'),
          findsOneWidget,
        );
        expect(find.text('Manage storage'), findsOneWidget);
        expect(find.text('Upload to My Drive'), findsOneWidget);
        expect(find.byKey(UploadPanelKeys.retryAll), findsOneWidget);
        expect(find.byKey(UploadPanelKeys.clearFinished), findsOneWidget);
        // The extension stays visible when the name is cut.
        expect(find.text('.m4a'), findsOneWidget);
        final panel = tester.getRect(find.byKey(UploadPanelKeys.panel));
        expect(panel.width, size.width < 768 ? size.width - 16 : 360);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  }

  testWidgets('Given running uploads when the panel is collapsed then a '
      'pill shows the batch progress and expands it again', (tester) async {
    await seedStates();
    await pump(tester);

    await tester.tap(find.byKey(UploadPanelKeys.collapse));
    await tester.pumpAndSettle();

    expect(find.byKey(UploadPanelKeys.panel), findsNothing);
    // 42 of the 120 bytes of the 3 active uploads.
    expect(find.text('Uploading 3 · 35 %'), findsOneWidget);

    await tester.tap(find.byKey(UploadPanelKeys.pill));
    await tester.pumpAndSettle();
    expect(find.byKey(UploadPanelKeys.panel), findsOneWidget);
  });

  testWidgets('Given uploads waiting offline when the panel is collapsed '
      'then the pill says they are waiting, not uploading', (tester) async {
    // D-18: the pill said "Uploading 2 · 0 %" while offline.
    await q.start();
    h.services.connectivity.forceOffline(true);
    await q.enqueue([textFile('a.txt'), textFile('b.txt')]);
    host.showPanel();
    await pump(tester);
    expect(
      q.tasks.map((t) => t.status),
      everyElement(UploadStatus.waitingForNetwork),
    );

    await tester.tap(find.byKey(UploadPanelKeys.collapse));
    await tester.pumpAndSettle();

    final l = driveL10nEnglish;
    expect(find.text(l.uploadPillWaiting(2)), findsOneWidget);
    expect(find.textContaining('Uploading'), findsNothing);
  });

  testWidgets('Given running uploads when the panel is closed then a '
      'confirm cancels them and hides the panel', (tester) async {
    await q.start();
    api.allSendsGate = Completer<void>();
    await q.enqueue([textFile('a.txt'), textFile('b.txt')]);
    host.showPanel();
    await pump(tester);

    await tester.tap(find.byKey(UploadPanelKeys.close));
    await tester.pumpAndSettle();
    expect(find.text('Cancel 2 uploads?'), findsOneWidget);

    await tester.tap(find.text('Cancel uploads'));
    await tester.pumpAndSettle();

    expect(q.tasks, isEmpty);
    expect(host.panelVisible.value, isFalse);
    expect(api.calls.where((c) => c.startsWith('cancel:')), hasLength(2));
  });

  testWidgets('Given a running upload when its ✕ is pressed then only it is '
      'cancelled', (tester) async {
    await q.start();
    api.allSendsGate = Completer<void>();
    final [a, _] = await q.enqueue([textFile('a.txt'), textFile('b.txt')]);
    host.showPanel();
    await pump(tester);

    await tester.tap(find.byKey(UploadPanelKeys.action(a.id, 'cancel')));
    await tester.pumpAndSettle();

    expect(a.status, UploadStatus.cancelled);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Uploading 1 item'), findsOneWidget);
  });

  testWidgets('Given a failed upload when Retry is pressed then it '
      'uploads and the header says complete', (tester) async {
    await q.start();
    api.failNext(
      'create',
      'a.txt',
      WonkyException(code: WonkyErrorCode.limitExceeded, message: 'Wait'),
    );
    final [a] = await q.enqueue([textFile('a.txt')]);
    host.showPanel();
    await pump(tester);
    expect(find.text('1 upload failed'), findsOneWidget);

    await tester.tap(find.byKey(UploadPanelKeys.action(a.id, 'retry')));
    await tester.pumpAndSettle();

    expect(a.status, UploadStatus.done);
    expect(find.text('1 upload complete'), findsOneWidget);
  });

  testWidgets('Given the queue is empty when signed in then no panel shows', (
    tester,
  ) async {
    await q.start();
    await pump(tester);

    expect(find.byKey(UploadPanelKeys.panel), findsNothing);
    expect(find.byKey(UploadPanelKeys.pill), findsNothing);
  });

  testWidgets('Given 5 MB left when 3 files of 8 MB are uploaded from the '
      'UI then the pre-check dialog offers the files that fit (J-D3)', (
    tester,
  ) async {
    const mb = 1024 * 1024;
    final storage = FakeStorage.used(45 * mb);
    final h2 = CommandTestHarness(
      config: const DriveAppConfig(),
      storage: storage,
    );
    addTearDown(h2.dispose);
    final host2 = UploadHost.of(h2.services)..api = api;
    final q2 = UploadQueue(
      api: api,
      store: MemoryUploadStore(),
      connectivity: h2.services.connectivity,
      newId: sequentialIds(),
    );
    host2.attach(q2);
    addTearDown(host2.stop);
    await q2.start();
    await pumpWonky(
      tester,
      Builder(
        builder: (context) => GestureDetector(
          onTap: () => h2.services.dispatcher.invoke(
            'drive.upload.files',
            args: {
              'staged': host2.stage([
                textFile('a.bin', 3 * mb),
                textFile('b.bin', 4 * mb),
                textFile('c.bin', mb),
              ]),
            },
            context: context,
          ),
          child: const Text('upload'),
        ),
      ),
      // 360 px: the dialog stacks its three buttons.
      size: const Size(360, 800),
      extraDelegates: const [
        WonkyAppLocalizations.delegate,
        DriveLocalizations.delegate,
      ],
    );

    await tester.tap(find.text('upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Not enough storage for all files'), findsOneWidget);

    await tester.tap(find.text('Upload the files that fit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(q2.tasks.map((t) => t.fileName), ['a.bin', 'c.bin']);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
