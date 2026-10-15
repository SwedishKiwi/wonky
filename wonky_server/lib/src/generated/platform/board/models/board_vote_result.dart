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

abstract class BoardVoteResult
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardVoteResult._({
    required this.number,
    required this.score,
    required this.voteCount,
    required this.myVote,
  });

  factory BoardVoteResult({
    required int number,
    required int score,
    required int voteCount,
    required int myVote,
  }) = _BoardVoteResultImpl;

  factory BoardVoteResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardVoteResult(
      number: jsonSerialization['number'] as int,
      score: jsonSerialization['score'] as int,
      voteCount: jsonSerialization['voteCount'] as int,
      myVote: jsonSerialization['myVote'] as int,
    );
  }

  int number;

  int score;

  int voteCount;

  int myVote;

  /// Returns a shallow copy of this [BoardVoteResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardVoteResult copyWith({
    int? number,
    int? score,
    int? voteCount,
    int? myVote,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardVoteResult',
      'number': number,
      'score': score,
      'voteCount': voteCount,
      'myVote': myVote,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardVoteResult',
      'number': number,
      'score': score,
      'voteCount': voteCount,
      'myVote': myVote,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BoardVoteResultImpl extends BoardVoteResult {
  _BoardVoteResultImpl({
    required int number,
    required int score,
    required int voteCount,
    required int myVote,
  }) : super._(
         number: number,
         score: score,
         voteCount: voteCount,
         myVote: myVote,
       );

  /// Returns a shallow copy of this [BoardVoteResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardVoteResult copyWith({
    int? number,
    int? score,
    int? voteCount,
    int? myVote,
  }) {
    return BoardVoteResult(
      number: number ?? this.number,
      score: score ?? this.score,
      voteCount: voteCount ?? this.voteCount,
      myVote: myVote ?? this.myVote,
    );
  }
}
