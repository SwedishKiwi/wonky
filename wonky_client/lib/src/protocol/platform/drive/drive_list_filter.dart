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
import '../../platform/drive/drive_view.dart' as _i18qsry5;
import '../../platform/drive/file_category.dart' as _idj2ejj9;

/// Filter of `drive.list`.
abstract class DriveListFilter
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DriveListFilter._({
    _i18qsry5.DriveView? view,
    this.kinds,
    _ir62qy36.DriveOwnerFilter? owner,
    this.fileCategories,
    this.foldersContaining,
  }) : view = view ?? _i18qsry5.DriveView.folder,
       owner = owner ?? _ir62qy36.DriveOwnerFilter.anyone;

  factory DriveListFilter({
    _i18qsry5.DriveView? view,
    List<_i26ubj99.DriveItemKind>? kinds,
    _ir62qy36.DriveOwnerFilter? owner,
    List<_idj2ejj9.FileCategory>? fileCategories,
    _i26ubj99.DriveItemKind? foldersContaining,
  }) = _DriveListFilterImpl;

  factory DriveListFilter.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveListFilter(
      view: jsonSerialization['view'] == null
          ? null
          : _i18qsry5.DriveView.fromJson((jsonSerialization['view'] as String)),
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
      fileCategories: jsonSerialization['fileCategories'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<_idj2ejj9.FileCategory>>(
              jsonSerialization['fileCategories'],
            ),
      foldersContaining: jsonSerialization['foldersContaining'] == null
          ? null
          : _i26ubj99.DriveItemKind.fromJson(
              (jsonSerialization['foldersContaining'] as String),
            ),
    );
  }

  _i18qsry5.DriveView view;

  /// Null = all kinds.
  List<_i26ubj99.DriveItemKind>? kinds;

  _ir62qy36.DriveOwnerFilter owner;

  /// (v2) Files only: restrict `file` items to these categories (Drive's
  /// type chip). Null = all categories.
  List<_idj2ejj9.FileCategory>? fileCategories;

  /// (v2) App homes: folders are returned only if their `kindMask` has this
  /// kind (suite 05 §3.2). Null = every folder.
  _i26ubj99.DriveItemKind? foldersContaining;

  /// Returns a shallow copy of this [DriveListFilter]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DriveListFilter copyWith({
    _i18qsry5.DriveView? view,
    List<_i26ubj99.DriveItemKind>? kinds =
        const _isc.$UndefinedList<_i26ubj99.DriveItemKind>(),
    _ir62qy36.DriveOwnerFilter? owner,
    List<_idj2ejj9.FileCategory>? fileCategories =
        const _isc.$UndefinedList<_idj2ejj9.FileCategory>(),
    _i26ubj99.DriveItemKind? foldersContaining,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveListFilter',
      'view': view.toJson(),
      if (kinds != null) 'kinds': kinds?.toJson(valueToJson: (v) => v.toJson()),
      'owner': owner.toJson(),
      if (fileCategories != null)
        'fileCategories': fileCategories?.toJson(
          valueToJson: (v) => v.toJson(),
        ),
      if (foldersContaining != null)
        'foldersContaining': foldersContaining?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveListFilter',
      'view': view.toJson(),
      if (kinds != null) 'kinds': kinds?.toJson(valueToJson: (v) => v.toJson()),
      'owner': owner.toJson(),
      if (fileCategories != null)
        'fileCategories': fileCategories?.toJson(
          valueToJson: (v) => v.toJson(),
        ),
      if (foldersContaining != null)
        'foldersContaining': foldersContaining?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DriveListFilterImpl extends DriveListFilter {
  _DriveListFilterImpl({
    _i18qsry5.DriveView? view,
    List<_i26ubj99.DriveItemKind>? kinds,
    _ir62qy36.DriveOwnerFilter? owner,
    List<_idj2ejj9.FileCategory>? fileCategories,
    _i26ubj99.DriveItemKind? foldersContaining,
  }) : super._(
         view: view,
         kinds: kinds,
         owner: owner,
         fileCategories: fileCategories,
         foldersContaining: foldersContaining,
       );

  /// Returns a shallow copy of this [DriveListFilter]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DriveListFilter copyWith({
    _i18qsry5.DriveView? view,
    List<_i26ubj99.DriveItemKind>? kinds =
        const _isc.$UndefinedList<_i26ubj99.DriveItemKind>(),
    _ir62qy36.DriveOwnerFilter? owner,
    List<_idj2ejj9.FileCategory>? fileCategories =
        const _isc.$UndefinedList<_idj2ejj9.FileCategory>(),
    Object? foldersContaining = _Undefined,
  }) {
    return DriveListFilter(
      view: view ?? this.view,
      kinds: kinds is _isc.UndefinedSentinel
          ? this.kinds?.map((e0) => e0).toList()
          : kinds,
      owner: owner ?? this.owner,
      fileCategories: fileCategories is _isc.UndefinedSentinel
          ? this.fileCategories?.map((e0) => e0).toList()
          : fileCategories,
      foldersContaining: foldersContaining is _i26ubj99.DriveItemKind?
          ? foldersContaining
          : this.foldersContaining,
    );
  }
}
