import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';
import 'package:wonky_drive/features/preview/file_preview_controller.dart';
import 'package:wonky_drive/features/preview/preview_api.dart';
import 'package:wonky_drive/features/preview/preview_bars.dart';
import 'package:wonky_drive/features/preview/viewers/csv_table_viewer.dart';
import 'package:wonky_drive/features/preview/viewers/image_viewer.dart';
import 'package:wonky_drive/features/preview/viewers/pdf_viewer.dart';
import 'package:wonky_drive/features/preview/viewers/preview_states.dart';
import 'package:wonky_drive/features/preview/viewers/text_file_viewer.dart';
import 'package:wonky_drive/l10n/drive_l10n.dart';

import '../../support/preview_fakes.dart';

final l = driveL10nEnglish;

void main() {
  late PreviewTestbed t;

  setUp(() => t = PreviewTestbed());
  tearDown(() => t.dispose());

  FilePreviewController active() => t.host.active.value!;

  DriveItemView image({UuidValue? parent, String name = 'holiday.png'}) =>
      t.api.addFile(
        name,
        mimeType: 'image/png',
        category: FileCategory.image,
        content: PreviewFixtures.png,
        parentUuid: parent,
      );

  DriveItemView pdf({int pages = 3}) => t.api.addFile(
    'report.pdf',
    mimeType: 'application/pdf',
    category: FileCategory.pdf,
    content: PreviewFixtures.pdf(pages: pages),
  );

  DriveItemView dart() => t.api.addFile(
    'main.dart',
    mimeType: 'text/x-dart',
    category: FileCategory.text,
    content: PreviewFixtures.dart,
  );

  DriveItemView csv() => t.api.addFile(
    'scores.csv',
    mimeType: 'text/csv',
    category: FileCategory.spreadsheet,
    content: PreviewFixtures.csv,
  );

  DriveItemView zip() => t.api.addFile(
    'backup.zip',
    mimeType: 'application/zip',
    category: FileCategory.archive,
    sizeBytes: 13002342,
  );

  // ------------------------------------------------------------ viewers

  for (final b in Brightness.values) {
    for (final (sizeName, size) in [
      ('wide', const Size(1280, 800)),
      ('narrow', const Size(360, 640)),
    ]) {
      final variant = '${b.name}, $sizeName';

      group('Given the preview in $variant', () {
        testWidgets('when an image is opened then it is shown with the '
            'image tools', (tester) async {
          await t.pump(tester, image(), brightness: b, size: size);

          expect(find.byKey(ImageViewer.imageKey), findsOneWidget);
          expect(find.byKey(PreviewViewerBar.rotateKey), findsOneWidget);
          expect(find.text('holiday.png'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('when a PDF is opened then its pages are shown with '
            'the page field', (tester) async {
          await t.pump(tester, pdf(), brightness: b, size: size);

          expect(find.byKey(PdfViewer.pageKey(0)), findsOneWidget);
          expect(find.text(l.previewPdfPageOf(3)), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('when a Dart file is opened then it is highlighted '
            'code', (tester) async {
          await t.pump(tester, dart(), brightness: b, size: size);

          final view = tester.widget<CodeView>(
            find.byKey(TextFileViewer.codeKey),
          );
          expect(view.language, 'dart');
          expect(find.text(l.previewLines(4)), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('when a CSV is opened then it is a table', (tester) async {
          await t.pump(tester, csv(), brightness: b, size: size);

          expect(find.byKey(CsvTableViewer.tableKey), findsOneWidget);
          expect(find.text('Malmö'), findsOneWidget);
          expect(find.text('007'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('when another file type is opened then the card offers '
            'Download', (tester) async {
          await t.pump(tester, zip(), brightness: b, size: size);

          expect(find.byKey(UnsupportedFileView.cardKey), findsOneWidget);
          expect(
            find.text(l.previewTypeSize('ZIP archive', '12.4 MB')),
            findsOneWidget,
          );
          expect(find.byKey(UnsupportedFileView.downloadKey), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      });
    }
  }

  group('Given the preview screen for accessibility', () {
    for (final b in Brightness.values) {
      testWidgets('when a file card is shown in ${b.name} then tap targets '
          'are labeled and text has contrast', (tester) async {
        final handle = tester.ensureSemantics();
        await t.pump(tester, zip(), brightness: b);

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('when an image is shown in ${b.name} then it is labeled '
          'with its size', (tester) async {
        final handle = tester.ensureSemantics();
        await t.pump(tester, image(), brightness: b);

        expect(find.bySemanticsLabel('holiday.png, 4 by 3 pixels'), findsOne);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  // ------------------------------------------------------- malformed files

  group('Given malformed files', () {
    testWidgets('when bytes named .png are no image then the error state '
        'shows', (tester) async {
      final v = t.api.addFile(
        'broken.png',
        mimeType: 'image/png',
        category: FileCategory.image,
        content: PreviewFixtures.notAnImage,
      );

      await t.pump(tester, v);

      expect(find.text(l.previewImageBroken), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('when a PNG is truncated then the error state shows, not a '
        'crash', (tester) async {
      final v = t.api.addFile(
        'cut.png',
        mimeType: 'image/png',
        category: FileCategory.image,
        content: PreviewFixtures.truncatedPng,
      );

      await t.pump(tester, v);
      await t.settleImages(tester);

      expect(find.text(l.previewImageBroken), findsOneWidget);
      expect(find.byKey(ImageViewer.imageKey), findsNothing);
    });

    testWidgets('when a PDF is broken then the error state shows', (
      tester,
    ) async {
      final v = t.api.addFile(
        'broken.pdf',
        mimeType: 'application/pdf',
        category: FileCategory.pdf,
        content: PreviewFixtures.brokenPdf,
      );

      await t.pump(tester, v);

      expect(find.text(l.previewPdfBroken), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('when a PDF is encrypted then the password state offers '
        'Download', (tester) async {
      final v = t.api.addFile(
        'secret.pdf',
        mimeType: 'application/pdf',
        category: FileCategory.pdf,
        content: PreviewFixtures.encryptedPdf,
      );

      await t.pump(tester, v);

      expect(find.text(l.previewPdfPassword), findsOneWidget);
      expect(find.byKey(UnsupportedFileView.downloadKey), findsOneWidget);
    });

    testWidgets('when pdf.js is not available then PDFs ask to download', (
      tester,
    ) async {
      t.rasterizer.isAvailable = false;

      await t.pump(tester, pdf());

      expect(find.text(l.previewPdfUnavailable), findsOneWidget);
    });

    testWidgets('when a .txt file holds binary data then the error state '
        'shows', (tester) async {
      final v = t.api.addFile(
        'data.txt',
        mimeType: 'text/plain',
        category: FileCategory.text,
        content: PreviewFixtures.binaryText,
      );

      await t.pump(tester, v);

      expect(find.text(l.previewNotText), findsOneWidget);
      expect(find.byType(CodeView), findsNothing);
    });

    testWidgets('when a .jpg is really HTML then its source is shown as '
        'text', (tester) async {
      final v = t.api.addFile(
        'cat.jpg',
        mimeType: 'text/html',
        category: FileCategory.text,
        content: PreviewFixtures.html,
      );

      await t.pump(tester, v);

      final view = tester.widget<CodeView>(find.byKey(TextFileViewer.codeKey));
      expect(view.code, contains('<script>'));
      expect(view.language, 'html');
      expect(find.byKey(ImageViewer.imageKey), findsNothing);
    });

    testWidgets('when a text file is Latin-1 then the notice shows', (
      tester,
    ) async {
      final v = t.api.addFile(
        'old.txt',
        mimeType: 'text/plain',
        category: FileCategory.text,
        content: PreviewFixtures.latin1Text,
      );

      await t.pump(tester, v);

      expect(find.byKey(PreviewNotices.latin1Key), findsOneWidget);
      expect(find.text(l.previewLatin1), findsOneWidget);
    });
  });

  // ------------------------------------------------------------ states

  group('Given preview states', () {
    testWidgets('when the bytes are slow then a skeleton and, after 300 ms, '
        'a spinner show', (tester) async {
      t.api.fetchGate = Completer<void>();

      await t.pump(tester, image(), settle: false);
      await tester.pump();

      expect(find.byKey(const ValueKey('drive.preview.skeleton')), findsOne);
      expect(find.byKey(const ValueKey('drive.preview.spinner')), findsNothing);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('drive.preview.spinner')), findsOne);

      t.api.fetchGate!.complete();
      await t.settleImages(tester);
      expect(find.byKey(ImageViewer.imageKey), findsOneWidget);
    });

    testWidgets('when loading fails then Retry loads again', (tester) async {
      t.api.fetchFailsWith = const PreviewFetchException('HTTP 500');
      final v = image();
      await t.pump(tester, v);
      expect(find.text(l.previewErrorTitle), findsOneWidget);

      t.api.fetchFailsWith = null;
      await tester.tap(find.byKey(const ValueKey('drive.preview.retry')));
      await t.settleImages(tester);

      expect(find.byKey(ImageViewer.imageKey), findsOneWidget);
    });

    testWidgets('when offline and not cached then the offline state shows', (
      tester,
    ) async {
      t.api.fetchFailsWith = const OfflineException('down');

      await t.pump(tester, image());

      expect(find.text(l.previewOfflineTitle), findsOneWidget);
    });

    testWidgets('when offline but cached then the preview still shows', (
      tester,
    ) async {
      final v = image();
      await t.pump(tester, v);
      t.api.fetchFailsWith = const OfflineException('down');

      await active().load();
      await t.settleImages(tester);

      expect(find.byKey(ImageViewer.imageKey), findsOneWidget);
    });

    testWidgets('when the file is still uploading then progress shows and '
        'the preview appears once ready', (tester) async {
      final v = t.api.addFile(
        'big.png',
        mimeType: 'image/png',
        category: FileCategory.image,
        content: PreviewFixtures.png,
        uploadState: FileUploadState.uploading,
        sizeBytes: 200,
      );
      t.api.status = FileUploadProgress(
        uploadState: FileUploadState.uploading,
        receivedBytes: 84,
      );

      await t.pump(tester, v, settle: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text(l.previewUploadingPercent(42)), findsOneWidget);

      t.api.items[v.uuid] = v.copyWith(
        uploadState: FileUploadState.ready,
        sizeBytes: PreviewFixtures.png.length,
      );
      t.api.status = FileUploadProgress(uploadState: FileUploadState.ready);
      await tester.pump(const Duration(seconds: 3));
      await t.settleImages(tester);

      expect(find.byKey(ImageViewer.imageKey), findsOneWidget);
    });

    testWidgets('when the file does not exist then the not-found state shows', (
      tester,
    ) async {
      await t.pumpAt(tester, '/file/0192c6a4-0000-7000-8000-000000000999');

      expect(find.text(l.previewNotFoundTitle), findsOneWidget);
    });

    testWidgets('when an image is over 4 MB then the server preview is '
        'shown', (tester) async {
      final v = t.api.addFile(
        'huge.png',
        mimeType: 'image/png',
        category: FileCategory.image,
        content: PreviewFixtures.notAnImage,
        sizeBytes: 9 * 1024 * 1024,
        fileMetaJson: '{"width":6000,"height":4000}',
        preview: PreviewFixtures.png,
      );

      await t.pump(tester, v);

      expect(find.byKey(ImageViewer.imageKey), findsOneWidget);
      expect(t.api.calls, contains('storedFileUrl'));
      expect(find.text(l.previewImageSize(6000, 4000)), findsOneWidget);
    });

    testWidgets('when a large image has no server preview then it is too '
        'large to preview', (tester) async {
      final v = t.api.addFile(
        'huge.png',
        mimeType: 'image/png',
        category: FileCategory.image,
        sizeBytes: 9 * 1024 * 1024,
      );

      await t.pump(tester, v);

      expect(find.text(l.previewTooLargeTitle), findsOneWidget);
      expect(t.api.calls, isNot(contains('fetch')));
    });

    testWidgets('when the file is trashed then the banner restores it', (
      tester,
    ) async {
      final v = t.api.addFile(
        'old.png',
        mimeType: 'image/png',
        category: FileCategory.image,
        content: PreviewFixtures.png,
        trashedAt: DateTime.utc(2026, 10, 2),
      );
      t.h.drive.seed(
        name: 'old.png',
        kind: DriveItemKind.file,
        uuid: v.uuid,
        trashedAt: DateTime.utc(2026, 10, 2),
      );

      await t.pump(tester, v);
      expect(find.text(l.previewTrashedBanner), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('drive.preview.restore')));
      await t.settleImages(tester);

      expect(t.h.drive.calls, contains('restore'));
      expect(find.text(l.previewTrashedBanner), findsNothing);
    });

    testWidgets('when viewers may not download then Download is hidden', (
      tester,
    ) async {
      final v = t.api.addFile(
        'private.zip',
        mimeType: 'application/zip',
        category: FileCategory.archive,
        sizeBytes: 10,
        role: AccessRole.viewer,
        nonEditorsCanExport: false,
      );

      await t.pump(tester, v);

      expect(find.byKey(PreviewTopBar.downloadKey), findsNothing);
      expect(find.byKey(UnsupportedFileView.downloadKey), findsNothing);
    });
  });

  // ------------------------------------------------------------ commands

  group('Given the image preview', () {
    testWidgets('when zooming with the keyboard then the zoom steps and '
        '0 fits again', (tester) async {
      await t.pump(tester, image());
      expect(active().zoom, isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      expect(active().zoom, 1.0);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      expect(active().zoom, 1.25);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
      expect(active().zoom, 0.9);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();

      expect(active().zoom, isNull);
    });

    testWidgets('when R is pressed then the view rotates and nothing is '
        'saved', (tester) async {
      await t.pump(tester, image());

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();

      expect(active().quarterTurns, 1);
      expect(t.api.calls.where((c) => c.startsWith('update')), isEmpty);
    });

    testWidgets('when the zoom is at its maximum then zooming in stays '
        'there', (tester) async {
      await t.pump(tester, image());

      for (var i = 0; i < 20; i++) {
        await t.h.invoke('drive.preview.zoomIn');
      }

      expect(active().zoom, 8.0);
    });
  });

  group('Given a folder of files', () {
    late DriveItemView folder;
    late DriveItemView a;
    late DriveItemView b;
    late DriveItemView c;

    setUp(() {
      folder = t.api.addFolder('Holiday');
      a = image(parent: folder.uuid, name: 'a.png');
      b = t.api.addFile(
        'b.dart',
        mimeType: 'text/x-dart',
        category: FileCategory.text,
        content: PreviewFixtures.dart,
        parentUuid: folder.uuid,
      );
      t.api.addFile(
        'b2-uploading.png',
        mimeType: 'image/png',
        category: FileCategory.image,
        parentUuid: folder.uuid,
        uploadState: FileUploadState.uploading,
      );
      c = image(parent: folder.uuid, name: 'c.png');
    });

    testWidgets('when the second file is open then the position counts '
        'ready files only', (tester) async {
      await t.pump(tester, b);

      expect(find.text(l.previewPosition(2, 3, 'Holiday')), findsOneWidget);
    });

    testWidgets('when → is pressed then the next file opens and ← goes '
        'back', (tester) async {
      await t.pump(tester, a);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.settleImages(tester);
      expect(active().itemUuid, b.uuid);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.settleImages(tester);
      expect(active().itemUuid, c.uuid);
      expect(active().hasNext, isFalse);

      await tester.tap(find.byKey(const ValueKey('drive.preview.previous')));
      await t.settleImages(tester);
      expect(active().itemUuid, b.uuid);
    });

    testWidgets('when Esc is pressed after stepping then the folder opens '
        'with the file selected', (tester) async {
      await t.pumpAt(tester, '/f/${folder.uuid.uuid}');
      t.router.go('/file/${a.uuid.uuid}');
      await t.settleImages(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.settleImages(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('folder ${folder.uuid.uuid}'), findsOneWidget);
      expect(t.services.driveSelection.value.single.uuid, b.uuid);
    });
  });

  group('Given the PDF preview', () {
    testWidgets('when going to a page then the page indicator follows', (
      tester,
    ) async {
      await t.pump(tester, pdf(pages: 24));

      final r = await t.h.invoke('drive.preview.goToPage', {'page': 20});
      await tester.pumpAndSettle();

      expect(r.isOk, isTrue);
      expect(active().pdfPage, 19);
      expect(find.byKey(PdfViewer.pageKey(19)), findsOneWidget);
    });

    testWidgets('when going to a page out of range then it fails', (
      tester,
    ) async {
      await t.pump(tester, pdf(pages: 2));

      final r = await t.h.invoke('drive.preview.goToPage', {'page': 9});

      expect(r.isOk, isFalse);
    });

    testWidgets('when Mod+G is pressed then the dialog goes to the page', (
      tester,
    ) async {
      await t.pump(tester, pdf(pages: 10));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(find.text(l.previewGoToPageTitle), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, '7');
      await tester.tap(find.text(l.previewGo));
      await tester.pumpAndSettle();

      expect(active().pdfPage, 6);
    });

    testWidgets('when an editor views it then the page count is written '
        'back once', (tester) async {
      await t.pump(tester, pdf(pages: 4));

      expect(t.api.calls.where((c) => c.startsWith('updateFileMeta')), [
        'updateFileMeta:{"pages":4}',
      ]);
    });
  });

  group('Given the text preview', () {
    testWidgets('when Alt+Z is pressed then lines wrap', (tester) async {
      await t.pump(tester, dart());

      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pump();

      final view = tester.widget<CodeView>(find.byKey(TextFileViewer.codeKey));
      expect(view.wrap, isTrue);
    });

    testWidgets('when Copy all is pressed then the text is on the '
        'clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await t.pump(tester, dart());

      await tester.tap(find.byKey(PreviewViewerBar.copyKey));
      await tester.pump();

      expect(copied, startsWith("import 'dart:math';"));
    });
  });

  group('Given the CSV preview', () {
    testWidgets('when switching to Text then the source shows', (tester) async {
      await t.pump(tester, csv());

      await tester.tap(find.byKey(PreviewViewerBar.textKey));
      await tester.pumpAndSettle();

      expect(find.byKey(CsvTableViewer.tableKey), findsNothing);
      final view = tester.widget<CodeView>(find.byKey(TextFileViewer.codeKey));
      expect(view.code, startsWith('Name;City;Score'));
    });

    testWidgets('when Open with is chosen then Wonky Sheets imports it in '
        'the same tab', (tester) async {
      final v = csv();
      await t.pump(tester, v);

      await t.h.invoke('drive.file.openWith');

      expect(t.h.crossApp.opened.single, (
        WonkyAppKind.sheets,
        '/import?file=${v.uuid.uuid}',
      ));
    });
  });

  group('Given a downloadable file', () {
    testWidgets('when Download is pressed then the download URL is clicked '
        'in the same tab', (tester) async {
      final v = zip();
      await t.pump(tester, v);

      await tester.tap(find.byKey(PreviewTopBar.downloadKey));
      await tester.pumpAndSettle();

      expect(t.downloader.downloads.single, (
        'https://files.test/d/${v.uuid.uuid}/backup.zip',
        'backup.zip',
      ));
    });

    testWidgets('when downloads are not available then it fails with a '
        'message', (tester) async {
      t.downloader.works = false;
      await t.pump(tester, zip());

      final r = await t.h.invoke('drive.file.download');

      expect(r.isOk, isFalse);
      expect(r.message, l.previewDownloadUnavailable);
    });

    testWidgets('when downloading by uuid then no preview is needed', (
      tester,
    ) async {
      final v = zip();

      final r = await t.h.invoke('drive.file.download', {
        'uuids': [v.uuid.uuid],
      });

      expect(r.isOk, isTrue);
      expect(t.downloader.downloads, hasLength(1));
    });
  });
}
