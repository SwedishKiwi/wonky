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

/// Per-user view state of a drive item (specs/05 §1). A row also makes a
/// link-shared item appear in "Shared with me" after the first open.
abstract class DriveItemUserState
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DriveItemUserState._({
    this.id,
    required this.itemId,
    required this.userId,
    bool? starred,
    this.lastOpenedAt,
    this.lastEditedAt,
    bool? pinnedOffline,
    this.shortcutParentId,
    bool? viaLink,
  }) : starred = starred ?? false,
       pinnedOffline = pinnedOffline ?? false,
       viaLink = viaLink ?? false;

  factory DriveItemUserState({
    int? id,
    required int itemId,
    required int userId,
    bool? starred,
    DateTime? lastOpenedAt,
    DateTime? lastEditedAt,
    bool? pinnedOffline,
    int? shortcutParentId,
    bool? viaLink,
  }) = _DriveItemUserStateImpl;

  factory DriveItemUserState.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveItemUserState(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      userId: jsonSerialization['userId'] as int,
      starred: jsonSerialization['starred'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['starred']),
      lastOpenedAt: jsonSerialization['lastOpenedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastOpenedAt'],
            ),
      lastEditedAt: jsonSerialization['lastEditedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastEditedAt'],
            ),
      pinnedOffline: jsonSerialization['pinnedOffline'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['pinnedOffline']),
      shortcutParentId: jsonSerialization['shortcutParentId'] as int?,
      viaLink: jsonSerialization['viaLink'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['viaLink']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int itemId;

  int userId;

  bool starred;

  DateTime? lastOpenedAt;

  DateTime? lastEditedAt;

  bool pinnedOffline;

  /// "Add shortcut to My Drive" for shared items.
  int? shortcutParentId;

  /// The user opened the item through its share link.
  bool viaLink;

  /// Returns a shallow copy of this [DriveItemUserState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DriveItemUserState copyWith({
    int? id,
    int? itemId,
    int? userId,
    bool? starred,
    DateTime? lastOpenedAt = const _isc.$UndefinedDateTime(),
    DateTime? lastEditedAt = const _isc.$UndefinedDateTime(),
    bool? pinnedOffline,
    int? shortcutParentId,
    bool? viaLink,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveItemUserState',
      if (id != null) 'id': id,
      'itemId': itemId,
      'userId': userId,
      'starred': starred,
      if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt?.toJson(),
      if (lastEditedAt != null) 'lastEditedAt': lastEditedAt?.toJson(),
      'pinnedOffline': pinnedOffline,
      if (shortcutParentId != null) 'shortcutParentId': shortcutParentId,
      'viaLink': viaLink,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveItemUserState',
      if (id != null) 'id': id,
      'itemId': itemId,
      'userId': userId,
      'starred': starred,
      if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt?.toJson(),
      if (lastEditedAt != null) 'lastEditedAt': lastEditedAt?.toJson(),
      'pinnedOffline': pinnedOffline,
      if (shortcutParentId != null) 'shortcutParentId': shortcutParentId,
      'viaLink': viaLink,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DriveItemUserStateImpl extends DriveItemUserState {
  _DriveItemUserStateImpl({
    int? id,
    required int itemId,
    required int userId,
    bool? starred,
    DateTime? lastOpenedAt,
    DateTime? lastEditedAt,
    bool? pinnedOffline,
    int? shortcutParentId,
    bool? viaLink,
  }) : super._(
         id: id,
         itemId: itemId,
         userId: userId,
         starred: starred,
         lastOpenedAt: lastOpenedAt,
         lastEditedAt: lastEditedAt,
         pinnedOffline: pinnedOffline,
         shortcutParentId: shortcutParentId,
         viaLink: viaLink,
       );

  /// Returns a shallow copy of this [DriveItemUserState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DriveItemUserState copyWith({
    Object? id = _Undefined,
    int? itemId,
    int? userId,
    bool? starred,
    DateTime? lastOpenedAt = const _isc.$UndefinedDateTime(),
    DateTime? lastEditedAt = const _isc.$UndefinedDateTime(),
    bool? pinnedOffline,
    Object? shortcutParentId = _Undefined,
    bool? viaLink,
  }) {
    return DriveItemUserState(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      userId: userId ?? this.userId,
      starred: starred ?? this.starred,
      lastOpenedAt: lastOpenedAt is _isc.UndefinedSentinel
          ? this.lastOpenedAt
          : lastOpenedAt,
      lastEditedAt: lastEditedAt is _isc.UndefinedSentinel
          ? this.lastEditedAt
          : lastEditedAt,
      pinnedOffline: pinnedOffline ?? this.pinnedOffline,
      shortcutParentId: shortcutParentId is int?
          ? shortcutParentId
          : this.shortcutParentId,
      viaLink: viaLink ?? this.viaLink,
    );
  }
}
