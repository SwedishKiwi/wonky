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

abstract class StorageFutureCallRefreshItemSizeModel
    implements _is.SerializableModel, _is.ProtocolSerialization {
  StorageFutureCallRefreshItemSizeModel._({required this.itemId});

  factory StorageFutureCallRefreshItemSizeModel({required int itemId}) =
      _StorageFutureCallRefreshItemSizeModelImpl;

  factory StorageFutureCallRefreshItemSizeModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StorageFutureCallRefreshItemSizeModel(
      itemId: jsonSerialization['itemId'] as int,
    );
  }

  int itemId;

  /// Returns a shallow copy of this [StorageFutureCallRefreshItemSizeModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StorageFutureCallRefreshItemSizeModel copyWith({int? itemId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StorageFutureCallRefreshItemSizeModel',
      'itemId': itemId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _StorageFutureCallRefreshItemSizeModelImpl
    extends StorageFutureCallRefreshItemSizeModel {
  _StorageFutureCallRefreshItemSizeModelImpl({required int itemId})
    : super._(itemId: itemId);

  /// Returns a shallow copy of this [StorageFutureCallRefreshItemSizeModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StorageFutureCallRefreshItemSizeModel copyWith({int? itemId}) {
    return StorageFutureCallRefreshItemSizeModel(itemId: itemId ?? this.itemId);
  }
}
