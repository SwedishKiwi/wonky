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
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;
import '../../platform/drive/drive_item_view.dart' as _ivpffrb8;
import '../../platform/drive/storage_usage.dart' as _ibv4vztx;
import '../../platform/files/file_upload_ticket.dart' as _ipo9m0e6;

/// (v2) Result of `drive.createFileUpload` (Drive 02 §3.3).
abstract class FileUploadStart
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  FileUploadStart._({
    required this.item,
    required this.ticket,
    this.chunkSizeBytes,
    required this.storage,
  });

  factory FileUploadStart({
    required _ivpffrb8.DriveItemView item,
    required _ipo9m0e6.FileUploadTicket ticket,
    int? chunkSizeBytes,
    required _ibv4vztx.StorageUsage storage,
  }) = _FileUploadStartImpl;

  factory FileUploadStart.fromJson(Map<String, dynamic> jsonSerialization) {
    return FileUploadStart(
      item: _i8pkqg1o.Protocol().deserialize<_ivpffrb8.DriveItemView>(
        jsonSerialization['item'],
      ),
      ticket: _i8pkqg1o.Protocol().deserialize<_ipo9m0e6.FileUploadTicket>(
        jsonSerialization['ticket'],
      ),
      chunkSizeBytes: jsonSerialization['chunkSizeBytes'] as int?,
      storage: _i8pkqg1o.Protocol().deserialize<_ibv4vztx.StorageUsage>(
        jsonSerialization['storage'],
      ),
    );
  }

  _ivpffrb8.DriveItemView item;

  /// `uploadDescription` is null when the bytes are already complete
  /// (idempotent retry) or for chunked uploads.
  _ipo9m0e6.FileUploadTicket ticket;

  /// Chunked uploads only (P1).
  int? chunkSizeBytes;

  /// The caller's usage after the reservation (Drive 03 §3).
  _ibv4vztx.StorageUsage storage;

  /// Returns a shallow copy of this [FileUploadStart]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FileUploadStart copyWith({
    _ivpffrb8.DriveItemView? item,
    _ipo9m0e6.FileUploadTicket? ticket,
    int? chunkSizeBytes,
    _ibv4vztx.StorageUsage? storage,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FileUploadStart',
      'item': item.toJson(),
      'ticket': ticket.toJson(),
      if (chunkSizeBytes != null) 'chunkSizeBytes': chunkSizeBytes,
      'storage': storage.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FileUploadStart',
      'item': item.toJsonForProtocol(),
      'ticket': ticket.toJsonForProtocol(),
      if (chunkSizeBytes != null) 'chunkSizeBytes': chunkSizeBytes,
      'storage': storage.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FileUploadStartImpl extends FileUploadStart {
  _FileUploadStartImpl({
    required _ivpffrb8.DriveItemView item,
    required _ipo9m0e6.FileUploadTicket ticket,
    int? chunkSizeBytes,
    required _ibv4vztx.StorageUsage storage,
  }) : super._(
         item: item,
         ticket: ticket,
         chunkSizeBytes: chunkSizeBytes,
         storage: storage,
       );

  /// Returns a shallow copy of this [FileUploadStart]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FileUploadStart copyWith({
    _ivpffrb8.DriveItemView? item,
    _ipo9m0e6.FileUploadTicket? ticket,
    Object? chunkSizeBytes = _Undefined,
    _ibv4vztx.StorageUsage? storage,
  }) {
    return FileUploadStart(
      item: item ?? this.item.copyWith(),
      ticket: ticket ?? this.ticket.copyWith(),
      chunkSizeBytes: chunkSizeBytes is int?
          ? chunkSizeBytes
          : this.chunkSizeBytes,
      storage: storage ?? this.storage.copyWith(),
    );
  }
}
