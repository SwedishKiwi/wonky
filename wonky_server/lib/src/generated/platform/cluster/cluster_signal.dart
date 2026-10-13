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

/// Internal session.messages payload between server instances
/// (specs/13 §4): relays unary calls to the instance that holds the
/// in-memory state they act on, and invalidates per-instance caches.
abstract class ClusterSignal
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ClusterSignal._({
    required this.kind,
    required this.originInstance,
    this.userId,
    this.authUserId,
    this.runId,
    this.threadId,
    this.confirmationId,
    this.allow,
  });

  factory ClusterSignal({
    required String kind,
    required String originInstance,
    int? userId,
    _is.UuidValue? authUserId,
    String? runId,
    int? threadId,
    String? confirmationId,
    bool? allow,
  }) = _ClusterSignalImpl;

  factory ClusterSignal.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClusterSignal(
      kind: jsonSerialization['kind'] as String,
      originInstance: jsonSerialization['originInstance'] as String,
      userId: jsonSerialization['userId'] as int?,
      authUserId: jsonSerialization['authUserId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['authUserId'],
            ),
      runId: jsonSerialization['runId'] as String?,
      threadId: jsonSerialization['threadId'] as int?,
      confirmationId: jsonSerialization['confirmationId'] as String?,
      allow: jsonSerialization['allow'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['allow']),
    );
  }

  /// assistant.stop, assistant.confirm, user.forget.
  String kind;

  /// The instance that posted the signal (it ignores its own signals).
  String originInstance;

  int? userId;

  _is.UuidValue? authUserId;

  String? runId;

  int? threadId;

  String? confirmationId;

  bool? allow;

  /// Returns a shallow copy of this [ClusterSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ClusterSignal copyWith({
    String? kind,
    String? originInstance,
    int? userId,
    _is.UuidValue? authUserId = const _is.$UndefinedUuidValue(),
    String? runId,
    int? threadId,
    String? confirmationId,
    bool? allow,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClusterSignal',
      'kind': kind,
      'originInstance': originInstance,
      if (userId != null) 'userId': userId,
      if (authUserId != null) 'authUserId': authUserId?.toJson(),
      if (runId != null) 'runId': runId,
      if (threadId != null) 'threadId': threadId,
      if (confirmationId != null) 'confirmationId': confirmationId,
      if (allow != null) 'allow': allow,
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

class _Undefined {}

class _ClusterSignalImpl extends ClusterSignal {
  _ClusterSignalImpl({
    required String kind,
    required String originInstance,
    int? userId,
    _is.UuidValue? authUserId,
    String? runId,
    int? threadId,
    String? confirmationId,
    bool? allow,
  }) : super._(
         kind: kind,
         originInstance: originInstance,
         userId: userId,
         authUserId: authUserId,
         runId: runId,
         threadId: threadId,
         confirmationId: confirmationId,
         allow: allow,
       );

  /// Returns a shallow copy of this [ClusterSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ClusterSignal copyWith({
    String? kind,
    String? originInstance,
    Object? userId = _Undefined,
    _is.UuidValue? authUserId = const _is.$UndefinedUuidValue(),
    Object? runId = _Undefined,
    Object? threadId = _Undefined,
    Object? confirmationId = _Undefined,
    Object? allow = _Undefined,
  }) {
    return ClusterSignal(
      kind: kind ?? this.kind,
      originInstance: originInstance ?? this.originInstance,
      userId: userId is int? ? userId : this.userId,
      authUserId: authUserId is _is.UndefinedSentinel
          ? this.authUserId
          : authUserId,
      runId: runId is String? ? runId : this.runId,
      threadId: threadId is int? ? threadId : this.threadId,
      confirmationId: confirmationId is String?
          ? confirmationId
          : this.confirmationId,
      allow: allow is bool? ? allow : this.allow,
    );
  }
}
