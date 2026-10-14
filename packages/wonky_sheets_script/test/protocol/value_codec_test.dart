import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

void main() {
  group('Given the value codec', () {
    final cases = <(String, Object?)>[
      ('null', null),
      ('booleans', [true, false]),
      ('small and large ints', [0, -1, 127, -128, 128, 1 << 40, -(1 << 40)]),
      ('doubles', [0.5, -2.25, double.infinity]),
      ('strings', ['', 'hello', 'åäö 🎉']),
      ('cell errors', const [CellError('#N/A'), CellError('#ERROR!', 'boom')]),
      (
        'nested lists',
        [
          [1, 'a'],
          [null, true],
        ],
      ),
      (
        'maps',
        {
          'a': 1,
          'b': {'c': 'd'},
        },
      ),
    ];
    for (final (name, value) in cases) {
      test('when round-tripping $name then the value is unchanged', () {
        expect(ValueCodec.decode(ValueCodec.encode(value)), value);
      });
    }

    test(
      'when round-tripping a DateTime then instant and zone flag survive',
      () {
        final d = DateTime.utc(2024, 3, 15, 10, 30, 1, 2, 3);
        final back = ValueCodec.decode(ValueCodec.encode(d))! as DateTime;
        expect(back, d);
        expect(back.isUtc, isTrue);
      },
    );

    test('when round-tripping bytes then they stay bytes', () {
      final b = Uint8List.fromList([1, 2, 255]);
      expect(ValueCodec.decode(ValueCodec.encode(b)), b);
    });

    test('when encoding an unsupported value then it throws', () {
      expect(() => ValueCodec.encode(Object()), throwsArgumentError);
    });
  });

  group('Given host replies', () {
    test(
      'when an error reply is encoded then code, message and status survive',
      () {
        const reply = HostReply.error(
          ScriptError('url_fetch', 'nope', statusCode: 404),
        );
        final back = HostReply.decode(reply.encode());
        expect(back.isError, isTrue);
        expect(back.error!.code, 'url_fetch');
        expect(back.error!.message, 'nope');
        expect(back.error!.statusCode, 404);
      },
    );
  });
}
