import 'package:test/test.dart';
import 'package:wonky_server/src/sheets/scripts/script_triggers.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    show FixedOffsetResolver;

void main() {
  const tz = FixedOffsetResolver({'Europe/Stockholm': Duration(hours: 2)});
  final now = DateTime.utc(2026, 10, 14, 10, 7, 30);

  DateTime? next(
    Map<String, Object?> s, {
    DateTime? lastRun,
    String zone = 'UTC',
  }) => ScriptSchedule.next(
    s,
    now,
    timeZone: zone,
    triggerId: 'abc',
    timeZones: tz,
    lastRun: lastRun,
  );

  group('Given time-driven schedules', () {
    test(
      'when running every 5 minutes then the next run is on the next 5-minute mark',
      () {
        expect(
          next({'type': 'minutes', 'interval': 5}),
          DateTime.utc(2026, 10, 14, 10, 10),
        );
      },
    );

    test(
      'when running every 2 hours then the next run is on the next even hour',
      () {
        expect(
          next({'type': 'hours', 'interval': 2}),
          DateTime.utc(2026, 10, 14, 12),
        );
      },
    );

    test(
      'when running daily at 7 in Stockholm then it runs at 05:00 UTC ± 15 min tomorrow',
      () {
        final n = next({
          'type': 'days',
          'interval': 1,
          'atHour': 7,
        }, zone: 'Europe/Stockholm')!;
        final base = DateTime.utc(2026, 10, 15, 5);
        expect(n.difference(base).inMinutes.abs(), lessThanOrEqualTo(15));
      },
    );

    test('when the jitter is computed then it is stable per trigger', () {
      final a = next({'type': 'days', 'atHour': 12});
      final b = next({'type': 'days', 'atHour': 12});
      expect(a, b);
    });

    test('when running weekly on Fridays then the next Friday is chosen', () {
      final n = next({
        'type': 'weeks',
        'interval': 1,
        'weekday': DateTime.friday,
        'atHour': 9,
      })!;
      expect(n.weekday, DateTime.friday);
      expect(n.isAfter(now), isTrue);
    });

    test(
      'when running monthly on day 31 then short months use their last day',
      () {
        final n = ScriptSchedule.next(
          {'type': 'monthly', 'monthDay': 31, 'atHour': 0},
          DateTime.utc(2026, 11, 2),
          timeZone: 'UTC',
          triggerId: 'x',
        )!;
        expect(n.month, 11);
        expect(n.day, anyOf(30, 29));
      },
    );

    test('when a one-shot trigger has run then there is no next run', () {
      final at = {'type': 'once', 'at': '2026-10-20T08:00:00Z'};
      expect(next(at), DateTime.utc(2026, 10, 20, 8));
      expect(next(at, lastRun: now), isNull);
    });

    test('when the schedule is unknown then there is no next run', () {
      expect(next({'type': 'never'}), isNull);
    });
  });
}
