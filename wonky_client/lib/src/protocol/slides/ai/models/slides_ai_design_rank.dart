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

/// One ranked design idea (Slides 11 §6.6 `rank_designs`).
abstract class SlidesAiDesignRank
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SlidesAiDesignRank._({
    required this.candidateId,
    required this.score,
    this.reason,
  });

  factory SlidesAiDesignRank({
    required String candidateId,
    required double score,
    String? reason,
  }) = _SlidesAiDesignRankImpl;

  factory SlidesAiDesignRank.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlidesAiDesignRank(
      candidateId: jsonSerialization['candidateId'] as String,
      score: (jsonSerialization['score'] as num).toDouble(),
      reason: jsonSerialization['reason'] as String?,
    );
  }

  String candidateId;

  double score;

  String? reason;

  /// Returns a shallow copy of this [SlidesAiDesignRank]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SlidesAiDesignRank copyWith({
    String? candidateId,
    double? score,
    String? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiDesignRank',
      'candidateId': candidateId,
      'score': score,
      if (reason != null) 'reason': reason,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiDesignRank',
      'candidateId': candidateId,
      'score': score,
      if (reason != null) 'reason': reason,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SlidesAiDesignRankImpl extends SlidesAiDesignRank {
  _SlidesAiDesignRankImpl({
    required String candidateId,
    required double score,
    String? reason,
  }) : super._(
         candidateId: candidateId,
         score: score,
         reason: reason,
       );

  /// Returns a shallow copy of this [SlidesAiDesignRank]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SlidesAiDesignRank copyWith({
    String? candidateId,
    double? score,
    Object? reason = _Undefined,
  }) {
    return SlidesAiDesignRank(
      candidateId: candidateId ?? this.candidateId,
      score: score ?? this.score,
      reason: reason is String? ? reason : this.reason,
    );
  }
}
