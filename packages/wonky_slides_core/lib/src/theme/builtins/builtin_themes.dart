/// The registry of the 10 built-in themes (Slides 05 §6).
library;

import '../layout/slide_size.dart';
import 'builtin_theme_def.dart';
import 'theme_package.dart';
import 'themes/aurora.dart';
import 'themes/botanical.dart';
import 'themes/classic.dart';
import 'themes/midnight.dart';
import 'themes/mono.dart';
import 'themes/paper.dart';
import 'themes/studio.dart';
import 'themes/swiss.dart';
import 'themes/terminal.dart';
import 'themes/wonky.dart';

/// The built-in themes. Applying one copies [package] into the deck with
/// deterministic ids (`SlidesIds.themeCopyId(deck, sourceKey)`,
/// `themePartId(theme, partKey)`, 02 §2.1).
abstract final class BuiltInThemes {
  /// Key of the default theme.
  static const defaultKey = 'wonky';

  /// Definitions in Themes-panel order (stable keys, A-05-2).
  static final List<BuiltInThemeDef> all = List.unmodifiable([
    wonkyTheme,
    paperTheme,
    midnightTheme,
    swissTheme,
    terminalTheme,
    auroraTheme,
    studioTheme,
    classicTheme,
    monoTheme,
    botanicalTheme,
  ]);

  /// The keys in order.
  static List<String> get keys => [for (final t in all) t.key];

  /// The definition of [key], or `null`.
  static BuiltInThemeDef? byKey(String key) {
    for (final t in all) {
      if (t.key == key) return t;
    }
    return null;
  }

  /// The definition named by a `builtin:<key>@<version>` source key (any
  /// version), or `null`.
  static BuiltInThemeDef? bySourceKey(String sourceKey) {
    final m = RegExp(r'^builtin:([A-Za-z0-9_-]+)@(\d+)$').firstMatch(sourceKey);
    return m == null ? null : byKey(m.group(1)!);
  }

  /// The default theme (*Wonky*).
  static BuiltInThemeDef get defaultTheme => byKey(defaultKey)!;

  static final Map<String, ThemePackage> _packages = {};

  /// The package of [key] with geometry for [size] (cached), or `null`.
  static ThemePackage? package(
    String key, {
    SlideSize size = SlideSize.widescreen,
  }) {
    final def = byKey(key);
    if (def == null) return null;
    return _packages.putIfAbsent(
      '$key@${def.version}/${size.width}x${size.height}/${size.kind.name}',
      () => def.build(size: size),
    );
  }
}
