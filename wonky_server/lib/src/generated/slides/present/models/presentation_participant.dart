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
import '../../../slides/present/models/presentation_role.dart' as _i0s4aueu;

/// A device joined to a presentation session (the presenter's roster).
abstract class PresentationParticipant
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationParticipant._({
    required this.connectionId,
    required this.role,
    required this.deviceLabel,
    required this.userId,
    required this.displayName,
  });

  factory PresentationParticipant({
    required String connectionId,
    required _i0s4aueu.PresentationRole role,
    required String deviceLabel,
    required int userId,
    required String displayName,
  }) = _PresentationParticipantImpl;

  factory PresentationParticipant.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationParticipant(
      connectionId: jsonSerialization['connectionId'] as String,
      role: _i0s4aueu.PresentationRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
      deviceLabel: jsonSerialization['deviceLabel'] as String,
      userId: jsonSerialization['userId'] as int,
      displayName: jsonSerialization['displayName'] as String,
    );
  }

  String connectionId;

  _i0s4aueu.PresentationRole role;

  String deviceLabel;

  int userId;

  String displayName;

  /// Returns a shallow copy of this [PresentationParticipant]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PresentationParticipant copyWith({
    String? connectionId,
    _i0s4aueu.PresentationRole? role,
    String? deviceLabel,
    int? userId,
    String? displayName,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationParticipant',
      'connectionId': connectionId,
      'role': role.toJson(),
      'deviceLabel': deviceLabel,
      'userId': userId,
      'displayName': displayName,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationParticipant',
      'connectionId': connectionId,
      'role': role.toJson(),
      'deviceLabel': deviceLabel,
      'userId': userId,
      'displayName': displayName,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresentationParticipantImpl extends PresentationParticipant {
  _PresentationParticipantImpl({
    required String connectionId,
    required _i0s4aueu.PresentationRole role,
    required String deviceLabel,
    required int userId,
    required String displayName,
  }) : super._(
         connectionId: connectionId,
         role: role,
         deviceLabel: deviceLabel,
         userId: userId,
         displayName: displayName,
       );

  /// Returns a shallow copy of this [PresentationParticipant]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationParticipant copyWith({
    String? connectionId,
    _i0s4aueu.PresentationRole? role,
    String? deviceLabel,
    int? userId,
    String? displayName,
  }) {
    return PresentationParticipant(
      connectionId: connectionId ?? this.connectionId,
      role: role ?? this.role,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
    );
  }
}
