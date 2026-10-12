/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'doc_client_message.dart';

/// Local selection as Delta offsets at [revision] (throttled 10/s).
abstract class DocCursorUpdate extends _iototaiw.DocClientMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocCursorUpdate._({
    required this.revision,
    required this.anchor,
    required this.head,
    required this.focused,
  });

  factory DocCursorUpdate({
    required int revision,
    required int anchor,
    required int head,
    required bool focused,
  }) = _DocCursorUpdateImpl;

  factory DocCursorUpdate.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocCursorUpdate(
      revision: jsonSerialization['revision'] as int,
      anchor: jsonSerialization['anchor'] as int,
      head: jsonSerialization['head'] as int,
      focused: _is.BoolJsonExtension.fromJson(jsonSerialization['focused']),
    );
  }

  int revision;

  int anchor;

  int head;

  bool focused;

  /// Returns a shallow copy of this [DocCursorUpdate]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  DocCursorUpdate copyWith({
    int? revision,
    int? anchor,
    int? head,
    bool? focused,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocCursorUpdate',
      'revision': revision,
      'anchor': anchor,
      'head': head,
      'focused': focused,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocCursorUpdate',
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

class _DocCursorUpdateImpl extends DocCursorUpdate {
  _DocCursorUpdateImpl({
    required int revision,
    required int anchor,
    required int head,
    required bool focused,
  }) : super._(
         revision: revision,
         anchor: anchor,
         head: head,
         focused: focused,
       );

  /// Returns a shallow copy of this [DocCursorUpdate]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocCursorUpdate copyWith({
    int? revision,
    int? anchor,
    int? head,
    bool? focused,
  }) {
    return DocCursorUpdate(
      revision: revision ?? this.revision,
      anchor: anchor ?? this.anchor,
      head: head ?? this.head,
      focused: focused ?? this.focused,
    );
  }
}
