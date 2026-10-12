import 'dart:convert';

import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show UuidV7Generator;
import 'package:wonky_write_core/wonky_write_core.dart' show WriteThemeData;

/// A theme as the theme library sees it (Write 06 §5.5 `WriteThemeView`).
@immutable
class ThemeRecord {
  const ThemeRecord({
    required this.uuid,
    required this.name,
    required this.json,
    required this.version,
    this.description,
    this.builtinKey,
    this.ownerName,
    this.ownerUuid,
    this.deletedAt,
    this.updatedAt,
  });

  final String uuid;
  final String name;
  final String? description;
  final String? builtinKey;

  /// Canonical theme JSON.
  final String json;

  /// Server version (optimistic concurrency, 1-based).
  final int version;
  final String? ownerName;
  final String? ownerUuid;
  final DateTime? deletedAt;
  final DateTime? updatedAt;

  bool get isBuiltin => builtinKey != null;
  bool get isDeleted => deletedAt != null;

  /// The parsed theme; throws for invalid JSON.
  WriteThemeData get data => WriteThemeData.fromJsonString(json);

  ThemeRecord copyWith({
    String? name,
    String? json,
    int? version,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) => ThemeRecord(
    uuid: uuid,
    name: name ?? this.name,
    description: description,
    builtinKey: builtinKey,
    json: json ?? this.json,
    version: version ?? this.version,
    ownerName: ownerName,
    ownerUuid: ownerUuid,
    deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
    updatedAt: updatedAt,
  );

  static ThemeRecord fromView(WriteThemeView v) => ThemeRecord(
    uuid: v.uuid.uuid,
    name: v.name,
    description: v.description,
    builtinKey: v.builtinKey,
    json: v.json,
    version: v.version,
    ownerName: v.owner?.displayName,
    ownerUuid: v.owner?.uuid.uuid,
    deletedAt: v.deletedAt,
    updatedAt: v.updatedAt,
  );
}

/// One saved version of a theme (`writeTheme.listRevisions`).
@immutable
class ThemeRevision {
  const ThemeRevision({
    required this.version,
    required this.json,
    required this.createdAt,
    this.savedBy,
    this.byAgent = false,
  });

  final int version;
  final String json;
  final DateTime createdAt;
  final String? savedBy;

  /// Saved by MCP / AI / a script rather than in the app.
  final bool byAgent;
}

/// The theme was saved elsewhere since it was loaded (`ThemeConflict`,
/// Write 06 §10.4).
class ThemeConflict implements Exception {
  const ThemeConflict({
    required this.serverJson,
    required this.serverVersion,
    required this.serverName,
  });

  final String serverJson;
  final int serverVersion;
  final String serverName;

  @override
  String toString() => 'ThemeConflict(v$serverVersion)';
}

/// Server access for the theme library and editor (`writeTheme`), plus the
/// two document/preference writes the editor needs. Fakes implement it in
/// tests.
abstract class ThemeRepository {
  Future<List<ThemeRecord>> listMine();

  Future<ThemeRecord> get(String uuid, {String? viaDocumentUuid});

  Future<ThemeRecord> create(String name, String json, {String? basedOnUuid});

  /// Saves [json]; throws [ThemeConflict] when [expectedVersion] is stale.
  Future<ThemeRecord> update(String uuid, String json, int expectedVersion);

  /// Renames; throws [ThemeConflict] when [expectedVersion] is stale.
  Future<ThemeRecord> rename(String uuid, String name, int expectedVersion);

  Future<ThemeRecord> duplicate(
    String uuid,
    String name, {
    String? viaDocumentUuid,
  });

  Future<ThemeRecord> delete(String uuid);

  Future<ThemeRecord> restore(String uuid);

  Future<List<ThemeRevision>> listRevisions(String uuid);

  /// Number of the caller's documents using the theme.
  Future<int> usage(String uuid);

  /// Assigns a theme to a document (`document.updateMeta`, field
  /// `themeId`; null = the viewer's default).
  Future<void> assignToDocument(String documentUuid, String? themeUuid);
}

/// [ThemeRepository] over the generated client.
class ServerThemeRepository implements ThemeRepository {
  ServerThemeRepository(this.client);

  final Client client;

  static UuidValue _u(String s) => UuidValue.withValidation(s);

  Future<T> _conflicts<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ThemeConflictException catch (e) {
      throw ThemeConflict(
        serverJson: e.serverJson,
        serverVersion: e.serverVersion,
        serverName: e.serverName,
      );
    }
  }

  @override
  Future<List<ThemeRecord>> listMine() async => [
    for (final v in await client.writeTheme.listMine())
      if (!v.isBuiltin) ThemeRecord.fromView(v),
  ];

  @override
  Future<ThemeRecord> get(String uuid, {String? viaDocumentUuid}) async =>
      ThemeRecord.fromView(
        await client.writeTheme.get(
          _u(uuid),
          viaDocumentUuid == null ? null : _u(viaDocumentUuid),
        ),
      );

  @override
  Future<ThemeRecord> create(
    String name,
    String json, {
    String? basedOnUuid,
  }) async => ThemeRecord.fromView(
    await client.writeTheme.create(
      name,
      json,
      basedOnUuid == null ? null : _u(basedOnUuid),
    ),
  );

  @override
  Future<ThemeRecord> update(String uuid, String json, int expectedVersion) =>
      _conflicts(
        () async => ThemeRecord.fromView(
          await client.writeTheme.update(_u(uuid), json, expectedVersion),
        ),
      );

  @override
  Future<ThemeRecord> rename(String uuid, String name, int expectedVersion) =>
      _conflicts(
        () async => ThemeRecord.fromView(
          await client.writeTheme.rename(_u(uuid), name, expectedVersion),
        ),
      );

  @override
  Future<ThemeRecord> duplicate(
    String uuid,
    String name, {
    String? viaDocumentUuid,
  }) async => ThemeRecord.fromView(
    await client.writeTheme.duplicate(
      _u(uuid),
      name,
      viaDocumentUuid == null ? null : _u(viaDocumentUuid),
    ),
  );

  @override
  Future<ThemeRecord> delete(String uuid) async =>
      ThemeRecord.fromView(await client.writeTheme.delete(_u(uuid)));

  @override
  Future<ThemeRecord> restore(String uuid) async =>
      ThemeRecord.fromView(await client.writeTheme.restore(_u(uuid)));

  @override
  Future<List<ThemeRevision>> listRevisions(String uuid) async => [
    for (final r in await client.writeTheme.listRevisions(_u(uuid)))
      ThemeRevision(
        version: r.version,
        json: r.json,
        createdAt: r.createdAt,
        savedBy: r.savedBy?.displayName,
        byAgent: r.actorKind != ActorKind.user,
      ),
  ];

  @override
  Future<int> usage(String uuid) => client.writeTheme.usage(_u(uuid));

  @override
  Future<void> assignToDocument(String documentUuid, String? themeUuid) =>
      client.document.updateMeta(
        _u(documentUuid),
        DocumentMetaPatch(field: 'themeId', valueJson: jsonEncode(themeUuid)),
        UuidV7Generator.instance.next(),
      );
}
