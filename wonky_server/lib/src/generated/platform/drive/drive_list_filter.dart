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
import '../../platform/drive/drive_owner_filter.dart' as _ir62qy36;
import '../../platform/drive/drive_view.dart' as _i18qsry5;

/// Filter of `drive.list`.
abstract class DriveListFilter
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DriveListFilter._({
    _i18qsry5.DriveView? view,
    this.kinds,
    _ir62qy36.DriveOwnerFilter? owner,
  }) : view = view ?? _i18qsry5.DriveView.folder,
       owner = owner ?? _ir62qy36.DriveOwnerFilter.anyone;

  factory DriveListFilter({
    _i18qsry5.DriveView? view,
    List<_i26ubj99.DriveItemKind>? kinds,
    _ir62qy36.DriveOwnerFilter? owner,
  }) = _DriveListFilterImpl;

  factory DriveListFilter.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveListFilter(
      view: jsonSerialization['view'] == null
          ? null
          : _i18qsry5.DriveView.fromJson((jsonSerialization['view'] as String)),
      kinds: jsonSerialization['kinds'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<List<_i26ubj99.DriveItemKind>>(
              jsonSerialization['kinds'],
            ),
      owner: jsonSerialization['owner'] == null
          ? null
          : _ir62qy36.DriveOwnerFilter.fromJson(
              (jsonSerialization['owner'] as String),
            ),
    );
  }

  _i18qsry5.DriveView view;

  /// Null = all kinds.
  List<_i26ubj99.DriveItemKind>? kinds;

  _ir62qy36.DriveOwnerFilter owner;

  /// Returns a shallow copy of this [DriveListFilter]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DriveListFilter copyWith({
    _i18qsry5.DriveView? view,
    List<_i26ubj99.DriveItemKind>? kinds =
        const _is.$UndefinedList<_i26ubj99.DriveItemKind>(),
    _ir62qy36.DriveOwnerFilter? owner,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveListFilter',
      'view': view.toJson(),
      if (kinds != null) 'kinds': kinds?.toJson(valueToJson: (v) => v.toJson()),
      'owner': owner.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveListFilter',
      'view': view.toJson(),
      if (kinds != null) 'kinds': kinds?.toJson(valueToJson: (v) => v.toJson()),
      'owner': owner.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DriveListFilterImpl extends DriveListFilter {
  _DriveListFilterImpl({
    _i18qsry5.DriveView? view,
    List<_i26ubj99.DriveItemKind>? kinds,
    _ir62qy36.DriveOwnerFilter? owner,
  }) : super._(
         view: view,
         kinds: kinds,
         owner: owner,
       );

  /// Returns a shallow copy of this [DriveListFilter]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DriveListFilter copyWith({
    _i18qsry5.DriveView? view,
    List<_i26ubj99.DriveItemKind>? kinds =
        const _is.$UndefinedList<_i26ubj99.DriveItemKind>(),
    _ir62qy36.DriveOwnerFilter? owner,
  }) {
    return DriveListFilter(
      view: view ?? this.view,
      kinds: kinds is _is.UndefinedSentinel
          ? this.kinds?.map((e0) => e0).toList()
          : kinds,
      owner: owner ?? this.owner,
    );
  }
}
