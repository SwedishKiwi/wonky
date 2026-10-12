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
import '../../platform/drive/drive_sort_field.dart' as _ibyh7r91;

abstract class DriveSort
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DriveSort._({
    _ibyh7r91.DriveSortField? field,
    bool? descending,
    bool? foldersFirst,
  }) : field = field ?? _ibyh7r91.DriveSortField.modifiedAt,
       descending = descending ?? true,
       foldersFirst = foldersFirst ?? true;

  factory DriveSort({
    _ibyh7r91.DriveSortField? field,
    bool? descending,
    bool? foldersFirst,
  }) = _DriveSortImpl;

  factory DriveSort.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveSort(
      field: jsonSerialization['field'] == null
          ? null
          : _ibyh7r91.DriveSortField.fromJson(
              (jsonSerialization['field'] as String),
            ),
      descending: jsonSerialization['descending'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['descending']),
      foldersFirst: jsonSerialization['foldersFirst'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['foldersFirst']),
    );
  }

  _ibyh7r91.DriveSortField field;

  bool descending;

  bool foldersFirst;

  /// Returns a shallow copy of this [DriveSort]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DriveSort copyWith({
    _ibyh7r91.DriveSortField? field,
    bool? descending,
    bool? foldersFirst,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveSort',
      'field': field.toJson(),
      'descending': descending,
      'foldersFirst': foldersFirst,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveSort',
      'field': field.toJson(),
      'descending': descending,
      'foldersFirst': foldersFirst,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DriveSortImpl extends DriveSort {
  _DriveSortImpl({
    _ibyh7r91.DriveSortField? field,
    bool? descending,
    bool? foldersFirst,
  }) : super._(
         field: field,
         descending: descending,
         foldersFirst: foldersFirst,
       );

  /// Returns a shallow copy of this [DriveSort]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DriveSort copyWith({
    _ibyh7r91.DriveSortField? field,
    bool? descending,
    bool? foldersFirst,
  }) {
    return DriveSort(
      field: field ?? this.field,
      descending: descending ?? this.descending,
      foldersFirst: foldersFirst ?? this.foldersFirst,
    );
  }
}
