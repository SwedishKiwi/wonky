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
import '../../../platform/board/models/board_area.dart' as _iknrpzcb;
import '../../../platform/board/models/board_post_kind.dart' as _i76aj3nz;
import '../../../platform/board/models/board_post_status.dart' as _ij83av7d;
import '../../../platform/board/models/board_size.dart' as _ibr3u4cf;
import '../../../platform/board/models/board_sort.dart' as _iizsfp0e;

/// Filters of `board.list` (specs/16 §4.4).
abstract class BoardListQuery
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardListQuery._({
    this.kind,
    required this.statuses,
    required this.areas,
    required this.sizes,
    required this.sort,
    this.query,
    required this.mine,
    this.cursor,
    required this.limit,
  });

  factory BoardListQuery({
    _i76aj3nz.BoardPostKind? kind,
    required List<_ij83av7d.BoardPostStatus> statuses,
    required List<_iknrpzcb.BoardArea> areas,
    required List<_ibr3u4cf.BoardSize> sizes,
    required _iizsfp0e.BoardSort sort,
    String? query,
    required bool mine,
    String? cursor,
    required int limit,
  }) = _BoardListQueryImpl;

  factory BoardListQuery.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardListQuery(
      kind: jsonSerialization['kind'] == null
          ? null
          : _i76aj3nz.BoardPostKind.fromJson(
              (jsonSerialization['kind'] as String),
            ),
      statuses: _i8pkqg1o.Protocol()
          .deserialize<List<_ij83av7d.BoardPostStatus>>(
            jsonSerialization['statuses'],
          ),
      areas: _i8pkqg1o.Protocol().deserialize<List<_iknrpzcb.BoardArea>>(
        jsonSerialization['areas'],
      ),
      sizes: _i8pkqg1o.Protocol().deserialize<List<_ibr3u4cf.BoardSize>>(
        jsonSerialization['sizes'],
      ),
      sort: _iizsfp0e.BoardSort.fromJson((jsonSerialization['sort'] as String)),
      query: jsonSerialization['query'] as String?,
      mine: _isc.BoolJsonExtension.fromJson(jsonSerialization['mine']),
      cursor: jsonSerialization['cursor'] as String?,
      limit: jsonSerialization['limit'] as int,
    );
  }

  _i76aj3nz.BoardPostKind? kind;

  /// Empty = open and planned.
  List<_ij83av7d.BoardPostStatus> statuses;

  List<_iknrpzcb.BoardArea> areas;

  List<_ibr3u4cf.BoardSize> sizes;

  _iizsfp0e.BoardSort sort;

  String? query;

  /// Posts I wrote or voted on.
  bool mine;

  String? cursor;

  int limit;

  /// Returns a shallow copy of this [BoardListQuery]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardListQuery copyWith({
    _i76aj3nz.BoardPostKind? kind,
    List<_ij83av7d.BoardPostStatus>? statuses,
    List<_iknrpzcb.BoardArea>? areas,
    List<_ibr3u4cf.BoardSize>? sizes,
    _iizsfp0e.BoardSort? sort,
    String? query,
    bool? mine,
    String? cursor,
    int? limit,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardListQuery',
      if (kind != null) 'kind': kind?.toJson(),
      'statuses': statuses.toJson(valueToJson: (v) => v.toJson()),
      'areas': areas.toJson(valueToJson: (v) => v.toJson()),
      'sizes': sizes.toJson(valueToJson: (v) => v.toJson()),
      'sort': sort.toJson(),
      if (query != null) 'query': query,
      'mine': mine,
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardListQuery',
      if (kind != null) 'kind': kind?.toJson(),
      'statuses': statuses.toJson(valueToJson: (v) => v.toJson()),
      'areas': areas.toJson(valueToJson: (v) => v.toJson()),
      'sizes': sizes.toJson(valueToJson: (v) => v.toJson()),
      'sort': sort.toJson(),
      if (query != null) 'query': query,
      'mine': mine,
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardListQueryImpl extends BoardListQuery {
  _BoardListQueryImpl({
    _i76aj3nz.BoardPostKind? kind,
    required List<_ij83av7d.BoardPostStatus> statuses,
    required List<_iknrpzcb.BoardArea> areas,
    required List<_ibr3u4cf.BoardSize> sizes,
    required _iizsfp0e.BoardSort sort,
    String? query,
    required bool mine,
    String? cursor,
    required int limit,
  }) : super._(
         kind: kind,
         statuses: statuses,
         areas: areas,
         sizes: sizes,
         sort: sort,
         query: query,
         mine: mine,
         cursor: cursor,
         limit: limit,
       );

  /// Returns a shallow copy of this [BoardListQuery]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardListQuery copyWith({
    Object? kind = _Undefined,
    List<_ij83av7d.BoardPostStatus>? statuses,
    List<_iknrpzcb.BoardArea>? areas,
    List<_ibr3u4cf.BoardSize>? sizes,
    _iizsfp0e.BoardSort? sort,
    Object? query = _Undefined,
    bool? mine,
    Object? cursor = _Undefined,
    int? limit,
  }) {
    return BoardListQuery(
      kind: kind is _i76aj3nz.BoardPostKind? ? kind : this.kind,
      statuses: statuses ?? this.statuses.map((e0) => e0).toList(),
      areas: areas ?? this.areas.map((e0) => e0).toList(),
      sizes: sizes ?? this.sizes.map((e0) => e0).toList(),
      sort: sort ?? this.sort,
      query: query is String? ? query : this.query,
      mine: mine ?? this.mine,
      cursor: cursor is String? ? cursor : this.cursor,
      limit: limit ?? this.limit,
    );
  }
}
