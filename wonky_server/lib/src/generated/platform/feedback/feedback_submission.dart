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
import '../../platform/feedback/feedback_kind.dart' as _id0rnmad;

/// Client payload of `feedback.submit` / `feedback.reportError`.
abstract class FeedbackSubmission
    implements _is.SerializableModel, _is.ProtocolSerialization {
  FeedbackSubmission._({
    required this.kind,
    required this.message,
    required this.app,
    required this.appVersion,
    required this.platform,
    this.route,
    this.stackTrace,
    this.contextJson,
  });

  factory FeedbackSubmission({
    required _id0rnmad.FeedbackKind kind,
    required String message,
    required String app,
    required String appVersion,
    required String platform,
    String? route,
    String? stackTrace,
    String? contextJson,
  }) = _FeedbackSubmissionImpl;

  factory FeedbackSubmission.fromJson(Map<String, dynamic> jsonSerialization) {
    return FeedbackSubmission(
      kind: _id0rnmad.FeedbackKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      message: jsonSerialization['message'] as String,
      app: jsonSerialization['app'] as String,
      appVersion: jsonSerialization['appVersion'] as String,
      platform: jsonSerialization['platform'] as String,
      route: jsonSerialization['route'] as String?,
      stackTrace: jsonSerialization['stackTrace'] as String?,
      contextJson: jsonSerialization['contextJson'] as String?,
    );
  }

  _id0rnmad.FeedbackKind kind;

  String message;

  /// write or sheets.
  String app;

  String appVersion;

  String platform;

  String? route;

  String? stackTrace;

  /// Anonymized state, no document content.
  String? contextJson;

  /// Returns a shallow copy of this [FeedbackSubmission]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FeedbackSubmission copyWith({
    _id0rnmad.FeedbackKind? kind,
    String? message,
    String? app,
    String? appVersion,
    String? platform,
    String? route,
    String? stackTrace,
    String? contextJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FeedbackSubmission',
      'kind': kind.toJson(),
      'message': message,
      'app': app,
      'appVersion': appVersion,
      'platform': platform,
      if (route != null) 'route': route,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (contextJson != null) 'contextJson': contextJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FeedbackSubmission',
      'kind': kind.toJson(),
      'message': message,
      'app': app,
      'appVersion': appVersion,
      'platform': platform,
      if (route != null) 'route': route,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (contextJson != null) 'contextJson': contextJson,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FeedbackSubmissionImpl extends FeedbackSubmission {
  _FeedbackSubmissionImpl({
    required _id0rnmad.FeedbackKind kind,
    required String message,
    required String app,
    required String appVersion,
    required String platform,
    String? route,
    String? stackTrace,
    String? contextJson,
  }) : super._(
         kind: kind,
         message: message,
         app: app,
         appVersion: appVersion,
         platform: platform,
         route: route,
         stackTrace: stackTrace,
         contextJson: contextJson,
       );

  /// Returns a shallow copy of this [FeedbackSubmission]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FeedbackSubmission copyWith({
    _id0rnmad.FeedbackKind? kind,
    String? message,
    String? app,
    String? appVersion,
    String? platform,
    Object? route = _Undefined,
    Object? stackTrace = _Undefined,
    Object? contextJson = _Undefined,
  }) {
    return FeedbackSubmission(
      kind: kind ?? this.kind,
      message: message ?? this.message,
      app: app ?? this.app,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      route: route is String? ? route : this.route,
      stackTrace: stackTrace is String? ? stackTrace : this.stackTrace,
      contextJson: contextJson is String? ? contextJson : this.contextJson,
    );
  }
}
