import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../shell/shell_services.dart';

/// A version restore (one undo step, suite 07 §5): undo restores the
/// restore point that was saved before; redo restores the version again.
class VersionRestoreEntry extends UndoEntry {
  const VersionRestoreEntry({
    required this.itemUuid,
    required this.versionId,
    required this.restorePointId,
  });

  final String itemUuid;
  final int versionId;
  final int restorePointId;

  static const domainName = 'versions';

  @override
  String get domain => domainName;

  @override
  UndoEntry? rebase(RemoteChange change) => this;

  @override
  Map<String, Object?> toJson() => {
    'itemUuid': itemUuid,
    'versionId': versionId,
    'restorePointId': restorePointId,
  };

  static VersionRestoreEntry? fromJson(Map<String, Object?> j) {
    try {
      return VersionRestoreEntry(
        itemUuid: j['itemUuid']! as String,
        versionId: j['versionId']! as int,
        restorePointId: j['restorePointId']! as int,
      );
    } catch (_) {
      return null;
    }
  }
}

class VersionsUndoHandler extends UndoHandler<VersionRestoreEntry> {
  VersionsUndoHandler(this.services);

  final ShellServices services;

  @override
  String get domain => VersionRestoreEntry.domainName;

  @override
  UndoEntryDecoder get decoder => VersionRestoreEntry.fromJson;

  @override
  Future<VersionRestoreEntry> undo(VersionRestoreEntry e) async {
    final r = await services.repositories.versions.restore(
      UuidValue.fromString(e.itemUuid),
      e.restorePointId,
    );
    return VersionRestoreEntry(
      itemUuid: e.itemUuid,
      versionId: e.versionId,
      restorePointId: r.restorePoint.id,
    );
  }

  @override
  Future<VersionRestoreEntry> redo(VersionRestoreEntry e) async {
    final r = await services.repositories.versions.restore(
      UuidValue.fromString(e.itemUuid),
      e.versionId,
    );
    return VersionRestoreEntry(
      itemUuid: e.itemUuid,
      versionId: e.versionId,
      restorePointId: r.restorePoint.id,
    );
  }
}
