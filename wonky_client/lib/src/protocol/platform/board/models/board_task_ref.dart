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
import '../../../platform/board/models/board_task_status.dart' as _isr33h3v;

abstract class BoardTaskRef
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardTaskRef._({
    required this.number,
    required this.title,
    required this.status,
  });

  factory BoardTaskRef({
    required int number,
    required String title,
    required _isr33h3v.BoardTaskStatus status,
  }) = _BoardTaskRefImpl;

  factory BoardTaskRef.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardTaskRef(
      number: jsonSerialization['number'] as int,
      title: jsonSerialization['title'] as String,
      status: _isr33h3v.BoardTaskStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
    );
  }

  int number;

  String title;

  _isr33h3v.BoardTaskStatus status;

  /// Returns a shallow copy of this [BoardTaskRef]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardTaskRef copyWith({
    int? number,
    String? title,
    _isr33h3v.BoardTaskStatus? status,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardTaskRef',
      'number': number,
      'title': title,
      'status': status.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardTaskRef',
      'number': number,
      'title': title,
      'status': status.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _BoardTaskRefImpl extends BoardTaskRef {
  _BoardTaskRefImpl({
    required int number,
    required String title,
    required _isr33h3v.BoardTaskStatus status,
  }) : super._(
         number: number,
         title: title,
         status: status,
       );

  /// Returns a shallow copy of this [BoardTaskRef]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardTaskRef copyWith({
    int? number,
    String? title,
    _isr33h3v.BoardTaskStatus? status,
  }) {
    return BoardTaskRef(
      number: number ?? this.number,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }
}
