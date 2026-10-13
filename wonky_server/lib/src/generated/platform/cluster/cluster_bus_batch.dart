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

/// The bus messages one server instance relays to the others in one Redis
/// publish (specs/13 §4): `messages[i]` (encoded with its type) goes to
/// `channels[i]`, in order.
abstract class ClusterBusBatch
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ClusterBusBatch._({
    required this.originInstance,
    required this.channels,
    required this.messages,
  });

  factory ClusterBusBatch({
    required String originInstance,
    required List<String> channels,
    required List<String> messages,
  }) = _ClusterBusBatchImpl;

  factory ClusterBusBatch.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClusterBusBatch(
      originInstance: jsonSerialization['originInstance'] as String,
      channels: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['channels'],
      ),
      messages: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['messages'],
      ),
    );
  }

  /// The instance that posted the batch (it ignores its own batches).
  String originInstance;

  List<String> channels;

  List<String> messages;

  /// Returns a shallow copy of this [ClusterBusBatch]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ClusterBusBatch copyWith({
    String? originInstance,
    List<String>? channels,
    List<String>? messages,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClusterBusBatch',
      'originInstance': originInstance,
      'channels': channels.toJson(),
      'messages': messages.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _ClusterBusBatchImpl extends ClusterBusBatch {
  _ClusterBusBatchImpl({
    required String originInstance,
    required List<String> channels,
    required List<String> messages,
  }) : super._(
         originInstance: originInstance,
         channels: channels,
         messages: messages,
       );

  /// Returns a shallow copy of this [ClusterBusBatch]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ClusterBusBatch copyWith({
    String? originInstance,
    List<String>? channels,
    List<String>? messages,
  }) {
    return ClusterBusBatch(
      originInstance: originInstance ?? this.originInstance,
      channels: channels ?? this.channels.map((e0) => e0).toList(),
      messages: messages ?? this.messages.map((e0) => e0).toList(),
    );
  }
}
