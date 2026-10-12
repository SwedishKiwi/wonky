/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'doc_server_message.dart';

abstract class DocRemoteCursor extends _iototaiw.DocServerMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocRemoteCursor._({
    required this.sessionId,
    required this.userId,
    required this.revision,
    required this.anchor,
    required this.head,
    required this.focused,
  });

  factory DocRemoteCursor({
    required String sessionId,
    required int userId,
    required int revision,
    required int anchor,
    required int head,
    required bool focused,
  }) = _DocRemoteCursorImpl;

  factory DocRemoteCursor.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocRemoteCursor(
      sessionId: jsonSerialization['sessionId'] as String,
      userId: jsonSerialization['userId'] as int,
      revision: jsonSerialization['revision'] as int,
      anchor: jsonSerialization['anchor'] as int,
      head: jsonSerialization['head'] as int,
      focused: _is.BoolJsonExtension.fromJson(jsonSerialization['focused']),
    );
  }

  String sessionId;

  int userId;

  int revision;

  int anchor;

  int head;

  bool focused;

  /// Returns a shallow copy of this [DocRemoteCursor]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  DocRemoteCursor copyWith({
    String? sessionId,
    int? userId,
    int? revision,
    int? anchor,
    int? head,
    bool? focused,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocRemoteCursor',
      'sessionId': sessionId,
      'userId': userId,
      'revision': revision,
      'anchor': anchor,
      'head': head,
      'focused': focused,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocRemoteCursor',
      'sessionId': sessionId,
      'userId': userId,
      'revision': revision,
      'anchor': anchor,
      'head': head,
      'focused': focused,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DocRemoteCursorImpl extends DocRemoteCursor {
  _DocRemoteCursorImpl({
    required String sessionId,
    required int userId,
    required int revision,
    required int anchor,
    required int head,
    required bool focused,
  }) : super._(
         sessionId: sessionId,
         userId: userId,
         revision: revision,
         anchor: anchor,
         head: head,
         focused: focused,
       );

  /// Returns a shallow copy of this [DocRemoteCursor]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocRemoteCursor copyWith({
    String? sessionId,
    int? userId,
    int? revision,
    int? anchor,
    int? head,
    bool? focused,
  }) {
    return DocRemoteCursor(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      revision: revision ?? this.revision,
      anchor: anchor ?? this.anchor,
      head: head ?? this.head,
      focused: focused ?? this.focused,
    );
  }
}
