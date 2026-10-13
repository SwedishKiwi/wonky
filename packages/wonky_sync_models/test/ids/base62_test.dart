import 'package:test/test.dart';
import 'package:wonky_sync_models/ids.dart';

void main() {
  group('Given the base-62 UUID codec', () {
    const cases = [
      ('00000000-0000-0000-0000-000000000000', '0000000000000000000000'),
      ('ffffffff-ffff-ffff-ffff-ffffffffffff', '7n42DGM5Tflk9n8mt7Fhc7'),
      ('00000000-0000-0000-0000-000000000001', '0000000000000000000001'),
      ('00000000-0000-0000-0000-00000000003e', '0000000000000000000010'),
    ];
    for (final (uuid, id22) in cases) {
      test('when encoding $uuid then it is $id22', () {
        expect(Base62Uuid.encode(uuid), id22);
      });
      test('when decoding $id22 then it is $uuid', () {
        expect(Base62Uuid.decode(id22), uuid);
      });
    }

    test(
      'when encoding upper-case UUIDs then the result equals lower-case',
      () {
        const u = '94020249-01B0-4143-B745-68F9AA91516F';
        expect(Base62Uuid.encode(u), Base62Uuid.encode(u.toLowerCase()));
      },
    );

    test('when decoding a malformed id then a FormatException is thrown', () {
      expect(() => Base62Uuid.decode('abc'), throwsFormatException);
      expect(
        () => Base62Uuid.decode('000000000000000000000!'),
        throwsFormatException,
      );
      expect(
        () => Base62Uuid.decode('zzzzzzzzzzzzzzzzzzzzzz'),
        throwsFormatException,
      );
    });

    test('when validating then only well-formed ids are valid', () {
      expect(Base62Uuid.isValid('0000000000000000000001'), isTrue);
      expect(Base62Uuid.isValid('zzzzzzzzzzzzzzzzzzzzzz'), isFalse);
      expect(Base62Uuid.isValid('short'), isFalse);
    });

    test(
      'when round-tripping random ids then encode/decode are inverse and order-preserving',
      () {
        final gen = SeededIdGenerator(42);
        final ids = List.generate(500, (_) => gen.newId());
        for (final id in ids) {
          expect(Base62Uuid.decode(Base62Uuid.encode(id)), id);
        }
        final byUuid = [...ids]..sort();
        final byEncoded = [
          ...ids,
        ]..sort((a, b) => Base62Uuid.encode(a).compareTo(Base62Uuid.encode(b)));
        expect(byEncoded, byUuid);
      },
    );
  });
}
