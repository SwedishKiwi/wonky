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
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;
import '../../../platform/board/models/board_task_view.dart' as _i50i73w9;

abstract class BoardTaskPage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardTaskPage._({
    required this.items,
    this.nextCursor,
  });

  factory BoardTaskPage({
    required List<_i50i73w9.BoardTaskView> items,
    String? nextCursor,
  }) = _BoardTaskPageImpl;

  factory BoardTaskPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardTaskPage(
      items: _il4umwa0.Protocol().deserialize<List<_i50i73w9.BoardTaskView>>(
        jsonSerialization['items'],
      ),
      nextCursor: jsonSerialization['nextCursor'] as String?,
    );
  }

  List<_i50i73w9.BoardTaskView> items;

  String? nextCursor;

  /// Returns a shallow copy of this [BoardTaskPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardTaskPage copyWith({
    List<_i50i73w9.BoardTaskView>? items,
    String? nextCursor,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardTaskPage',
      'items': items.toJson(valueToJson: (v) => v.toJson()),
      if (nextCursor != null) 'nextCursor': nextCursor,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardTaskPage',
      'items': items.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (nextCursor != null) 'nextCursor': nextCursor,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardTaskPageImpl extends BoardTaskPage {
  _BoardTaskPageImpl({
    required List<_i50i73w9.BoardTaskView> items,
    String? nextCursor,
  }) : super._(
         items: items,
         nextCursor: nextCursor,
       );

  /// Returns a shallow copy of this [BoardTaskPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardTaskPage copyWith({
    List<_i50i73w9.BoardTaskView>? items,
    Object? nextCursor = _Undefined,
  }) {
    return BoardTaskPage(
      items: items ?? this.items.map((e0) => e0.copyWith()).toList(),
      nextCursor: nextCursor is String? ? nextCursor : this.nextCursor,
    );
  }
}
