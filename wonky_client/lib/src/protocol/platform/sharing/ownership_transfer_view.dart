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
import '../../platform/users/user_summary.dart' as _itg9e9ms;

abstract class OwnershipTransferView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  OwnershipTransferView._({
    required this.id,
    required this.itemUuid,
    required this.itemName,
    required this.from,
    required this.to,
    required this.createdAt,
  });

  factory OwnershipTransferView({
    required int id,
    required _isc.UuidValue itemUuid,
    required String itemName,
    required _itg9e9ms.UserSummary from,
    required _itg9e9ms.UserSummary to,
    required DateTime createdAt,
  }) = _OwnershipTransferViewImpl;

  factory OwnershipTransferView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OwnershipTransferView(
      id: jsonSerialization['id'] as int,
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      itemName: jsonSerialization['itemName'] as String,
      from: _i8pkqg1o.Protocol().deserialize<_itg9e9ms.UserSummary>(
        jsonSerialization['from'],
      ),
      to: _i8pkqg1o.Protocol().deserialize<_itg9e9ms.UserSummary>(
        jsonSerialization['to'],
      ),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  int id;

  _isc.UuidValue itemUuid;

  String itemName;

  _itg9e9ms.UserSummary from;

  _itg9e9ms.UserSummary to;

  DateTime createdAt;

  /// Returns a shallow copy of this [OwnershipTransferView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  OwnershipTransferView copyWith({
    int? id,
    _isc.UuidValue? itemUuid,
    String? itemName,
    _itg9e9ms.UserSummary? from,
    _itg9e9ms.UserSummary? to,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OwnershipTransferView',
      'id': id,
      'itemUuid': itemUuid.toJson(),
      'itemName': itemName,
      'from': from.toJson(),
      'to': to.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'OwnershipTransferView',
      'id': id,
      'itemUuid': itemUuid.toJson(),
      'itemName': itemName,
      'from': from.toJsonForProtocol(),
      'to': to.toJsonForProtocol(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _OwnershipTransferViewImpl extends OwnershipTransferView {
  _OwnershipTransferViewImpl({
    required int id,
    required _isc.UuidValue itemUuid,
    required String itemName,
    required _itg9e9ms.UserSummary from,
    required _itg9e9ms.UserSummary to,
    required DateTime createdAt,
  }) : super._(
         id: id,
         itemUuid: itemUuid,
         itemName: itemName,
         from: from,
         to: to,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [OwnershipTransferView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  OwnershipTransferView copyWith({
    int? id,
    _isc.UuidValue? itemUuid,
    String? itemName,
    _itg9e9ms.UserSummary? from,
    _itg9e9ms.UserSummary? to,
    DateTime? createdAt,
  }) {
    return OwnershipTransferView(
      id: id ?? this.id,
      itemUuid: itemUuid ?? this.itemUuid,
      itemName: itemName ?? this.itemName,
      from: from ?? this.from.copyWith(),
      to: to ?? this.to.copyWith(),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
