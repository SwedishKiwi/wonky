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

/// An assistant conversation of a user, scoped to a file (suite 10 §2).
abstract class AssistantThread
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AssistantThread._({
    this.id,
    required this.userId,
    this.itemId,
    required this.title,
    this.contextRevision,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssistantThread({
    int? id,
    required int userId,
    int? itemId,
    required String title,
    int? contextRevision,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AssistantThreadImpl;

  factory AssistantThread.fromJson(Map<String, dynamic> jsonSerialization) {
    return AssistantThread(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      itemId: jsonSerialization['itemId'] as int?,
      title: jsonSerialization['title'] as String,
      contextRevision: jsonSerialization['contextRevision'] as int?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  int? itemId;

  String title;

  /// The document revision and Markdown the model last saw (appended as
  /// "document updated" turns when it changes; never rewritten).
  int? contextRevision;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [AssistantThread]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AssistantThread copyWith({
    int? id,
    int? userId,
    int? itemId,
    String? title,
    int? contextRevision,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantThread',
      if (id != null) 'id': id,
      'userId': userId,
      if (itemId != null) 'itemId': itemId,
      'title': title,
      if (contextRevision != null) 'contextRevision': contextRevision,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantThread',
      if (id != null) 'id': id,
      'userId': userId,
      if (itemId != null) 'itemId': itemId,
      'title': title,
      if (contextRevision != null) 'contextRevision': contextRevision,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantThreadImpl extends AssistantThread {
  _AssistantThreadImpl({
    int? id,
    required int userId,
    int? itemId,
    required String title,
    int? contextRevision,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         itemId: itemId,
         title: title,
         contextRevision: contextRevision,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AssistantThread]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AssistantThread copyWith({
    Object? id = _Undefined,
    int? userId,
    Object? itemId = _Undefined,
    String? title,
    Object? contextRevision = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssistantThread(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      itemId: itemId is int? ? itemId : this.itemId,
      title: title ?? this.title,
      contextRevision: contextRevision is int?
          ? contextRevision
          : this.contextRevision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
