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

/// `writeTheme.update`/`rename` with a stale expectedVersion.
abstract class ThemeConflictException
    implements
        _is.SerializableException,
        _is.SerializableModel,
        _is.ProtocolSerialization {
  ThemeConflictException._({
    required this.message,
    required this.serverJson,
    required this.serverVersion,
    required this.serverName,
  });

  factory ThemeConflictException({
    required String message,
    required String serverJson,
    required int serverVersion,
    required String serverName,
  }) = _ThemeConflictExceptionImpl;

  factory ThemeConflictException.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ThemeConflictException(
      message: jsonSerialization['message'] as String,
      serverJson: jsonSerialization['serverJson'] as String,
      serverVersion: jsonSerialization['serverVersion'] as int,
      serverName: jsonSerialization['serverName'] as String,
    );
  }

  String message;

  String serverJson;

  int serverVersion;

  String serverName;

  /// Returns a shallow copy of this [ThemeConflictException]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ThemeConflictException copyWith({
    String? message,
    String? serverJson,
    int? serverVersion,
    String? serverName,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ThemeConflictException',
      'message': message,
      'serverJson': serverJson,
      'serverVersion': serverVersion,
      'serverName': serverName,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ThemeConflictException',
      'message': message,
      'serverJson': serverJson,
      'serverVersion': serverVersion,
      'serverName': serverName,
    };
  }

  @override
  String toString() {
    return 'ThemeConflictException(message: $message, serverJson: $serverJson, serverVersion: $serverVersion, serverName: $serverName)';
  }
}

class _ThemeConflictExceptionImpl extends ThemeConflictException {
  _ThemeConflictExceptionImpl({
    required String message,
    required String serverJson,
    required int serverVersion,
    required String serverName,
  }) : super._(
         message: message,
         serverJson: serverJson,
         serverVersion: serverVersion,
         serverName: serverName,
       );

  /// Returns a shallow copy of this [ThemeConflictException]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ThemeConflictException copyWith({
    String? message,
    String? serverJson,
    int? serverVersion,
    String? serverName,
  }) {
    return ThemeConflictException(
      message: message ?? this.message,
      serverJson: serverJson ?? this.serverJson,
      serverVersion: serverVersion ?? this.serverVersion,
      serverName: serverName ?? this.serverName,
    );
  }
}
