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
import '../../platform/presence/presence_state.dart' as _ia3e8v5g;

/// Client → server presence update (specs/07 §1.1, Sheets 10 §2).
abstract class PresenceUpdate
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PresenceUpdate._({
    required this.state,
    this.cursorJson,
    this.viewportJson,
    this.mode,
    this.hints,
    this.followingSessionId,
  });

  factory PresenceUpdate({
    required _ia3e8v5g.PresenceState state,
    String? cursorJson,
    String? viewportJson,
    String? mode,
    List<String>? hints,
    String? followingSessionId,
  }) = _PresenceUpdateImpl;

  factory PresenceUpdate.fromJson(Map<String, dynamic> jsonSerialization) {
    return PresenceUpdate(
      state: _ia3e8v5g.PresenceState.fromJson(
        (jsonSerialization['state'] as String),
      ),
      cursorJson: jsonSerialization['cursorJson'] as String?,
      viewportJson: jsonSerialization['viewportJson'] as String?,
      mode: jsonSerialization['mode'] as String?,
      hints: jsonSerialization['hints'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<String>>(
              jsonSerialization['hints'],
            ),
      followingSessionId: jsonSerialization['followingSessionId'] as String?,
    );
  }

  _ia3e8v5g.PresenceState state;

  /// App-specific cursor JSON (Sheets); Write sends null.
  String? cursorJson;

  String? viewportJson;

  /// editing, suggesting or viewing.
  String? mode;

  /// Ephemeral commit hints (Sheets 10 §2.1), each a JSON object.
  List<String>? hints;

  /// Session id the sender is following, or null.
  String? followingSessionId;

  /// Returns a shallow copy of this [PresenceUpdate]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PresenceUpdate copyWith({
    _ia3e8v5g.PresenceState? state,
    String? cursorJson,
    String? viewportJson,
    String? mode,
    List<String>? hints = const _isc.$UndefinedList<String>(),
    String? followingSessionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PresenceUpdate',
      'state': state.toJson(),
      if (cursorJson != null) 'cursorJson': cursorJson,
      if (viewportJson != null) 'viewportJson': viewportJson,
      if (mode != null) 'mode': mode,
      if (hints != null) 'hints': hints?.toJson(),
      if (followingSessionId != null) 'followingSessionId': followingSessionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PresenceUpdate',
      'state': state.toJson(),
      if (cursorJson != null) 'cursorJson': cursorJson,
      if (viewportJson != null) 'viewportJson': viewportJson,
      if (mode != null) 'mode': mode,
      if (hints != null) 'hints': hints?.toJson(),
      if (followingSessionId != null) 'followingSessionId': followingSessionId,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PresenceUpdateImpl extends PresenceUpdate {
  _PresenceUpdateImpl({
    required _ia3e8v5g.PresenceState state,
    String? cursorJson,
    String? viewportJson,
    String? mode,
    List<String>? hints,
    String? followingSessionId,
  }) : super._(
         state: state,
         cursorJson: cursorJson,
         viewportJson: viewportJson,
         mode: mode,
         hints: hints,
         followingSessionId: followingSessionId,
       );

  /// Returns a shallow copy of this [PresenceUpdate]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PresenceUpdate copyWith({
    _ia3e8v5g.PresenceState? state,
    Object? cursorJson = _Undefined,
    Object? viewportJson = _Undefined,
    Object? mode = _Undefined,
    List<String>? hints = const _isc.$UndefinedList<String>(),
    Object? followingSessionId = _Undefined,
  }) {
    return PresenceUpdate(
      state: state ?? this.state,
      cursorJson: cursorJson is String? ? cursorJson : this.cursorJson,
      viewportJson: viewportJson is String? ? viewportJson : this.viewportJson,
      mode: mode is String? ? mode : this.mode,
      hints: hints is _isc.UndefinedSentinel
          ? this.hints?.map((e0) => e0).toList()
          : hints,
      followingSessionId: followingSessionId is String?
          ? followingSessionId
          : this.followingSessionId,
    );
  }
}
