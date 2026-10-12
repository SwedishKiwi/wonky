import 'dart:convert';

import 'package:wonky_write/features/themes/theme_repository.dart';
import 'package:wonky_write_core/wonky_write_core.dart'
    show BuiltinThemes, canonicalJsonEncode;

/// In-memory [ThemeRepository] with server semantics: versions, conflicts,
/// revisions, soft delete and document assignments.
class FakeThemeRepository implements ThemeRepository {
  FakeThemeRepository({this.me = 'me-uuid'});

  final String me;
  final Map<String, ThemeRecord> themes = {};
  final Map<String, List<ThemeRevision>> history = {};
  final Map<String, String?> documentThemes = {};
  int _next = 1;
  int usageCount = 0;

  /// Seeds a user theme owned by [owner] (default: [me]).
  ThemeRecord seed({
    String name = 'Report',
    String? json,
    String? owner,
    int version = 1,
  }) {
    final uuid =
        '00000000-0000-7000-8000-${(_next++).toString().padLeft(12, '0')}';
    final data = BuiltinThemes.wonkyDefault.json;
    final r = ThemeRecord(
      uuid: uuid,
      name: name,
      json: json ?? canonicalJsonEncode({...data, 'name': name}),
      version: version,
      ownerUuid: owner ?? me,
      ownerName: owner == null ? 'Me' : 'Someone',
    );
    themes[uuid] = r;
    history[uuid] = [
      ThemeRevision(version: version, json: r.json, createdAt: DateTime(2026)),
    ];
    return r;
  }

  /// Simulates a save from another window.
  ThemeRecord saveElsewhere(String uuid, String json) {
    final r = themes[uuid]!;
    final updated = r.copyWith(json: json, version: r.version + 1);
    themes[uuid] = updated;
    return updated;
  }

  ThemeRecord _require(String uuid) =>
      themes[uuid] ?? (throw StateError('Theme $uuid not found'));

  static String _canonical(String json) =>
      canonicalJsonEncode(jsonDecode(json));

  @override
  Future<List<ThemeRecord>> listMine() async => [
    for (final t in themes.values)
      if (t.ownerUuid == me && !t.isDeleted) t,
  ];

  @override
  Future<ThemeRecord> get(String uuid, {String? viaDocumentUuid}) async =>
      _require(uuid);

  @override
  Future<ThemeRecord> create(
    String name,
    String json, {
    String? basedOnUuid,
  }) async {
    final r = seed(name: name, json: _canonical(json));
    return r;
  }

  @override
  Future<ThemeRecord> update(
    String uuid,
    String json,
    int expectedVersion,
  ) async {
    final r = _require(uuid);
    if (r.version != expectedVersion) {
      throw ThemeConflict(
        serverJson: r.json,
        serverVersion: r.version,
        serverName: r.name,
      );
    }
    final updated = r.copyWith(json: _canonical(json), version: r.version + 1);
    themes[uuid] = updated;
    history[uuid]!.insert(
      0,
      ThemeRevision(
        version: updated.version,
        json: updated.json,
        createdAt: DateTime(2026),
      ),
    );
    return updated;
  }

  @override
  Future<ThemeRecord> rename(
    String uuid,
    String name,
    int expectedVersion,
  ) async {
    final r = _require(uuid);
    if (r.version != expectedVersion) {
      throw ThemeConflict(
        serverJson: r.json,
        serverVersion: r.version,
        serverName: r.name,
      );
    }
    return themes[uuid] = r.copyWith(name: name, version: r.version + 1);
  }

  @override
  Future<ThemeRecord> duplicate(
    String uuid,
    String name, {
    String? viaDocumentUuid,
  }) async => seed(name: name, json: _require(uuid).json);

  @override
  Future<ThemeRecord> delete(String uuid) async =>
      themes[uuid] = _require(uuid).copyWith(deletedAt: DateTime(2026));

  @override
  Future<ThemeRecord> restore(String uuid) async =>
      themes[uuid] = _require(uuid).copyWith(clearDeleted: true);

  @override
  Future<List<ThemeRevision>> listRevisions(String uuid) async =>
      history[uuid] ?? const [];

  @override
  Future<int> usage(String uuid) async => usageCount;

  @override
  Future<void> assignToDocument(String documentUuid, String? themeUuid) async {
    documentThemes[documentUuid] = themeUuid;
  }
}
