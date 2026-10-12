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
import '../../platform/files/stored_file_status.dart' as _is8j7as8;

abstract class FileUrlView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  FileUrlView._({
    required this.fileUuid,
    required this.status,
    this.url,
    this.expiresAt,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory FileUrlView({
    required _is.UuidValue fileUuid,
    required _is8j7as8.StoredFileStatus status,
    String? url,
    DateTime? expiresAt,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) = _FileUrlViewImpl;

  factory FileUrlView.fromJson(Map<String, dynamic> jsonSerialization) {
    return FileUrlView(
      fileUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['fileUuid'],
      ),
      status: _is8j7as8.StoredFileStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      url: jsonSerialization['url'] as String?,
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
      fileName: jsonSerialization['fileName'] as String,
      mimeType: jsonSerialization['mimeType'] as String,
      sizeBytes: jsonSerialization['sizeBytes'] as int,
    );
  }

  _is.UuidValue fileUuid;

  _is8j7as8.StoredFileStatus status;

  /// Signed URL (15 min) or public URL; null while pending.
  String? url;

  DateTime? expiresAt;

  String fileName;

  String mimeType;

  int sizeBytes;

  /// Returns a shallow copy of this [FileUrlView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FileUrlView copyWith({
    _is.UuidValue? fileUuid,
    _is8j7as8.StoredFileStatus? status,
    String? url,
    DateTime? expiresAt = const _is.$UndefinedDateTime(),
    String? fileName,
    String? mimeType,
    int? sizeBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FileUrlView',
      'fileUuid': fileUuid.toJson(),
      'status': status.toJson(),
      if (url != null) 'url': url,
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      'fileName': fileName,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FileUrlView',
      'fileUuid': fileUuid.toJson(),
      'status': status.toJson(),
      if (url != null) 'url': url,
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      'fileName': fileName,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FileUrlViewImpl extends FileUrlView {
  _FileUrlViewImpl({
    required _is.UuidValue fileUuid,
    required _is8j7as8.StoredFileStatus status,
    String? url,
    DateTime? expiresAt,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) : super._(
         fileUuid: fileUuid,
         status: status,
         url: url,
         expiresAt: expiresAt,
         fileName: fileName,
         mimeType: mimeType,
         sizeBytes: sizeBytes,
       );

  /// Returns a shallow copy of this [FileUrlView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FileUrlView copyWith({
    _is.UuidValue? fileUuid,
    _is8j7as8.StoredFileStatus? status,
    Object? url = _Undefined,
    DateTime? expiresAt = const _is.$UndefinedDateTime(),
    String? fileName,
    String? mimeType,
    int? sizeBytes,
  }) {
    return FileUrlView(
      fileUuid: fileUuid ?? this.fileUuid,
      status: status ?? this.status,
      url: url is String? ? url : this.url,
      expiresAt: expiresAt is _is.UndefinedSentinel
          ? this.expiresAt
          : expiresAt,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}
