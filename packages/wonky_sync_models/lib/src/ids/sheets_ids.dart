import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

/// Deterministic ids of Wonky Sheets entities (specs/wonky_sheets/02 §2).
///
/// UUIDv5 over fixed namespace UUIDs. The namespaces are part of the synced
/// data format: **never change them**. All ids are lower-case dashed UUID
/// strings; inputs are normalized to lower case before hashing, so the same
/// entity gets the same id on every replica.
abstract final class SheetsIds {
  /// Namespace of `Cell` ids.
  static const String cellNamespace = '94020249-01b0-4143-b745-68f9aa91516f';

  /// Namespace of `BasicFilter` ids (max one per sheet).
  static const String basicFilterNamespace =
      'b91fc39a-b965-45dd-97f5-cba48eaffd93';

  /// Namespace of `ScriptBuild` ids (one per script project).
  static const String scriptBuildNamespace =
      '6c3bc01f-4fcd-4bbe-9bdd-04eecab04088';

  static const Uuid _uuid = Uuid();

  /// `UUIDv5(ns, "cell:<sheetId>:<rowId>:<colId>")`.
  ///
  /// Hot path (every cell write): hashed with [_Uuid5] instead of
  /// `Uuid.v5`, which parses and validates the namespace on every call
  /// (~8 µs → ~1 µs; equal ids, `test/ids/sheets_ids_test.dart`).
  static String cellId(String sheetId, String rowId, String colId) =>
      _cellIds.of('cell:${_n(sheetId)}:${_n(rowId)}:${_n(colId)}');

  static final _Uuid5 _cellIds = _Uuid5(cellNamespace);

  /// `UUIDv5(ns, "basicFilter:<sheetId>")`.
  static String basicFilterId(String sheetId) =>
      _uuid.v5(basicFilterNamespace, 'basicFilter:${_n(sheetId)}');

  /// `UUIDv5(ns, "scriptBuild:<projectId>")`.
  static String scriptBuildId(String projectId) =>
      _uuid.v5(scriptBuildNamespace, 'scriptBuild:${_n(projectId)}');

  /// [cellId] as a [UuidValue].
  static UuidValue cellUuid(String sheetId, String rowId, String colId) =>
      UuidValue.fromString(cellId(sheetId, rowId, colId));

  /// Normalizes a UUID string to the canonical lower-case form.
  static String normalize(String id) => _n(id);

  static String _n(String id) => id.toLowerCase();
}

/// Source of fresh random entity ids (UUIDv7 in production).
///
/// Injected everywhere ids are created so tests are deterministic
/// (specs/15 §4).
abstract interface class IdGenerator {
  /// A new unique id (lower-case dashed UUID string).
  String newId();
}

/// Production generator: time-ordered UUIDv7.
final class UuidV7IdGenerator implements IdGenerator {
  /// Creates a UUIDv7 generator.
  const UuidV7IdGenerator();

  static const Uuid _uuid = Uuid();

  @override
  String newId() => _uuid.v7();
}

/// Deterministic generator for tests: RFC 4122 v4-shaped ids from a seeded
/// [Random].
final class SeededIdGenerator implements IdGenerator {
  /// Creates a generator seeded with [seed].
  SeededIdGenerator([int seed = 0]) : _random = Random(seed);

  final Random _random;

  @override
  String newId() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final sb = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) sb.write('-');
      sb.write(b[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

/// Sequential, human-readable ids for tests (`00000000-0000-4000-8000-000000000001`, …).
final class SequentialIdGenerator implements IdGenerator {
  /// Creates a generator starting after [start].
  SequentialIdGenerator([this._next = 0]);

  int _next;

  @override
  String newId() {
    _next++;
    final hex = _next.toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$hex';
  }
}

/// UUIDv5 (RFC 4122 §4.3: SHA-1 of namespace bytes + UTF-8 name, version 5,
/// RFC variant) for one fixed namespace, without per-call parsing.
final class _Uuid5 {
  _Uuid5(String namespace)
    : _ns = [
        for (var i = 0; i < 32; i += 2)
          int.parse(
            namespace.replaceAll('-', '').substring(i, i + 2),
            radix: 16,
          ),
      ];

  final List<int> _ns;
  final Uint32List _w = Uint32List(80);

  static const _hex = '0123456789abcdef';

  String of(String name) {
    final bytes = <int>[..._ns, ...utf8.encode(name)];
    final h = _sha1(bytes);
    h[6] = (h[6] & 0x0f) | 0x50;
    h[8] = (h[8] & 0x3f) | 0x80;
    final out = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) out.write('-');
      out
        ..write(_hex[h[i] >> 4])
        ..write(_hex[h[i] & 0x0f]);
    }
    return out.toString();
  }

  /// The first 16 bytes of the SHA-1 digest of [message].
  Uint8List _sha1(List<int> message) {
    final ml = message.length;
    final padded = Uint8List(((ml + 8) ~/ 64 + 1) * 64)..setAll(0, message);
    padded[ml] = 0x80;
    final bits = ml * 8;
    for (var i = 0; i < 8; i++) {
      padded[padded.length - 1 - i] = (bits >> (8 * i)) & 0xff;
    }
    var h0 = 0x67452301, h1 = 0xefcdab89, h2 = 0x98badcfe;
    var h3 = 0x10325476, h4 = 0xc3d2e1f0;
    final w = _w;
    int rotl(int x, int n) => ((x << n) | (x >> (32 - n))) & 0xffffffff;
    for (var off = 0; off < padded.length; off += 64) {
      for (var i = 0; i < 16; i++) {
        final j = off + i * 4;
        w[i] =
            (padded[j] << 24) |
            (padded[j + 1] << 16) |
            (padded[j + 2] << 8) |
            padded[j + 3];
      }
      for (var i = 16; i < 80; i++) {
        w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }
      var a = h0, b = h1, c = h2, d = h3, e = h4;
      for (var i = 0; i < 80; i++) {
        final int f, k;
        if (i < 20) {
          f = (b & c) | ((~b & 0xffffffff) & d);
          k = 0x5a827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ed9eba1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8f1bbcdc;
        } else {
          f = b ^ c ^ d;
          k = 0xca62c1d6;
        }
        final t = (rotl(a, 5) + f + e + k + w[i]) & 0xffffffff;
        e = d;
        d = c;
        c = rotl(b, 30);
        b = a;
        a = t;
      }
      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
    }
    final out = Uint8List(16);
    for (final (i, h) in [h0, h1, h2, h3].indexed) {
      out[i * 4] = h >> 24;
      out[i * 4 + 1] = (h >> 16) & 0xff;
      out[i * 4 + 2] = (h >> 8) & 0xff;
      out[i * 4 + 3] = h & 0xff;
    }
    return out;
  }
}
