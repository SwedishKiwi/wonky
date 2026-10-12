import 'package:wonky_app/wonky_app.dart' show UndoService, UndoStackKey;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_write_core/wonky_write_core.dart'
    show BuiltinThemes, canonicalJsonEncode;

import '../themes/document_theme.dart';
import '../themes/theme_repository.dart';
import 'theme_editor_model.dart';
import 'theme_undo.dart';

/// Theme library operations (Write 06 §10.4): create, duplicate, rename,
/// delete and restore. Each is an undoable `write.theme` step on the shell
/// stack, and the [catalog] is updated so open documents and pickers see
/// the change.
class ThemeLibrary {
  ThemeLibrary({
    required this.repository,
    required this.catalog,
    required this.undo,
    UuidV7Generator? ids,
  }) : _ids = ids ?? UuidV7Generator.instance;

  final ThemeRepository repository;
  final WriteThemeCatalog catalog;
  final UndoService undo;
  final UuidV7Generator _ids;

  void _push(String label, ThemeLibraryUndoEntry entry) => undo.push(
    UndoStep(id: _ids.nextString(), label: label, entries: [entry]),
    stack: UndoStackKey.shell,
  );

  void _publish(ThemeRecord r) {
    final o = ThemeOption.fromRecord(r);
    if (o != null) catalog.put(o);
  }

  /// A name not used by the user's themes ("Report (2)").
  String uniqueName(String base) {
    String clip(String s) => s.length > 80 ? s.substring(0, 80) : s;
    final taken = {for (final t in catalog.mine) t.name.toLowerCase()};
    final b = clip(base.trim().isEmpty ? 'Untitled theme' : base.trim());
    if (!taken.contains(b.toLowerCase())) return b;
    for (var i = 2; i < 1000; i++) {
      final c = clip('$b ($i)');
      if (!taken.contains(c.toLowerCase())) return c;
    }
    return b;
  }

  /// Creates a theme from [json] (named [name], de-duplicated).
  Future<ThemeRecord> create(
    String name,
    ThemeJson json, {
    String? basedOnUuid,
  }) async {
    final n = uniqueName(name);
    final data = Map<String, Object?>.from(json)..['name'] = n;
    final r = await repository.create(
      n,
      canonicalJsonEncode(data),
      basedOnUuid: basedOnUuid,
    );
    _publish(r);
    _push(
      'Create theme “${r.name}”',
      ThemeLibraryUndoEntry(op: ThemeLibraryOp.created, themeUuid: r.uuid),
    );
    return r;
  }

  /// A new theme based on *Wonky Default* (`write.theme.create`).
  Future<ThemeRecord> createNew({String name = 'My theme', ThemeJson? from}) =>
      create(
        name,
        from ?? BuiltinThemes.wonkyDefault.json,
        basedOnUuid: from == null ? BuiltinThemes.wonkyDefault.uuid : null,
      );

  /// Copies [uuid] into the user's library (`write.theme.duplicate`,
  /// "Copy to my themes"). With [draft], the unsaved draft is copied.
  Future<ThemeRecord> duplicate(
    String uuid, {
    String? name,
    ThemeJson? draft,
    String? viaDocumentUuid,
  }) async {
    final source = catalog.lookup(uuid);
    final n = uniqueName(name ?? '${source?.name ?? 'Theme'} (copy)');
    final ThemeRecord r;
    if (draft != null || (source?.isBuiltin ?? false)) {
      final json = Map<String, Object?>.from(draft ?? source!.data.toJson())
        ..['name'] = n
        ..['basedOn'] = source?.isBuiltin ?? false
            ? 'builtin:${source!.builtinKey}'
            : 'theme:$uuid';
      r = await repository.create(
        n,
        canonicalJsonEncode(json),
        basedOnUuid: uuid,
      );
    } else {
      r = await repository.duplicate(uuid, n, viaDocumentUuid: viaDocumentUuid);
    }
    _publish(r);
    _push(
      'Copy theme “${r.name}”',
      ThemeLibraryUndoEntry(op: ThemeLibraryOp.created, themeUuid: r.uuid),
    );
    return r;
  }

  /// Renames [record]; throws [ThemeConflict] when it changed elsewhere.
  Future<ThemeRecord> rename(ThemeRecord record, String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 80) {
      throw ArgumentError.value(
        name,
        'name',
        'Theme names have 1–80 characters',
      );
    }
    final r = await repository.rename(record.uuid, clean, record.version);
    _publish(r);
    _push(
      'Rename theme',
      ThemeLibraryUndoEntry(
        op: ThemeLibraryOp.renamed,
        themeUuid: r.uuid,
        before: record.name,
        after: clean,
        version: r.version,
      ),
    );
    return r;
  }

  /// Soft-deletes [uuid] (`write.theme.delete`; undo restores).
  Future<ThemeRecord> delete(String uuid) async {
    final r = await repository.delete(uuid);
    catalog.markDeleted(uuid);
    _push(
      'Delete theme “${r.name}”',
      ThemeLibraryUndoEntry(op: ThemeLibraryOp.deleted, themeUuid: uuid),
    );
    return r;
  }

  /// Restores a deleted theme (`write.theme.restore`).
  Future<ThemeRecord> restore(String uuid) async {
    final r = await repository.restore(uuid);
    _publish(r);
    _push(
      'Restore theme “${r.name}”',
      ThemeLibraryUndoEntry(op: ThemeLibraryOp.restored, themeUuid: uuid),
    );
    return r;
  }
}
