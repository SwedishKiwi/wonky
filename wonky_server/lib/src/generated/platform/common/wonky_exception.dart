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
import '../../platform/common/wonky_error_code.dart' as _isns0qlp;

/// The common error of Wonky endpoints. Never carries document content.
abstract class WonkyException
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  WonkyException._({
    required this.code,
    required this.message,
    this.detailsJson,
  });

  factory WonkyException({
    required _isns0qlp.WonkyErrorCode code,
    required String message,
    String? detailsJson,
  }) = _WonkyExceptionImpl;

  factory WonkyException.fromJson(Map<String, dynamic> jsonSerialization) {
    return WonkyException(
      code: _isns0qlp.WonkyErrorCode.fromJson(
        (jsonSerialization['code'] as String),
      ),
      message: jsonSerialization['message'] as String,
      detailsJson: jsonSerialization['detailsJson'] as String?,
    );
  }

  _isns0qlp.WonkyErrorCode code;

  String message;

  /// Optional JSON with details for the client (e.g. ids, limits).
  String? detailsJson;

  /// Returns a shallow copy of this [WonkyException]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WonkyException copyWith({
    _isns0qlp.WonkyErrorCode? code,
    String? message,
    String? detailsJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WonkyException',
      'code': code.toJson(),
      'message': message,
      if (detailsJson != null) 'detailsJson': detailsJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WonkyException',
      'code': code.toJson(),
      'message': message,
      if (detailsJson != null) 'detailsJson': detailsJson,
    };
  }

  @override
  String toString() {
    return 'WonkyException(code: $code, message: $message, detailsJson: $detailsJson)';
  }
}

class _Undefined {}

class _WonkyExceptionImpl extends WonkyException {
  _WonkyExceptionImpl({
    required _isns0qlp.WonkyErrorCode code,
    required String message,
    String? detailsJson,
  }) : super._(
         code: code,
         message: message,
         detailsJson: detailsJson,
       );

  /// Returns a shallow copy of this [WonkyException]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WonkyException copyWith({
    _isns0qlp.WonkyErrorCode? code,
    String? message,
    Object? detailsJson = _Undefined,
  }) {
    return WonkyException(
      code: code ?? this.code,
      message: message ?? this.message,
      detailsJson: detailsJson is String? ? detailsJson : this.detailsJson,
    );
  }
}
