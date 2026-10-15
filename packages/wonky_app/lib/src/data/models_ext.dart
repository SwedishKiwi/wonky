import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../bootstrap/app_urls.dart';

/// Domain role of a protocol role.
Role roleOf(AccessRole r) => switch (r) {
  AccessRole.viewer => Role.viewer,
  AccessRole.commenter => Role.commenter,
  AccessRole.editor => Role.editor,
  AccessRole.owner => Role.owner,
};

/// Protocol role of a domain role.
AccessRole accessRoleOf(Role r) => switch (r) {
  Role.viewer => AccessRole.viewer,
  Role.commenter => AccessRole.commenter,
  Role.editor => AccessRole.editor,
  Role.owner => AccessRole.owner,
};

/// Convenience accessors on drive items.
extension DriveItemViewX on DriveItemView {
  Role get myRole => roleOf(role);
  bool get isFolder => kind == DriveItemKind.folder;
  bool get isTrashed => trashedAt != null;
  bool get canEdit => myRole.canEdit;

  /// Rename, move, trash (Editor+).
  bool get canManage => myRole.canManage;

  bool get canShare => myRole.isOwner || (myRole.canEdit && editorsCanShare);

  bool get canDownload => myRole.canEdit || nonEditorsCanExport;

  /// The in-app path (`/drive/…`, `/d/…`, `/s/…`, `/p/…`, `/file/…`) in the
  /// app of its kind.
  String get path => WonkyAppKind.itemPathFor(kind, uuid.uuid);
}

/// The app that opens [kind] (folders: Write, as in v1).
WonkyAppKind appForKind(DriveItemKind kind) =>
    WonkyAppKind.forItemKind(kind, current: WonkyAppKind.write);
