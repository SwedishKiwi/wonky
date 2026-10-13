import 'package:test/test.dart';
import 'package:wonky_sync_models/ids.dart';

void main() {
  group('Given the fractional index', () {
    const betweenCases = [
      (null, null, 'a0'),
      (null, 'a0', 'Zz'),
      ('a0', null, 'a1'),
      ('a0', 'a1', 'a0V'),
      ('a1', 'a2', 'a1V'),
      ('a0V', 'a1', 'a0l'),
      ('Zz', 'a0', 'ZzV'),
      ('Zz', 'a1', 'a0'),
      (null, 'Y00', 'Xzzz'),
      ('bzz', null, 'c000'),
      ('a0', 'a0V', 'a0G'),
      ('a0', 'a0G', 'a08'),
      ('b125', 'b129', 'b127'),
      ('a0', 'a1V', 'a1'),
      ('Zz', 'a01', 'a0'),
      (null, 'a0V', 'a0'),
      (null, 'b999', 'b99'),
      ('az', null, 'b00'),
    ];
    for (final (a, b, expected) in betweenCases) {
      test('when generating a key between $a and $b then it is $expected', () {
        expect(FractionalIndex.between(a, b), expected);
      });
    }

    const invalid = [
      ('a00', null),
      ('a00', 'a1'),
      ('0', '1'),
      ('a1', 'a0'),
      ('a0', 'a0'),
    ];
    for (final (a, b) in invalid) {
      test(
        'when generating a key between invalid $a and $b then it throws',
        () {
          expect(() => FractionalIndex.between(a, b), throwsArgumentError);
        },
      );
    }

    test(
      'when generating n keys after null then they are consecutive integers',
      () {
        expect(FractionalIndex.nBetween(null, null, 5), [
          'a0',
          'a1',
          'a2',
          'a3',
          'a4',
        ]);
      },
    );

    test(
      'when generating n keys before a key then they ascend and precede it',
      () {
        expect(FractionalIndex.nBetween(null, 'a0', 3), ['Zx', 'Zy', 'Zz']);
      },
    );

    test(
      'when generating n keys between two keys then they ascend inside the interval',
      () {
        final keys = FractionalIndex.nBetween('a0', 'a1', 20);
        expect(keys, hasLength(20));
        expect(keys.first.compareTo('a0'), greaterThan(0));
        expect(keys.last.compareTo('a1'), lessThan(0));
        expect([...keys]..sort(), keys);
      },
    );

    test('when generating 0 keys then the list is empty', () {
      expect(FractionalIndex.nBetween('a0', 'a1', 0), isEmpty);
    });

    test(
      'when validating keys then trailing zeros and bad heads are invalid',
      () {
        expect(FractionalIndex.isValid('a0'), isTrue);
        expect(FractionalIndex.isValid('a0V'), isTrue);
        expect(FractionalIndex.isValid('a00'), isFalse);
        expect(FractionalIndex.isValid('0a'), isFalse);
        expect(FractionalIndex.isValid('a'), isFalse);
      },
    );

    test('when comparing equal keys then the id breaks the tie', () {
      expect(FractionalIndex.compare('a0', 'x', 'a0', 'y'), lessThan(0));
      expect(FractionalIndex.compare('a1', 'a', 'a0', 'z'), greaterThan(0));
    });
  });
}
