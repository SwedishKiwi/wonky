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
import '../../platform/drive/drive_change_kind.dart' as _ijkkpwz4;
import '../../platform/drive/drive_item_view.dart' as _ivpffrb8;

/// A live drive change for the watching user (`drive.watch`).
abstract class DriveChange
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DriveChange._({
    required this.kind,
    required this.itemUuid,
    this.item,
  });

  factory DriveChange({
    required _ijkkpwz4.DriveChangeKind kind,
    required _isc.UuidValue itemUuid,
    _ivpffrb8.DriveItemView? item,
  }) = _DriveChangeImpl;

  factory DriveChange.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveChange(
      kind: _ijkkpwz4.DriveChangeKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      item: jsonSerialization['item'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_ivpffrb8.DriveItemView>(
              jsonSerialization['item'],
            ),
    );
  }

  _ijkkpwz4.DriveChangeKind kind;

  _isc.UuidValue itemUuid;

  /// The item as the watcher sees it; null for [DriveChangeKind.removed].
  _ivpffrb8.DriveItemView? item;

  /// Returns a shallow copy of this [DriveChange]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DriveChange copyWith({
    _ijkkpwz4.DriveChangeKind? kind,
    _isc.UuidValue? itemUuid,
    _ivpffrb8.DriveItemView? item = const _UndefinedDriveChange$item(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveChange',
      'kind': kind.toJson(),
      'itemUuid': itemUuid.toJson(),
      if (item != null) 'item': item?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveChange',
      'kind': kind.toJson(),
      'itemUuid': itemUuid.toJson(),
      if (item != null) 'item': item?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _UndefinedDriveChange$item extends _isc.UndefinedSentinel
    implements _ivpffrb8.DriveItemView {
  const _UndefinedDriveChange$item();
}

class _DriveChangeImpl extends DriveChange {
  _DriveChangeImpl({
    required _ijkkpwz4.DriveChangeKind kind,
    required _isc.UuidValue itemUuid,
    _ivpffrb8.DriveItemView? item,
  }) : super._(
         kind: kind,
         itemUuid: itemUuid,
         item: item,
       );

  /// Returns a shallow copy of this [DriveChange]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DriveChange copyWith({
    _ijkkpwz4.DriveChangeKind? kind,
    _isc.UuidValue? itemUuid,
    _ivpffrb8.DriveItemView? item = const _UndefinedDriveChange$item(),
  }) {
    return DriveChange(
      kind: kind ?? this.kind,
      itemUuid: itemUuid ?? this.itemUuid,
      item: item is _isc.UndefinedSentinel ? this.item?.copyWith() : item,
    );
  }
}
