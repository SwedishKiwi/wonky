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
import '../../platform/users/app_theme_mode.dart' as _ii7psk14;
import '../../platform/users/ui_density.dart' as _iuahhh6p;

/// Per-user preferences shared by both apps (specs/04 §3).
abstract class UserPreferences
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  UserPreferences._({
    this.id,
    required this.userId,
    _ii7psk14.AppThemeMode? appTheme,
    this.accentColor,
    _iuahhh6p.UiDensity? density,
    bool? reduceMotion,
    String? keymapOverrides,
    String? writeDefaults,
    String? sheetsDefaults,
    String? notificationSettings,
    bool? aiEnabled,
    this.updatedAt,
  }) : appTheme = appTheme ?? _ii7psk14.AppThemeMode.system,
       density = density ?? _iuahhh6p.UiDensity.comfortable,
       reduceMotion = reduceMotion ?? false,
       keymapOverrides = keymapOverrides ?? '{}',
       writeDefaults = writeDefaults ?? '{}',
       sheetsDefaults = sheetsDefaults ?? '{}',
       notificationSettings = notificationSettings ?? '{}',
       aiEnabled = aiEnabled ?? true;

  factory UserPreferences({
    int? id,
    required int userId,
    _ii7psk14.AppThemeMode? appTheme,
    String? accentColor,
    _iuahhh6p.UiDensity? density,
    bool? reduceMotion,
    String? keymapOverrides,
    String? writeDefaults,
    String? sheetsDefaults,
    String? notificationSettings,
    bool? aiEnabled,
    DateTime? updatedAt,
  }) = _UserPreferencesImpl;

  factory UserPreferences.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserPreferences(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      appTheme: jsonSerialization['appTheme'] == null
          ? null
          : _ii7psk14.AppThemeMode.fromJson(
              (jsonSerialization['appTheme'] as String),
            ),
      accentColor: jsonSerialization['accentColor'] as String?,
      density: jsonSerialization['density'] == null
          ? null
          : _iuahhh6p.UiDensity.fromJson(
              (jsonSerialization['density'] as String),
            ),
      reduceMotion: jsonSerialization['reduceMotion'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['reduceMotion']),
      keymapOverrides: jsonSerialization['keymapOverrides'] as String?,
      writeDefaults: jsonSerialization['writeDefaults'] as String?,
      sheetsDefaults: jsonSerialization['sheetsDefaults'] as String?,
      notificationSettings:
          jsonSerialization['notificationSettings'] as String?,
      aiEnabled: jsonSerialization['aiEnabled'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['aiEnabled']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  _ii7psk14.AppThemeMode appTheme;

  /// One of the design-system accents; null = default.
  String? accentColor;

  _iuahhh6p.UiDensity density;

  bool reduceMotion;

  /// JSON {commandId: [binding, …]}.
  String keymapOverrides;

  /// JSON: defaultThemeId, spellcheck, smartQuotes, …
  String writeDefaults;

  /// JSON: default locale, font, formula help, …
  String sheetsDefaults;

  /// JSON: {mentions, replies, shares, suggestions: "inApp"|"email"|"off", digest: bool}.
  String notificationSettings;

  bool aiEnabled;

  DateTime? updatedAt;

  /// Returns a shallow copy of this [UserPreferences]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UserPreferences copyWith({
    int? id,
    int? userId,
    _ii7psk14.AppThemeMode? appTheme,
    String? accentColor,
    _iuahhh6p.UiDensity? density,
    bool? reduceMotion,
    String? keymapOverrides,
    String? writeDefaults,
    String? sheetsDefaults,
    String? notificationSettings,
    bool? aiEnabled,
    DateTime? updatedAt = const _isc.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserPreferences',
      if (id != null) 'id': id,
      'userId': userId,
      'appTheme': appTheme.toJson(),
      if (accentColor != null) 'accentColor': accentColor,
      'density': density.toJson(),
      'reduceMotion': reduceMotion,
      'keymapOverrides': keymapOverrides,
      'writeDefaults': writeDefaults,
      'sheetsDefaults': sheetsDefaults,
      'notificationSettings': notificationSettings,
      'aiEnabled': aiEnabled,
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UserPreferences',
      if (id != null) 'id': id,
      'userId': userId,
      'appTheme': appTheme.toJson(),
      if (accentColor != null) 'accentColor': accentColor,
      'density': density.toJson(),
      'reduceMotion': reduceMotion,
      'keymapOverrides': keymapOverrides,
      'writeDefaults': writeDefaults,
      'sheetsDefaults': sheetsDefaults,
      'notificationSettings': notificationSettings,
      'aiEnabled': aiEnabled,
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserPreferencesImpl extends UserPreferences {
  _UserPreferencesImpl({
    int? id,
    required int userId,
    _ii7psk14.AppThemeMode? appTheme,
    String? accentColor,
    _iuahhh6p.UiDensity? density,
    bool? reduceMotion,
    String? keymapOverrides,
    String? writeDefaults,
    String? sheetsDefaults,
    String? notificationSettings,
    bool? aiEnabled,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         userId: userId,
         appTheme: appTheme,
         accentColor: accentColor,
         density: density,
         reduceMotion: reduceMotion,
         keymapOverrides: keymapOverrides,
         writeDefaults: writeDefaults,
         sheetsDefaults: sheetsDefaults,
         notificationSettings: notificationSettings,
         aiEnabled: aiEnabled,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [UserPreferences]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UserPreferences copyWith({
    Object? id = _Undefined,
    int? userId,
    _ii7psk14.AppThemeMode? appTheme,
    Object? accentColor = _Undefined,
    _iuahhh6p.UiDensity? density,
    bool? reduceMotion,
    String? keymapOverrides,
    String? writeDefaults,
    String? sheetsDefaults,
    String? notificationSettings,
    bool? aiEnabled,
    DateTime? updatedAt = const _isc.$UndefinedDateTime(),
  }) {
    return UserPreferences(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      appTheme: appTheme ?? this.appTheme,
      accentColor: accentColor is String? ? accentColor : this.accentColor,
      density: density ?? this.density,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      keymapOverrides: keymapOverrides ?? this.keymapOverrides,
      writeDefaults: writeDefaults ?? this.writeDefaults,
      sheetsDefaults: sheetsDefaults ?? this.sheetsDefaults,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      updatedAt: updatedAt is _isc.UndefinedSentinel
          ? this.updatedAt
          : updatedAt,
    );
  }
}
