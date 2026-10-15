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
import '../../../platform/board/models/board_author.dart' as _imhv5g8m;
import '../../../platform/board/models/board_flag_reason.dart' as _ienu5u16;

/// A flag as admins see it.
abstract class BoardFlagView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardFlagView._({
    required this.reason,
    this.note,
    this.by,
    required this.createdAt,
  });

  factory BoardFlagView({
    required _ienu5u16.BoardFlagReason reason,
    String? note,
    _imhv5g8m.BoardAuthor? by,
    required DateTime createdAt,
  }) = _BoardFlagViewImpl;

  factory BoardFlagView.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardFlagView(
      reason: _ienu5u16.BoardFlagReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
      note: jsonSerialization['note'] as String?,
      by: jsonSerialization['by'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<_imhv5g8m.BoardAuthor>(
              jsonSerialization['by'],
            ),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  _ienu5u16.BoardFlagReason reason;

  String? note;

  _imhv5g8m.BoardAuthor? by;

  DateTime createdAt;

  /// Returns a shallow copy of this [BoardFlagView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardFlagView copyWith({
    _ienu5u16.BoardFlagReason? reason,
    String? note,
    _imhv5g8m.BoardAuthor? by = const _UndefinedBoardFlagView$by(),
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardFlagView',
      'reason': reason.toJson(),
      if (note != null) 'note': note,
      if (by != null) 'by': by?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardFlagView',
      'reason': reason.toJson(),
      if (note != null) 'note': note,
      if (by != null) 'by': by?.toJsonForProtocol(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedBoardFlagView$by extends _isc.UndefinedSentinel
    implements _imhv5g8m.BoardAuthor {
  const _UndefinedBoardFlagView$by();
}

class _BoardFlagViewImpl extends BoardFlagView {
  _BoardFlagViewImpl({
    required _ienu5u16.BoardFlagReason reason,
    String? note,
    _imhv5g8m.BoardAuthor? by,
    required DateTime createdAt,
  }) : super._(
         reason: reason,
         note: note,
         by: by,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardFlagView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardFlagView copyWith({
    _ienu5u16.BoardFlagReason? reason,
    Object? note = _Undefined,
    _imhv5g8m.BoardAuthor? by = const _UndefinedBoardFlagView$by(),
    DateTime? createdAt,
  }) {
    return BoardFlagView(
      reason: reason ?? this.reason,
      note: note is String? ? note : this.note,
      by: by is _isc.UndefinedSentinel ? this.by?.copyWith() : by,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
