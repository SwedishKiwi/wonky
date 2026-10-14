import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/sheets/scripts/script_jobs.dart';
import 'package:wonky_server/src/sheets/scripts/script_limits.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart' show GridRect;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

FetchResponseData _ok(String body, {int status = 200}) => FetchResponseData(
  statusCode: status,
  headers: const {},
  bytes: Uint8List.fromList(utf8.encode(body)),
  contentText: body,
);

void main() {
  group('Given a rate limiter', () {
    test('when the limit is reached then further events are refused until '
        'the window passes', () {
      var now = DateTime.utc(2026, 10, 14, 12);
      withClock(Clock(() => now), () {
        final l = ScriptRateLimiter(max: 2, window: const Duration(minutes: 1));
        expect(l.tryAcquire('u'), isTrue);
        expect(l.tryAcquire('u'), isTrue);
        expect(l.tryAcquire('u'), isFalse);
        expect(l.tryAcquire('other'), isTrue);
        expect(l.retryAfter('u'), const Duration(minutes: 1));
        now = now.add(const Duration(seconds: 61));
        expect(l.tryAcquire('u'), isTrue);
      });
    });
  });

  group('Given compile coalescing', () {
    test('when compiles are requested during a running one then they share '
        'one follow-up compile', () async {
      final c = CompileCoalescer.instance;
      var runs = 0;
      final gate = Completer<void>();
      Future<int> compile() async {
        runs++;
        if (runs == 1) await gate.future;
        return runs;
      }

      final first = c.run('p', compile);
      final second = c.run('p', compile);
      final third = c.run('p', compile);
      gate.complete();
      expect(await first, 1);
      expect(await second, 2);
      expect(await third, 2);
      expect(runs, 2);
    });
  });

  group('Given the custom-function fetch cache', () {
    test('when a successful response is stored then the same request hits '
        'for an hour', () {
      var now = DateTime.utc(2026);
      withClock(Clock(() => now), () {
        final cache = ScriptFetchCache();
        final r = FetchRequestData.fromApi('https://api.test/x', null);
        cache.put(r, _ok('hi'));
        expect(cache.get(r)?.contentText, 'hi');
        final other = FetchRequestData.fromApi('https://api.test/y', null);
        expect(cache.get(other), isNull);
        cache.put(other, _ok('nope', status: 500));
        expect(cache.get(other), isNull);
        now = now.add(const Duration(minutes: 61));
        expect(cache.get(r), isNull);
      });
    });
  });

  group('Given job events', () {
    test('when an edit event is encoded then it decodes unchanged', () {
      final e = ScriptJobEvents.decode(
        ScriptJobEvents.encode(
          const EditEventData(
            sheetId: 's',
            range: GridRect(1, 2, 3, 4),
            triggerUid: 't',
            offline: true,
          ),
        ),
      );
      expect(e, isA<EditEventData>());
      final edit = e as EditEventData;
      expect(edit.range, const GridRect(1, 2, 3, 4));
      expect(edit.offline, isTrue);
      expect(edit.triggerUid, 't');
    });

    test('when two edits are coalesced then the range is their bounding box '
        'and the event is marked', () {
      final a = ScriptJobEvents.encode(
        const EditEventData(sheetId: 's', range: GridRect(5, 5, 5, 5)),
      );
      final b = ScriptJobEvents.encode(
        const EditEventData(sheetId: 's', range: GridRect(1, 7, 2, 8)),
      );
      final m =
          ScriptJobEvents.decode(ScriptJobEvents.merge(a, b)) as EditEventData;
      expect(m.range, const GridRect(1, 5, 5, 8));
      expect(m.coalesced, isTrue);
    });

    test('when a time event is decoded then it gets the fire time', () {
      final at = DateTime.utc(2026, 10, 14, 9);
      final e =
          ScriptJobEvents.decode(
                ScriptJobEvents.encode(
                  TimeEventData(triggerUid: 't', scheduledAt: at, firedAt: at),
                ),
                firedAt: at.add(const Duration(minutes: 1)),
              )
              as TimeEventData;
      expect(e.scheduledAt, at);
      expect(e.firedAt, at.add(const Duration(minutes: 1)));
    });
  });
}
