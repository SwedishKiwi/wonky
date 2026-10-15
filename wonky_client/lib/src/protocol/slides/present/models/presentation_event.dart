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
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;
import '../../../protocol.dart' as _i26f4ubs;
import 'presentation_participant.dart' as _ib4fvwj1;
import 'presentation_role.dart' as _ia2cflib;
import 'presentation_state.dart' as _i4sa9kmk;
part 'presentation_ink_event.dart';
part 'presentation_command_event.dart';
part 'presentation_state_event.dart';
part 'presentation_ended_event.dart';
part 'presentation_welcome.dart';
part 'presentation_presenter_event.dart';
part 'presentation_laser_event.dart';
part 'presentation_roster_event.dart';

/// Server → client messages of a presentation session (sealed; Slides 10
/// §6.2). Every event carries the server time it was sent at (epoch ms),
/// for the follower's clock offset.
sealed class PresentationEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresentationEvent({required this.serverTimeMs});

  int serverTimeMs;

  /// Returns a shallow copy of this [PresentationEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PresentationEvent copyWith({int? serverTimeMs});
}

class _Undefined {}

class _UndefinedPresentationWelcome$state extends _isc.UndefinedSentinel
    implements _i4sa9kmk.PresentationState {
  const _UndefinedPresentationWelcome$state();
}
