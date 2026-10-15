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

/// The caller's storage (Drive 03 §3): `drive.storageUsage()`, the
/// `storageChanged` drive event and the result of byte-adding endpoints.
/// Bytes count the owner's items incl. trash (Drive 03 §2).
abstract class StorageUsage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StorageUsage._({
    required this.bytesUsed,
    required this.documents,
    required this.spreadsheets,
    required this.folders,
    required this.files,
    int? quotaBytes,
    int? reservedBytes,
    int? availableBytes,
    bool? overQuota,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    int? presentations,
    int? maxFileUploadBytes,
    bool? calculating,
  }) : quotaBytes = quotaBytes ?? 52428800,
       reservedBytes = reservedBytes ?? 0,
       availableBytes = availableBytes ?? 0,
       overQuota = overQuota ?? false,
       documentsBytes = documentsBytes ?? 0,
       spreadsheetsBytes = spreadsheetsBytes ?? 0,
       presentationsBytes = presentationsBytes ?? 0,
       filesBytes = filesBytes ?? 0,
       trashBytes = trashBytes ?? 0,
       presentations = presentations ?? 0,
       maxFileUploadBytes = maxFileUploadBytes ?? 0,
       calculating = calculating ?? false;

  factory StorageUsage({
    required int bytesUsed,
    required int documents,
    required int spreadsheets,
    required int folders,
    required int files,
    int? quotaBytes,
    int? reservedBytes,
    int? availableBytes,
    bool? overQuota,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    int? presentations,
    int? maxFileUploadBytes,
    bool? calculating,
  }) = _StorageUsageImpl;

  factory StorageUsage.fromJson(Map<String, dynamic> jsonSerialization) {
    return StorageUsage(
      bytesUsed: jsonSerialization['bytesUsed'] as int,
      documents: jsonSerialization['documents'] as int,
      spreadsheets: jsonSerialization['spreadsheets'] as int,
      folders: jsonSerialization['folders'] as int,
      files: jsonSerialization['files'] as int,
      quotaBytes: jsonSerialization['quotaBytes'] as int?,
      reservedBytes: jsonSerialization['reservedBytes'] as int?,
      availableBytes: jsonSerialization['availableBytes'] as int?,
      overQuota: jsonSerialization['overQuota'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['overQuota']),
      documentsBytes: jsonSerialization['documentsBytes'] as int?,
      spreadsheetsBytes: jsonSerialization['spreadsheetsBytes'] as int?,
      presentationsBytes: jsonSerialization['presentationsBytes'] as int?,
      filesBytes: jsonSerialization['filesBytes'] as int?,
      trashBytes: jsonSerialization['trashBytes'] as int?,
      presentations: jsonSerialization['presentations'] as int?,
      maxFileUploadBytes: jsonSerialization['maxFileUploadBytes'] as int?,
      calculating: jsonSerialization['calculating'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['calculating']),
    );
  }

  /// (v1 meaning changed in v2) Counted usage incl. trash (Drive 03 §2 only).
  int bytesUsed;

  /// Item counts (non-trashed).
  int documents;

  int spreadsheets;

  int folders;

  int files;

  /// (v2) The user's quota (config default or per-user override).
  int quotaBytes;

  /// (v2) Open reservations of pending uploads (Drive 03 §5).
  int reservedBytes;

  /// (v2) max(0, quotaBytes - bytesUsed - reservedBytes).
  int availableBytes;

  /// (v2) bytesUsed > quotaBytes.
  bool overQuota;

  /// (v2) Breakdown of non-trashed items incl. their attachments.
  int documentsBytes;

  int spreadsheetsBytes;

  int presentationsBytes;

  int filesBytes;

  /// (v2) All trashed items.
  int trashBytes;

  int presentations;

  /// (v2) min(availableBytes, wonky.files.maxFileUploadBytes).
  int maxFileUploadBytes;

  /// (v2) The storage backfill for this user hasn't finished (Drive 03 §9):
  /// meters show "Calculating storage…" and enforcement fails open.
  bool calculating;

  /// Returns a shallow copy of this [StorageUsage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StorageUsage copyWith({
    int? bytesUsed,
    int? documents,
    int? spreadsheets,
    int? folders,
    int? files,
    int? quotaBytes,
    int? reservedBytes,
    int? availableBytes,
    bool? overQuota,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    int? presentations,
    int? maxFileUploadBytes,
    bool? calculating,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StorageUsage',
      'bytesUsed': bytesUsed,
      'documents': documents,
      'spreadsheets': spreadsheets,
      'folders': folders,
      'files': files,
      'quotaBytes': quotaBytes,
      'reservedBytes': reservedBytes,
      'availableBytes': availableBytes,
      'overQuota': overQuota,
      'documentsBytes': documentsBytes,
      'spreadsheetsBytes': spreadsheetsBytes,
      'presentationsBytes': presentationsBytes,
      'filesBytes': filesBytes,
      'trashBytes': trashBytes,
      'presentations': presentations,
      'maxFileUploadBytes': maxFileUploadBytes,
      'calculating': calculating,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StorageUsage',
      'bytesUsed': bytesUsed,
      'documents': documents,
      'spreadsheets': spreadsheets,
      'folders': folders,
      'files': files,
      'quotaBytes': quotaBytes,
      'reservedBytes': reservedBytes,
      'availableBytes': availableBytes,
      'overQuota': overQuota,
      'documentsBytes': documentsBytes,
      'spreadsheetsBytes': spreadsheetsBytes,
      'presentationsBytes': presentationsBytes,
      'filesBytes': filesBytes,
      'trashBytes': trashBytes,
      'presentations': presentations,
      'maxFileUploadBytes': maxFileUploadBytes,
      'calculating': calculating,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StorageUsageImpl extends StorageUsage {
  _StorageUsageImpl({
    required int bytesUsed,
    required int documents,
    required int spreadsheets,
    required int folders,
    required int files,
    int? quotaBytes,
    int? reservedBytes,
    int? availableBytes,
    bool? overQuota,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    int? presentations,
    int? maxFileUploadBytes,
    bool? calculating,
  }) : super._(
         bytesUsed: bytesUsed,
         documents: documents,
         spreadsheets: spreadsheets,
         folders: folders,
         files: files,
         quotaBytes: quotaBytes,
         reservedBytes: reservedBytes,
         availableBytes: availableBytes,
         overQuota: overQuota,
         documentsBytes: documentsBytes,
         spreadsheetsBytes: spreadsheetsBytes,
         presentationsBytes: presentationsBytes,
         filesBytes: filesBytes,
         trashBytes: trashBytes,
         presentations: presentations,
         maxFileUploadBytes: maxFileUploadBytes,
         calculating: calculating,
       );

  /// Returns a shallow copy of this [StorageUsage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StorageUsage copyWith({
    int? bytesUsed,
    int? documents,
    int? spreadsheets,
    int? folders,
    int? files,
    int? quotaBytes,
    int? reservedBytes,
    int? availableBytes,
    bool? overQuota,
    int? documentsBytes,
    int? spreadsheetsBytes,
    int? presentationsBytes,
    int? filesBytes,
    int? trashBytes,
    int? presentations,
    int? maxFileUploadBytes,
    bool? calculating,
  }) {
    return StorageUsage(
      bytesUsed: bytesUsed ?? this.bytesUsed,
      documents: documents ?? this.documents,
      spreadsheets: spreadsheets ?? this.spreadsheets,
      folders: folders ?? this.folders,
      files: files ?? this.files,
      quotaBytes: quotaBytes ?? this.quotaBytes,
      reservedBytes: reservedBytes ?? this.reservedBytes,
      availableBytes: availableBytes ?? this.availableBytes,
      overQuota: overQuota ?? this.overQuota,
      documentsBytes: documentsBytes ?? this.documentsBytes,
      spreadsheetsBytes: spreadsheetsBytes ?? this.spreadsheetsBytes,
      presentationsBytes: presentationsBytes ?? this.presentationsBytes,
      filesBytes: filesBytes ?? this.filesBytes,
      trashBytes: trashBytes ?? this.trashBytes,
      presentations: presentations ?? this.presentations,
      maxFileUploadBytes: maxFileUploadBytes ?? this.maxFileUploadBytes,
      calculating: calculating ?? this.calculating,
    );
  }
}
