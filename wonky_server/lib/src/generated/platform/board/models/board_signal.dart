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
import '../../../platform/board/models/board_event_kind.dart' as _iuhklii8;

/// Internal bus message on `board:post:<id>` and `board:tasks`.
abstract class BoardSignal
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardSignal._({
    required this.kind,
    required this.number,
  });

  factory BoardSignal({
    required _iuhklii8.BoardEventKind kind,
    required int number,
  }) = _BoardSignalImpl;

  factory BoardSignal.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardSignal(
      kind: _iuhklii8.BoardEventKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      number: jsonSerialization['number'] as int,
    );
  }

  _iuhklii8.BoardEventKind kind;

  int number;

  /// Returns a shallow copy of this [BoardSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardSignal copyWith({
    _iuhklii8.BoardEventKind? kind,
    int? number,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardSignal',
      'kind': kind.toJson(),
      'number': number,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardSignal',
      'kind': kind.toJson(),
      'number': number,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BoardSignalImpl extends BoardSignal {
  _BoardSignalImpl({
    required _iuhklii8.BoardEventKind kind,
    required int number,
  }) : super._(
         kind: kind,
         number: number,
       );

  /// Returns a shallow copy of this [BoardSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardSignal copyWith({
    _iuhklii8.BoardEventKind? kind,
    int? number,
  }) {
    return BoardSignal(
      kind: kind ?? this.kind,
      number: number ?? this.number,
    );
  }
}
