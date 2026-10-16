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

/// The count badges of the board's tabs (specs/16 §4.4).
abstract class BoardCounts
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardCounts._({
    required this.ideas,
    required this.bugs,
    required this.upForGrabs,
    required this.claimed,
  });

  factory BoardCounts({
    required int ideas,
    required int bugs,
    required int upForGrabs,
    required int claimed,
  }) = _BoardCountsImpl;

  factory BoardCounts.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardCounts(
      ideas: jsonSerialization['ideas'] as int,
      bugs: jsonSerialization['bugs'] as int,
      upForGrabs: jsonSerialization['upForGrabs'] as int,
      claimed: jsonSerialization['claimed'] as int,
    );
  }

  /// Visible open and planned ideas (*Improvements*).
  int ideas;

  /// Visible open and planned bugs (*Bugs*).
  int bugs;

  /// Published tasks without a valid claim (*Up for grabs*).
  int upForGrabs;

  /// Claimed and in-review tasks (*Claimed*).
  int claimed;

  /// Returns a shallow copy of this [BoardCounts]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardCounts copyWith({
    int? ideas,
    int? bugs,
    int? upForGrabs,
    int? claimed,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardCounts',
      'ideas': ideas,
      'bugs': bugs,
      'upForGrabs': upForGrabs,
      'claimed': claimed,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardCounts',
      'ideas': ideas,
      'bugs': bugs,
      'upForGrabs': upForGrabs,
      'claimed': claimed,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _BoardCountsImpl extends BoardCounts {
  _BoardCountsImpl({
    required int ideas,
    required int bugs,
    required int upForGrabs,
    required int claimed,
  }) : super._(
         ideas: ideas,
         bugs: bugs,
         upForGrabs: upForGrabs,
         claimed: claimed,
       );

  /// Returns a shallow copy of this [BoardCounts]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardCounts copyWith({
    int? ideas,
    int? bugs,
    int? upForGrabs,
    int? claimed,
  }) {
    return BoardCounts(
      ideas: ideas ?? this.ideas,
      bugs: bugs ?? this.bugs,
      upForGrabs: upForGrabs ?? this.upForGrabs,
      claimed: claimed ?? this.claimed,
    );
  }
}
