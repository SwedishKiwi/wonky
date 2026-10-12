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

enum VersionStorage implements _is.SerializableModel {
  /// Write: an op-log revision (with a snapshot at that revision).
  writeRevision,

  /// Sheets: a compressed snapshot file in cloud storage.
  snapshotFile;

  static VersionStorage fromJson(String name) {
    switch (name) {
      case 'writeRevision':
        return VersionStorage.writeRevision;
      case 'snapshotFile':
        return VersionStorage.snapshotFile;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "VersionStorage"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
