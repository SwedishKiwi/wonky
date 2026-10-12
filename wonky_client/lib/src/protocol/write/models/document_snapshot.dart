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

abstract class DocumentSnapshot
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocumentSnapshot._({
    this.id,
    required this.documentId,
    required this.revision,
    required this.deltaJson,
    required this.compressed,
    required this.createdAt,
  });

  factory DocumentSnapshot({
    int? id,
    required int documentId,
    required int revision,
    required String deltaJson,
    required bool compressed,
    required DateTime createdAt,
  }) = _DocumentSnapshotImpl;

  factory DocumentSnapshot.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocumentSnapshot(
      id: jsonSerialization['id'] as int?,
      documentId: jsonSerialization['documentId'] as int,
      revision: jsonSerialization['revision'] as int,
      deltaJson: jsonSerialization['deltaJson'] as String,
      compressed: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['compressed'],
      ),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int documentId;

  int revision;

  /// Full document delta (gzip+base64 when [compressed]).
  String deltaJson;

  bool compressed;

  DateTime createdAt;

  /// Returns a shallow copy of this [DocumentSnapshot]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DocumentSnapshot copyWith({
    int? id,
    int? documentId,
    int? revision,
    String? deltaJson,
    bool? compressed,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocumentSnapshot',
      if (id != null) 'id': id,
      'documentId': documentId,
      'revision': revision,
      'deltaJson': deltaJson,
      'compressed': compressed,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocumentSnapshot',
      if (id != null) 'id': id,
      'documentId': documentId,
      'revision': revision,
      'deltaJson': deltaJson,
      'compressed': compressed,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocumentSnapshotImpl extends DocumentSnapshot {
  _DocumentSnapshotImpl({
    int? id,
    required int documentId,
    required int revision,
    required String deltaJson,
    required bool compressed,
    required DateTime createdAt,
  }) : super._(
         id: id,
         documentId: documentId,
         revision: revision,
         deltaJson: deltaJson,
         compressed: compressed,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DocumentSnapshot]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocumentSnapshot copyWith({
    Object? id = _Undefined,
    int? documentId,
    int? revision,
    String? deltaJson,
    bool? compressed,
    DateTime? createdAt,
  }) {
    return DocumentSnapshot(
      id: id is int? ? id : this.id,
      documentId: documentId ?? this.documentId,
      revision: revision ?? this.revision,
      deltaJson: deltaJson ?? this.deltaJson,
      compressed: compressed ?? this.compressed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
