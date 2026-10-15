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

abstract class BoardReviewCounts
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardReviewCounts._({
    required this.held,
    required this.check,
    required this.unchecked,
    required this.duplicates,
    required this.drafts,
    required this.suggestions,
  });

  factory BoardReviewCounts({
    required int held,
    required int check,
    required int unchecked,
    required int duplicates,
    required int drafts,
    required int suggestions,
  }) = _BoardReviewCountsImpl;

  factory BoardReviewCounts.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardReviewCounts(
      held: jsonSerialization['held'] as int,
      check: jsonSerialization['check'] as int,
      unchecked: jsonSerialization['unchecked'] as int,
      duplicates: jsonSerialization['duplicates'] as int,
      drafts: jsonSerialization['drafts'] as int,
      suggestions: jsonSerialization['suggestions'] as int,
    );
  }

  int held;

  int check;

  int unchecked;

  int duplicates;

  int drafts;

  int suggestions;

  /// Returns a shallow copy of this [BoardReviewCounts]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardReviewCounts copyWith({
    int? held,
    int? check,
    int? unchecked,
    int? duplicates,
    int? drafts,
    int? suggestions,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardReviewCounts',
      'held': held,
      'check': check,
      'unchecked': unchecked,
      'duplicates': duplicates,
      'drafts': drafts,
      'suggestions': suggestions,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardReviewCounts',
      'held': held,
      'check': check,
      'unchecked': unchecked,
      'duplicates': duplicates,
      'drafts': drafts,
      'suggestions': suggestions,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BoardReviewCountsImpl extends BoardReviewCounts {
  _BoardReviewCountsImpl({
    required int held,
    required int check,
    required int unchecked,
    required int duplicates,
    required int drafts,
    required int suggestions,
  }) : super._(
         held: held,
         check: check,
         unchecked: unchecked,
         duplicates: duplicates,
         drafts: drafts,
         suggestions: suggestions,
       );

  /// Returns a shallow copy of this [BoardReviewCounts]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardReviewCounts copyWith({
    int? held,
    int? check,
    int? unchecked,
    int? duplicates,
    int? drafts,
    int? suggestions,
  }) {
    return BoardReviewCounts(
      held: held ?? this.held,
      check: check ?? this.check,
      unchecked: unchecked ?? this.unchecked,
      duplicates: duplicates ?? this.duplicates,
      drafts: drafts ?? this.drafts,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}
