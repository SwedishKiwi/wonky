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

/// A pending ownership transfer; the new owner must accept (specs/06 §4).
abstract class OwnershipTransfer
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  OwnershipTransfer._({
    this.id,
    required this.itemId,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
    this.handledAt,
    this.accepted,
  });

  factory OwnershipTransfer({
    int? id,
    required int itemId,
    required int fromUserId,
    required int toUserId,
    required DateTime createdAt,
    DateTime? handledAt,
    bool? accepted,
  }) = _OwnershipTransferImpl;

  factory OwnershipTransfer.fromJson(Map<String, dynamic> jsonSerialization) {
    return OwnershipTransfer(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      fromUserId: jsonSerialization['fromUserId'] as int,
      toUserId: jsonSerialization['toUserId'] as int,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      handledAt: jsonSerialization['handledAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['handledAt']),
      accepted: jsonSerialization['accepted'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['accepted']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int itemId;

  int fromUserId;

  int toUserId;

  DateTime createdAt;

  DateTime? handledAt;

  bool? accepted;

  /// Returns a shallow copy of this [OwnershipTransfer]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  OwnershipTransfer copyWith({
    int? id,
    int? itemId,
    int? fromUserId,
    int? toUserId,
    DateTime? createdAt,
    DateTime? handledAt = const _isc.$UndefinedDateTime(),
    bool? accepted,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OwnershipTransfer',
      if (id != null) 'id': id,
      'itemId': itemId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'createdAt': createdAt.toJson(),
      if (handledAt != null) 'handledAt': handledAt?.toJson(),
      if (accepted != null) 'accepted': accepted,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'OwnershipTransfer',
      if (id != null) 'id': id,
      'itemId': itemId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'createdAt': createdAt.toJson(),
      if (handledAt != null) 'handledAt': handledAt?.toJson(),
      if (accepted != null) 'accepted': accepted,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OwnershipTransferImpl extends OwnershipTransfer {
  _OwnershipTransferImpl({
    int? id,
    required int itemId,
    required int fromUserId,
    required int toUserId,
    required DateTime createdAt,
    DateTime? handledAt,
    bool? accepted,
  }) : super._(
         id: id,
         itemId: itemId,
         fromUserId: fromUserId,
         toUserId: toUserId,
         createdAt: createdAt,
         handledAt: handledAt,
         accepted: accepted,
       );

  /// Returns a shallow copy of this [OwnershipTransfer]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  OwnershipTransfer copyWith({
    Object? id = _Undefined,
    int? itemId,
    int? fromUserId,
    int? toUserId,
    DateTime? createdAt,
    DateTime? handledAt = const _isc.$UndefinedDateTime(),
    Object? accepted = _Undefined,
  }) {
    return OwnershipTransfer(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      createdAt: createdAt ?? this.createdAt,
      handledAt: handledAt is _isc.UndefinedSentinel
          ? this.handledAt
          : handledAt,
      accepted: accepted is bool? ? accepted : this.accepted,
    );
  }
}
