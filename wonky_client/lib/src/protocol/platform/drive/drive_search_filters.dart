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
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;
import '../../platform/drive/drive_owner_filter.dart' as _ir62qy36;
import '../../platform/drive/file_category.dart' as _idj2ejj9;

/// Filters of `drive.search`.
abstract class DriveSearchFilters
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DriveSearchFilters._({
    this.kinds,
    _ir62qy36.DriveOwnerFilter? owner,
    this.modifiedAfter,
    this.modifiedBefore,
    bool? sharedOnly,
    this.fileCategories,
  }) : owner = owner ?? _ir62qy36.DriveOwnerFilter.anyone,
       sharedOnly = sharedOnly ?? false;

  factory DriveSearchFilters({
    List<_i26ubj99.DriveItemKind>? kinds,
    _ir62qy36.DriveOwnerFilter? owner,
    DateTime? modifiedAfter,
    DateTime? modifiedBefore,
    bool? sharedOnly,
    List<_idj2ejj9.FileCategory>? fileCategories,
  }) = _DriveSearchFiltersImpl;

  factory DriveSearchFilters.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveSearchFilters(
      kinds: jsonSerialization['kinds'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<_i26ubj99.DriveItemKind>>(
              jsonSerialization['kinds'],
            ),
      owner: jsonSerialization['owner'] == null
          ? null
          : _ir62qy36.DriveOwnerFilter.fromJson(
              (jsonSerialization['owner'] as String),
            ),
      modifiedAfter: jsonSerialization['modifiedAfter'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['modifiedAfter'],
            ),
      modifiedBefore: jsonSerialization['modifiedBefore'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['modifiedBefore'],
            ),
      sharedOnly: jsonSerialization['sharedOnly'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['sharedOnly']),
      fileCategories: jsonSerialization['fileCategories'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<_idj2ejj9.FileCategory>>(
              jsonSerialization['fileCategories'],
            ),
    );
  }

  List<_i26ubj99.DriveItemKind>? kinds;

  _ir62qy36.DriveOwnerFilter owner;

  DateTime? modifiedAfter;

  DateTime? modifiedBefore;

  /// Only items shared with or by the caller.
  bool sharedOnly;

  /// (v2) Files only: restrict `file` items to these categories. Null = all.
  List<_idj2ejj9.FileCategory>? fileCategories;

  /// Returns a shallow copy of this [DriveSearchFilters]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DriveSearchFilters copyWith({
    List<_i26ubj99.DriveItemKind>? kinds =
        const _isc.$UndefinedList<_i26ubj99.DriveItemKind>(),
    _ir62qy36.DriveOwnerFilter? owner,
    DateTime? modifiedAfter = const _isc.$UndefinedDateTime(),
    DateTime? modifiedBefore = const _isc.$UndefinedDateTime(),
    bool? sharedOnly,
    List<_idj2ejj9.FileCategory>? fileCategories =
        const _isc.$UndefinedList<_idj2ejj9.FileCategory>(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveSearchFilters',
      if (kinds != null) 'kinds': kinds?.toJson(valueToJson: (v) => v.toJson()),
      'owner': owner.toJson(),
      if (modifiedAfter != null) 'modifiedAfter': modifiedAfter?.toJson(),
      if (modifiedBefore != null) 'modifiedBefore': modifiedBefore?.toJson(),
      'sharedOnly': sharedOnly,
      if (fileCategories != null)
        'fileCategories': fileCategories?.toJson(
          valueToJson: (v) => v.toJson(),
        ),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveSearchFilters',
      if (kinds != null) 'kinds': kinds?.toJson(valueToJson: (v) => v.toJson()),
      'owner': owner.toJson(),
      if (modifiedAfter != null) 'modifiedAfter': modifiedAfter?.toJson(),
      if (modifiedBefore != null) 'modifiedBefore': modifiedBefore?.toJson(),
      'sharedOnly': sharedOnly,
      if (fileCategories != null)
        'fileCategories': fileCategories?.toJson(
          valueToJson: (v) => v.toJson(),
        ),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _DriveSearchFiltersImpl extends DriveSearchFilters {
  _DriveSearchFiltersImpl({
    List<_i26ubj99.DriveItemKind>? kinds,
    _ir62qy36.DriveOwnerFilter? owner,
    DateTime? modifiedAfter,
    DateTime? modifiedBefore,
    bool? sharedOnly,
    List<_idj2ejj9.FileCategory>? fileCategories,
  }) : super._(
         kinds: kinds,
         owner: owner,
         modifiedAfter: modifiedAfter,
         modifiedBefore: modifiedBefore,
         sharedOnly: sharedOnly,
         fileCategories: fileCategories,
       );

  /// Returns a shallow copy of this [DriveSearchFilters]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DriveSearchFilters copyWith({
    List<_i26ubj99.DriveItemKind>? kinds =
        const _isc.$UndefinedList<_i26ubj99.DriveItemKind>(),
    _ir62qy36.DriveOwnerFilter? owner,
    DateTime? modifiedAfter = const _isc.$UndefinedDateTime(),
    DateTime? modifiedBefore = const _isc.$UndefinedDateTime(),
    bool? sharedOnly,
    List<_idj2ejj9.FileCategory>? fileCategories =
        const _isc.$UndefinedList<_idj2ejj9.FileCategory>(),
  }) {
    return DriveSearchFilters(
      kinds: kinds is _isc.UndefinedSentinel
          ? this.kinds?.map((e0) => e0).toList()
          : kinds,
      owner: owner ?? this.owner,
      modifiedAfter: modifiedAfter is _isc.UndefinedSentinel
          ? this.modifiedAfter
          : modifiedAfter,
      modifiedBefore: modifiedBefore is _isc.UndefinedSentinel
          ? this.modifiedBefore
          : modifiedBefore,
      sharedOnly: sharedOnly ?? this.sharedOnly,
      fileCategories: fileCategories is _isc.UndefinedSentinel
          ? this.fileCategories?.map((e0) => e0).toList()
          : fileCategories,
    );
  }
}
