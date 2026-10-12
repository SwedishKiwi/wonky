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

/// One proofreading finding (Write 09 §5.5), validated against the head.
abstract class ProofreadIssue
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ProofreadIssue._({
    required this.id,
    required this.quote,
    required this.occurrence,
    required this.replacement,
    required this.category,
    required this.explanation,
    required this.start,
    required this.length,
  });

  factory ProofreadIssue({
    required String id,
    required String quote,
    required int occurrence,
    required String replacement,
    required String category,
    required String explanation,
    required int start,
    required int length,
  }) = _ProofreadIssueImpl;

  factory ProofreadIssue.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProofreadIssue(
      id: jsonSerialization['id'] as String,
      quote: jsonSerialization['quote'] as String,
      occurrence: jsonSerialization['occurrence'] as int,
      replacement: jsonSerialization['replacement'] as String,
      category: jsonSerialization['category'] as String,
      explanation: jsonSerialization['explanation'] as String,
      start: jsonSerialization['start'] as int,
      length: jsonSerialization['length'] as int,
    );
  }

  String id;

  String quote;

  int occurrence;

  String replacement;

  /// spelling | grammar | punctuation | style | clarity
  String category;

  String explanation;

  int start;

  int length;

  /// Returns a shallow copy of this [ProofreadIssue]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ProofreadIssue copyWith({
    String? id,
    String? quote,
    int? occurrence,
    String? replacement,
    String? category,
    String? explanation,
    int? start,
    int? length,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProofreadIssue',
      'id': id,
      'quote': quote,
      'occurrence': occurrence,
      'replacement': replacement,
      'category': category,
      'explanation': explanation,
      'start': start,
      'length': length,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ProofreadIssue',
      'id': id,
      'quote': quote,
      'occurrence': occurrence,
      'replacement': replacement,
      'category': category,
      'explanation': explanation,
      'start': start,
      'length': length,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _ProofreadIssueImpl extends ProofreadIssue {
  _ProofreadIssueImpl({
    required String id,
    required String quote,
    required int occurrence,
    required String replacement,
    required String category,
    required String explanation,
    required int start,
    required int length,
  }) : super._(
         id: id,
         quote: quote,
         occurrence: occurrence,
         replacement: replacement,
         category: category,
         explanation: explanation,
         start: start,
         length: length,
       );

  /// Returns a shallow copy of this [ProofreadIssue]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ProofreadIssue copyWith({
    String? id,
    String? quote,
    int? occurrence,
    String? replacement,
    String? category,
    String? explanation,
    int? start,
    int? length,
  }) {
    return ProofreadIssue(
      id: id ?? this.id,
      quote: quote ?? this.quote,
      occurrence: occurrence ?? this.occurrence,
      replacement: replacement ?? this.replacement,
      category: category ?? this.category,
      explanation: explanation ?? this.explanation,
      start: start ?? this.start,
      length: length ?? this.length,
    );
  }
}
