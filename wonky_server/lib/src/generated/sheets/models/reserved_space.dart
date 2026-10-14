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

/// A space reserved for this device by `sheets.reserveSpaces`, so a
/// spreadsheet can be created while offline (suite 12 §2.2). Client-only
/// (local SQLite of the Sheets app); never synced.
abstract class ReservedSpace
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ReservedSpace._({
    this.id,
    required this.spaceUuid,
    DateTime? reservedAt,
  }) : reservedAt = reservedAt ?? DateTime.now();

  factory ReservedSpace({
    int? id,
    required _is.UuidValue spaceUuid,
    DateTime? reservedAt,
  }) = _ReservedSpaceImpl;

  factory ReservedSpace.fromJson(Map<String, dynamic> jsonSerialization) {
    return ReservedSpace(
      id: jsonSerialization['id'] as int?,
      spaceUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      reservedAt: jsonSerialization['reservedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['reservedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// uuidSpaceId of an empty space reserved for this device.
  _is.UuidValue spaceUuid;

  DateTime reservedAt;

  /// Returns a shallow copy of this [ReservedSpace]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ReservedSpace copyWith({
    int? id,
    _is.UuidValue? spaceUuid,
    DateTime? reservedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ReservedSpace',
      if (id != null) 'id': id,
      'spaceUuid': spaceUuid.toJson(),
      'reservedAt': reservedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ReservedSpace',
      if (id != null) 'id': id,
      'spaceUuid': spaceUuid.toJson(),
      'reservedAt': reservedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReservedSpaceImpl extends ReservedSpace {
  _ReservedSpaceImpl({
    int? id,
    required _is.UuidValue spaceUuid,
    DateTime? reservedAt,
  }) : super._(
         id: id,
         spaceUuid: spaceUuid,
         reservedAt: reservedAt,
       );

  /// Returns a shallow copy of this [ReservedSpace]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ReservedSpace copyWith({
    Object? id = _Undefined,
    _is.UuidValue? spaceUuid,
    DateTime? reservedAt,
  }) {
    return ReservedSpace(
      id: id is int? ? id : this.id,
      spaceUuid: spaceUuid ?? this.spaceUuid,
      reservedAt: reservedAt ?? this.reservedAt,
    );
  }
}
