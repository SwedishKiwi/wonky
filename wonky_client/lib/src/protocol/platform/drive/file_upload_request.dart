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
import '../../platform/drive/upload_conflict_mode.dart' as _iux1qhua;

/// (v2) Argument of `drive.createFileUpload` (Drive 02 §3.3). Idempotent on
/// ([itemUuid], [fileUuid]).
abstract class FileUploadRequest
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  FileUploadRequest._({
    required this.itemUuid,
    required this.fileUuid,
    this.parentUuid,
    required this.name,
    required this.sizeBytes,
    this.declaredMimeType,
    this.lastModified,
    _iux1qhua.UploadConflictMode? conflict,
    bool? chunked,
  }) : conflict = conflict ?? _iux1qhua.UploadConflictMode.keepBoth,
       chunked = chunked ?? false;

  factory FileUploadRequest({
    required _isc.UuidValue itemUuid,
    required _isc.UuidValue fileUuid,
    _isc.UuidValue? parentUuid,
    required String name,
    required int sizeBytes,
    String? declaredMimeType,
    DateTime? lastModified,
    _iux1qhua.UploadConflictMode? conflict,
    bool? chunked,
  }) = _FileUploadRequestImpl;

  factory FileUploadRequest.fromJson(Map<String, dynamic> jsonSerialization) {
    return FileUploadRequest(
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      fileUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['fileUuid'],
      ),
      parentUuid: jsonSerialization['parentUuid'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['parentUuid'],
            ),
      name: jsonSerialization['name'] as String,
      sizeBytes: jsonSerialization['sizeBytes'] as int,
      declaredMimeType: jsonSerialization['declaredMimeType'] as String?,
      lastModified: jsonSerialization['lastModified'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastModified'],
            ),
      conflict: jsonSerialization['conflict'] == null
          ? null
          : _iux1qhua.UploadConflictMode.fromJson(
              (jsonSerialization['conflict'] as String),
            ),
      chunked: jsonSerialization['chunked'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['chunked']),
    );
  }

  /// Client-generated (UUIDv7); the drive item's uuid.
  _isc.UuidValue itemUuid;

  /// Client-generated; the `driveFile` StoredFile's uuid.
  _isc.UuidValue fileUuid;

  /// Null = My Drive root.
  _isc.UuidValue? parentUuid;

  /// Original file name (display name; sanitized by the server, Drive 02 §5.1).
  String name;

  int sizeBytes;

  /// Browser/OS type, informative only (the server sniffs, Drive 02 §5).
  String? declaredMimeType;

  DateTime? lastModified;

  _iux1qhua.UploadConflictMode conflict;

  /// P1 resumable upload (Drive 02 §4.3).
  bool chunked;

  /// Returns a shallow copy of this [FileUploadRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FileUploadRequest copyWith({
    _isc.UuidValue? itemUuid,
    _isc.UuidValue? fileUuid,
    _isc.UuidValue? parentUuid = const _isc.$UndefinedUuidValue(),
    String? name,
    int? sizeBytes,
    String? declaredMimeType,
    DateTime? lastModified = const _isc.$UndefinedDateTime(),
    _iux1qhua.UploadConflictMode? conflict,
    bool? chunked,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FileUploadRequest',
      'itemUuid': itemUuid.toJson(),
      'fileUuid': fileUuid.toJson(),
      if (parentUuid != null) 'parentUuid': parentUuid?.toJson(),
      'name': name,
      'sizeBytes': sizeBytes,
      if (declaredMimeType != null) 'declaredMimeType': declaredMimeType,
      if (lastModified != null) 'lastModified': lastModified?.toJson(),
      'conflict': conflict.toJson(),
      'chunked': chunked,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FileUploadRequest',
      'itemUuid': itemUuid.toJson(),
      'fileUuid': fileUuid.toJson(),
      if (parentUuid != null) 'parentUuid': parentUuid?.toJson(),
      'name': name,
      'sizeBytes': sizeBytes,
      if (declaredMimeType != null) 'declaredMimeType': declaredMimeType,
      if (lastModified != null) 'lastModified': lastModified?.toJson(),
      'conflict': conflict.toJson(),
      'chunked': chunked,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FileUploadRequestImpl extends FileUploadRequest {
  _FileUploadRequestImpl({
    required _isc.UuidValue itemUuid,
    required _isc.UuidValue fileUuid,
    _isc.UuidValue? parentUuid,
    required String name,
    required int sizeBytes,
    String? declaredMimeType,
    DateTime? lastModified,
    _iux1qhua.UploadConflictMode? conflict,
    bool? chunked,
  }) : super._(
         itemUuid: itemUuid,
         fileUuid: fileUuid,
         parentUuid: parentUuid,
         name: name,
         sizeBytes: sizeBytes,
         declaredMimeType: declaredMimeType,
         lastModified: lastModified,
         conflict: conflict,
         chunked: chunked,
       );

  /// Returns a shallow copy of this [FileUploadRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FileUploadRequest copyWith({
    _isc.UuidValue? itemUuid,
    _isc.UuidValue? fileUuid,
    _isc.UuidValue? parentUuid = const _isc.$UndefinedUuidValue(),
    String? name,
    int? sizeBytes,
    Object? declaredMimeType = _Undefined,
    DateTime? lastModified = const _isc.$UndefinedDateTime(),
    _iux1qhua.UploadConflictMode? conflict,
    bool? chunked,
  }) {
    return FileUploadRequest(
      itemUuid: itemUuid ?? this.itemUuid,
      fileUuid: fileUuid ?? this.fileUuid,
      parentUuid: parentUuid is _isc.UndefinedSentinel
          ? this.parentUuid
          : parentUuid,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      declaredMimeType: declaredMimeType is String?
          ? declaredMimeType
          : this.declaredMimeType,
      lastModified: lastModified is _isc.UndefinedSentinel
          ? this.lastModified
          : lastModified,
      conflict: conflict ?? this.conflict,
      chunked: chunked ?? this.chunked,
    );
  }
}
