import 'dart:math';

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';

/// Generates RFC 9562 UUIDv7 identifiers.
///
/// Ids are time-ordered (48-bit Unix millisecond timestamp) and strictly
/// monotonic within one generator: when several ids are created in the same
/// millisecond (or the clock goes backwards) the 12-bit `rand_a` field is used
/// as a counter, and the timestamp is advanced when the counter overflows
/// (RFC 9562 §6.2, methods 1 and 3).
///
/// Time and randomness are injectable so tests are deterministic:
///
/// ```dart
/// final ids = UuidV7Generator(clock: Clock.fixed(t), random: Random(1));
/// ```
class UuidV7Generator {
  /// Creates a generator. [clock] defaults to the zone's `clock`, [random] to
  /// `Random.secure()`.
  UuidV7Generator({this._clock, Random? random})
    : _random = random ?? Random.secure();

  final Clock? _clock;
  final Random _random;

  int _lastMillis = -1;
  int _counter = 0;

  /// The shared default generator.
  static final UuidV7Generator instance = UuidV7Generator();

  /// Returns the next id.
  UuidValue next() => UuidValue.fromString(nextString());

  /// Returns the next id in canonical 8-4-4-4-12 form.
  String nextString() {
    final now = (_clock ?? clock).now().toUtc().millisecondsSinceEpoch;
    int millis;
    if (now > _lastMillis) {
      millis = now;
      // Seed the counter in the lower half so that many ids per millisecond
      // fit before an overflow.
      _counter = _random.nextInt(0x800);
    } else {
      millis = _lastMillis;
      _counter++;
      if (_counter > 0xfff) {
        millis++;
        _counter = _random.nextInt(0x800);
      }
    }
    _lastMillis = millis;

    final bytes = List<int>.filled(16, 0);
    // Division instead of shifts: on the web, bit operations truncate to
    // 32 bits and would drop the timestamp's high bytes.
    for (var i = 0; i < 6; i++) {
      bytes[i] = (millis ~/ _byteScale[5 - i]) % 256;
    }
    bytes[6] = 0x70 | ((_counter >> 8) & 0x0f);
    bytes[7] = _counter & 0xff;
    bytes[8] = 0x80 | _random.nextInt(0x40);
    for (var i = 9; i < 16; i++) {
      bytes[i] = _random.nextInt(0x100);
    }
    return _format(bytes);
  }

  /// Extracts the creation time of a UUIDv7 [id].
  static DateTime timestampOf(UuidValue id) {
    final hex = id.uuid.replaceAll('-', '').substring(0, 12);
    return DateTime.fromMillisecondsSinceEpoch(
      int.parse(hex, radix: 16),
      isUtc: true,
    );
  }

  /// Whether [id] is a version 7 UUID.
  static bool isV7(String id) {
    final parts = id.split('-');
    return parts.length == 5 &&
        parts[2].length == 4 &&
        parts[2][0] == '7' &&
        '89ab'.contains(parts[3][0].toLowerCase());
  }

  static const _byteScale = [
    1,
    0x100,
    0x10000,
    0x1000000,
    0x100000000,
    0x10000000000,
  ];

  static String _format(List<int> bytes) {
    final b = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) b.write('-');
      b.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }
}

/// Deterministic color slot (0–11) for a collaborator, used to pick
/// `presence1…presence12` (suite 02 §2).
///
/// Uses FNV-1a over the UTF-16 code units of [key] (typically the user id or
/// uuid), so every client assigns the same color to the same user.
int presenceColorIndex(String key, {int slots = 12}) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    // hash * 0x01000193 mod 2^32, split so every intermediate stays exact
    // in a JS double (the web has no 64-bit ints): 0x01000193 = 2^24 + 0x193.
    hash = ((hash & 0xff) * 0x1000000 + hash * 0x193) % 0x100000000;
  }
  return hash % slots;
}
