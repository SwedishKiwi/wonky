import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given an image spec', () {
    test('when round-tripping then unknown keys survive', () {
      final json = {
        'v': 1,
        'fileUuid': '0193a3c2-0000-7000-8000-0000000000aa',
        'mime': 'image/jpeg',
        'naturalWidth': 1200,
        'naturalHeight': 800,
        'crop': {'l': 0.1, 't': 0, 'r': 0, 'b': 0.2},
        'fit': 'contain',
        'sourceUrl': 'https://example.test/a.jpg',
        'future': 1,
      };
      final s = ImageSpec.fromJson(json);
      expect(s.fit, ImageFit.contain);
      expect(s.toJson(), json);
      expect(ImageSpec.fromJson(s.encode()), s);
      expect(s.fileUrl, 'wonky-file://0193a3c2-0000-7000-8000-0000000000aa');
    });
  });
}
