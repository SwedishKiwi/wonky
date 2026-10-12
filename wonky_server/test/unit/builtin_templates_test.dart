import 'package:test/test.dart';
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
  });
}
