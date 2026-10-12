import 'package:flutter/foundation.dart';

import 'preferences_controller.dart';

/// Editor chrome visibility (suite 03 §3.1): compact mode, full screen and
/// the Show ▸ toggles. Persisted per device.
class ShellViewState extends ChangeNotifier {
  ShellViewState(this._prefs);

  final PreferencesController _prefs;
  bool _fullScreen = false;

  bool get compact => _prefs.device<bool>('view.compact') ?? false;
  bool get showToolbar => _prefs.device<bool>('view.toolbar') ?? true;
  bool get showMenubar => _prefs.device<bool>('view.menubar') ?? true;
  bool get showStatusBar => _prefs.device<bool>('view.statusBar') ?? true;
  bool get fullScreen => _fullScreen;

  Future<void> _set(String key, bool value) async {
    await _prefs.setDevice(key, value);
    notifyListeners();
  }

  Future<void> toggleCompact() => _set('view.compact', !compact);
  Future<void> toggleToolbar() => _set('view.toolbar', !showToolbar);
  Future<void> toggleMenubar() => _set('view.menubar', !showMenubar);
  Future<void> toggleStatusBar() => _set('view.statusBar', !showStatusBar);

  void setFullScreen(bool value) {
    if (_fullScreen == value) return;
    _fullScreen = value;
    notifyListeners();
  }
}
