import 'present_platform_io.dart'
    if (dart.library.js_interop) 'present_platform_web.dart';

/// Browser services of presenting (Slides 10 §1.3, §5.2): the Fullscreen
/// API, the device label of the session roster and the extended-display
/// check. Desktop builds (deferred, suite 01 A13) present full window.
///
/// Presenting never opens a window: no `window.open`, no Window Management
/// API (`getScreenDetails`) — suite 03 §1, v2 review Q5/Q29.
abstract class PresentPlatform {
  /// The platform's implementation; tests replace it.
  static PresentPlatform instance = createPresentPlatform();

  /// Requests full screen for the page (within the user gesture that
  /// started presenting). Completes with whether the page is full screen.
  Future<bool> requestFullscreen();

  /// Leaves full screen (no-op when not full screen).
  Future<void> exitFullscreen();

  /// Whether the page is full screen now.
  bool get isFullscreen;

  /// Calls [onChange] when full screen is entered or left (also by the
  /// browser: Esc, F11). Returns the function that stops listening.
  void Function() listenFullscreen(void Function(bool fullscreen) onChange);

  /// "Chrome · macOS" (the presenter's roster, the audience banner).
  String get deviceLabel;

  /// Whether the device has an extended second display
  /// (`window.screen.isExtended`, Chromium).
  bool get screenIsExtended;

  /// Captures F5 / Shift+F5 while presenting (no browser reload, 10 §2.1)
  /// even when no Flutter widget has focus. Returns the release function.
  void Function() captureReloadKeys();
}
