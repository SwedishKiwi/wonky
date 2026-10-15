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

/// (v2) Upload state of a `file` drive item (Drive 02 §2).
enum FileUploadState implements _isc.SerializableModel {
  /// Created, bytes not yet verified. Listed only for the uploader.
  uploading,
  ready,

  /// Verification failed (size mismatch, storage error); bytes deleted.
  failed;

  static FileUploadState fromJson(String name) {
    switch (name) {
      case 'uploading':
        return FileUploadState.uploading;
      case 'ready':
        return FileUploadState.ready;
      case 'failed':
        return FileUploadState.failed;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "FileUploadState"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
