import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Server-corrected wall clock for NOW()/TODAY() (05 §12). Truncated to whole seconds.
abstract interface class EngineClock {
  /// Current instant (UTC).
  DateTime nowUtc();
}

/// Device time plus a measured server offset.
final class SystemEngineClock implements EngineClock {
  Duration serverOffset;
  SystemEngineClock({this.serverOffset = Duration.zero});

  @override
  DateTime nowUtc() {
    final t = DateTime.now().toUtc().add(serverOffset);
    return DateTime.fromMillisecondsSinceEpoch(
      t.millisecondsSinceEpoch - t.millisecondsSinceEpoch % 1000,
      isUtc: true,
    );
  }
}

/// A fixed (settable) clock for tests and deterministic server evaluation.
final class FixedEngineClock implements EngineClock {
  DateTime instant;
  FixedEngineClock(DateTime instant) : instant = instant.toUtc();

  @override
  DateTime nowUtc() => instant;
}

/// Time zone offsets for `Spreadsheet.timeZone` (IANA ids).
abstract interface class TimeZoneResolver {
  /// UTC offset of [timeZone] at the instant [utc]. Unknown zones → zero.
  Duration offsetAt(String timeZone, DateTime utc);
}

/// [TimeZoneResolver] over the bundled `timezone` database (10-year window).
final class TzDatabaseResolver implements TimeZoneResolver {
  static bool _initialized = false;
  static final Map<String, tz.Location?> _locations = {};

  const TzDatabaseResolver();

  static void _init() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  @override
  Duration offsetAt(String timeZone, DateTime utc) {
    if (timeZone.isEmpty ||
        timeZone == 'UTC' ||
        timeZone == 'Etc/UTC' ||
        timeZone == 'GMT') {
      return Duration.zero;
    }
    _init();
    final loc = _locations.putIfAbsent(timeZone, () {
      try {
        return tz.getLocation(timeZone);
      } on Object {
        return null;
      }
    });
    if (loc == null) return Duration.zero;
    final zone = loc.timeZone(utc.millisecondsSinceEpoch);
    return zone.offset;
  }
}

/// Fixed-offset resolver (tests, platforms without tz data).
final class FixedOffsetResolver implements TimeZoneResolver {
  final Map<String, Duration> offsets;
  const FixedOffsetResolver([this.offsets = const {}]);

  @override
  Duration offsetAt(String timeZone, DateTime utc) =>
      offsets[timeZone] ?? Duration.zero;
}

/// Deterministic, platform-independent pseudo-random numbers for RAND()/RANDBETWEEN()/
/// RANDARRAY() (05 §12). Uses only 32-bit integer arithmetic so dart2js/wasm/VM agree.
abstract final class DeterministicRandom {
  static int _imul(int a, int b) {
    final ah = (a >> 16) & 0xffff, al = a & 0xffff;
    final bh = (b >> 16) & 0xffff, bl = b & 0xffff;
    return ((al * bl) + ((((ah * bl) + (al * bh)) & 0xffff) << 16)) &
        0xffffffff;
  }

  /// FNV-1a over UTF-16 code units.
  static int hashString(String s, [int seed = 0x811c9dc5]) {
    var h = seed & 0xffffffff;
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = _imul(h, 0x01000193);
    }
    return h;
  }

  static int _mix(int h) {
    h ^= h >> 16;
    h = _imul(h, 0x85ebca6b);
    h ^= h >> 13;
    h = _imul(h, 0xc2b2ae35);
    h ^= h >> 16;
    return h & 0xffffffff;
  }

  /// Uniform double in [0, 1) for (spreadsheet, cell, call index, epoch).
  static double uniform(
    String spreadsheetId,
    String cellId,
    int callIndex,
    String epoch,
  ) {
    final h1 = hashString('$spreadsheetId|$cellId|$epoch');
    final a = _mix(h1 ^ _imul(callIndex + 1, 0x9e3779b9));
    final b = _mix(a ^ 0x5bd1e995 ^ _imul(callIndex + 7, 0x27d4eb2d));
    // 53 bits: 26 from a, 27 from b
    final hi = a >> 6; // 26 bits
    final lo = b >> 5; // 27 bits
    return (hi * 134217728.0 + lo) / 9007199254740992.0;
  }
}
