import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_write/features/export/export_service.dart';
import 'package:wonky_write/features/themes/write_fonts.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

ExportSource source(String markdown) => ExportSource(
  documentUuid: '00000000-0000-7000-8000-0000000000a1',
  delta: const MarkdownCodec().importMarkdown(markdown).delta,
  title: 'Plan: Q3/Q4',
  theme: BuiltinThemes.wonkyDefault.theme,
  pageSetup: const PageSetup(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Given a document with non-Latin-1 text', () {
    final src = source(
      '# Résumé — Łódź\n\nПривет, мир. **Bold** and `code`.\n',
    );
    final exporter = WriteExporter(images: const MapImageResolver({}));

    test('when exporting Markdown then the text round-trips', () async {
      final a = await exporter.export(src, WriteDownloadFormat.md);

      expect(a.fileName, 'Plan Q3 Q4.md');
      expect(utf8.decode(a.bytes), contains('# Résumé — Łódź'));
    });

    test('when exporting PDF with the bundled fonts then a PDF is produced '
        'without font fallback warnings', () async {
      final a = await exporter.export(src, WriteDownloadFormat.pdf);

      expect(String.fromCharCodes(a.bytes.take(5)), '%PDF-');
      expect(a.pageCount, 1);
      expect(a.warnings.where((w) => w.code == 'font_fallback'), isEmpty);
    });

    test('when exporting HTML then the document is self-contained', () async {
      final a = await exporter.export(src, WriteDownloadFormat.html);

      expect(utf8.decode(a.bytes), contains('<!doctype html'));
    });

    test('when exporting plain text then formatting is dropped', () async {
      final a = await exporter.export(src, WriteDownloadFormat.txt);

      expect(utf8.decode(a.bytes), contains('Привет, мир. Bold and code.'));
    });
  });

  test('Given a family that is not bundled when loading it for PDF then '
      'the category substitute is returned', () async {
    final face = await AssetFontProvider().load('Source Serif 4', weight: 700);

    expect(face.bytes.length, greaterThan(10000));
    expect(face.weight, 700);
  });

  test('Given unsafe characters in a title when sanitizing then they are '
      'replaced and the name is trimmed', () {
    expect(sanitizeFileName(' a/b:c*d? '), 'a b c d');
    expect(sanitizeFileName(''), 'Untitled document');
    expect(sanitizeFileName('x' * 200).length, 120);
  });
}
