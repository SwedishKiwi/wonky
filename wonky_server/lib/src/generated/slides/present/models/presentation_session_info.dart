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

/// A live presentation session of the caller on a deck (the *Show audience
/// view here* banner, Slides 10 §5.2).
abstract class PresentationSessionInfo
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationSessionInfo._({
    required this.sessionId,
    required this.deviceLabel,
    required this.startedAtMs,
  });

  factory PresentationSessionInfo({
    required String sessionId,
    required String deviceLabel,
    required int startedAtMs,
  }) = _PresentationSessionInfoImpl;

  factory PresentationSessionInfo.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationSessionInfo(
      sessionId: jsonSerialization['sessionId'] as String,
      deviceLabel: jsonSerialization['deviceLabel'] as String,
      startedAtMs: jsonSerialization['startedAtMs'] as int,
    );
  }

  String sessionId;

  String deviceLabel;

  /// Server time of the presenter's join (epoch ms).
  int startedAtMs;

  /// Returns a shallow copy of this [PresentationSessionInfo]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PresentationSessionInfo copyWith({
    String? sessionId,
    String? deviceLabel,
    int? startedAtMs,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationSessionInfo',
      'sessionId': sessionId,
      'deviceLabel': deviceLabel,
      'startedAtMs': startedAtMs,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationSessionInfo',
      'sessionId': sessionId,
      'deviceLabel': deviceLabel,
      'startedAtMs': startedAtMs,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresentationSessionInfoImpl extends PresentationSessionInfo {
  _PresentationSessionInfoImpl({
    required String sessionId,
    required String deviceLabel,
    required int startedAtMs,
  }) : super._(
         sessionId: sessionId,
         deviceLabel: deviceLabel,
         startedAtMs: startedAtMs,
       );

  /// Returns a shallow copy of this [PresentationSessionInfo]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationSessionInfo copyWith({
    String? sessionId,
    String? deviceLabel,
    int? startedAtMs,
  }) {
    return PresentationSessionInfo(
      sessionId: sessionId ?? this.sessionId,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      startedAtMs: startedAtMs ?? this.startedAtMs,
    );
  }
}
