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
import '../../platform/drive/file_upload_state.dart' as _idvu08o8;

/// (v2) Result of `drive.fileUploadStatus` (resume, Drive 02 §4.3).
abstract class FileUploadProgress
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  FileUploadProgress._({
    required this.uploadState,
    int? receivedBytes,
  }) : receivedBytes = receivedBytes ?? 0;

  factory FileUploadProgress({
    required _idvu08o8.FileUploadState uploadState,
    int? receivedBytes,
  }) = _FileUploadProgressImpl;

  factory FileUploadProgress.fromJson(Map<String, dynamic> jsonSerialization) {
    return FileUploadProgress(
      uploadState: _idvu08o8.FileUploadState.fromJson(
        (jsonSerialization['uploadState'] as String),
      ),
      receivedBytes: jsonSerialization['receivedBytes'] as int?,
    );
  }

  _idvu08o8.FileUploadState uploadState;

  /// Chunked: bytes the server has; otherwise 0 or the file size.
  int receivedBytes;

  /// Returns a shallow copy of this [FileUploadProgress]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FileUploadProgress copyWith({
    _idvu08o8.FileUploadState? uploadState,
    int? receivedBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FileUploadProgress',
      'uploadState': uploadState.toJson(),
      'receivedBytes': receivedBytes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FileUploadProgress',
      'uploadState': uploadState.toJson(),
      'receivedBytes': receivedBytes,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _FileUploadProgressImpl extends FileUploadProgress {
  _FileUploadProgressImpl({
    required _idvu08o8.FileUploadState uploadState,
    int? receivedBytes,
  }) : super._(
         uploadState: uploadState,
         receivedBytes: receivedBytes,
       );

  /// Returns a shallow copy of this [FileUploadProgress]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FileUploadProgress copyWith({
    _idvu08o8.FileUploadState? uploadState,
    int? receivedBytes,
  }) {
    return FileUploadProgress(
      uploadState: uploadState ?? this.uploadState,
      receivedBytes: receivedBytes ?? this.receivedBytes,
    );
  }
}
