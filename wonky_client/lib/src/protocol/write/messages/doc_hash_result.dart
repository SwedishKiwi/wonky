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

/// Answer to DocHashCheck with the server's hash at that revision.
abstract class DocHashResult extends _iototaiw.DocServerMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocHashResult._({
    required this.revision,
    required this.sha256,
    required this.matches,
  });

  factory DocHashResult({
    required int revision,
    required String sha256,
    required bool matches,
  }) = _DocHashResultImpl;

  factory DocHashResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocHashResult(
      revision: jsonSerialization['revision'] as int,
      sha256: jsonSerialization['sha256'] as String,
      matches: _isc.BoolJsonExtension.fromJson(jsonSerialization['matches']),
    );
  }

  int revision;

  String sha256;

  bool matches;

  /// Returns a shallow copy of this [DocHashResult]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  DocHashResult copyWith({
    int? revision,
    String? sha256,
    bool? matches,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocHashResult',
      'revision': revision,
      'sha256': sha256,
      'matches': matches,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocHashResult',
      'revision': revision,
      'sha256': sha256,
      'matches': matches,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _DocHashResultImpl extends DocHashResult {
  _DocHashResultImpl({
    required int revision,
    required String sha256,
    required bool matches,
  }) : super._(
         revision: revision,
         sha256: sha256,
         matches: matches,
       );

  /// Returns a shallow copy of this [DocHashResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocHashResult copyWith({
    int? revision,
    String? sha256,
    bool? matches,
  }) {
    return DocHashResult(
      revision: revision ?? this.revision,
      sha256: sha256 ?? this.sha256,
      matches: matches ?? this.matches,
    );
  }
}
