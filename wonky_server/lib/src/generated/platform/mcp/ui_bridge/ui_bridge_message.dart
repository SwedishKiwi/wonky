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
part 'ui_bridge_cancel.dart';
part 'ui_bridge_hello.dart';
part 'ui_bridge_request.dart';
part 'ui_bridge_response.dart';
part 'ui_bridge_status.dart';
part 'ui_bridge_stop.dart';
part 'ui_bridge_welcome.dart';

/// Messages of `uiBridge.connect` in both directions (suite 09 §6.1).
sealed class UiBridgeMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  UiBridgeMessage();

  /// Returns a shallow copy of this [UiBridgeMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UiBridgeMessage copyWith();
}

class _Undefined {}
