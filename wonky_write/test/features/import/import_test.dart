import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show ImportWarningView, UuidValue;
import 'package:wonky_write/features/import/import_service.dart';
import 'package:wonky_write/features/import/import_warnings_banner.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../screen/support/screen_harness.dart';

Future<ExportArtifact> _docx(String markdown, {bool withImage = false}) {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAAEklEQVR4nGORq7jDAAYsDDAAABnSAXu4ADnlAAAAAElFTkSuQmCC',
  );
  return const DocxExporter().export(
    ExportInput(
      document: const MarkdownCodec().importMarkdown(markdown).delta,
      meta: const DocMeta(title: 'Imported plan'),
      theme: BuiltinThemes.wonkyDefault.theme,
      images: MapImageResolver({
        if (withImage)
          'https://example.com/i.png': ResolvedImage(
            bytes: png,
            mime: 'image/png',
            widthPx: 3,
            heightPx: 2,
          ),
      }),
      fonts: InMemoryFontProvider(const []),
      now: DateTime.utc(2026),
    ),
    const OfficeExportOptions(),
  );
}

void main() {
  group('Given a Word file', () {
    test(
      'when converting it then the title and content are taken from it',
      () async {
        final a = await _docx('# Plan\n\nSome **bold** text.\n');

        final c = await convertImport('plan.docx', a.bytes);

        expect(c.name, 'Imported plan');
        expect(c.markdown, '# Plan\n\nSome **bold** text.\n');
      },
    );

    test(
      'when converting with an uploader then images become stored files',
      () async {
        final a = await _docx(
          'Pic:\n\n![Dot](https://example.com/i.png)\n',
          withImage: true,
        );
        final uploaded = <ImportedImage>[];

        final c = await convertImport(
          'pic.docx',
          a.bytes,
          uploadImage: (image) async {
            uploaded.add(image);
            return '0192aaaa-0000-7000-8000-0000000000b1';
          },
        );

        expect(uploaded.single.mime, 'image/png');
        expect(
          c.markdown,
          'Pic:\n\n![Dot](wonky-file://0192aaaa-0000-7000-8000-0000000000b1)\n',
        );
      },
    );

    test(
      'when converting without an uploader then images become placeholders',
      () async {
        final a = await _docx(
          '![Dot](https://example.com/i.png)\n',
          withImage: true,
        );

        final c = await convertImport('pic.docx', a.bytes);

        expect(c.markdown, '\\[image: Dot\\]\n');
        expect(c.warnings, isNotEmpty);
      },
    );
  });

  test(
    'Given import file names when picking types then every format is accepted',
    () {
      expect(
        writeImportExtensions,
        containsAll(['docx', 'odt', 'rtf', 'html', 'md', 'txt']),
      );
      expect(importMimeType('a.docx'), ExportFormat.docx.mimeType);
      expect(importMimeType('a.rtf'), 'application/rtf');
    },
  );

  group('Given an imported document with warnings', () {
    testWidgets('when it opens then the banner lists them until dismissed', (
      tester,
    ) async {
      final h = await ScreenHarness.open(tester);
      await h.pump(
        tester,
        ImportWarningsBanner(
          services: h.services,
          documentUuid: UuidValue.withValidation(
            '0192aaaa-0000-7000-8000-0000000000c1',
          ),
          loadWarnings: (_) async => [
            ImportWarningView(
              kind: 'commentsDropped',
              message: 'Comments in the document were not imported.',
            ),
            ImportWarningView(
              kind: 'formattingRemoved',
              message: 'Formatting not supported in Markdown was removed.',
            ),
          ],
          child: const Text('canvas'),
        ),
      );
      await tester.pump();

      expect(
        find.text("2 elements couldn't be imported exactly"),
        findsOneWidget,
      );
      expect(find.text('canvas'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('write.importBanner.details')),
      );
      await tester.pump();
      expect(
        find.text('• Comments in the document were not imported.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('write.importBanner.dismiss')),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('write.importBanner')), findsNothing);
      expect(find.text('canvas'), findsOneWidget);
      await h.dispose(tester);
    });
  });
}
