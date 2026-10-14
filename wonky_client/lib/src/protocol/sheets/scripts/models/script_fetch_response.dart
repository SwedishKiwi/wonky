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

/// Response of the URL fetch proxy (Sheets 09 §8.3).
abstract class ScriptFetchResponse
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ScriptFetchResponse._({
    required this.statusCode,
    required this.headersJson,
    required this.bodyBase64,
    required this.contentText,
  });

  factory ScriptFetchResponse({
    required int statusCode,
    required String headersJson,
    required String bodyBase64,
    required String contentText,
  }) = _ScriptFetchResponseImpl;

  factory ScriptFetchResponse.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScriptFetchResponse(
      statusCode: jsonSerialization['statusCode'] as int,
      headersJson: jsonSerialization['headersJson'] as String,
      bodyBase64: jsonSerialization['bodyBase64'] as String,
      contentText: jsonSerialization['contentText'] as String,
    );
  }

  int statusCode;

  String headersJson;

  String bodyBase64;

  String contentText;

  /// Returns a shallow copy of this [ScriptFetchResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ScriptFetchResponse copyWith({
    int? statusCode,
    String? headersJson,
    String? bodyBase64,
    String? contentText,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScriptFetchResponse',
      'statusCode': statusCode,
      'headersJson': headersJson,
      'bodyBase64': bodyBase64,
      'contentText': contentText,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScriptFetchResponse',
      'statusCode': statusCode,
      'headersJson': headersJson,
      'bodyBase64': bodyBase64,
      'contentText': contentText,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ScriptFetchResponseImpl extends ScriptFetchResponse {
  _ScriptFetchResponseImpl({
    required int statusCode,
    required String headersJson,
    required String bodyBase64,
    required String contentText,
  }) : super._(
         statusCode: statusCode,
         headersJson: headersJson,
         bodyBase64: bodyBase64,
         contentText: contentText,
       );

  /// Returns a shallow copy of this [ScriptFetchResponse]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ScriptFetchResponse copyWith({
    int? statusCode,
    String? headersJson,
    String? bodyBase64,
    String? contentText,
  }) {
    return ScriptFetchResponse(
      statusCode: statusCode ?? this.statusCode,
      headersJson: headersJson ?? this.headersJson,
      bodyBase64: bodyBase64 ?? this.bodyBase64,
      contentText: contentText ?? this.contentText,
    );
  }
}
