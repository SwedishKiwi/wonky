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

/// An AI-suggested group of small posts (specs/16 §9.3).
abstract class BoardBundleSuggestion
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  BoardBundleSuggestion._({
    this.id,
    required this.title,
    required this.rationale,
    this.area,
    required this.postIds,
    required this.state,
    required this.createdAt,
  });

  factory BoardBundleSuggestion({
    int? id,
    required String title,
    required String rationale,
    _iknrpzcb.BoardArea? area,
    required List<int> postIds,
    required String state,
    required DateTime createdAt,
  }) = _BoardBundleSuggestionImpl;

  factory BoardBundleSuggestion.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BoardBundleSuggestion(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      rationale: jsonSerialization['rationale'] as String,
      area: jsonSerialization['area'] == null
          ? null
          : _iknrpzcb.BoardArea.fromJson((jsonSerialization['area'] as String)),
      postIds: _i8pkqg1o.Protocol().deserialize<List<int>>(
        jsonSerialization['postIds'],
      ),
      state: jsonSerialization['state'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String title;

  String rationale;

  _iknrpzcb.BoardArea? area;

  List<int> postIds;

  /// pending | accepted | dismissed
  String state;

  DateTime createdAt;

  /// Returns a shallow copy of this [BoardBundleSuggestion]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  BoardBundleSuggestion copyWith({
    int? id,
    String? title,
    String? rationale,
    _iknrpzcb.BoardArea? area,
    List<int>? postIds,
    String? state,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardBundleSuggestion',
      if (id != null) 'id': id,
      'title': title,
      'rationale': rationale,
      if (area != null) 'area': area?.toJson(),
      'postIds': postIds.toJson(),
      'state': state,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardBundleSuggestion',
      if (id != null) 'id': id,
      'title': title,
      'rationale': rationale,
      if (area != null) 'area': area?.toJson(),
      'postIds': postIds.toJson(),
      'state': state,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardBundleSuggestionImpl extends BoardBundleSuggestion {
  _BoardBundleSuggestionImpl({
    int? id,
    required String title,
    required String rationale,
    _iknrpzcb.BoardArea? area,
    required List<int> postIds,
    required String state,
    required DateTime createdAt,
  }) : super._(
         id: id,
         title: title,
         rationale: rationale,
         area: area,
         postIds: postIds,
         state: state,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [BoardBundleSuggestion]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  BoardBundleSuggestion copyWith({
    Object? id = _Undefined,
    String? title,
    String? rationale,
    Object? area = _Undefined,
    List<int>? postIds,
    String? state,
    DateTime? createdAt,
  }) {
    return BoardBundleSuggestion(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      rationale: rationale ?? this.rationale,
      area: area is _iknrpzcb.BoardArea? ? area : this.area,
      postIds: postIds ?? this.postIds.map((e0) => e0).toList(),
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
