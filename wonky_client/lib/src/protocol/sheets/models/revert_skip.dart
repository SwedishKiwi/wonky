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

abstract class RevertSkip
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  RevertSkip._({
    required this.table,
    required this.rowId,
    required this.column,
    required this.reason,
    this.byUserUuid,
  });

  factory RevertSkip({
    required String table,
    required _isc.UuidValue rowId,
    required String column,
    required String reason,
    _isc.UuidValue? byUserUuid,
  }) = _RevertSkipImpl;

  factory RevertSkip.fromJson(Map<String, dynamic> jsonSerialization) {
    return RevertSkip(
      table: jsonSerialization['table'] as String,
      rowId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['rowId']),
      column: jsonSerialization['column'] as String,
      reason: jsonSerialization['reason'] as String,
      byUserUuid: jsonSerialization['byUserUuid'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['byUserUuid'],
            ),
    );
  }

  String table;

  _isc.UuidValue rowId;

  String column;

  /// changed_by_other or row_deleted.
  String reason;

  _isc.UuidValue? byUserUuid;

  /// Returns a shallow copy of this [RevertSkip]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  RevertSkip copyWith({
    String? table,
    _isc.UuidValue? rowId,
    String? column,
    String? reason,
    _isc.UuidValue? byUserUuid = const _isc.$UndefinedUuidValue(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RevertSkip',
      'table': table,
      'rowId': rowId.toJson(),
      'column': column,
      'reason': reason,
      if (byUserUuid != null) 'byUserUuid': byUserUuid?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RevertSkip',
      'table': table,
      'rowId': rowId.toJson(),
      'column': column,
      'reason': reason,
      if (byUserUuid != null) 'byUserUuid': byUserUuid?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _RevertSkipImpl extends RevertSkip {
  _RevertSkipImpl({
    required String table,
    required _isc.UuidValue rowId,
    required String column,
    required String reason,
    _isc.UuidValue? byUserUuid,
  }) : super._(
         table: table,
         rowId: rowId,
         column: column,
         reason: reason,
         byUserUuid: byUserUuid,
       );

  /// Returns a shallow copy of this [RevertSkip]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  RevertSkip copyWith({
    String? table,
    _isc.UuidValue? rowId,
    String? column,
    String? reason,
    _isc.UuidValue? byUserUuid = const _isc.$UndefinedUuidValue(),
  }) {
    return RevertSkip(
      table: table ?? this.table,
      rowId: rowId ?? this.rowId,
      column: column ?? this.column,
      reason: reason ?? this.reason,
      byUserUuid: byUserUuid is _isc.UndefinedSentinel
          ? this.byUserUuid
          : byUserUuid,
    );
  }
}
