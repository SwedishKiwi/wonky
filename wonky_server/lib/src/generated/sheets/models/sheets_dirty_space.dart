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

/// A spreadsheet space with local writes that may not have reached the
/// server yet (the pending-change guard of suite 12 §2.3: before syncing,
/// the app calls `sheets.ensureSubscribed` for these). Cleared after a
/// complete sync while still a member. Client-only; never synced.
abstract class SheetsDirtySpace
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SheetsDirtySpace._({
    this.id,
    required this.spaceUuid,
    DateTime? markedAt,
  }) : markedAt = markedAt ?? DateTime.now();

  factory SheetsDirtySpace({
    int? id,
    required _is.UuidValue spaceUuid,
    DateTime? markedAt,
  }) = _SheetsDirtySpaceImpl;

  factory SheetsDirtySpace.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsDirtySpace(
      id: jsonSerialization['id'] as int?,
      spaceUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spaceUuid'],
      ),
      markedAt: jsonSerialization['markedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['markedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  _is.UuidValue spaceUuid;

  DateTime markedAt;

  /// Returns a shallow copy of this [SheetsDirtySpace]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsDirtySpace copyWith({
    int? id,
    _is.UuidValue? spaceUuid,
    DateTime? markedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsDirtySpace',
      if (id != null) 'id': id,
      'spaceUuid': spaceUuid.toJson(),
      'markedAt': markedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsDirtySpace',
      if (id != null) 'id': id,
      'spaceUuid': spaceUuid.toJson(),
      'markedAt': markedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsDirtySpaceImpl extends SheetsDirtySpace {
  _SheetsDirtySpaceImpl({
    int? id,
    required _is.UuidValue spaceUuid,
    DateTime? markedAt,
  }) : super._(
         id: id,
         spaceUuid: spaceUuid,
         markedAt: markedAt,
       );

  /// Returns a shallow copy of this [SheetsDirtySpace]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsDirtySpace copyWith({
    Object? id = _Undefined,
    _is.UuidValue? spaceUuid,
    DateTime? markedAt,
  }) {
    return SheetsDirtySpace(
      id: id is int? ? id : this.id,
      spaceUuid: spaceUuid ?? this.spaceUuid,
      markedAt: markedAt ?? this.markedAt,
    );
  }
}
