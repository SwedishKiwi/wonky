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
import '../../../platform/ai/models/ai_quality.dart' as _i054hihs;

/// Whether the assistant can be used (suite 10 §1 privacy and limits).
abstract class AssistantStatus
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AssistantStatus._({
    required this.available,
    this.reason,
    this.message,
    required this.quality,
    required this.tokensUsedToday,
    required this.dailyTokenBudget,
  });

  factory AssistantStatus({
    required bool available,
    String? reason,
    String? message,
    required _i054hihs.AiQuality quality,
    required int tokensUsedToday,
    required int dailyTokenBudget,
  }) = _AssistantStatusImpl;

  factory AssistantStatus.fromJson(Map<String, dynamic> jsonSerialization) {
    return AssistantStatus(
      available: _is.BoolJsonExtension.fromJson(jsonSerialization['available']),
      reason: jsonSerialization['reason'] as String?,
      message: jsonSerialization['message'] as String?,
      quality: _i054hihs.AiQuality.fromJson(
        (jsonSerialization['quality'] as String),
      ),
      tokensUsedToday: jsonSerialization['tokensUsedToday'] as int,
      dailyTokenBudget: jsonSerialization['dailyTokenBudget'] as int,
    );
  }

  bool available;

  /// notConfigured | disabled | optedOut | null when available.
  String? reason;

  String? message;

  _i054hihs.AiQuality quality;

  int tokensUsedToday;

  int dailyTokenBudget;

  /// Returns a shallow copy of this [AssistantStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AssistantStatus copyWith({
    bool? available,
    String? reason,
    String? message,
    _i054hihs.AiQuality? quality,
    int? tokensUsedToday,
    int? dailyTokenBudget,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantStatus',
      'available': available,
      if (reason != null) 'reason': reason,
      if (message != null) 'message': message,
      'quality': quality.toJson(),
      'tokensUsedToday': tokensUsedToday,
      'dailyTokenBudget': dailyTokenBudget,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantStatus',
      'available': available,
      if (reason != null) 'reason': reason,
      if (message != null) 'message': message,
      'quality': quality.toJson(),
      'tokensUsedToday': tokensUsedToday,
      'dailyTokenBudget': dailyTokenBudget,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantStatusImpl extends AssistantStatus {
  _AssistantStatusImpl({
    required bool available,
    String? reason,
    String? message,
    required _i054hihs.AiQuality quality,
    required int tokensUsedToday,
    required int dailyTokenBudget,
  }) : super._(
         available: available,
         reason: reason,
         message: message,
         quality: quality,
         tokensUsedToday: tokensUsedToday,
         dailyTokenBudget: dailyTokenBudget,
       );

  /// Returns a shallow copy of this [AssistantStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AssistantStatus copyWith({
    bool? available,
    Object? reason = _Undefined,
    Object? message = _Undefined,
    _i054hihs.AiQuality? quality,
    int? tokensUsedToday,
    int? dailyTokenBudget,
  }) {
    return AssistantStatus(
      available: available ?? this.available,
      reason: reason is String? ? reason : this.reason,
      message: message is String? ? message : this.message,
      quality: quality ?? this.quality,
      tokensUsedToday: tokensUsedToday ?? this.tokensUsedToday,
      dailyTokenBudget: dailyTokenBudget ?? this.dailyTokenBudget,
    );
  }
}
