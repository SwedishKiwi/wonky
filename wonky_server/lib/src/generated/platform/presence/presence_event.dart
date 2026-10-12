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
import '../../protocol.dart' as _iototaiw;
import 'participant.dart' as _ih83ei55;
import 'presence_state.dart' as _i6muekp2;
part 'presence_follower_count.dart';
part 'presence_hints.dart';
part 'presence_joined.dart';
part 'presence_left.dart';
part 'presence_notice.dart';
part 'presence_roster.dart';
part 'presence_updated.dart';

/// Server → client presence events (sealed).
sealed class PresenceEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PresenceEvent();

  /// Returns a shallow copy of this [PresenceEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PresenceEvent copyWith();
}

class _Undefined {}
