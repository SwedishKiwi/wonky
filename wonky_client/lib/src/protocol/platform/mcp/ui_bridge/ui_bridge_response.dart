/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'ui_bridge_message.dart';

/// App → server: the result of a [UiBridgeRequest].
abstract class UiBridgeResponse extends _i26f4ubs.UiBridgeMessage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  UiBridgeResponse._({
    required this.requestId,
    required this.ok,
    this.resultJson,
    this.text,
    this.imageBase64,
    this.errorCode,
    this.errorMessage,
    this.errorDetailsJson,
  });

  factory UiBridgeResponse({
    required String requestId,
    required bool ok,
    String? resultJson,
    String? text,
    String? imageBase64,
    String? errorCode,
    String? errorMessage,
    String? errorDetailsJson,
  }) = _UiBridgeResponseImpl;

  factory UiBridgeResponse.fromJson(Map<String, dynamic> jsonSerialization) {
    return UiBridgeResponse(
      requestId: jsonSerialization['requestId'] as String,
      ok: _isc.BoolJsonExtension.fromJson(jsonSerialization['ok']),
      resultJson: jsonSerialization['resultJson'] as String?,
      text: jsonSerialization['text'] as String?,
      imageBase64: jsonSerialization['imageBase64'] as String?,
      errorCode: jsonSerialization['errorCode'] as String?,
      errorMessage: jsonSerialization['errorMessage'] as String?,
      errorDetailsJson: jsonSerialization['errorDetailsJson'] as String?,
    );
  }

  String requestId;

  bool ok;

  /// JSON result (structured content) when [ok].
  String? resultJson;

  /// Short human-readable summary.
  String? text;

  /// Base64 PNG for `ui.screenshot`.
  String? imageBase64;

  String? errorCode;

  String? errorMessage;

  String? errorDetailsJson;

  /// Returns a shallow copy of this [UiBridgeResponse]
  /// with some or all fields replaced by the given arguments.
  @override
  @_isc.useResult
  UiBridgeResponse copyWith({
    String? requestId,
    bool? ok,
    String? resultJson,
    String? text,
    String? imageBase64,
    String? errorCode,
    String? errorMessage,
    String? errorDetailsJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UiBridgeResponse',
      'requestId': requestId,
      'ok': ok,
      if (resultJson != null) 'resultJson': resultJson,
      if (text != null) 'text': text,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (errorDetailsJson != null) 'errorDetailsJson': errorDetailsJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UiBridgeResponse',
      'requestId': requestId,
      'ok': ok,
      if (resultJson != null) 'resultJson': resultJson,
      if (text != null) 'text': text,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (errorDetailsJson != null) 'errorDetailsJson': errorDetailsJson,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _UiBridgeResponseImpl extends UiBridgeResponse {
  _UiBridgeResponseImpl({
    required String requestId,
    required bool ok,
    String? resultJson,
    String? text,
    String? imageBase64,
    String? errorCode,
    String? errorMessage,
    String? errorDetailsJson,
  }) : super._(
         requestId: requestId,
         ok: ok,
         resultJson: resultJson,
         text: text,
         imageBase64: imageBase64,
         errorCode: errorCode,
         errorMessage: errorMessage,
         errorDetailsJson: errorDetailsJson,
       );

  /// Returns a shallow copy of this [UiBridgeResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UiBridgeResponse copyWith({
    String? requestId,
    bool? ok,
    Object? resultJson = _Undefined,
    Object? text = _Undefined,
    Object? imageBase64 = _Undefined,
    Object? errorCode = _Undefined,
    Object? errorMessage = _Undefined,
    Object? errorDetailsJson = _Undefined,
  }) {
    return UiBridgeResponse(
      requestId: requestId ?? this.requestId,
      ok: ok ?? this.ok,
      resultJson: resultJson is String? ? resultJson : this.resultJson,
      text: text is String? ? text : this.text,
      imageBase64: imageBase64 is String? ? imageBase64 : this.imageBase64,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      errorMessage: errorMessage is String? ? errorMessage : this.errorMessage,
      errorDetailsJson: errorDetailsJson is String?
          ? errorDetailsJson
          : this.errorDetailsJson,
    );
  }
}
