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

/// A warning produced by an import (Write 07 §3, Sheets 11).
abstract class ImportWarningView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ImportWarningView._({
    required this.kind,
    required this.message,
    this.line,
  });

  factory ImportWarningView({
    required String kind,
    required String message,
    int? line,
  }) = _ImportWarningViewImpl;

  factory ImportWarningView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ImportWarningView(
      kind: jsonSerialization['kind'] as String,
      message: jsonSerialization['message'] as String,
      line: jsonSerialization['line'] as int?,
    );
  }

  String kind;

  String message;

  int? line;

  /// Returns a shallow copy of this [ImportWarningView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ImportWarningView copyWith({
    String? kind,
    String? message,
    int? line,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ImportWarningView',
      'kind': kind,
      'message': message,
      if (line != null) 'line': line,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ImportWarningView',
      'kind': kind,
      'message': message,
      if (line != null) 'line': line,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ImportWarningViewImpl extends ImportWarningView {
  _ImportWarningViewImpl({
    required String kind,
    required String message,
    int? line,
  }) : super._(
         kind: kind,
         message: message,
         line: line,
       );

  /// Returns a shallow copy of this [ImportWarningView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ImportWarningView copyWith({
    String? kind,
    String? message,
    Object? line = _Undefined,
  }) {
    return ImportWarningView(
      kind: kind ?? this.kind,
      message: message ?? this.message,
      line: line is int? ? line : this.line,
    );
  }
}
