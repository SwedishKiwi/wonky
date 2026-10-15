/// `DeckThemeResolver` (Slides 05 §1 P3): resolves a theme for an appearance,
/// memoized per (content hash, appearance).
library;

import 'dart:collection';

import 'package:wonky_fonts/wonky_fonts.dart';

import '../color/color_ref.dart';
import '../fonts/slides_fonts.dart';
import '../json/json_util.dart';
import '../model/common.dart';
import '../model/deck_theme_data.dart';
import '../model/text_styles.dart';
import 'resolved_theme.dart';

/// Resolves [DeckThemeData] into [ResolvedTheme]s.
final class DeckThemeResolver {
  /// Creates a resolver keeping up to [cacheSize] resolved themes.
  DeckThemeResolver({this.cacheSize = 32});

  /// Maximum cached entries (least recently used are dropped).
  final int cacheSize;

  final LinkedHashMap<String, ResolvedTheme> _cache = LinkedHashMap();

  /// Number of cached entries (for tests).
  int get cachedCount => _cache.length;

  /// Resolves [theme] for [appearance] (cached by content hash).
  ResolvedTheme resolve(DeckThemeData theme, SlideAppearance appearance) {
    final hash = theme.contentHash;
    final key = '$hash/${appearance.name}';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final resolved = resolveUncached(theme, appearance, hash: hash);
    _cache[key] = resolved;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return resolved;
  }

  /// Resolves without the cache.
  static ResolvedTheme resolveUncached(
    DeckThemeData theme,
    SlideAppearance appearance, {
    String? hash,
  }) {
    final warnings = <ThemeIssue>[];
    final fonts = <ThemeFontRole, ResolvedFontFace>{};
    for (final role in ThemeFontRole.values) {
      final f = theme.fonts.of(role);
      final face = SlidesFonts.resolve(
        f.family,
        weight: f.weight,
        defaultCategory: SlidesFonts.categoryOfRole(role),
      );
      if (face.isFallback) {
        warnings.add(
          ThemeIssue(
            ThemeIssueSeverity.warning,
            'fontsJson.${role.name}.family',
            'unknown_font',
            '"${f.family}" is not bundled; ${face.family} is used.',
          ),
        );
      }
      fonts[role] = face;
    }

    int colorOf(ColorRef ref, String path) {
      final c = ref.resolve((k) => theme.colors.colorOf(k, appearance));
      if (c != null) return c;
      warnings.add(
        ThemeIssue(
          ThemeIssueSeverity.warning,
          path,
          'unknown_color',
          '"${ref.json}" does not exist in this theme; text1 is used.',
        ),
      );
      return theme.colors.scheme(appearance).text1;
    }

    final body = theme.textStyles.styles['body'] ?? const ThemeTextStyle();
    final styles = <String, ResolvedTextStyle>{};
    for (final key in themeTextStyleKeys) {
      final s = theme.textStyles.styles[key] ?? body;
      final fontRef = s.font ?? body.font ?? const FontRef('@body');
      final role = fontRef.role;
      final weight =
          s.weight ??
          (role != null ? theme.fonts.of(role).weight : null) ??
          400;
      final italic = s.italic ?? false;
      final family = role != null ? theme.fonts.of(role).family : fontRef.value;
      final face = SlidesFonts.resolve(
        family,
        weight: weight,
        italic: italic,
        defaultCategory: role != null
            ? SlidesFonts.categoryOfRole(role)
            : FontCategory.sans,
      );
      if (face.isFallback && role == null) {
        warnings.add(
          ThemeIssue(
            ThemeIssueSeverity.warning,
            'textStylesJson.styles.$key.font',
            'unknown_font',
            '"$family" is not bundled; ${face.family} is used.',
          ),
        );
      }
      styles[key] = ResolvedTextStyle(
        key: key,
        font: face,
        size: s.size ?? body.size ?? 40,
        lineHeight: s.lineHeight ?? body.lineHeight ?? 1.2,
        letterSpacing: s.letterSpacing ?? 0,
        color: colorOf(
          s.color ?? body.color ?? const ThemeColor('text1'),
          'textStylesJson.styles.$key.color',
        ),
        caps: s.caps,
        align: s.align ?? 'left',
        spaceBefore: s.spaceBefore ?? 0,
        spaceAfter: s.spaceAfter ?? 0,
      );
    }
    return ResolvedTheme.internal(
      theme: theme,
      appearance: appearance,
      contentHash: hash ?? theme.contentHash,
      fonts: Map.unmodifiable(fonts),
      textStyles: Map.unmodifiable(styles),
      warnings: List.unmodifiable(warnings),
    );
  }

  /// Drops every cached entry.
  void clear() => _cache.clear();
}
