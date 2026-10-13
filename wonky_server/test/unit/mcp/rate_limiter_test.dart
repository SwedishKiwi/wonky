import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/mcp/tool_executor.dart';

/// A [RateCounter] shared by several limiters, like Redis is shared by
/// several server instances.
class _SharedCounter implements RateCounter {
  final Map<String, int> counts = {};
  bool reachable = true;

  @override
  Future<int> increment(String key, Duration ttl) async {
    if (!reachable) throw StateError('unreachable');
    return counts[key] = (counts[key] ?? 0) + 1;
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 13, 12, 0, 30);

  group('Given two instances sharing a rate counter', () {
    late _SharedCounter counter;
    late McpRateLimiter first;
    late McpRateLimiter second;
    setUp(() {
      counter = _SharedCounter();
      first = McpRateLimiter(limit: 2, counter: counter);
      second = McpRateLimiter(limit: 2, counter: counter);
    });

    test('when the token spends its limit across both then the next call is '
        'limited until the window ends', () async {
      await withClock(Clock.fixed(now), () async {
        final a = await first.check(7);
        final b = await second.check(7);
        final c = await first.check(7);

        expect(a, isNull);
        expect(b, isNull);
        expect(c, const Duration(seconds: 30));
      });
    });

    test('when another token calls then it has its own limit', () async {
      await withClock(Clock.fixed(now), () async {
        await first.check(7);
        await second.check(7);

        expect(await first.check(8), isNull);
      });
    });

    test(
      'when the counter is unreachable then the local window applies',
      () async {
        counter.reachable = false;
        await withClock(Clock.fixed(now), () async {
          final a = await first.check(7);
          final b = await first.check(7);
          final c = await first.check(7);

          expect([a, b], [isNull, isNull]);
          expect(c, isNotNull);
        });
      },
    );
  });
}
