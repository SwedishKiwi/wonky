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

/// The presenter ends the session.
abstract class PresentationEndUpdate extends _i26f4ubs.PresentationUpdate
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationEndUpdate._();

  factory PresentationEndUpdate() = _PresentationEndUpdateImpl;

  factory PresentationEndUpdate.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationEndUpdate();
  }

  /// Returns a shallow copy of this [PresentationEndUpdate]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  PresentationEndUpdate copyWith();
  @override
  Map<String, dynamic> toJson() {
    return {'__className__': 'PresentationEndUpdate'};
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {'__className__': 'PresentationEndUpdate'};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _PresentationEndUpdateImpl extends PresentationEndUpdate {
  _PresentationEndUpdateImpl() : super._();

  /// Returns a shallow copy of this [PresentationEndUpdate]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PresentationEndUpdate copyWith() {
    return PresentationEndUpdate();
  }
}
