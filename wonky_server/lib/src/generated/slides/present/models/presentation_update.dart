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
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;
import '../../../protocol.dart' as _i26f4ubs;
import 'presentation_state.dart' as _i4sa9kmk;
part 'presentation_ink_update.dart';
part 'presentation_state_update.dart';
part 'presentation_command_update.dart';
part 'presentation_laser_update.dart';
part 'presentation_end_update.dart';

/// Client → server messages of a presentation session (Slides 10 §6.2).
/// Only the presenter sends state, laser, ink and end; audiences and
/// remotes send commands.
sealed class PresentationUpdate
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresentationUpdate();

  /// Returns a shallow copy of this [PresentationUpdate]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PresentationUpdate copyWith();
}

class _Undefined {}
