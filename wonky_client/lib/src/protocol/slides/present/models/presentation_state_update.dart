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

abstract class PresentationStateUpdate extends _i26f4ubs.PresentationUpdate
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationStateUpdate._({required this.state});

  factory PresentationStateUpdate({
    required _i4sa9kmk.PresentationState state,
  }) = _PresentationStateUpdateImpl;

  factory PresentationStateUpdate.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PresentationStateUpdate(
      state: _i8pkqg1o.Protocol().deserialize<_i4sa9kmk.PresentationState>(
        jsonSerialization['state'],
      ),
    );
  }

  _i4sa9kmk.PresentationState state;

  /// Returns a shallow copy of this [PresentationStateUpdate]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  PresentationStateUpdate copyWith({_i4sa9kmk.PresentationState? state});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresentationStateUpdate',
      'state': state.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresentationStateUpdate',
      'state': state.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PresentationStateUpdateImpl extends PresentationStateUpdate {
  _PresentationStateUpdateImpl({required _i4sa9kmk.PresentationState state})
    : super._(state: state);

  /// Returns a shallow copy of this [PresentationStateUpdate]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresentationStateUpdate copyWith({_i4sa9kmk.PresentationState? state}) {
    return PresentationStateUpdate(state: state ?? this.state.copyWith());
  }
}
