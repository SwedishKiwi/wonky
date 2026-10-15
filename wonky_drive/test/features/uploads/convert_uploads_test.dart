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

/// *Convert uploads to Wonky formats* (Drive 02 §7.3, Drive 04 §8; default
/// off, v2 review Q13): convertible uploads become documents and
/// spreadsheets, everything else stays a file.
void main() {
  late CommandTestHarness h;
  late FakeUploadApi api;
  late UploadHost host;
  late UploadQueue q;

  setUp(() async {
    h = CommandTestHarness(config: const DriveAppConfig());
    api = FakeUploadApi()
      ..onReady = (v) => h.drive.seed(
        name: v.name,
        kind: v.kind,
        uuid: v.uuid,
        parentUuid: v.parentUuid,
      );
    host = UploadHost.of(h.services)..api = api;
    q = UploadQueue(
      api: api,
      store: MemoryUploadStore(),
      connectivity: h.services.connectivity,
      newId: sequentialIds(),
    );
    host.attach(q);
    await q.start();
  });

  tearDown(() async {
    await host.stop();
    await h.dispose();
  });

  Future<void> upload(List<UploadFile> files) async {
    await h.invoke('drive.upload.files', {'staged': host.stage(files)});
    await settle();
  }

  UploadTask task(String name) =>
      q.tasks.singleWhere((t) => t.fileName == name);

  test('Given the setting is off when convertible files are uploaded then '
      'they stay files', () async {
    await upload([textFile('notes.md'), textFile('data.csv')]);

    expect(api.calls.where((c) => c.startsWith('convert')), isEmpty);
    expect(
      q.tasks.map((t) => t.result!.kind),
      everyElement(DriveItemKind.file),
    );
  });

  group('Given Convert uploads is on', () {
    setUp(() async {
      await h.invoke('drive.prefs.set', {
        'key': 'convertUploads',
        'value': true,
      });
    });

    test(
      'when Markdown, CSV and an image are uploaded then the first two '
      'become a document and a spreadsheet and the image stays a file',
      () async {
        await upload([
          textFile('notes.md'),
          textFile('data.csv'),
          textFile('photo.png'),
        ]);

        expect(task('notes.md').result!.kind, DriveItemKind.document);
        expect(task('notes.md').result!.name, 'notes');
        expect(task('data.csv').result!.kind, DriveItemKind.spreadsheet);
        expect(task('photo.png').result!.kind, DriveItemKind.file);
        expect(
          api.calls,
          containsAll(['convert:notes.md', 'convert:data.csv']),
        );
        expect(api.calls, isNot(contains('convert:photo.png')));
      },
    );

    test('when the batch is undone then the converted items are trashed '
        'and redo restores them', () async {
      await upload([textFile('notes.md')]);
      final doc = task('notes.md').result!.uuid;

      await h.undo();
      expect(h.drive.item(doc).isTrashed, isTrue);
      await h.redo();
      expect(h.drive.item(doc).isTrashed, isFalse);
    });

    test(
      'when the conversion fails then the file is kept and marked',
      () async {
        api.failNext(
          'convert',
          'broken.docx',
          WonkyException(code: WonkyErrorCode.invalidArgument, message: 'bad'),
        );

        await upload([textFile('broken.docx')]);

        final t = task('broken.docx');
        expect(t.status, UploadStatus.done);
        expect(t.result!.kind, DriveItemKind.file);
        expect(t.conversionFailed, isTrue);
      },
    );

    testWidgets('when the panel shows a converted upload then the row says '
        'what it became', (tester) async {
      await tester.runAsync(() => upload([textFile('notes.md')]));
      host.showPanel();
      await pumpWonky(
        tester,
        UploadPanelLayer(services: h.services, child: const SizedBox.expand()),
        extraDelegates: const [
          WonkyAppLocalizations.delegate,
          DriveLocalizations.delegate,
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text(driveL10nEnglish.uploadStatusConverted('document')),
        findsOneWidget,
      );
    });
  });
}
