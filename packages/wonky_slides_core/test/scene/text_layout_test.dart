import 'package:test/test.dart';
import 'package:wonky_slides_core/scene.dart';

void main() {
  group('Given text body JSON', () {
    final cases = <(String?, String)>[
      (null, '\n'),
      ('', '\n'),
      ('not json', '\n'),
      (
        '[{"insert":"Hello "},{"insert":"world\\n","attributes":{"bold":true}}]',
        'Hello world\n',
      ),
      ('{"ops":[{"insert":"Ops\\n"}]}', 'Ops\n'),
    ];
    for (final (json, text) in cases) {
      test('when parsing ${json ?? 'null'} then the plain text is '
          '${text.replaceAll('\n', r'\n')}', () {
        expect(TextBody.fromJson(json).plainText, text);
      });
    }

    test('when building a plain body then it ends with a newline and '
        'round-trips', () {
      final body = TextBody.plain('Hi');

      expect(TextBody.fromJson(body.toJson()).plainText, 'Hi\n');
      expect(TextBody.empty.isBlank, isTrue);
    });
  });

  group('Given an image reference', () {
    test('when it is an uploaded file then the file uuid is exposed', () {
      expect(const SlideImageRef('wonky-file://abc').fileUuid, 'abc');
      expect(const SlideImageRef('https://x/y.png').fileUuid, isNull);
    });
  });
}
