import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'present_platform.dart';

PresentPlatform createPresentPlatform() => WebPresentPlatform();

/// The Fullscreen API of the browser (behind a conditional import, Slides
/// 10 §1.3).
class WebPresentPlatform extends PresentPlatform {
  @override
  Future<bool> requestFullscreen() async {
    final root = web.document.documentElement;
    if (root == null) return false;
    try {
      await root
          .requestFullscreen(web.FullscreenOptions(navigationUI: 'hide'))
          .toDart;
      return isFullscreen;
    } on Object {
      // Refused (iframe, policy, no user gesture): present full window.
      return false;
    }
  }

  @override
  Future<void> exitFullscreen() async {
    if (!isFullscreen) return;
    try {
      await web.document.exitFullscreen().toDart;
    } on Object {
      // Already left.
    }
  }

  @override
  bool get isFullscreen => web.document.fullscreenElement != null;

  @override
  void Function() listenFullscreen(void Function(bool fullscreen) onChange) {
    final listener = ((web.Event _) => onChange(isFullscreen)).toJS;
    web.document.addEventListener('fullscreenchange', listener);
    return () => web.document.removeEventListener('fullscreenchange', listener);
  }

  @override
  String get deviceLabel {
    final ua = web.window.navigator.userAgent;
    final browser = ua.contains('Edg/')
        ? 'Edge'
        : ua.contains('Firefox/')
        ? 'Firefox'
        : ua.contains('Chrome/')
        ? 'Chrome'
        : ua.contains('Safari/')
        ? 'Safari'
        : 'Browser';
    final os = ua.contains('iPhone') || ua.contains('iPad')
        ? 'iOS'
        : ua.contains('Android')
        ? 'Android'
        : ua.contains('Mac OS X')
        ? 'macOS'
        : ua.contains('Windows')
        ? 'Windows'
        : ua.contains('Linux')
        ? 'Linux'
        : null;
    return os == null ? browser : '$browser · $os';
  }

  @override
  bool get screenIsExtended {
    final v = (web.window.screen as JSObject).getProperty<JSAny?>(
      'isExtended'.toJS,
    );
    return v != null && v.isA<JSBoolean>() && (v as JSBoolean).toDart;
  }

  @override
  void Function() captureReloadKeys() {
    final listener = ((web.KeyboardEvent e) {
      if (e.key == 'F5') e.preventDefault();
    }).toJS;
    web.window.addEventListener('keydown', listener, true.toJS);
    return () => web.window.removeEventListener('keydown', listener, true.toJS);
  }
}
