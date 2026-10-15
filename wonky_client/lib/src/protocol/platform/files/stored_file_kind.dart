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
import 'package:serverpod_client/serverpod_client.dart' as _isc;

enum StoredFileKind implements _isc.SerializableModel {
  /// Images in documents and over cells.
  image,
  avatar,

  /// Files uploaded for import (expire after 24 h).
  importSource,

  /// Export results (expire after 24 h).
  exportResult,
  thumbnail,

  /// Version snapshots (Sheets).
  snapshot,
  scriptBytecode,

  /// (v2) The bytes of a `file` drive item; access follows the item
  /// (`itemId` set). Counted (Drive 03 §2).
  driveFile,

  /// (v2) Server-made preview image of a file item (Drive 02 §6.2); not
  /// counted, deleted with the item.
  preview;

  static StoredFileKind fromJson(String name) {
    switch (name) {
      case 'image':
        return StoredFileKind.image;
      case 'avatar':
        return StoredFileKind.avatar;
      case 'importSource':
        return StoredFileKind.importSource;
      case 'exportResult':
        return StoredFileKind.exportResult;
      case 'thumbnail':
        return StoredFileKind.thumbnail;
      case 'snapshot':
        return StoredFileKind.snapshot;
      case 'scriptBytecode':
        return StoredFileKind.scriptBytecode;
      case 'driveFile':
        return StoredFileKind.driveFile;
      case 'preview':
        return StoredFileKind.preview;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "StoredFileKind"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
