import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../data/user_repository.dart';
import 'local_store.dart';

/// The user's preferences (suite 04 §3–4): server-synced `UserPreferences`
/// plus per-device settings (stored locally).
///
/// Values apply immediately (optimistic) and are written to the server in
/// the background; the last server copy is cached on the device so the
/// theme is right before sign-in completes. Settings are not undoable.
class PreferencesController extends ChangeNotifier {
  PreferencesController({required this._device, this.users});

  final LocalStore _device;
  UserRepository? users;

  AppThemeMode _theme = AppThemeMode.system;
  UiDensity _density = UiDensity.comfortable;
  bool _reduceMotion = false;
  String _keymap = '{}';
  Map<String, Object?> _write = {};
  Map<String, Object?> _sheets = {};
  Map<String, Object?> _notifications = {};
  bool _aiEnabled = true;
  final Map<String, Object?> _deviceValues = {};

  AppThemeMode get appTheme => _theme;
  ThemeMode get themeMode => switch (_theme) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
  UiDensity get density => _density;
  WonkyDensity get wonkyDensity => _density == UiDensity.compact
      ? WonkyDensity.compact
      : WonkyDensity.comfortable;
  bool get reduceMotion => _reduceMotion;
  String get keymapOverrides => _keymap;
  Map<String, Object?> get writeDefaults => Map.unmodifiable(_write);
  Map<String, Object?> get sheetsDefaults => Map.unmodifiable(_sheets);
  Map<String, Object?> get notificationSettings =>
      Map.unmodifiable(_notifications);
  bool get aiEnabled => _aiEnabled;

  /// The app theme: always the neutral palette (there is no accent color
  /// choice, suite 04 §4.2).
  WonkyThemeConfig get themeConfig => WonkyThemeConfig(density: wonkyDensity);

  /// Loads the device cache (fast, before sign-in).
  Future<void> loadLocal() async {
    final cached = await _device.read('prefs.cache');
    if (cached is Map) {
      try {
        _apply(
          UserPreferences.fromJson(cached.cast<String, dynamic>()),
          notify: false,
        );
      } catch (_) {}
    }
    final dev = await _device.read('prefs.device');
    if (dev is Map) _deviceValues.addAll(dev.cast<String, Object?>());
    notifyListeners();
  }

  /// Loads the server copy (after sign-in).
  Future<void> loadRemote() async {
    final repo = users;
    if (repo == null) return;
    try {
      final p = await repo.getPreferences();
      _apply(p);
      await _device.write('prefs.cache', p.toJson());
    } catch (e) {
      debugPrint('Loading preferences failed: $e');
    }
  }

  void _apply(UserPreferences p, {bool notify = true}) {
    _theme = p.appTheme;
    _density = p.density;
    _reduceMotion = p.reduceMotion;
    _keymap = p.keymapOverrides;
    _write = _decode(p.writeDefaults);
    _sheets = _decode(p.sheetsDefaults);
    _notifications = _decode(p.notificationSettings);
    _aiEnabled = p.aiEnabled;
    if (notify) notifyListeners();
  }

  static Map<String, Object?> _decode(String json) {
    try {
      final v = jsonDecode(json);
      return v is Map ? v.cast<String, Object?>() : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(UserPreferencesPatch patch) async {
    notifyListeners();
    final repo = users;
    if (repo == null) return;
    try {
      final p = await repo.updatePreferences(patch);
      await _device.write('prefs.cache', p.toJson());
    } catch (e) {
      debugPrint('Saving preferences failed: $e');
      await _device.write('prefs.cache', _snapshot().toJson());
    }
  }

  UserPreferences _snapshot() => UserPreferences(
    userId: 0,
    appTheme: _theme,
    density: _density,
    reduceMotion: _reduceMotion,
    keymapOverrides: _keymap,
    writeDefaults: jsonEncode(_write),
    sheetsDefaults: jsonEncode(_sheets),
    notificationSettings: jsonEncode(_notifications),
    aiEnabled: _aiEnabled,
  );

  Future<void> setAppTheme(AppThemeMode mode) {
    _theme = mode;
    return _save(UserPreferencesPatch(appTheme: mode));
  }

  /// Cycles system → light → dark (top-bar toggle).
  Future<void> cycleTheme() => setAppTheme(switch (_theme) {
    AppThemeMode.system => AppThemeMode.light,
    AppThemeMode.light => AppThemeMode.dark,
    AppThemeMode.dark => AppThemeMode.system,
  });

  Future<void> setDensity(UiDensity density) {
    _density = density;
    return _save(UserPreferencesPatch(density: density));
  }

  Future<void> setReduceMotion(bool value) {
    _reduceMotion = value;
    return _save(UserPreferencesPatch(reduceMotion: value));
  }

  Future<void> setKeymapOverrides(String json) {
    _keymap = json;
    return _save(UserPreferencesPatch(keymapOverrides: json));
  }

  Future<void> setAiEnabled(bool value) {
    _aiEnabled = value;
    return _save(UserPreferencesPatch(aiEnabled: value));
  }

  Future<void> setWriteDefault(String key, Object? value) {
    _write = {..._write, key: value};
    return _save(UserPreferencesPatch(writeDefaults: jsonEncode(_write)));
  }

  Future<void> setSheetsDefault(String key, Object? value) {
    _sheets = {..._sheets, key: value};
    return _save(UserPreferencesPatch(sheetsDefaults: jsonEncode(_sheets)));
  }

  Future<void> setNotificationSetting(String key, Object? value) {
    _notifications = {..._notifications, key: value};
    return _save(
      UserPreferencesPatch(notificationSettings: jsonEncode(_notifications)),
    );
  }

  // ---- Per-device values ----

  T? device<T>(String key) {
    final v = _deviceValues[key];
    return v is T ? v : null;
  }

  Future<void> setDevice(String key, Object? value) async {
    _deviceValues[key] = value;
    notifyListeners();
    await _device.write('prefs.device', _deviceValues);
  }
}
