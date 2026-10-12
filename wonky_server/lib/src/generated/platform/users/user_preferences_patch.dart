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
import '../../platform/users/app_theme_mode.dart' as _ii7psk14;
import '../../platform/users/ui_density.dart' as _iuahhh6p;

/// Partial update of [UserPreferences]; null fields are left unchanged. JSON
/// fields are merged key by key (a key set to null is removed).
abstract class UserPreferencesPatch
    implements _is.SerializableModel, _is.ProtocolSerialization {
  UserPreferencesPatch._({
    this.appTheme,
    this.accentColor,
    this.clearAccentColor,
    this.density,
    this.reduceMotion,
    this.keymapOverrides,
    this.writeDefaults,
    this.sheetsDefaults,
    this.notificationSettings,
    this.aiEnabled,
  });

  factory UserPreferencesPatch({
    _ii7psk14.AppThemeMode? appTheme,
    String? accentColor,
    bool? clearAccentColor,
    _iuahhh6p.UiDensity? density,
    bool? reduceMotion,
    String? keymapOverrides,
    String? writeDefaults,
    String? sheetsDefaults,
    String? notificationSettings,
    bool? aiEnabled,
  }) = _UserPreferencesPatchImpl;

  factory UserPreferencesPatch.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return UserPreferencesPatch(
      appTheme: jsonSerialization['appTheme'] == null
          ? null
          : _ii7psk14.AppThemeMode.fromJson(
              (jsonSerialization['appTheme'] as String),
            ),
      accentColor: jsonSerialization['accentColor'] as String?,
      clearAccentColor: jsonSerialization['clearAccentColor'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['clearAccentColor'],
            ),
      density: jsonSerialization['density'] == null
          ? null
          : _iuahhh6p.UiDensity.fromJson(
              (jsonSerialization['density'] as String),
            ),
      reduceMotion: jsonSerialization['reduceMotion'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['reduceMotion']),
      keymapOverrides: jsonSerialization['keymapOverrides'] as String?,
      writeDefaults: jsonSerialization['writeDefaults'] as String?,
      sheetsDefaults: jsonSerialization['sheetsDefaults'] as String?,
      notificationSettings:
          jsonSerialization['notificationSettings'] as String?,
      aiEnabled: jsonSerialization['aiEnabled'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['aiEnabled']),
    );
  }

  _ii7psk14.AppThemeMode? appTheme;

  String? accentColor;

  bool? clearAccentColor;

  _iuahhh6p.UiDensity? density;

  bool? reduceMotion;

  String? keymapOverrides;

  String? writeDefaults;

  String? sheetsDefaults;

  String? notificationSettings;

  bool? aiEnabled;

  /// Returns a shallow copy of this [UserPreferencesPatch]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UserPreferencesPatch copyWith({
    _ii7psk14.AppThemeMode? appTheme,
    String? accentColor,
    bool? clearAccentColor,
    _iuahhh6p.UiDensity? density,
    bool? reduceMotion,
    String? keymapOverrides,
    String? writeDefaults,
    String? sheetsDefaults,
    String? notificationSettings,
    bool? aiEnabled,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserPreferencesPatch',
      if (appTheme != null) 'appTheme': appTheme?.toJson(),
      if (accentColor != null) 'accentColor': accentColor,
      if (clearAccentColor != null) 'clearAccentColor': clearAccentColor,
      if (density != null) 'density': density?.toJson(),
      if (reduceMotion != null) 'reduceMotion': reduceMotion,
      if (keymapOverrides != null) 'keymapOverrides': keymapOverrides,
      if (writeDefaults != null) 'writeDefaults': writeDefaults,
      if (sheetsDefaults != null) 'sheetsDefaults': sheetsDefaults,
      if (notificationSettings != null)
        'notificationSettings': notificationSettings,
      if (aiEnabled != null) 'aiEnabled': aiEnabled,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UserPreferencesPatch',
      if (appTheme != null) 'appTheme': appTheme?.toJson(),
      if (accentColor != null) 'accentColor': accentColor,
      if (clearAccentColor != null) 'clearAccentColor': clearAccentColor,
      if (density != null) 'density': density?.toJson(),
      if (reduceMotion != null) 'reduceMotion': reduceMotion,
      if (keymapOverrides != null) 'keymapOverrides': keymapOverrides,
      if (writeDefaults != null) 'writeDefaults': writeDefaults,
      if (sheetsDefaults != null) 'sheetsDefaults': sheetsDefaults,
      if (notificationSettings != null)
        'notificationSettings': notificationSettings,
      if (aiEnabled != null) 'aiEnabled': aiEnabled,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserPreferencesPatchImpl extends UserPreferencesPatch {
  _UserPreferencesPatchImpl({
    _ii7psk14.AppThemeMode? appTheme,
    String? accentColor,
    bool? clearAccentColor,
    _iuahhh6p.UiDensity? density,
    bool? reduceMotion,
    String? keymapOverrides,
    String? writeDefaults,
    String? sheetsDefaults,
    String? notificationSettings,
    bool? aiEnabled,
  }) : super._(
         appTheme: appTheme,
         accentColor: accentColor,
         clearAccentColor: clearAccentColor,
         density: density,
         reduceMotion: reduceMotion,
         keymapOverrides: keymapOverrides,
         writeDefaults: writeDefaults,
         sheetsDefaults: sheetsDefaults,
         notificationSettings: notificationSettings,
         aiEnabled: aiEnabled,
       );

  /// Returns a shallow copy of this [UserPreferencesPatch]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UserPreferencesPatch copyWith({
    Object? appTheme = _Undefined,
    Object? accentColor = _Undefined,
    Object? clearAccentColor = _Undefined,
    Object? density = _Undefined,
    Object? reduceMotion = _Undefined,
    Object? keymapOverrides = _Undefined,
    Object? writeDefaults = _Undefined,
    Object? sheetsDefaults = _Undefined,
    Object? notificationSettings = _Undefined,
    Object? aiEnabled = _Undefined,
  }) {
    return UserPreferencesPatch(
      appTheme: appTheme is _ii7psk14.AppThemeMode? ? appTheme : this.appTheme,
      accentColor: accentColor is String? ? accentColor : this.accentColor,
      clearAccentColor: clearAccentColor is bool?
          ? clearAccentColor
          : this.clearAccentColor,
      density: density is _iuahhh6p.UiDensity? ? density : this.density,
      reduceMotion: reduceMotion is bool? ? reduceMotion : this.reduceMotion,
      keymapOverrides: keymapOverrides is String?
          ? keymapOverrides
          : this.keymapOverrides,
      writeDefaults: writeDefaults is String?
          ? writeDefaults
          : this.writeDefaults,
      sheetsDefaults: sheetsDefaults is String?
          ? sheetsDefaults
          : this.sheetsDefaults,
      notificationSettings: notificationSettings is String?
          ? notificationSettings
          : this.notificationSettings,
      aiEnabled: aiEnabled is bool? ? aiEnabled : this.aiEnabled,
    );
  }
}
