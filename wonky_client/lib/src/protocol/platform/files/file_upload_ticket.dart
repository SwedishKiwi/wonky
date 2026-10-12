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
import '../../platform/files/stored_file_status.dart' as _is8j7as8;

/// Upload description for a client-side upload (`FileUploader`).
abstract class FileUploadTicket
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  FileUploadTicket._({
    required this.fileUuid,
    this.uploadDescription,
    required this.status,
  });

  factory FileUploadTicket({
    required _isc.UuidValue fileUuid,
    String? uploadDescription,
    required _is8j7as8.StoredFileStatus status,
  }) = _FileUploadTicketImpl;

  factory FileUploadTicket.fromJson(Map<String, dynamic> jsonSerialization) {
    return FileUploadTicket(
      fileUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['fileUuid'],
      ),
      uploadDescription: jsonSerialization['uploadDescription'] as String?,
      status: _is8j7as8.StoredFileStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
    );
  }

  _isc.UuidValue fileUuid;

  /// Null when the file is already uploaded (idempotent retry).
  String? uploadDescription;

  _is8j7as8.StoredFileStatus status;

  /// Returns a shallow copy of this [FileUploadTicket]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FileUploadTicket copyWith({
    _isc.UuidValue? fileUuid,
    String? uploadDescription,
    _is8j7as8.StoredFileStatus? status,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FileUploadTicket',
      'fileUuid': fileUuid.toJson(),
      if (uploadDescription != null) 'uploadDescription': uploadDescription,
      'status': status.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FileUploadTicket',
      'fileUuid': fileUuid.toJson(),
      if (uploadDescription != null) 'uploadDescription': uploadDescription,
      'status': status.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FileUploadTicketImpl extends FileUploadTicket {
  _FileUploadTicketImpl({
    required _isc.UuidValue fileUuid,
    String? uploadDescription,
    required _is8j7as8.StoredFileStatus status,
  }) : super._(
         fileUuid: fileUuid,
         uploadDescription: uploadDescription,
         status: status,
       );

  /// Returns a shallow copy of this [FileUploadTicket]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FileUploadTicket copyWith({
    _isc.UuidValue? fileUuid,
    Object? uploadDescription = _Undefined,
    _is8j7as8.StoredFileStatus? status,
  }) {
    return FileUploadTicket(
      fileUuid: fileUuid ?? this.fileUuid,
      uploadDescription: uploadDescription is String?
          ? uploadDescription
          : this.uploadDescription,
      status: status ?? this.status,
    );
  }
}
