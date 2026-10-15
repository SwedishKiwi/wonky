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
import '../../platform/drive/drive_change_kind.dart' as _ijkkpwz4;
import '../../platform/drive/drive_item_view.dart' as _ivpffrb8;
import '../../platform/drive/storage_usage.dart' as _ibv4vztx;

/// A live drive change for the watching user (`drive.watch`).
abstract class DriveChange
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DriveChange._({
    required this.kind,
    required this.itemUuid,
    this.item,
    this.storage,
  });

  factory DriveChange({
    required _ijkkpwz4.DriveChangeKind kind,
    required _is.UuidValue itemUuid,
    _ivpffrb8.DriveItemView? item,
    _ibv4vztx.StorageUsage? storage,
  }) = _DriveChangeImpl;

  factory DriveChange.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveChange(
      kind: _ijkkpwz4.DriveChangeKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      itemUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      item: jsonSerialization['item'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_ivpffrb8.DriveItemView>(
              jsonSerialization['item'],
            ),
      storage: jsonSerialization['storage'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_ibv4vztx.StorageUsage>(
              jsonSerialization['storage'],
            ),
    );
  }

  _ijkkpwz4.DriveChangeKind kind;

  /// The changed item. (v2) For [DriveChangeKind.storageChanged] the nil
  /// UUID (00000000-0000-0000-0000-000000000000): the change is the
  /// caller's storage, not an item.
  _is.UuidValue itemUuid;

  /// The item as the watcher sees it; null for [DriveChangeKind.removed]
  /// and [DriveChangeKind.storageChanged].
  _ivpffrb8.DriveItemView? item;

  /// (v2) The watcher's new usage; set only for
  /// [DriveChangeKind.storageChanged] (Drive 03 §3).
  _ibv4vztx.StorageUsage? storage;

  /// Returns a shallow copy of this [DriveChange]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DriveChange copyWith({
    _ijkkpwz4.DriveChangeKind? kind,
    _is.UuidValue? itemUuid,
    _ivpffrb8.DriveItemView? item = const _UndefinedDriveChange$item(),
    _ibv4vztx.StorageUsage? storage = const _UndefinedDriveChange$storage(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveChange',
      'kind': kind.toJson(),
      'itemUuid': itemUuid.toJson(),
      if (item != null) 'item': item?.toJson(),
      if (storage != null) 'storage': storage?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveChange',
      'kind': kind.toJson(),
      'itemUuid': itemUuid.toJson(),
      if (item != null) 'item': item?.toJsonForProtocol(),
      if (storage != null) 'storage': storage?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _UndefinedDriveChange$item extends _is.UndefinedSentinel
    implements _ivpffrb8.DriveItemView {
  const _UndefinedDriveChange$item();
}

class _UndefinedDriveChange$storage extends _is.UndefinedSentinel
    implements _ibv4vztx.StorageUsage {
  const _UndefinedDriveChange$storage();
}

class _DriveChangeImpl extends DriveChange {
  _DriveChangeImpl({
    required _ijkkpwz4.DriveChangeKind kind,
    required _is.UuidValue itemUuid,
    _ivpffrb8.DriveItemView? item,
    _ibv4vztx.StorageUsage? storage,
  }) : super._(
         kind: kind,
         itemUuid: itemUuid,
         item: item,
         storage: storage,
       );

  /// Returns a shallow copy of this [DriveChange]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DriveChange copyWith({
    _ijkkpwz4.DriveChangeKind? kind,
    _is.UuidValue? itemUuid,
    _ivpffrb8.DriveItemView? item = const _UndefinedDriveChange$item(),
    _ibv4vztx.StorageUsage? storage = const _UndefinedDriveChange$storage(),
  }) {
    return DriveChange(
      kind: kind ?? this.kind,
      itemUuid: itemUuid ?? this.itemUuid,
      item: item is _is.UndefinedSentinel ? this.item?.copyWith() : item,
      storage: storage is _is.UndefinedSentinel
          ? this.storage?.copyWith()
          : storage,
    );
  }
}
