import 'package:wonky_core/wonky_core.dart';

import '../themes/document_theme.dart';
import '../themes/theme_repository.dart';

/// Undo domain of themes (Write 06 §10.4, suite 08): draft edits in the
/// theme editor and theme library operations.
const themeUndoDomain = 'write.theme';

/// The draft undo stack of the theme editor for [themeUuid].
String themeDraftStackKey(String themeUuid) => 'theme-draft:$themeUuid';

/// One draft edit of the theme editor: the draft JSON before and after
/// (`write.theme.setProperty`, reset element, contrast fix, …). Steps of
/// one slider/stepper gesture coalesce.
class ThemeDraftUndoEntry extends UndoEntry {
  const ThemeDraftUndoEntry({
    required this.themeUuid,
    required this.beforeJson,
    required this.afterJson,
  });

  final String themeUuid;
  final String beforeJson;
  final String afterJson;

  @override
  String get domain => themeUndoDomain;

  ThemeDraftUndoEntry get swapped => ThemeDraftUndoEntry(
    themeUuid: themeUuid,
    beforeJson: afterJson,
    afterJson: beforeJson,
  );

  @override
  UndoEntry? rebase(RemoteChange change) => this;

  @override
  UndoEntry? coalesce(UndoEntry next) {
    if (next is! ThemeDraftUndoEntry || next.themeUuid != themeUuid) {
      return null;
    }
    return ThemeDraftUndoEntry(
      themeUuid: themeUuid,
      beforeJson: beforeJson,
      afterJson: next.afterJson,
    );
  }
}

/// Kinds of theme library operations.
enum ThemeLibraryOp {
  /// A theme was created (new, duplicate, import): undo deletes it.
  created,

  /// A theme was deleted: undo restores it.
  deleted,

  /// A theme was restored: undo deletes it again.
  restored,

  /// A theme was renamed ([before] / [after] names).
  renamed,

  /// The theme JSON was saved ([before] / [after] JSON, [version] after).
  saved,

  /// A document's theme was changed from the theme editor ([target] is
  /// the document uuid, [before] / [after] theme uuids or null).
  assigned,
}

/// One theme library step (shell or document stack).
class ThemeLibraryUndoEntry extends UndoEntry {
  const ThemeLibraryUndoEntry({
    required this.op,
    required this.themeUuid,
    this.before,
    this.after,
    this.version,
    this.target,
  });

  final ThemeLibraryOp op;
  final String themeUuid;
  final String? before;
  final String? after;

  /// The theme version after the step ([ThemeLibraryOp.saved],
  /// [ThemeLibraryOp.renamed]).
  final int? version;
  final String? target;

  @override
  String get domain => themeUndoDomain;

  @override
  UndoEntry? rebase(RemoteChange change) => this;

  @override
  Map<String, Object?> toJson() => {
    'op': op.name,
    'themeUuid': themeUuid,
    'before': before,
    'after': after,
    'version': version,
    'target': target,
  };

  static ThemeLibraryUndoEntry? fromJson(Map<String, Object?> j) {
    final op = ThemeLibraryOp.values
        .where((o) => o.name == j['op'])
        .firstOrNull;
    final uuid = j['themeUuid'];
    if (op == null || uuid is! String) return null;
    return ThemeLibraryUndoEntry(
      op: op,
      themeUuid: uuid,
      before: j['before'] as String?,
      after: j['after'] as String?,
      version: (j['version'] as num?)?.toInt(),
      target: j['target'] as String?,
    );
  }
}

/// The open theme editor's draft operations ([ThemeDraftUndoEntry]).
abstract interface class ThemeDraftHost {
  String get themeUuid;

  /// Replaces the draft with [json] (undo/redo).
  void applyDraftJson(String json);

  /// The library changed the saved theme (undo of a save / rename).
  void onLibraryChanged(ThemeRecord record);
}

/// Runs `write.theme` undo entries.
class ThemeUndoHandler extends UndoHandler<UndoEntry> {
  ThemeUndoHandler({
    required this.repository,
    required this.catalog,
    required this.host,
  });

  final ThemeRepository? Function() repository;
  final WriteThemeCatalog catalog;

  /// The open theme editor, if any.
  final ThemeDraftHost? Function() host;

  @override
  String get domain => themeUndoDomain;

  @override
  UndoEntryDecoder? get decoder =>
      (j) => j.containsKey('op') ? ThemeLibraryUndoEntry.fromJson(j) : null;

  ThemeRepository _repo() =>
      repository() ?? (throw const UndoConflict('No server connection'));

  @override
  Future<UndoEntry> undo(UndoEntry entry) => _run(entry);

  @override
  Future<UndoEntry> redo(UndoEntry entry) => _run(entry, redo: true);

  Future<UndoEntry> _run(UndoEntry entry, {bool redo = false}) async {
    switch (entry) {
      case ThemeDraftUndoEntry():
        final h = host();
        if (h == null || h.themeUuid != entry.themeUuid) {
          throw const UndoConflict('The theme editor is closed');
        }
        h.applyDraftJson(entry.beforeJson);
        return entry.swapped;
      case ThemeLibraryUndoEntry():
        return _library(entry, redo: redo);
    }
    throw ArgumentError.value(entry, 'entry', 'Not a theme undo entry');
  }

  Future<ThemeLibraryUndoEntry> _library(
    ThemeLibraryUndoEntry e, {
    required bool redo,
  }) async {
    final repo = _repo();
    void publish(ThemeRecord r) {
      final o = ThemeOption.fromRecord(r);
      if (o != null) catalog.put(o);
      final h = host();
      if (h != null && h.themeUuid == r.uuid) h.onLibraryChanged(r);
    }

    switch (e.op) {
      case ThemeLibraryOp.created || ThemeLibraryOp.restored:
        // Undo of a creation deletes; redo (stored as "deleted") restores.
        publish(await repo.delete(e.themeUuid));
        return ThemeLibraryUndoEntry(
          op: ThemeLibraryOp.deleted,
          themeUuid: e.themeUuid,
        );
      case ThemeLibraryOp.deleted:
        publish(await repo.restore(e.themeUuid));
        return ThemeLibraryUndoEntry(
          op: ThemeLibraryOp.restored,
          themeUuid: e.themeUuid,
        );
      case ThemeLibraryOp.renamed:
        final ThemeRecord r;
        try {
          r = await repo.rename(e.themeUuid, e.before!, e.version!);
        } on ThemeConflict {
          throw const UndoConflict('The theme was changed elsewhere');
        }
        publish(r);
        return ThemeLibraryUndoEntry(
          op: ThemeLibraryOp.renamed,
          themeUuid: e.themeUuid,
          before: e.after,
          after: e.before,
          version: r.version,
        );
      case ThemeLibraryOp.saved:
        // Saves the previous JSON only while nobody saved in between
        // (Write 06 §10.4).
        final ThemeRecord r;
        try {
          r = await repo.update(e.themeUuid, e.before!, e.version!);
        } on ThemeConflict {
          throw const UndoConflict('The theme was changed elsewhere');
        }
        publish(r);
        return ThemeLibraryUndoEntry(
          op: ThemeLibraryOp.saved,
          themeUuid: e.themeUuid,
          before: e.after,
          after: e.before,
          version: r.version,
        );
      case ThemeLibraryOp.assigned:
        await repo.assignToDocument(e.target!, e.before);
        return ThemeLibraryUndoEntry(
          op: ThemeLibraryOp.assigned,
          themeUuid: e.themeUuid,
          before: e.after,
          after: e.before,
          target: e.target,
        );
    }
  }
}
