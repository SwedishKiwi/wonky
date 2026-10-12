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
import '../../../platform/ai/models/assistant_message_view.dart' as _i4mls35m;
import '../../../platform/ai/models/assistant_thread_view.dart' as _idip3929;

abstract class AssistantThreadDetail
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AssistantThreadDetail._({
    required this.thread,
    required this.messages,
  });

  factory AssistantThreadDetail({
    required _idip3929.AssistantThreadView thread,
    required List<_i4mls35m.AssistantMessageView> messages,
  }) = _AssistantThreadDetailImpl;

  factory AssistantThreadDetail.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AssistantThreadDetail(
      thread: _i8pkqg1o.Protocol().deserialize<_idip3929.AssistantThreadView>(
        jsonSerialization['thread'],
      ),
      messages: _i8pkqg1o.Protocol()
          .deserialize<List<_i4mls35m.AssistantMessageView>>(
            jsonSerialization['messages'],
          ),
    );
  }

  _idip3929.AssistantThreadView thread;

  List<_i4mls35m.AssistantMessageView> messages;

  /// Returns a shallow copy of this [AssistantThreadDetail]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AssistantThreadDetail copyWith({
    _idip3929.AssistantThreadView? thread,
    List<_i4mls35m.AssistantMessageView>? messages,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantThreadDetail',
      'thread': thread.toJson(),
      'messages': messages.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantThreadDetail',
      'thread': thread.toJsonForProtocol(),
      'messages': messages.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _AssistantThreadDetailImpl extends AssistantThreadDetail {
  _AssistantThreadDetailImpl({
    required _idip3929.AssistantThreadView thread,
    required List<_i4mls35m.AssistantMessageView> messages,
  }) : super._(
         thread: thread,
         messages: messages,
       );

  /// Returns a shallow copy of this [AssistantThreadDetail]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AssistantThreadDetail copyWith({
    _idip3929.AssistantThreadView? thread,
    List<_i4mls35m.AssistantMessageView>? messages,
  }) {
    return AssistantThreadDetail(
      thread: thread ?? this.thread.copyWith(),
      messages: messages ?? this.messages.map((e0) => e0.copyWith()).toList(),
    );
  }
}
