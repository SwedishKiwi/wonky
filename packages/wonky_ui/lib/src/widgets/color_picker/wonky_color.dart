import 'package:flutter/widgets.dart';

/// A color chosen in a [WonkyColorPicker]: an absolute [hex] plus an optional
/// [themeRef] (e.g. `accent1`) so theme-referenced colors can follow theme
/// changes.
@immutable
class WonkyColor {
  const WonkyColor(this.hex, {this.themeRef});

  /// `#RRGGBB` or `#RRGGBBAA` (lower case).
  final String hex;
  final String? themeRef;

  /// From a Flutter color (alpha kept when < 255).
  factory WonkyColor.fromColor(Color c, {String? themeRef}) {
    String h(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
    final rgb = '#${h(c.r)}${h(c.g)}${h(c.b)}';
    return WonkyColor(c.a >= 0.999 ? rgb : '$rgb${h(c.a)}', themeRef: themeRef);
  }

  /// Parses `#rgb`, `#rrggbb`, `#rrggbbaa` (with or without `#`).
  static WonkyColor? tryParse(String text) {
    var t = text.trim().toLowerCase();
    if (t.startsWith('#')) t = t.substring(1);
    if (!RegExp(r'^([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$').hasMatch(t)) {
      return null;
    }
    if (t.length == 3) t = t.split('').map((c) => '$c$c').join();
    if (t.length == 8 && t.endsWith('ff')) t = t.substring(0, 6);
    return WonkyColor('#$t');
  }

  Color toColor() {
    final t = hex.substring(1);
    final rgb = int.parse(t.substring(0, 6), radix: 16);
    final a = t.length == 8 ? int.parse(t.substring(6), radix: 16) : 0xff;
    return Color((a << 24) | rgb);
  }

  WonkyColor withoutThemeRef() => WonkyColor(hex);

  Map<String, Object?> toJson() => {
    'hex': hex,
    if (themeRef != null) 'themeRef': themeRef,
  };

  static WonkyColor? fromJson(Object? json) {
    if (json is String) return tryParse(json);
    if (json is Map && json['hex'] is String) {
      final c = tryParse(json['hex'] as String);
      return c == null
          ? null
          : WonkyColor(c.hex, themeRef: json['themeRef'] as String?);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is WonkyColor && other.hex == hex && other.themeRef == themeRef;

  @override
  int get hashCode => Object.hash(hex, themeRef);

  @override
  String toString() => themeRef == null ? hex : '$hex ($themeRef)';
}

/// The Google-style 10×8 palette (row-major).
abstract final class WonkyColorPalette {
  static const rows = <List<int>>[
    [
      0x000000,
      0x434343,
      0x666666,
      0x999999,
      0xb7b7b7,
      0xcccccc,
      0xd9d9d9,
      0xefefef,
      0xf3f3f3,
      0xffffff,
    ],
    [
      0x980000,
      0xff0000,
      0xff9900,
      0xffff00,
      0x00ff00,
      0x00ffff,
      0x4a86e8,
      0x0000ff,
      0x9900ff,
      0xff00ff,
    ],
    [
      0xe6b8af,
      0xf4cccc,
      0xfce5cd,
      0xfff2cc,
      0xd9ead3,
      0xd0e0e3,
      0xc9daf8,
      0xcfe2f3,
      0xd9d2e9,
      0xead1dc,
    ],
    [
      0xdd7e6b,
      0xea9999,
      0xf9cb9c,
      0xffe599,
      0xb6d7a8,
      0xa2c4c9,
      0xa4c2f4,
      0x9fc5e8,
      0xb4a7d6,
      0xd5a6bd,
    ],
    [
      0xcc4125,
      0xe06666,
      0xf6b26b,
      0xffd966,
      0x93c47d,
      0x76a5af,
      0x6d9eeb,
      0x6fa8dc,
      0x8e7cc3,
      0xc27ba0,
    ],
    [
      0xa61c00,
      0xcc0000,
      0xe69138,
      0xf1c232,
      0x6aa84f,
      0x45818e,
      0x3c78d8,
      0x3d85c6,
      0x674ea7,
      0xa64d79,
    ],
    [
      0x85200c,
      0x990000,
      0xb45f06,
      0xbf9000,
      0x38761d,
      0x134f5c,
      0x1155cc,
      0x0b5394,
      0x351c75,
      0x741b47,
    ],
    [
      0x5b0f00,
      0x660000,
      0x783f04,
      0x7f6000,
      0x274e13,
      0x0c343d,
      0x1c4587,
      0x073763,
      0x20124d,
      0x4c1130,
    ],
  ];

  static WonkyColor at(int row, int col) =>
      WonkyColor('#${rows[row][col].toRadixString(16).padLeft(6, '0')}');
}
