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

abstract class WriteVersionDocument
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  WriteVersionDocument._({
    required this.revision,
    required this.deltaJson,
  });

  factory WriteVersionDocument({
    required int revision,
    required String deltaJson,
  }) = _WriteVersionDocumentImpl;

  factory WriteVersionDocument.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WriteVersionDocument(
      revision: jsonSerialization['revision'] as int,
      deltaJson: jsonSerialization['deltaJson'] as String,
    );
  }

  int revision;

  /// Materialized content with comment/suggestion overlays stripped.
  String deltaJson;

  /// Returns a shallow copy of this [WriteVersionDocument]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  WriteVersionDocument copyWith({
    int? revision,
    String? deltaJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WriteVersionDocument',
      'revision': revision,
      'deltaJson': deltaJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WriteVersionDocument',
      'revision': revision,
      'deltaJson': deltaJson,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _WriteVersionDocumentImpl extends WriteVersionDocument {
  _WriteVersionDocumentImpl({
    required int revision,
    required String deltaJson,
  }) : super._(
         revision: revision,
         deltaJson: deltaJson,
       );

  /// Returns a shallow copy of this [WriteVersionDocument]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  WriteVersionDocument copyWith({
    int? revision,
    String? deltaJson,
  }) {
    return WriteVersionDocument(
      revision: revision ?? this.revision,
      deltaJson: deltaJson ?? this.deltaJson,
    );
  }
}
