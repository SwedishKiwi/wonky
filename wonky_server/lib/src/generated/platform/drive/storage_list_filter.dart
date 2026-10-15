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
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;

/// (v2) Filter of `drive.listByStorage` (Storage page, Drive 03 §6.4): the
/// caller's owned items (incl. trashed) sorted by counted size, descending.
abstract class StorageListFilter
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StorageListFilter._({
    this.kinds,
    bool? trashedOnly,
    this.minCountedBytes,
    this.notOpenedSince,
  }) : trashedOnly = trashedOnly ?? false;

  factory StorageListFilter({
    List<_i26ubj99.DriveItemKind>? kinds,
    bool? trashedOnly,
    int? minCountedBytes,
    DateTime? notOpenedSince,
  }) = _StorageListFilterImpl;

  factory StorageListFilter.fromJson(Map<String, dynamic> jsonSerialization) {
    return StorageListFilter(
      kinds: jsonSerialization['kinds'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<List<_i26ubj99.DriveItemKind>>(
              jsonSerialization['kinds'],
            ),
      trashedOnly: jsonSerialization['trashedOnly'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['trashedOnly']),
      minCountedBytes: jsonSerialization['minCountedBytes'] as int?,
      notOpenedSince: jsonSerialization['notOpenedSince'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['notOpenedSince'],
            ),
    );
  }

  /// Null = all kinds except folders.
  List<_i26ubj99.DriveItemKind>? kinds;

  /// Only trashed items (the *Trash* type filter).
  bool trashedOnly;

  /// Only items whose counted size is at least this (*Large files*: 1 MB).
  int? minCountedBytes;

  /// Only items not opened by the caller since this time, or never
  /// (*Not opened in 6 months*).
  DateTime? notOpenedSince;

  /// Returns a shallow copy of this [StorageListFilter]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StorageListFilter copyWith({
    List<_i26ubj99.DriveItemKind>? kinds =
        const _is.$UndefinedList<_i26ubj99.DriveItemKind>(),
    bool? trashedOnly,
    int? minCountedBytes,
    DateTime? notOpenedSince = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StorageListFilter',
      if (kinds != null) 'kinds': kinds?.toJson(valueToJson: (v) => v.toJson()),
      'trashedOnly': trashedOnly,
      if (minCountedBytes != null) 'minCountedBytes': minCountedBytes,
      if (notOpenedSince != null) 'notOpenedSince': notOpenedSince?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StorageListFilter',
      if (kinds != null) 'kinds': kinds?.toJson(valueToJson: (v) => v.toJson()),
      'trashedOnly': trashedOnly,
      if (minCountedBytes != null) 'minCountedBytes': minCountedBytes,
      if (notOpenedSince != null) 'notOpenedSince': notOpenedSince?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StorageListFilterImpl extends StorageListFilter {
  _StorageListFilterImpl({
    List<_i26ubj99.DriveItemKind>? kinds,
    bool? trashedOnly,
    int? minCountedBytes,
    DateTime? notOpenedSince,
  }) : super._(
         kinds: kinds,
         trashedOnly: trashedOnly,
         minCountedBytes: minCountedBytes,
         notOpenedSince: notOpenedSince,
       );

  /// Returns a shallow copy of this [StorageListFilter]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StorageListFilter copyWith({
    List<_i26ubj99.DriveItemKind>? kinds =
        const _is.$UndefinedList<_i26ubj99.DriveItemKind>(),
    bool? trashedOnly,
    Object? minCountedBytes = _Undefined,
    DateTime? notOpenedSince = const _is.$UndefinedDateTime(),
  }) {
    return StorageListFilter(
      kinds: kinds is _is.UndefinedSentinel
          ? this.kinds?.map((e0) => e0).toList()
          : kinds,
      trashedOnly: trashedOnly ?? this.trashedOnly,
      minCountedBytes: minCountedBytes is int?
          ? minCountedBytes
          : this.minCountedBytes,
      notOpenedSince: notOpenedSince is _is.UndefinedSentinel
          ? this.notOpenedSince
          : notOpenedSince,
    );
  }
}
