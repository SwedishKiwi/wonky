import 'dart:math';

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
  static const String basicFilterNamespace = 'b91fc39a-b965-45dd-97f5-cba48eaffd93';

  /// Namespace of `ScriptBuild` ids (one per script project).
  static const String scriptBuildNamespace = '6c3bc01f-4fcd-4bbe-9bdd-04eecab04088';

  static const Uuid _uuid = Uuid();

  /// `UUIDv5(ns, "cell:<sheetId>:<rowId>:<colId>")`.
  static String cellId(String sheetId, String rowId, String colId) =>
      _uuid.v5(cellNamespace, 'cell:${_n(sheetId)}:${_n(rowId)}:${_n(colId)}');

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
