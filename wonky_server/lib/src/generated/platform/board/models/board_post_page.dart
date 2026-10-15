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
import '../../../platform/board/models/board_post_list_item.dart' as _i20hkddq;

abstract class BoardPostPage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardPostPage._({
    required this.items,
    this.nextCursor,
    required this.total,
  });

  factory BoardPostPage({
    required List<_i20hkddq.BoardPostListItem> items,
    String? nextCursor,
    required int total,
  }) = _BoardPostPageImpl;

  factory BoardPostPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardPostPage(
      items: _il4umwa0.Protocol()
          .deserialize<List<_i20hkddq.BoardPostListItem>>(
            jsonSerialization['items'],
          ),
      nextCursor: jsonSerialization['nextCursor'] as String?,
      total: jsonSerialization['total'] as int,
    );
  }

  List<_i20hkddq.BoardPostListItem> items;

  String? nextCursor;

  int total;

  /// Returns a shallow copy of this [BoardPostPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardPostPage copyWith({
    List<_i20hkddq.BoardPostListItem>? items,
    String? nextCursor,
    int? total,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardPostPage',
      'items': items.toJson(valueToJson: (v) => v.toJson()),
      if (nextCursor != null) 'nextCursor': nextCursor,
      'total': total,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardPostPage',
      'items': items.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (nextCursor != null) 'nextCursor': nextCursor,
      'total': total,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardPostPageImpl extends BoardPostPage {
  _BoardPostPageImpl({
    required List<_i20hkddq.BoardPostListItem> items,
    String? nextCursor,
    required int total,
  }) : super._(
         items: items,
         nextCursor: nextCursor,
         total: total,
       );

  /// Returns a shallow copy of this [BoardPostPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardPostPage copyWith({
    List<_i20hkddq.BoardPostListItem>? items,
    Object? nextCursor = _Undefined,
    int? total,
  }) {
    return BoardPostPage(
      items: items ?? this.items.map((e0) => e0.copyWith()).toList(),
      nextCursor: nextCursor is String? ? nextCursor : this.nextCursor,
      total: total ?? this.total,
    );
  }
}
