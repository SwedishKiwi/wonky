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
import '../../../platform/board/models/board_post_list_item.dart' as _i20hkddq;

abstract class BoardBundleSuggestionView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardBundleSuggestionView._({
    required this.id,
    required this.title,
    required this.rationale,
    this.area,
    required this.posts,
    required this.createdAt,
  });

  factory BoardBundleSuggestionView({
    required int id,
    required String title,
    required String rationale,
    _iknrpzcb.BoardArea? area,
    required List<_i20hkddq.BoardPostListItem> posts,
    required DateTime createdAt,
  }) = _BoardBundleSuggestionViewImpl;

  factory BoardBundleSuggestionView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BoardBundleSuggestionView(
      id: jsonSerialization['id'] as int,
      title: jsonSerialization['title'] as String,
      rationale: jsonSerialization['rationale'] as String,
      area: jsonSerialization['area'] == null
          ? null
          : _iknrpzcb.BoardArea.fromJson((jsonSerialization['area'] as String)),
      posts: _i8pkqg1o.Protocol()
          .deserialize<List<_i20hkddq.BoardPostListItem>>(
            jsonSerialization['posts'],
          ),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  int id;

  String title;

  String rationale;

  _iknrpzcb.BoardArea? area;

  List<_i20hkddq.BoardPostListItem> posts;

  DateTime createdAt;

  /// Returns a shallow copy of this [BoardBundleSuggestionView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardBundleSuggestionView copyWith({
    int? id,
    String? title,
    String? rationale,
    _iknrpzcb.BoardArea? area,
    List<_i20hkddq.BoardPostListItem>? posts,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardBundleSuggestionView',
      'id': id,
      'title': title,
      'rationale': rationale,
      if (area != null) 'area': area?.toJson(),
      'posts': posts.toJson(valueToJson: (v) => v.toJson()),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardBundleSuggestionView',
      'id': id,
      'title': title,
      'rationale': rationale,
      if (area != null) 'area': area?.toJson(),
      'posts': posts.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardBundleSuggestionViewImpl extends BoardBundleSuggestionView {
  _BoardBundleSuggestionViewImpl({
    required int id,
    required String title,
    required String rationale,
    _iknrpzcb.BoardArea? area,
    required List<_i20hkddq.BoardPostListItem> posts,
    required DateTime createdAt,
  }) : super._(
         id: id,
         title: title,
         rationale: rationale,
         area: area,
         posts: posts,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardBundleSuggestionView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardBundleSuggestionView copyWith({
    int? id,
    String? title,
    String? rationale,
    Object? area = _Undefined,
    List<_i20hkddq.BoardPostListItem>? posts,
    DateTime? createdAt,
  }) {
    return BoardBundleSuggestionView(
      id: id ?? this.id,
      title: title ?? this.title,
      rationale: rationale ?? this.rationale,
      area: area is _iknrpzcb.BoardArea? ? area : this.area,
      posts: posts ?? this.posts.map((e0) => e0.copyWith()).toList(),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
