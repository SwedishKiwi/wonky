/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

/// Virtual views of `drive.list` (specs/05 §2).
enum DriveView implements _is.SerializableModel {
  /// Children of a folder (or of the caller's root when folderUuid is null).
  folder,

  /// Items owned by others, shared directly, via a folder or opened via link.
  sharedWithMe,
  starred,

  /// Recently opened by the caller.
  recent,

  /// Owned items in the trash (only top-level trashed items).
  trash,

  /// Items pinned for offline use.
  offline;

  static DriveView fromJson(String name) {
    switch (name) {
      case 'folder':
        return DriveView.folder;
      case 'sharedWithMe':
        return DriveView.sharedWithMe;
      case 'starred':
        return DriveView.starred;
      case 'recent':
        return DriveView.recent;
      case 'trash':
        return DriveView.trash;
      case 'offline':
        return DriveView.offline;
      default:
        throw ArgumentError('Value "$name" cannot be converted to "DriveView"');
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
