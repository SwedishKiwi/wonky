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

/// Token usage of one model request (suite 10 §1, daily budgets).
abstract class AiUsage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AiUsage._({
    this.id,
    required this.userId,
    required this.model,
    required this.feature,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheWriteTokens,
    required this.at,
  });

  factory AiUsage({
    int? id,
    required int userId,
    required String model,
    required String feature,
    required int inputTokens,
    required int outputTokens,
    required int cacheReadTokens,
    required int cacheWriteTokens,
    required DateTime at,
  }) = _AiUsageImpl;

  factory AiUsage.fromJson(Map<String, dynamic> jsonSerialization) {
    return AiUsage(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      model: jsonSerialization['model'] as String,
      feature: jsonSerialization['feature'] as String,
      inputTokens: jsonSerialization['inputTokens'] as int,
      outputTokens: jsonSerialization['outputTokens'] as int,
      cacheReadTokens: jsonSerialization['cacheReadTokens'] as int,
      cacheWriteTokens: jsonSerialization['cacheWriteTokens'] as int,
      at: _isc.DateTimeJsonExtension.fromJson(jsonSerialization['at']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  String model;

  /// chat, rewrite, continue, summarize, outline, explain, proofread.
  String feature;

  int inputTokens;

  int outputTokens;

  int cacheReadTokens;

  int cacheWriteTokens;

  DateTime at;

  /// Returns a shallow copy of this [AiUsage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AiUsage copyWith({
    int? id,
    int? userId,
    String? model,
    String? feature,
    int? inputTokens,
    int? outputTokens,
    int? cacheReadTokens,
    int? cacheWriteTokens,
    DateTime? at,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AiUsage',
      if (id != null) 'id': id,
      'userId': userId,
      'model': model,
      'feature': feature,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'cacheReadTokens': cacheReadTokens,
      'cacheWriteTokens': cacheWriteTokens,
      'at': at.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AiUsage',
      if (id != null) 'id': id,
      'userId': userId,
      'model': model,
      'feature': feature,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'cacheReadTokens': cacheReadTokens,
      'cacheWriteTokens': cacheWriteTokens,
      'at': at.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AiUsageImpl extends AiUsage {
  _AiUsageImpl({
    int? id,
    required int userId,
    required String model,
    required String feature,
    required int inputTokens,
    required int outputTokens,
    required int cacheReadTokens,
    required int cacheWriteTokens,
    required DateTime at,
  }) : super._(
         id: id,
         userId: userId,
         model: model,
         feature: feature,
         inputTokens: inputTokens,
         outputTokens: outputTokens,
         cacheReadTokens: cacheReadTokens,
         cacheWriteTokens: cacheWriteTokens,
         at: at,
       );

  /// Returns a shallow copy of this [AiUsage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AiUsage copyWith({
    Object? id = _Undefined,
    int? userId,
    String? model,
    String? feature,
    int? inputTokens,
    int? outputTokens,
    int? cacheReadTokens,
    int? cacheWriteTokens,
    DateTime? at,
  }) {
    return AiUsage(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      model: model ?? this.model,
      feature: feature ?? this.feature,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      cacheReadTokens: cacheReadTokens ?? this.cacheReadTokens,
      cacheWriteTokens: cacheWriteTokens ?? this.cacheWriteTokens,
      at: at ?? this.at,
    );
  }
}
