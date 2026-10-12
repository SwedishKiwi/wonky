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

abstract class StorageUsage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  StorageUsage._({
    required this.bytesUsed,
    required this.documents,
    required this.spreadsheets,
    required this.folders,
    required this.files,
  });

  factory StorageUsage({
    required int bytesUsed,
    required int documents,
    required int spreadsheets,
    required int folders,
    required int files,
  }) = _StorageUsageImpl;

  factory StorageUsage.fromJson(Map<String, dynamic> jsonSerialization) {
    return StorageUsage(
      bytesUsed: jsonSerialization['bytesUsed'] as int,
      documents: jsonSerialization['documents'] as int,
      spreadsheets: jsonSerialization['spreadsheets'] as int,
      folders: jsonSerialization['folders'] as int,
      files: jsonSerialization['files'] as int,
    );
  }

  int bytesUsed;

  int documents;

  int spreadsheets;

  int folders;

  int files;

  /// Returns a shallow copy of this [StorageUsage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  StorageUsage copyWith({
    int? bytesUsed,
    int? documents,
    int? spreadsheets,
    int? folders,
    int? files,
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
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _StorageUsageImpl extends StorageUsage {
  _StorageUsageImpl({
    required int bytesUsed,
    required int documents,
    required int spreadsheets,
    required int folders,
    required int files,
  }) : super._(
         bytesUsed: bytesUsed,
         documents: documents,
         spreadsheets: spreadsheets,
         folders: folders,
         files: files,
       );

  /// Returns a shallow copy of this [StorageUsage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  StorageUsage copyWith({
    int? bytesUsed,
    int? documents,
    int? spreadsheets,
    int? folders,
    int? files,
  }) {
    return StorageUsage(
      bytesUsed: bytesUsed ?? this.bytesUsed,
      documents: documents ?? this.documents,
      spreadsheets: spreadsheets ?? this.spreadsheets,
      folders: folders ?? this.folders,
      files: files ?? this.files,
    );
  }
}
