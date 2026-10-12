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
import '../../../platform/ai/models/inline_ai_event_type.dart' as _iireapcc;

abstract class InlineAiEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  InlineAiEvent._({
    required this.type,
    this.text,
    this.markdown,
    this.error,
    this.errorCode,
  });

  factory InlineAiEvent({
    required _iireapcc.InlineAiEventType type,
    String? text,
    String? markdown,
    String? error,
    String? errorCode,
  }) = _InlineAiEventImpl;

  factory InlineAiEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return InlineAiEvent(
      type: _iireapcc.InlineAiEventType.fromJson(
        (jsonSerialization['type'] as String),
      ),
      text: jsonSerialization['text'] as String?,
      markdown: jsonSerialization['markdown'] as String?,
      error: jsonSerialization['error'] as String?,
      errorCode: jsonSerialization['errorCode'] as String?,
    );
  }

  _iireapcc.InlineAiEventType type;

  String? text;

  /// done: the cleaned final Markdown.
  String? markdown;

  String? error;

  String? errorCode;

  /// Returns a shallow copy of this [InlineAiEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  InlineAiEvent copyWith({
    _iireapcc.InlineAiEventType? type,
    String? text,
    String? markdown,
    String? error,
    String? errorCode,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'InlineAiEvent',
      'type': type.toJson(),
      if (text != null) 'text': text,
      if (markdown != null) 'markdown': markdown,
      if (error != null) 'error': error,
      if (errorCode != null) 'errorCode': errorCode,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'InlineAiEvent',
      'type': type.toJson(),
      if (text != null) 'text': text,
      if (markdown != null) 'markdown': markdown,
      if (error != null) 'error': error,
      if (errorCode != null) 'errorCode': errorCode,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _InlineAiEventImpl extends InlineAiEvent {
  _InlineAiEventImpl({
    required _iireapcc.InlineAiEventType type,
    String? text,
    String? markdown,
    String? error,
    String? errorCode,
  }) : super._(
         type: type,
         text: text,
         markdown: markdown,
         error: error,
         errorCode: errorCode,
       );

  /// Returns a shallow copy of this [InlineAiEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  InlineAiEvent copyWith({
    _iireapcc.InlineAiEventType? type,
    Object? text = _Undefined,
    Object? markdown = _Undefined,
    Object? error = _Undefined,
    Object? errorCode = _Undefined,
  }) {
    return InlineAiEvent(
      type: type ?? this.type,
      text: text is String? ? text : this.text,
      markdown: markdown is String? ? markdown : this.markdown,
      error: error is String? ? error : this.error,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
    );
  }
}
