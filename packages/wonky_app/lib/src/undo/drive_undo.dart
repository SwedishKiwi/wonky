import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../data/drive_repository.dart';

/// Drive operations recorded on the shell stack (suite 08 §3.3 `drive`).
enum DriveUndoOp { rename, move, star, pin, trash, createFolder, description }

/// `{op, items, before, after}` — undo writes `before` back.
class DriveUndoEntry extends UndoEntry {
  const DriveUndoEntry({
    required this.op,
    required this.items,
    required this.before,
    required this.after,
  });

  final DriveUndoOp op;
  final List<String> items;

  /// Per item: the value before (name, parent uuid, starred …).
  final Map<String, Object?> before;
  final Map<String, Object?> after;

  static const domainName = 'drive';

  @override
  String get domain => domainName;

  @override
  UndoEntry? rebase(RemoteChange change) {
    if (change is! FieldRemoteChange || !items.contains(change.target)) return this;
    if (change.deleted) {
      final rest = [for (final i in items) if (i != change.target) i];
      return rest.isEmpty
          ? null
          : DriveUndoEntry(op: op, items: rest, before: before, after: after);
    }
    // Someone else changed the same field: it is no longer ours to undo.
    if (change.key == op.name && change.value != after[change.target]) {
      final rest = [for (final i in items) if (i != change.target) i];
      return rest.isEmpty
          ? null
          : DriveUndoEntry(op: op, items: rest, before: before, after: after);
    }
    return this;
  }

  DriveUndoEntry get inverse =>
      DriveUndoEntry(op: op, items: items, before: after, after: before);

  @override
  Map<String, Object?> toJson() => {
    'op': op.name,
    'items': items,
    'before': before,
    'after': after,
  };

  static DriveUndoEntry? fromJson(Map<String, Object?> j) {
    try {
      return DriveUndoEntry(
        op: DriveUndoOp.values.byName(j['op']! as String),
        items: [for (final i in j['items']! as List) '$i'],
        before: (j['before']! as Map).cast<String, Object?>(),
        after: (j['after']! as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Applies [DriveUndoEntry]s through the drive repository. Undoing a trash
/// restores; undoing a folder creation trashes the folder.
class DriveUndoHandler extends UndoHandler<DriveUndoEntry> {
  DriveUndoHandler(this.drive);

  final DriveRepository drive;

  @override
  String get domain => DriveUndoEntry.domainName;

  @override
  UndoEntryDecoder get decoder => DriveUndoEntry.fromJson;

  @override
  Future<DriveUndoEntry> undo(DriveUndoEntry entry) async {
    await _write(entry, entry.before, reverse: true);
    return entry;
  }

  @override
  Future<DriveUndoEntry> redo(DriveUndoEntry entry) async {
    await _write(entry, entry.after, reverse: false);
    return entry;
  }

  Future<void> _write(DriveUndoEntry e, Map<String, Object?> target, {required bool reverse}) async {
    UuidValue u(String s) => UuidValue.fromString(s);
    var skipped = 0;
    for (final id in e.items) {
      try {
        switch (e.op) {
          case DriveUndoOp.rename:
            final current = await drive.get(u(id));
            final expected = (reverse ? e.after : e.before)[id];
            if (current.name != expected) {
              skipped++;
              continue;
            }
            await drive.rename(u(id), '${target[id]}');
          case DriveUndoOp.description:
            await drive.updateDescription(u(id), target[id] as String?);
          case DriveUndoOp.move:
            final parent = target[id] as String?;
            await drive.move([u(id)], parent == null ? null : u(parent));
          case DriveUndoOp.star:
            await drive.setStarred(u(id), target[id] == true);
          case DriveUndoOp.pin:
            await drive.setPinnedOffline(u(id), target[id] == true);
          case DriveUndoOp.trash:
          case DriveUndoOp.createFolder:
            // true = the item is visible (not trashed / exists).
            target[id] == true ? await drive.restore([u(id)]) : await drive.trash([u(id)]);
        }
      } on WonkyException catch (err) {
        if (err.code == WonkyErrorCode.notFound) {
          skipped++;
          continue;
        }
        rethrow;
      }
    }
    if (skipped > 0) throw const UndoConflict('Changed by someone else');
  }
}
