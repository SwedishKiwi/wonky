/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'presentation_update.dart';

/// The presenter asks for a phone-remote pairing key (Slides 10 §6.4,
/// SL-41): the answer is a [PresentationPairingEvent]. Earlier unused keys
/// are revoked; `revoke: true` only revokes them.
abstract class PresentationPairingUpdate extends _i26f4ubs.PresentationUpdate
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationPairingUpdate._({this.revoke});

  factory PresentationPairingUpdate({bool? revoke}) =
      _PresentationPairingUpdateImpl;

  factory PresentationPairingUpdate.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationPairingUpdate(
      revoke: jsonSerialization['revoke'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['revoke']),
    );
  }

  bool? revoke;

  /// Returns a shallow copy of this [PresentationPairingUpdate]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresentationPairingUpdate copyWith({bool? revoke});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationPairingUpdate',
      if (revoke != null) 'revoke': revoke,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationPairingUpdate',
      if (revoke != null) 'revoke': revoke,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationPairingUpdateImpl extends PresentationPairingUpdate {
  _PresentationPairingUpdateImpl({bool? revoke}) : super._(revoke: revoke);

  /// Returns a shallow copy of this [PresentationPairingUpdate]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationPairingUpdate copyWith({Object? revoke = _Undefined}) {
    return PresentationPairingUpdate(
      revoke: revoke is bool? ? revoke : this.revoke,
    );
  }
}
