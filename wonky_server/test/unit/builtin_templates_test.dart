import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/drive/templates/builtin_templates.dart';

void main() {
  group('Given the built-in document templates', () {
    test('when building the preview text then blocks stay on their own '
        'lines without Markdown syntax', () {
      final t = BuiltinTemplates.byKey('write.meeting-notes');
      final lines = t.previewText.split('\n');

      expect(lines.first, startsWith('# '));
      expect(t.previewText, isNot(contains('|')));
      expect(t.previewText, isNot(contains('**')));
      expect(lines.length, greaterThan(3));
    });

    test('when listing the gallery then every document template has its own '
        'built-in theme and a preview style with valid colors', () {
      final docs = [
        for (final t in BuiltinTemplates.all)
          if (t.inGallery && t.kind == DriveItemKind.document) t,
      ];
      final themes = {for (final t in docs) t.themeKey};

      expect(themes, hasLength(docs.length));
      expect(themes, isNot(contains(null)));
      for (final t in docs) {
        final style = t.previewStyle!;
        for (final c in [
          style.paper,
          style.text,
          style.heading,
          style.accent,
          style.darkPaper,
          style.darkText,
          style.darkHeading,
          style.darkAccent,
        ]) {
          expect(c, matches(RegExp(r'^#[0-9a-fA-F]{6}$')), reason: t.key);
        }
        expect(['serif', 'sans', 'mono'], contains(style.fontCategory));
      }
    });
  });
}
