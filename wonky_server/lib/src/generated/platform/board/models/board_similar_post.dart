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
import '../../../platform/board/models/board_post_kind.dart' as _i76aj3nz;
import '../../../platform/board/models/board_post_status.dart' as _ij83av7d;

abstract class BoardSimilarPost
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardSimilarPost._({
    required this.number,
    required this.kind,
    required this.title,
    required this.status,
    required this.score,
    required this.myVote,
  });

  factory BoardSimilarPost({
    required int number,
    required _i76aj3nz.BoardPostKind kind,
    required String title,
    required _ij83av7d.BoardPostStatus status,
    required int score,
    required int myVote,
  }) = _BoardSimilarPostImpl;

  factory BoardSimilarPost.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardSimilarPost(
      number: jsonSerialization['number'] as int,
      kind: _i76aj3nz.BoardPostKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      title: jsonSerialization['title'] as String,
      status: _ij83av7d.BoardPostStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      score: jsonSerialization['score'] as int,
      myVote: jsonSerialization['myVote'] as int,
    );
  }

  int number;

  _i76aj3nz.BoardPostKind kind;

  String title;

  _ij83av7d.BoardPostStatus status;

  int score;

  int myVote;

  /// Returns a shallow copy of this [BoardSimilarPost]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardSimilarPost copyWith({
    int? number,
    _i76aj3nz.BoardPostKind? kind,
    String? title,
    _ij83av7d.BoardPostStatus? status,
    int? score,
    int? myVote,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardSimilarPost',
      'number': number,
      'kind': kind.toJson(),
      'title': title,
      'status': status.toJson(),
      'score': score,
      'myVote': myVote,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardSimilarPost',
      'number': number,
      'kind': kind.toJson(),
      'title': title,
      'status': status.toJson(),
      'score': score,
      'myVote': myVote,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BoardSimilarPostImpl extends BoardSimilarPost {
  _BoardSimilarPostImpl({
    required int number,
    required _i76aj3nz.BoardPostKind kind,
    required String title,
    required _ij83av7d.BoardPostStatus status,
    required int score,
    required int myVote,
  }) : super._(
         number: number,
         kind: kind,
         title: title,
         status: status,
         score: score,
         myVote: myVote,
       );

  /// Returns a shallow copy of this [BoardSimilarPost]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardSimilarPost copyWith({
    int? number,
    _i76aj3nz.BoardPostKind? kind,
    String? title,
    _ij83av7d.BoardPostStatus? status,
    int? score,
    int? myVote,
  }) {
    return BoardSimilarPost(
      number: number ?? this.number,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      status: status ?? this.status,
      score: score ?? this.score,
      myVote: myVote ?? this.myVote,
    );
  }
}
