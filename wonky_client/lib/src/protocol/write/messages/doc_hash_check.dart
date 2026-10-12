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

/// Integrity check: SHA-256 of the canonical document JSON at [revision].
abstract class DocHashCheck extends _iototaiw.DocClientMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocHashCheck._({
    required this.revision,
    required this.sha256,
  });

  factory DocHashCheck({
    required int revision,
    required String sha256,
  }) = _DocHashCheckImpl;

  factory DocHashCheck.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocHashCheck(
      revision: jsonSerialization['revision'] as int,
      sha256: jsonSerialization['sha256'] as String,
    );
  }

  int revision;

  String sha256;

  /// Returns a shallow copy of this [DocHashCheck]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  DocHashCheck copyWith({
    int? revision,
    String? sha256,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocHashCheck',
      'revision': revision,
      'sha256': sha256,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocHashCheck',
      'revision': revision,
      'sha256': sha256,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _DocHashCheckImpl extends DocHashCheck {
  _DocHashCheckImpl({
    required int revision,
    required String sha256,
  }) : super._(
         revision: revision,
         sha256: sha256,
       );

  /// Returns a shallow copy of this [DocHashCheck]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocHashCheck copyWith({
    int? revision,
    String? sha256,
  }) {
    return DocHashCheck(
      revision: revision ?? this.revision,
      sha256: sha256 ?? this.sha256,
    );
  }
}
