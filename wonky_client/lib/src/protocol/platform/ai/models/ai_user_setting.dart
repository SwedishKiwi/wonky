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
import '../../../platform/ai/models/ai_quality.dart' as _i054hihs;

/// Per-user AI settings beyond the opt-out (`UserPreferences.aiEnabled`).
abstract class AiUserSetting
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AiUserSetting._({
    this.id,
    required this.userId,
    _i054hihs.AiQuality? quality,
    required this.updatedAt,
  }) : quality = quality ?? _i054hihs.AiQuality.best;

  factory AiUserSetting({
    int? id,
    required int userId,
    _i054hihs.AiQuality? quality,
    required DateTime updatedAt,
  }) = _AiUserSettingImpl;

  factory AiUserSetting.fromJson(Map<String, dynamic> jsonSerialization) {
    return AiUserSetting(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      quality: jsonSerialization['quality'] == null
          ? null
          : _i054hihs.AiQuality.fromJson(
              (jsonSerialization['quality'] as String),
            ),
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  _i054hihs.AiQuality quality;

  DateTime updatedAt;

  /// Returns a shallow copy of this [AiUserSetting]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AiUserSetting copyWith({
    int? id,
    int? userId,
    _i054hihs.AiQuality? quality,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AiUserSetting',
      if (id != null) 'id': id,
      'userId': userId,
      'quality': quality.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AiUserSetting',
      if (id != null) 'id': id,
      'userId': userId,
      'quality': quality.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AiUserSettingImpl extends AiUserSetting {
  _AiUserSettingImpl({
    int? id,
    required int userId,
    _i054hihs.AiQuality? quality,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         quality: quality,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AiUserSetting]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AiUserSetting copyWith({
    Object? id = _Undefined,
    int? userId,
    _i054hihs.AiQuality? quality,
    DateTime? updatedAt,
  }) {
    return AiUserSetting(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      quality: quality ?? this.quality,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
