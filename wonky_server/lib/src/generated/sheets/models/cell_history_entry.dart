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
import 'package:wonky_sync_models/wonky_sync_models.dart' as _i810rwvy;
import '../../platform/users/user_summary.dart' as _itg9e9ms;

abstract class CellHistoryEntry
    implements _is.SerializableModel, _is.ProtocolSerialization {
  CellHistoryEntry._({
    required this.changeLogId,
    this.user,
    required this.actorKind,
    required this.label,
    required this.at,
    this.before,
    this.after,
  });

  factory CellHistoryEntry({
    required _is.UuidValue changeLogId,
    _itg9e9ms.UserSummary? user,
    required _i810rwvy.ActorKind actorKind,
    required String label,
    required DateTime at,
    String? before,
    String? after,
  }) = _CellHistoryEntryImpl;

  factory CellHistoryEntry.fromJson(Map<String, dynamic> jsonSerialization) {
    return CellHistoryEntry(
      changeLogId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['changeLogId'],
      ),
      user: jsonSerialization['user'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_itg9e9ms.UserSummary>(
              jsonSerialization['user'],
            ),
      actorKind: _i810rwvy.ActorKind.fromJson(
        (jsonSerialization['actorKind'] as String),
      ),
      label: jsonSerialization['label'] as String,
      at: _is.DateTimeJsonExtension.fromJson(jsonSerialization['at']),
      before: jsonSerialization['before'] as String?,
      after: jsonSerialization['after'] as String?,
    );
  }

  _is.UuidValue changeLogId;

  _itg9e9ms.UserSummary? user;

  _i810rwvy.ActorKind actorKind;

  String label;

  DateTime at;

  String? before;

  String? after;

  /// Returns a shallow copy of this [CellHistoryEntry]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CellHistoryEntry copyWith({
    _is.UuidValue? changeLogId,
    _itg9e9ms.UserSummary? user = const _UndefinedCellHistoryEntry$user(),
    _i810rwvy.ActorKind? actorKind,
    String? label,
    DateTime? at,
    String? before,
    String? after,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CellHistoryEntry',
      'changeLogId': changeLogId.toJson(),
      if (user != null) 'user': user?.toJson(),
      'actorKind': actorKind.toJson(),
      'label': label,
      'at': at.toJson(),
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'CellHistoryEntry',
      'changeLogId': changeLogId.toJson(),
      if (user != null) 'user': user?.toJsonForProtocol(),
      'actorKind': actorKind.toJson(),
      'label': label,
      'at': at.toJson(),
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedCellHistoryEntry$user extends _is.UndefinedSentinel
    implements _itg9e9ms.UserSummary {
  const _UndefinedCellHistoryEntry$user();
}

class _CellHistoryEntryImpl extends CellHistoryEntry {
  _CellHistoryEntryImpl({
    required _is.UuidValue changeLogId,
    _itg9e9ms.UserSummary? user,
    required _i810rwvy.ActorKind actorKind,
    required String label,
    required DateTime at,
    String? before,
    String? after,
  }) : super._(
         changeLogId: changeLogId,
         user: user,
         actorKind: actorKind,
         label: label,
         at: at,
         before: before,
         after: after,
       );

  /// Returns a shallow copy of this [CellHistoryEntry]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CellHistoryEntry copyWith({
    _is.UuidValue? changeLogId,
    _itg9e9ms.UserSummary? user = const _UndefinedCellHistoryEntry$user(),
    _i810rwvy.ActorKind? actorKind,
    String? label,
    DateTime? at,
    Object? before = _Undefined,
    Object? after = _Undefined,
  }) {
    return CellHistoryEntry(
      changeLogId: changeLogId ?? this.changeLogId,
      user: user is _is.UndefinedSentinel ? this.user?.copyWith() : user,
      actorKind: actorKind ?? this.actorKind,
      label: label ?? this.label,
      at: at ?? this.at,
      before: before is String? ? before : this.before,
      after: after is String? ? after : this.after,
    );
  }
}
