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

abstract class BoardFutureCallTriageModel
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardFutureCallTriageModel._({required this.postId});

  factory BoardFutureCallTriageModel({required int postId}) =
      _BoardFutureCallTriageModelImpl;

  factory BoardFutureCallTriageModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BoardFutureCallTriageModel(
      postId: jsonSerialization['postId'] as int,
    );
  }

  int postId;

  /// Returns a shallow copy of this [BoardFutureCallTriageModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardFutureCallTriageModel copyWith({int? postId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardFutureCallTriageModel',
      'postId': postId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BoardFutureCallTriageModelImpl extends BoardFutureCallTriageModel {
  _BoardFutureCallTriageModelImpl({required int postId})
    : super._(postId: postId);

  /// Returns a shallow copy of this [BoardFutureCallTriageModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardFutureCallTriageModel copyWith({int? postId}) {
    return BoardFutureCallTriageModel(postId: postId ?? this.postId);
  }
}
