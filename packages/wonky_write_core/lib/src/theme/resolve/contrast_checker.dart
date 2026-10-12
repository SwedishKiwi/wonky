/// WCAG contrast checks of resolved themes and the minimal-lightness fix
/// (06 §10.6).
library;

import 'dart:math' as math;

import '../model/color_ref.dart';
import '../model/json_util.dart';
import '../model/properties.dart';
import '../model/syntax_token.dart';
import '../model/values.dart';
import '../model/write_theme_data.dart';
import '../edit/theme_property_path.dart';
import 'base_theme.dart';
import 'oklch.dart';
import 'resolved_theme.dart';
import 'theme_resolver.dart';

/// Normal-text threshold (WCAG AA).
const double contrastNormal = 4.5;

/// Large-text threshold (WCAG AA, ≥ 18pt or ≥ 14pt bold).
const double contrastLarge = 3.0;

/// One checked foreground/background pair.
final class ContrastResult {
  /// Creates a result.
  const ContrastResult({
    required this.pairId,
    required this.variant,
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.required,
    required this.isLargeText,
  });

  /// Stable pair id, e.g. `body`, `h2`, `link`, `syntax.keyword`,
  /// `tableHeader`, `taskChecked` (see [ContrastChecker.pairIds]).
  final String pairId;

  /// The variant checked.
  final ThemeVariant variant;

  /// Effective opaque foreground (opacity composited).
  final int foreground;

  /// Effective opaque background (composited over the paper).
  final int background;

  /// WCAG ratio 1–21.
  final double ratio;

  /// Required ratio (4.5, or 3.0 for large text).
  final double required;

  /// Whether the pair's text counts as large.
  final bool isLargeText;

  /// Whether [ratio] ≥ [required].
  bool get passes => ratio + 1e-9 >= required;

  /// MCP `contrast_warnings` entry `{pair, variant, ratio, required}`
  /// (ratio rounded to 2 decimals).
  JsonMap toJson() => {
    'pair': pairId,
    'variant': variant.json,
    'ratio': normalizeJsonNumber(double.parse(ratio.toStringAsFixed(2))),
    'required': normalizeJsonNumber(required),
  };

  @override
  String toString() =>
      'ContrastResult($pairId ${variant.name}: '
      '${ratio.toStringAsFixed(2)} / $required)';
}

/// A proposed fix: set [path] (a `write.theme.setProperty` path, already
/// variant-qualified) to the hex [value].
final class ContrastFix {
  /// Creates a fix.
  const ContrastFix({
    required this.pairId,
    required this.variant,
    required this.path,
    required this.value,
    required this.ratio,
  });

  /// The fixed pair.
  final String pairId;

  /// The fixed variant.
  final ThemeVariant variant;

  /// Property path to change (e.g. `palette.text`, `dark.palette.muted`,
  /// `elements.h2.color`, `dark.syntax.comment.color`).
  final String path;

  /// New color as `#rrggbb`.
  final String value;

  /// Contrast ratio after the fix.
  final double ratio;

  /// JSON form.
  JsonMap toJson() => {
    'pair': pairId,
    'variant': variant.json,
    'path': path,
    'value': value,
    'ratio': normalizeJsonNumber(double.parse(ratio.toStringAsFixed(2))),
  };

  @override
  String toString() => 'ContrastFix($pairId → $path = $value)';
}

/// Where a pair's foreground color is defined (for fixes).
typedef _Source = ({ThemeElement? element, String key, SyntaxToken? token});

/// Computes contrast ratios for the pairs of 06 §10.6 and fixes failures.
final class ContrastChecker {
  /// Creates a checker using [resolver].
  ContrastChecker({ThemeResolver? resolver})
    : resolver = resolver ?? ThemeResolver.instance;

  /// The resolver.
  final ThemeResolver resolver;

  /// All pair ids in check order.
  static final List<String> pairIds = [
    'body',
    for (var l = 1; l <= 6; l++) 'h$l',
    'caption',
    'header',
    'footer',
    'link',
    'mention',
    'inlineCode',
    'codeBlock',
    for (final t in SyntaxToken.values) 'syntax.${t.name}',
    'blockquote',
    'tableHeader',
    'tableCell',
    'tableZebra',
    'taskChecked',
  ];

  /// Checks [theme] in both variants (light first).
  List<ContrastResult> check(WriteThemeData theme) => [
    for (final v in ThemeVariant.values)
      ...checkResolved(resolver.resolve(theme, v)),
  ];

  /// The failing pairs of [theme] in both variants.
  List<ContrastResult> warnings(WriteThemeData theme) => [
    for (final r in check(theme))
      if (!r.passes) r,
  ];

  /// MCP `contrast_warnings` for [theme].
  List<JsonMap> warningsJson(WriteThemeData theme) => [
    for (final w in warnings(theme)) w.toJson(),
  ];

  /// Checks one resolved variant.
  List<ContrastResult> checkResolved(ResolvedWriteTheme t) {
    final paper = t.page.paperColor | 0xff000000;
    final out = <ContrastResult>[];
    void pair(String id, int fg, int? bg, bool large, {int? under}) {
      final ground = under == null ? paper : compositeOver(under, paper);
      final b = bg == null ? ground : compositeOver(bg, ground);
      final f = compositeOver(fg, b);
      out.add(
        ContrastResult(
          pairId: id,
          variant: t.variant,
          foreground: f,
          background: b,
          ratio: contrastRatio(f, b),
          required: large ? contrastLarge : contrastNormal,
          isLargeText: large,
        ),
      );
    }

    pair(
      'body',
      t.body.style.color,
      t.body.box.background,
      t.body.style.isLargeText,
    );
    for (final h in t.headings) {
      pair('h${h.level}', h.style.color, h.box.background, h.style.isLargeText);
    }
    final cap = t.image.caption.style;
    pair('caption', cap.color, null, cap.isLargeText);
    pair('header', t.header.style.color, null, t.header.style.isLargeText);
    pair('footer', t.footer.style.color, null, t.footer.style.isLargeText);
    pair('link', t.link.color, t.body.box.background, t.body.style.isLargeText);
    pair('mention', t.mention.color, t.mention.background, false);
    final inlineLarge = t.body.style.fontSize * t.inlineCode.sizeRatio >= 18;
    pair(
      'inlineCode',
      t.inlineCode.color,
      t.inlineCode.background,
      inlineLarge,
    );
    final code = t.codeBlock;
    pair(
      'codeBlock',
      code.style.color,
      code.box.background,
      code.style.isLargeText,
    );
    for (final e in t.syntax.entries) {
      pair(
        'syntax.${e.key.name}',
        e.value.color,
        code.box.background,
        code.style.isLargeText,
      );
    }
    final q = t.blockquote;
    pair('blockquote', q.style.color, q.box.background, q.style.isLargeText);
    final tb = t.table;
    pair(
      'tableHeader',
      tb.headerStyle.color,
      tb.headerBackground,
      tb.headerStyle.isLargeText,
    );
    pair('tableCell', tb.style.color, tb.box.background, tb.style.isLargeText);
    if (tb.zebra) {
      pair('tableZebra', tb.style.color, tb.zebraColor, tb.style.isLargeText);
    }
    pair(
      'taskChecked',
      withOpacity(t.task.checkedColor, t.task.checkedOpacity),
      null,
      t.task.style.isLargeText,
    );
    return out;
  }

  static _Source _sourceOf(String pairId) {
    if (pairId.startsWith('syntax.')) {
      final token = SyntaxToken.fromJsonName(pairId.substring(7));
      return (element: null, key: 'color', token: token);
    }
    final level = RegExp(r'^h([1-6])$').firstMatch(pairId);
    if (level != null) {
      return (
        element: ThemeElement.heading(int.parse(level.group(1)!)),
        key: 'color',
        token: null,
      );
    }
    return switch (pairId) {
      'body' => (element: ThemeElement.body, key: 'color', token: null),
      'caption' => (
        element: ThemeElement.image,
        key: 'caption.color',
        token: null,
      ),
      'header' => (element: ThemeElement.header, key: 'color', token: null),
      'footer' => (element: ThemeElement.footer, key: 'color', token: null),
      'link' => (element: ThemeElement.link, key: 'color', token: null),
      'mention' => (element: ThemeElement.mention, key: 'color', token: null),
      'inlineCode' => (
        element: ThemeElement.inlineCode,
        key: 'color',
        token: null,
      ),
      'codeBlock' => (
        element: ThemeElement.codeBlock,
        key: 'color',
        token: null,
      ),
      'blockquote' => (
        element: ThemeElement.blockquote,
        key: 'color',
        token: null,
      ),
      'tableHeader' => (
        element: ThemeElement.table,
        key: 'headerColor',
        token: null,
      ),
      'tableCell' ||
      'tableZebra' => (element: ThemeElement.table, key: 'color', token: null),
      'taskChecked' => (
        element: ThemeElement.task,
        key: 'checkedText.color',
        token: null,
      ),
      _ => throw ArgumentError.value(pairId, 'pairId', 'Unknown contrast pair'),
    };
  }

  /// Proposes a fix for [pairId] in [variant]: the foreground's OKLCH
  /// lightness is changed minimally (darker or lighter, whichever needs the
  /// smaller change) until the pair passes. Returns `null` when the pair
  /// already passes or no lightness passes.
  ///
  /// The change targets where the color is defined: a palette reference
  /// changes that palette entry (`palette.<key>` / `dark.palette.<key>`),
  /// a literal changes the element property in the variant's layer.
  ContrastFix? fix(WriteThemeData theme, String pairId, ThemeVariant variant) {
    final resolved = resolver.resolve(theme, variant);
    final result = checkResolved(resolved).where((r) => r.pairId == pairId);
    if (result.isEmpty || result.first.passes) return null;
    final r = result.first;
    final source = _sourceOf(pairId);
    final opacity = pairId == 'taskChecked'
        ? resolved.task.checkedOpacity
        : 1.0;
    final rawFg = _rawForeground(resolved, pairId);
    final fixed = _minimalLightness(rawFg, r.background, r.required, opacity);
    if (fixed == null) return null;
    final path = _targetPath(theme, source, variant);
    final newFg = compositeOver(withOpacity(fixed, opacity), r.background);
    return ContrastFix(
      pairId: pairId,
      variant: variant,
      path: path,
      value: argbToHex(fixed),
      ratio: contrastRatio(newFg, r.background),
    );
  }

  /// Applies [fix] and returns the updated theme.
  WriteThemeData applyFix(WriteThemeData theme, ContrastFix fix) {
    final json = ThemePropertyPath.set(theme.toJson(), fix.path, fix.value);
    return WriteThemeData.fromJson(json);
  }

  int _rawForeground(ResolvedWriteTheme t, String pairId) {
    if (pairId.startsWith('syntax.')) {
      return t.syntax[SyntaxToken.fromJsonName(pairId.substring(7))]!.color;
    }
    final level = RegExp(r'^h([1-6])$').firstMatch(pairId);
    if (level != null) return t.heading(int.parse(level.group(1)!)).style.color;
    return switch (pairId) {
      'body' => t.body.style.color,
      'caption' => t.image.caption.style.color,
      'header' => t.header.style.color,
      'footer' => t.footer.style.color,
      'link' => t.link.color,
      'mention' => t.mention.color,
      'inlineCode' => t.inlineCode.color,
      'codeBlock' => t.codeBlock.style.color,
      'blockquote' => t.blockquote.style.color,
      'tableHeader' => t.table.headerStyle.color,
      'tableCell' || 'tableZebra' => t.table.style.color,
      'taskChecked' => t.task.checkedColor,
      _ => throw ArgumentError.value(pairId, 'pairId'),
    };
  }

  static int? _minimalLightness(
    int fg,
    int background,
    double required,
    double opacity,
  ) {
    final base = Oklch.fromArgb(fg | 0xff000000);
    bool ok(int c) =>
        contrastRatio(
          compositeOver(withOpacity(c, opacity), background),
          background,
        ) >=
        required;
    for (var step = 1; step <= 200; step++) {
      final d = step * 0.005;
      final candidates = [
        if (base.l - d >= 0) base.copyWith(l: base.l - d),
        if (base.l + d <= 1) base.copyWith(l: base.l + d),
      ];
      for (final c in candidates) {
        final argb = c.toArgb() | 0xff000000;
        if (ok(argb)) return argb;
      }
      if (base.l - d < 0 && base.l + d > 1) break;
    }
    for (final extreme in const [0xff000000, 0xffffffff]) {
      if (ok(extreme)) return extreme;
    }
    return null;
  }

  /// The variant-qualified path to change for [source].
  static String _targetPath(
    WriteThemeData theme,
    _Source source,
    ThemeVariant variant,
  ) {
    final dark = variant == ThemeVariant.dark;
    final prefix = dark ? 'dark.' : '';
    ColorRef? found;
    if (source.token != null) {
      final t = source.token!;
      found =
          (dark ? (theme.dark.syntax?[t])?.color('color') : null) ??
          theme.syntax[t]?.color('color') ??
          BaseTheme.instance.syntax(t)?.color('color');
      if (found?.kind == ColorRefKind.palette) {
        return '${prefix}palette.${found!.paletteKey!.name}';
      }
      return '${prefix}syntax.${t.name}.color';
    }
    final element = source.element!;
    final layers = <PropertyBag>[
      if (dark) theme.dark.elements[element] ?? PropertyBag.empty,
      if (dark && element.headingLevel != null)
        theme.dark.elements[ThemeElement.headings] ?? PropertyBag.empty,
      theme.element(element),
      if (element.headingLevel != null) theme.element(ThemeElement.headings),
      if (element == ThemeElement.header || element == ThemeElement.footer)
        theme.page.bag('headerFooter') ?? PropertyBag.empty,
      BaseTheme.instance.element(element),
      if (element.headingLevel != null)
        BaseTheme.instance.element(ThemeElement.headings),
      if (element == ThemeElement.header || element == ThemeElement.footer)
        BaseTheme.instance.page.bag('headerFooter') ?? PropertyBag.empty,
      if (source.key == 'color' && _inheritsBodyColor(element)) ...[
        if (dark) theme.dark.elements[ThemeElement.body] ?? PropertyBag.empty,
        theme.element(ThemeElement.body),
        BaseTheme.instance.element(ThemeElement.body),
      ],
    ];
    for (final bag in layers) {
      found = _lookup(bag, source.key);
      if (found != null) break;
    }
    if (found?.kind == ColorRefKind.palette) {
      return '${prefix}palette.${found!.paletteKey!.name}';
    }
    return '${prefix}elements.${element.name}.${source.key}';
  }

  static bool _inheritsBodyColor(ThemeElement e) => switch (e) {
    ThemeElement.link ||
    ThemeElement.mention ||
    ThemeElement.inlineCode ||
    ThemeElement.task => false,
    _ => true,
  };

  static ColorRef? _lookup(PropertyBag bag, String key) {
    final parts = key.split('.');
    PropertyBag? b = bag;
    for (var i = 0; i < parts.length - 1; i++) {
      b = b?.bag(parts[i]);
    }
    return b?.color(parts.last);
  }

  /// The ratio needed to pass for text of [fontSize] pt and [fontWeight].
  static double requiredFor(double fontSize, int fontWeight) =>
      fontSize >= 18 || (fontSize >= 14 && fontWeight >= 700)
      ? contrastLarge
      : contrastNormal;

  /// Convenience: WCAG ratio of two opaque ARGB colors.
  static double ratio(int a, int b) => contrastRatio(a, b);

  /// The higher of the two ratios a color can reach against [background]
  /// (black or white text), useful for picking legible overlay text.
  static double bestPossible(int background) => math.max(
    contrastRatio(0xff000000, background),
    contrastRatio(0xffffffff, background),
  );
}
