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

/// (v2) What `drive.createFileUpload` does when a ready item with the same
/// name exists in the target folder (Drive 02 §3.2).
enum UploadConflictMode implements _isc.SerializableModel {
  /// The new file gets " (1)" before the extension (default).
  keepBoth,

  /// Uploads a new version of the existing file (P2, Drive 02 §9).
  replace,

  /// Refuses with `conflict`.
  fail;

  static UploadConflictMode fromJson(String name) {
    switch (name) {
      case 'keepBoth':
        return UploadConflictMode.keepBoth;
      case 'replace':
        return UploadConflictMode.replace;
      case 'fail':
        return UploadConflictMode.fail;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "UploadConflictMode"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
