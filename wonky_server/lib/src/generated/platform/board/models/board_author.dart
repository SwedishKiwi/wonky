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

/// Public author info on the board: never the email (specs/16 §11).
abstract class BoardAuthor
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardAuthor._({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.avatarColor,
    required this.colorIndex,
    required this.isAdmin,
  });

  factory BoardAuthor({
    required int id,
    required String displayName,
    String? avatarUrl,
    required String avatarColor,
    required int colorIndex,
    required bool isAdmin,
  }) = _BoardAuthorImpl;

  factory BoardAuthor.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardAuthor(
      id: jsonSerialization['id'] as int,
      displayName: jsonSerialization['displayName'] as String,
      avatarUrl: jsonSerialization['avatarUrl'] as String?,
      avatarColor: jsonSerialization['avatarColor'] as String,
      colorIndex: jsonSerialization['colorIndex'] as int,
      isAdmin: _is.BoolJsonExtension.fromJson(jsonSerialization['isAdmin']),
    );
  }

  int id;

  String displayName;

  String? avatarUrl;

  String avatarColor;

  int colorIndex;

  bool isAdmin;

  /// Returns a shallow copy of this [BoardAuthor]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardAuthor copyWith({
    int? id,
    String? displayName,
    String? avatarUrl,
    String? avatarColor,
    int? colorIndex,
    bool? isAdmin,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardAuthor',
      'id': id,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'avatarColor': avatarColor,
      'colorIndex': colorIndex,
      'isAdmin': isAdmin,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardAuthor',
      'id': id,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'avatarColor': avatarColor,
      'colorIndex': colorIndex,
      'isAdmin': isAdmin,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardAuthorImpl extends BoardAuthor {
  _BoardAuthorImpl({
    required int id,
    required String displayName,
    String? avatarUrl,
    required String avatarColor,
    required int colorIndex,
    required bool isAdmin,
  }) : super._(
         id: id,
         displayName: displayName,
         avatarUrl: avatarUrl,
         avatarColor: avatarColor,
         colorIndex: colorIndex,
         isAdmin: isAdmin,
       );

  /// Returns a shallow copy of this [BoardAuthor]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardAuthor copyWith({
    int? id,
    String? displayName,
    Object? avatarUrl = _Undefined,
    String? avatarColor,
    int? colorIndex,
    bool? isAdmin,
  }) {
    return BoardAuthor(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl is String? ? avatarUrl : this.avatarUrl,
      avatarColor: avatarColor ?? this.avatarColor,
      colorIndex: colorIndex ?? this.colorIndex,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
