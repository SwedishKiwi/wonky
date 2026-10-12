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

abstract class AssistantThreadView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AssistantThreadView._({
    required this.id,
    this.itemUuid,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssistantThreadView({
    required int id,
    _isc.UuidValue? itemUuid,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AssistantThreadViewImpl;

  factory AssistantThreadView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AssistantThreadView(
      id: jsonSerialization['id'] as int,
      itemUuid: jsonSerialization['itemUuid'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['itemUuid']),
      title: jsonSerialization['title'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  int id;

  _isc.UuidValue? itemUuid;

  String title;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [AssistantThreadView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AssistantThreadView copyWith({
    int? id,
    _isc.UuidValue? itemUuid = const _isc.$UndefinedUuidValue(),
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantThreadView',
      'id': id,
      if (itemUuid != null) 'itemUuid': itemUuid?.toJson(),
      'title': title,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantThreadView',
      'id': id,
      if (itemUuid != null) 'itemUuid': itemUuid?.toJson(),
      'title': title,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _AssistantThreadViewImpl extends AssistantThreadView {
  _AssistantThreadViewImpl({
    required int id,
    _isc.UuidValue? itemUuid,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         itemUuid: itemUuid,
         title: title,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AssistantThreadView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AssistantThreadView copyWith({
    int? id,
    _isc.UuidValue? itemUuid = const _isc.$UndefinedUuidValue(),
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssistantThreadView(
      id: id ?? this.id,
      itemUuid: itemUuid is _isc.UndefinedSentinel ? this.itemUuid : itemUuid,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
