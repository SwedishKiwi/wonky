@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_drive/config/drive_app_config.dart';
import 'package:wonky_drive/features/uploads/upload_host.dart';
import 'package:wonky_drive/features/uploads/upload_panel.dart';
import 'package:wonky_drive/features/uploads/upload_queue.dart';
import 'package:wonky_drive/features/uploads/upload_store.dart';
import 'package:wonky_drive/features/uploads/upload_task.dart';
import 'package:wonky_drive/l10n/drive_l10n.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/upload_fakes.dart';

/// Golden images of the upload panel states (Drive 05 D-13: running,
/// waiting for the connection, finished with failures, collapsed) in light
/// and dark, wide and at 360 px. Masters are made and compared on CI Linux
/// only (specs/15 §7): run locally with `-x golden`.
void main() {
  late CommandTestHarness h;
  late UploadHost host;
  late UploadQueue q;

  setUp(() {
    h = CommandTestHarness(config: const DriveAppConfig());
    host = UploadHost.of(h.services)..api = FakeUploadApi();
    q = UploadQueue(
      api: host.api,
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

  final states = <String, FutureOr<void> Function(List<UploadTask>)>{
    'running': (t) {
      t[0]
        ..status = UploadStatus.uploading
        ..bytesSent = 42;
      t[1].status = UploadStatus.queued;
      t[2].status = UploadStatus.verifying;
    },
    'waiting': (t) {},
    'finished': (t) {
      t[0].status = UploadStatus.done;
      t[1]
        ..status = UploadStatus.failed
        ..failure = UploadFailure.outOfStorage;
      t[2]
        ..status = UploadStatus.failed
        ..failure = UploadFailure.network;
    },
    'collapsed': (t) {
      t[0]
        ..status = UploadStatus.uploading
        ..bytesSent = 42;
      host.panelCollapsed.value = true;
    },
  };

  for (final b in Brightness.values) {
    for (final (variant, size) in [
      ('wide', const Size(800, 480)),
      ('narrow', const Size(360, 480)),
    ]) {
      for (final e in states.entries) {
        testWidgets('upload panel ${e.key} $variant ${b.name}', (tester) async {
          await q.start();
          h.services.connectivity.forceOffline(true);
          final tasks = await q.enqueue([
            textFile('interview-recording.m4a', 100),
            textFile('notes.pdf', 100),
            textFile('main.dart', 100),
          ]);
          await e.value(tasks);
          host.showPanel();
          if (e.key == 'collapsed') host.panelCollapsed.value = true;
          await pumpWonky(
            tester,
            UploadPanelLayer(
              services: h.services,
              child: const SizedBox.expand(),
            ),
            brightness: b,
            size: size,
            extraDelegates: const [
              WonkyAppLocalizations.delegate,
              DriveLocalizations.delegate,
            ],
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(UploadPanelLayer),
            matchesGoldenFile('upload_panel_${e.key}_${variant}_${b.name}.png'),
          );
        });
      }
    }
  }
}
