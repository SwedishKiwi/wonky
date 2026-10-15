import 'dart:io' show Platform;

import 'present_platform.dart';

PresentPlatform createPresentPlatform() => IoPresentPlatform();

/// Desktop and tests: no full screen (presenting runs full window).
class IoPresentPlatform extends PresentPlatform {
  @override
  Future<bool> requestFullscreen() async => false;

  @override
  Future<void> exitFullscreen() async {}

  @override
  bool get isFullscreen => false;

  @override
  void Function() listenFullscreen(void Function(bool fullscreen) onChange) =>
      () {};

  @override
  String get deviceLabel => switch (Platform.operatingSystem) {
    'macos' => 'macOS',
    'windows' => 'Windows',
    'linux' => 'Linux',
    final os => os,
  };

  @override
  bool get screenIsExtended => false;

  @override
  void Function() captureReloadKeys() => () {};
}
