import 'dart:math';

import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  final t = DateTime.utc(2026, 10, 12, 9, 30);

  group('Given a generator with a fixed clock and seeded random', () {
    late UuidV7Generator ids;
    setUp(
      () => ids = UuidV7Generator(clock: Clock.fixed(t), random: Random(7)),
    );

    test('when generating an id then it is a version 7 uuid', () {
      final id = ids.nextString();
      expect(UuidV7Generator.isV7(id), isTrue);
      expect(
        id,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab]')),
      );
    });

    test('when generating an id then its timestamp is the clock time', () {
      expect(UuidV7Generator.timestampOf(ids.next()), t);
    });

    test('when generating many ids in one millisecond then they are '
        'strictly increasing', () {
      final list = [for (var i = 0; i < 5000; i++) ids.nextString()];
      final sorted = [...list]..sort();
      expect(list, equals(sorted));
      expect(list.toSet().length, list.length);
    });

    test('when using the same seed twice then the ids are identical', () {
      final a = UuidV7Generator(clock: Clock.fixed(t), random: Random(1));
      final b = UuidV7Generator(clock: Clock.fixed(t), random: Random(1));
      expect(a.nextString(), b.nextString());
    });
  });

  test('Given a clock that goes backwards when generating then ids stay '
      'ordered', () {
    var now = t;
    final ids = UuidV7Generator(clock: Clock(() => now), random: Random(3));
    final first = ids.nextString();
    now = t.subtract(const Duration(seconds: 5));
    final second = ids.nextString();
    expect(second.compareTo(first), greaterThan(0));
  });

  group('Given presence colors', () {
    test('when hashing the same key then the slot is stable', () {
      expect(presenceColorIndex('user-42'), presenceColorIndex('user-42'));
    });
    test('when hashing known keys then the slots match on every platform '
        '(32-bit FNV-1a, web included)', () {
      expect(
        [
          for (final k in [
            '1',
            '42',
            'anna@example.test',
            '01a131ab-5f3f-7e30-a9b2-2d12f5b49832',
          ])
            presenceColorIndex(k),
        ],
        [4, 11, 1, 10],
      );
    });
    test('when hashing many keys then all slots are within 0..11', () {
      final slots = {for (var i = 0; i < 500; i++) presenceColorIndex('u$i')};
      expect(slots.every((s) => s >= 0 && s < 12), isTrue);
      expect(slots.length, 12);
    });
  });
}
