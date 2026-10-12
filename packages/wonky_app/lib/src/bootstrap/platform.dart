import 'package:flutter/foundation.dart';
import 'package:wonky_core/wonky_core.dart';

/// The key platform of the running app (`Mod` = ⌘ on macOS).
KeyPlatform get currentKeyPlatform {
  final mac =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
  return KeyPlatform(isMac: mac, isWeb: kIsWeb);
}

/// A short human platform label ("Web", "macOS"…), used in feedback reports
/// and the MCP session list.
String get platformLabel {
  if (kIsWeb) return 'Web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.android => 'Android',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
}
