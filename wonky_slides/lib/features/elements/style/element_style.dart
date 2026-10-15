import 'dart:convert';

import 'package:flutter/widgets.dart' show Color;

import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../selection/slide_elements.dart';
import '../../canvas/slide_canvas_controller.dart' show selectionOf;

/// Style JSON helpers of the element format commands and sections
/// (Slides 02 §5.2–§5.4; 03 §6.3, §6.4, §9): the kinds a style applies
/// to, merge patches of `fillJson` / `strokeJson` / `effectsJson`, color
/// refs from the color picker and the theme swatches.
abstract final class ElementStyle {
  /// Kinds with a `fillJson` (icons: the background behind the glyph).
  static bool hasFill(ElementKind k) => switch (k) {
    ElementKind.text || ElementKind.shape || ElementKind.icon => true,
    _ => false,
  };

  /// Kinds with a `strokeJson` (icons: the glyph color).
  static bool hasStroke(ElementKind k) => switch (k) {
    ElementKind.text ||
    ElementKind.shape ||
    ElementKind.line ||
    ElementKind.image ||
    ElementKind.icon => true,
    _ => false,
  };

  /// Kinds that hold text (box text properties and runs).
  static bool hasText(ElementKind k) =>
      k == ElementKind.text || k == ElementKind.shape;

  /// A style column's JSON object, or null (null, invalid or not an
  /// object).
  static Map<String, Object?>? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final v = jsonDecode(json);
      return v is Map ? v.cast<String, Object?>() : null;
    } on FormatException {
      return null;
    }
  }

  /// Encodes a style object with `"v": 1` (null for null).
  static String? encode(Map<String, Object?>? style) =>
      style == null ? null : jsonEncode({'v': 1, ...style..remove('v')});

  /// Applies an RFC 7386 merge [patch] to [base] (null values remove).
  static Map<String, Object?> merge(
    Map<String, Object?>? base,
    Map<String, Object?> patch,
  ) {
    final out = <String, Object?>{...?base};
    for (final MapEntry(:key, :value) in patch.entries) {
      if (value == null) {
        out.remove(key);
      } else if (value is Map && out[key] is Map) {
        out[key] = merge(
          (out[key] as Map).cast<String, Object?>(),
          value.cast<String, Object?>(),
        );
      } else {
        out[key] = value;
      }
    }
    return out;
  }

  /// Whether [color] is a valid `ColorRef` string.
  static bool validColor(Object? color) => ColorRef.tryParse(color) != null;

  /// Whether `fillJson` [fill] is valid (02 §5.2).
  static String? fillError(Map<String, Object?> fill) {
    final sink = IssueSink();
    final f = SlideFill.fromJson({'v': 1, ...fill}, 'fill', sink);
    if (f == null || sink.hasErrors) {
      return sink.errors.isEmpty
          ? 'Invalid fill'
          : sink.errors.map((i) => '${i.path}: ${i.message}').join('; ');
    }
    return null;
  }

  /// Whether `strokeJson` [stroke] is valid (02 §5.3).
  static String? strokeError(Map<String, Object?> stroke) {
    final sink = IssueSink();
    final s = SlideStroke.fromJson({'v': 1, ...stroke}, 'stroke', sink);
    if (s == null || sink.hasErrors) {
      return sink.errors.isEmpty
          ? 'Invalid border'
          : sink.errors.map((i) => '${i.path}: ${i.message}').join('; ');
    }
    return null;
  }

  /// The stored color of a picked color: `theme:<key>` for theme swatches,
  /// else `#RRGGBB` (`#RRGGBBAA` with alpha).
  static String colorRefOf(WonkyColor c) {
    final ref = c.themeRef;
    if (ref != null) return ref.startsWith('theme:') ? ref : 'theme:$ref';
    return c.hex.toUpperCase();
  }

  /// A picker value for stored color [ref] in [theme].
  static WonkyColor? pickerValueOf(String? ref, ResolvedTheme? theme) {
    final c = ColorRef.tryParse(ref);
    if (c == null || theme == null) return null;
    final argb = theme.color(c);
    final hex = WonkyColor.fromColor(_color(argb)).hex;
    return WonkyColor(hex, themeRef: ref!.startsWith('theme:') ? ref : null);
  }

  /// The "Theme colors" row of the pickers (05 §2.2 keys).
  static List<WonkyThemeSwatch> swatches(
    ResolvedTheme? theme,
    SlidesLocalizations l,
  ) {
    if (theme == null) return const [];
    return [
      for (final key in themeColorKeys)
        if (theme.colorOf(key) case final argb?)
          WonkyThemeSwatch(
            color: WonkyColor(
              WonkyColor.fromColor(_color(argb)).hex,
              themeRef: 'theme:$key',
            ),
            name: themeColorLabel(l, key),
          ),
    ];
  }

  /// The localized name of theme color [key].
  static String themeColorLabel(SlidesLocalizations l, String key) =>
      switch (key) {
        'bg1' => l.themeColorBg1,
        'bg2' => l.themeColorBg2,
        'text1' => l.themeColorText1,
        'text2' => l.themeColorText2,
        'link' => l.themeColorLink,
        _ when key.startsWith('accent') => l.themeColorAccent(
          int.tryParse(key.substring(6)) ?? 1,
        ),
        _ => key,
      };

  static Color _color(int argb) => Color(argb);

  // ------------------------------------------------------------ selection

  /// The elements a format command applies to: [ids] (MCP) or the
  /// selection, resolved on the current slide.
  static List<ResolvedElement> targets(
    DeckEditorController ed, [
    List<String>? ids,
  ]) {
    final els = selectionOf(ed).elements;
    if (els == null) return const [];
    return [for (final id in ids ?? ed.selectedElementIds) ?els[id]];
  }

  /// The theme of the current slide.
  static ResolvedTheme? themeOf(DeckEditorController ed) =>
      selectionOf(ed).slide?.theme;

  /// The theme's default object style of [kind] (05 §2.7), or null.
  static ObjectStyleDefaults? defaultsOf(ResolvedTheme theme, ElementKind k) =>
      switch (k) {
        ElementKind.text => theme.shapeStyles.text,
        ElementKind.shape => theme.shapeStyles.shape,
        ElementKind.line => theme.shapeStyles.line,
        ElementKind.icon => theme.shapeStyles.icon,
        _ => null,
      };

  /// The effective fill of [e] (own or the theme default), or null.
  static SlideFill? effectiveFill(ResolvedElement e, ResolvedTheme theme) {
    final own = e.fill;
    if (own != null) {
      final f = SlideFill.fromJson(own, 'fill', IssueSink());
      if (f != null) return f;
    }
    return defaultsOf(theme, e.record.kind)?.fill;
  }

  /// The effective stroke of [e] (own over the theme default), or null.
  static SlideStroke? effectiveStroke(ResolvedElement e, ResolvedTheme theme) {
    final own = e.stroke;
    final base = defaultsOf(theme, e.record.kind)?.stroke;
    if (own == null) return base;
    final merged = merge(base?.toJson(), own);
    return SlideStroke.fromJson(merged, 'stroke', IssueSink());
  }

  /// The ARGB of [e]'s solid fill, or null (none, gradient, image).
  static int? fillArgb(ResolvedElement e, ResolvedTheme theme) =>
      switch (effectiveFill(e, theme)) {
        SolidFill(:final color) => theme.color(color),
        GradientFill(:final stops) when stops.isNotEmpty => theme.color(
          stops.first.color,
        ),
        _ => null,
      };

  /// The ARGB of [e]'s stroke (null = none).
  static int? strokeArgb(ResolvedElement e, ResolvedTheme theme) {
    final s = effectiveStroke(e, theme);
    if (s == null || s.isNone) return null;
    final c = s.color;
    return c == null ? theme.colorOf('text1') : theme.color(c);
  }

  /// The shared value of [read] over [els], or null when mixed or empty.
  static T? common<T>(
    Iterable<ResolvedElement> els,
    T? Function(ResolvedElement) read,
  ) {
    T? out;
    var first = true;
    for (final e in els) {
      final v = read(e);
      if (first) {
        out = v;
        first = false;
      } else if (v != out) {
        return null;
      }
    }
    return out;
  }

  /// Whether every element in [els] is selectable on the canvas.
  static bool allSelectable(Iterable<ResolvedElement> els) =>
      els.every(SlideElements.selectable);

  /// The theme's shape quick styles (03 §6.3): the theme's own, else the
  /// eight defaults — solid accent fills 1–6, an outline and a soft tint.
  static List<QuickStyle> quickStyles(ResolvedTheme? theme) {
    final own = theme?.shapeStyles.quickStyles ?? const [];
    if (own.isNotEmpty) return own;
    SlideFill fill(Map<String, Object?> j) =>
        SlideFill.fromJson({'v': 1, ...j}, 'fill', IssueSink())!;
    SlideStroke stroke(Map<String, Object?> j) =>
        SlideStroke.fromJson({'v': 1, ...j}, 'stroke', IssueSink())!;
    return [
      for (var i = 1; i <= 6; i++)
        QuickStyle(
          fill: fill({'type': 'solid', 'color': 'theme:accent$i'}),
          stroke: stroke({'type': 'none'}),
          textColor: ColorRef.parse('theme:bg1'),
        ),
      QuickStyle(
        fill: fill({'type': 'none'}),
        stroke: stroke({'color': 'theme:accent1', 'width': 4}),
        textColor: ColorRef.parse('theme:text1'),
      ),
      QuickStyle(
        fill: fill({'type': 'solid', 'color': 'theme:accent1/alpha:0.15'}),
        stroke: stroke({'color': 'theme:accent1', 'width': 2}),
        textColor: ColorRef.parse('theme:text1'),
      ),
    ];
  }
}
